#!/usr/bin/env python3
"""GUARD-05 — ARB key + placeholder parity across 6 language files.

Per CONTEXT 34-CONTEXT.md D-13, D-14, D-15:
  D-13 — fail on any non-@ key-set divergence across {fr, en, de, es, it, pt}
         (union must equal each keyset) and on any ICU placeholder NAME drift
         in a translated value.
  D-14 — zero external deps, pure stdlib (json + re + argparse).
  D-15 — dead Dart-side orphan keys are out of scope (1864 per CONCERNS T5);
         this lint checks CROSS-LANGUAGE consistency only.

FR (app_fr.arb) is the Flutter template per apps/mobile/l10n.yaml
(`template-arb-file: app_fr.arb`) so only FR carries `@key` placeholder
metadata. The other 5 langs translate the plain `key: "value"` entry.
Placeholder parity is therefore:
  - FR `@key.placeholders` keys = the EXPECTED set of placeholder names.
  - For each non-FR lang, the VALUE of `key` must reference those same
    placeholder names (order-insensitive) via ICU `{name}` tokens.

ICU placeholder extraction uses RESEARCH Pattern 4 regex which captures
the first identifier inside `{...}` and filters out ICU type keywords
(plural, select, number, DateTime, date, time, ordinal). Pitfall 3:
plural/select inner braces (`{1 item}`, `{il}`) never match because the
leading char is a digit or inner ICU literal, not a placeholder identifier
(`[A-Za-z_]`). Inner `{count}` re-uses the outer name and dedupes via set.

Exit codes:
  0 — parity OK.
  1 — divergence (stderr lists missing keys + placeholder drifts).

Technical English only — dev-facing diagnostics (Pitfall 8, no i18n).
Python 3.9 compatible (dev) / 3.11 forward compat (CI).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

# 6 supported languages — CLAUDE.md §5 NEVER #1 authoritative set.
LANGS: List[str] = ["fr", "en", "de", "es", "it", "pt"]

# Default production l10n dir. `parents[2]` = repo root / tools / checks -> root.
DEFAULT_L10N_DIR: Path = (
    Path(__file__).resolve().parents[2] / "apps" / "mobile" / "lib" / "l10n"
)

# Identifier regex — a bare ICU name token at the CURRENT brace scope.
_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*", re.UNICODE)

# NOTE: the research-suggested ICU_KEYWORDS filter is intentionally NOT
# applied to emitted placeholder NAMES. Reason: MINT production ARB files
# use every ICU type keyword as a legitimate user-chosen placeholder name
# somewhere (e.g. `stepOcrContinueWith` has a placeholder literally named
# `plural`; `mortgageJourneyStepLabel` uses `number`; `mintHomeDeltaSince`
# uses `date`). Filtering at emission time would FALSE-NEGATIVE those keys.
#
# The walker below is STRUCTURALLY safe: type keywords appearing in type
# position (after the first comma of a `{name, type, ...}` form) are
# consumed by the branch that parses the `type_token` and are NEVER added
# to `names`. Only identifiers at genuine NAME position reach `names.add`.
#
# The set below is retained for documentation + defensive filtering of the
# two TYPE-ONLY tokens (`plural` / `select`) that — by their structural
# position — never legitimately appear as placeholder names in ARB VALUE
# strings even though they CAN be declared as @key.placeholders names in
# MINT (the value-side `{plural}` of that declaration IS a name reference,
# not a type marker). Keeping the set empty avoids any risk of false
# negatives; the walker takes care of structure.
ICU_TYPE_ONLY_KEYWORDS: Set[str] = set()


def extract_placeholders(value: str) -> Set[str]:
    """Return the set of ICU placeholder names referenced in an ARB value.

    Implements a depth-aware ICU walker (not a regex) — RESEARCH Pattern 4's
    one-line regex was naive about select variants: a select form like
    `{sex, select, male {il} female {elle}}` has inner `{il}` / `{elle}`
    where `il`/`elle` are LITERAL TEXT, not placeholder names. The single
    regex `\\{\\s*([A-Za-z_]...)` captures them falsely.

    Correct semantics per ICU MessageFormat (icu.unicode.org) + Flutter docs:
      - Placeholder names live at the OPENING of a `{` clause whose content
        is `name`, `name, type`, or `name, type, arg`.
      - Inside a `plural` or `select` clause, inner `{...}` are variant
        *bodies* (literal text), not placeholders. EXCEPTION: a placeholder
        reference like `{count}` inside the variant body is still a
        placeholder (ICU syntax "quoted placeholder in a variant").

    Algorithm (single pass, O(n)):
      - Walk char by char. Track brace depth and a stack of "clause kinds"
        per open brace:
          * kind="placeholder" — opened by `{` followed by an identifier at
            the root OR inside a variant body. The identifier is emitted.
          * kind="variant_body" — opened by `{` following a variant label
            (`one`, `other`, `male`, etc.) inside a plural/select clause.
            Content is literal text; inner `{` opens a new placeholder or
            nested variant.
      - A placeholder whose next non-ws token is `,` followed by `plural`
        or `select` becomes a "plural_or_select" scope; its `{variant_label}
        {body}` pairs are traversed.

    Supported forms (all 5 from Flutter docs + nested):
      - Simple:   `{name}`                                  -> {"name"}
      - Typed:    `{amount, number, currency}`              -> {"amount"}
      - Plural:   `{count, plural, one {1 item} other {{count} items}}`
                                                            -> {"count"}
      - Select:   `{sex, select, male {il} female {elle}}`  -> {"sex"}
      - DateTime: `{timestamp, DateTime, yMd}`              -> {"timestamp"}

    Type keywords (plural/select/number/date/DateTime/time/ordinal) are NOT
    filtered at emission — MINT production ARB uses every one as a legitimate
    placeholder name somewhere. The walker's structural dispatch prevents
    type tokens at TYPE position from ever reaching `names.add`, so no
    filter is needed. See `ICU_TYPE_ONLY_KEYWORDS` module-level comment.
    """
    names: Set[str] = set()
    n = len(value)
    i = 0

    # Stack element: dict with keys:
    #   "kind": "placeholder" | "plural_or_select" | "variant_body"
    stack: List[Dict] = []

    while i < n:
        ch = value[i]

        # Handle ICU escape `{{` / `}}` (Flutter allows literal braces).
        if ch == "{" and i + 1 < n and value[i + 1] == "{":
            i += 2
            continue
        if ch == "}" and i + 1 < n and value[i + 1] == "}":
            i += 2
            continue

        if ch == "{":
            # Peek at the current outer scope to decide kind.
            outer_kind = stack[-1]["kind"] if stack else "root"

            if outer_kind == "plural_or_select":
                # We are between variants. Next non-ws token is a variant
                # LABEL (one/other/male/=0/...), followed by whitespace,
                # followed by `{body}`. But we are already at `{` — so this
                # `{` opens the body directly (not possible here — variants
                # are always LABEL followed by `{body}`, so this `{` would
                # only appear after skipping the label). The label-skip
                # happens when we detect we're inside a plural_or_select.
                # Safety fallback: treat as variant_body.
                stack.append({"kind": "variant_body"})
                i += 1
                continue

            # outer_kind in {"root", "variant_body", "placeholder"}:
            # `{` opens a new placeholder clause. Inside a variant_body,
            # inner `{ident}` is a referenced placeholder (e.g. `{count}`
            # inside a plural `other {{count} items}`).
            # Try to parse `{` ws* IDENT ws* (',' | '}' ).
            j = i + 1
            while j < n and value[j].isspace():
                j += 1
            m = _IDENT.match(value, j)
            if m is None:
                # Not a placeholder (e.g. `{#}` or `{1 item}` in plural).
                # Inside a variant_body, `{1 item}` has no identifier, so
                # it's literal text with a brace-counted body. Treat as
                # opaque `variant_body` to track depth.
                stack.append({"kind": "variant_body"})
                i += 1
                continue

            ident = m.group(0)
            end = m.end()
            # Skip trailing whitespace.
            k = end
            while k < n and value[k].isspace():
                k += 1

            if k < n and value[k] == "}":
                # Simple placeholder `{ident}`. Always emit — `{plural}` /
                # `{count}` / `{date}` are all legitimate name references
                # (MINT uses each in production ARB).
                names.add(ident)
                # Consume the closing `}` as part of this token.
                i = k + 1
                continue

            if k < n and value[k] == ",":
                # Typed / plural / select form: `{ident, type, ...}`.
                # Emit the NAME (first ident); the type token is consumed
                # separately below and is never added to `names`.
                names.add(ident)
                # Parse the type token.
                k += 1  # skip comma
                while k < n and value[k].isspace():
                    k += 1
                tm = _IDENT.match(value, k)
                type_token = tm.group(0) if tm else ""
                if type_token in ("plural", "select"):
                    # Enter plural_or_select scope. The walker will now
                    # look for variant labels + bodies.
                    stack.append({"kind": "plural_or_select"})
                    i = tm.end() if tm else k
                    continue
                # Typed form (number/DateTime/date/time/ordinal): treat the
                # rest as opaque content of a placeholder clause.
                stack.append({"kind": "placeholder"})
                i = tm.end() if tm else k
                continue

            # Malformed — treat as opaque to keep walker moving.
            stack.append({"kind": "variant_body"})
            i += 1
            continue

        if ch == "}":
            if stack:
                stack.pop()
            i += 1
            continue

        # Inside a plural_or_select scope, we're scanning variant labels
        # like `one`, `other`, `=0`, `male`. When we hit `{`, the body
        # opens and we push variant_body; the identifier scanner above
        # handles `{count}` references inside that body correctly.
        # For this char, just advance.
        i += 1

    return names


def load_arb(path: Path) -> Dict:
    """Read and parse an ARB file (JSON). Raise on malformed input."""
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def check_parity(l10n_dir: Path) -> Tuple[int, List[str]]:
    """Verify key + placeholder parity across the 6 ARB files.

    Returns:
        (exit_code, messages). exit_code == 0 on pass, 1 on any divergence.
        messages preserves order: failures first, summary last on success.
    """
    messages: List[str] = []

    # Phase 1: load all 6 files. Any missing file or malformed JSON is
    # fail-fast with a human-readable path in the diagnostic.
    data: Dict[str, Dict] = {}
    for lang in LANGS:
        path = l10n_dir / "app_{}.arb".format(lang)
        if not path.exists():
            messages.append(
                "[arb_parity] FAIL - missing file: {}".format(path)
            )
            return 1, messages
        try:
            data[lang] = load_arb(path)
        except json.JSONDecodeError as e:
            messages.append(
                "[arb_parity] FAIL - malformed JSON in {}: {}".format(path, e)
            )
            return 1, messages

    # Phase 2: non-@ key parity (D-13). Build keysets excluding @-prefixed
    # metadata entries. Union must equal every individual keyset.
    keysets: Dict[str, Set[str]] = {
        lang: {k for k in d if not k.startswith("@")} for lang, d in data.items()
    }
    union: Set[str] = set().union(*keysets.values())

    fail = False
    for lang, ks in keysets.items():
        missing = union - ks
        if missing:
            for k in sorted(missing)[:10]:
                messages.append(
                    "[arb_parity] FAIL - key '{}' missing in app_{}.arb".format(
                        k, lang
                    )
                )
            if len(missing) > 10:
                messages.append(
                    "  ... and {} more in app_{}.arb".format(
                        len(missing) - 10, lang
                    )
                )
            fail = True

    # Phase 3: placeholder parity (D-13). FR template is source-of-truth.
    # For each FR @key with `placeholders`, verify each non-FR lang's VALUE
    # of the plain key references all expected placeholder names.
    fr = data["fr"]
    placeholder_keys_checked = 0
    for at_key, meta in fr.items():
        if not at_key.startswith("@") or not isinstance(meta, dict):
            continue
        phs = meta.get("placeholders")
        if not phs:
            continue
        placeholder_keys_checked += 1
        plain_key = at_key[1:]
        expected: Set[str] = set(phs.keys())
        for lang in LANGS:
            value = data[lang].get(plain_key)
            if not value or not isinstance(value, str):
                # Key-missing is already flagged in Phase 2; skip silently
                # here so we emit one FAIL per divergence, not two.
                continue
            actual = extract_placeholders(value)
            if actual != expected:
                missing_ph = expected - actual
                extra_ph = actual - expected
                parts = [
                    "[arb_parity] FAIL - key '{}' placeholder drift in "
                    "app_{}.arb".format(plain_key, lang)
                ]
                if missing_ph:
                    parts.append("missing={}".format(sorted(missing_ph)))
                if extra_ph:
                    parts.append("extra={}".format(sorted(extra_ph)))
                messages.append(" ".join(parts))
                fail = True

    if fail:
        return 1, messages

    messages.append(
        "[arb_parity] OK - 6 ARB files parity OK "
        "(non-@ keys={}, placeholder-bearing @keys checked={})".format(
            len(union), placeholder_keys_checked
        )
    )
    return 0, messages


def main(argv: List[str] = None) -> int:
    ap = argparse.ArgumentParser(
        description="GUARD-05 - ARB parity lint (6 langs, stdlib only).",
    )
    ap.add_argument(
        "--dir",
        default=str(DEFAULT_L10N_DIR),
        help=(
            "Directory containing app_{{fr,en,de,es,it,pt}}.arb "
            "(default: apps/mobile/lib/l10n/)"
        ),
    )
    args = ap.parse_args(argv)

    rc, messages = check_parity(Path(args.dir))
    for m in messages:
        stream = sys.stderr if "[arb_parity] FAIL" in m else sys.stdout
        print(m, file=stream)
    return rc


if __name__ == "__main__":
    sys.exit(main())
