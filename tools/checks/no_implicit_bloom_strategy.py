#!/usr/bin/env python3
"""CI gate: every MintTrameConfiance instantiation must pass an explicit
`bloomStrategy:` named argument.

Phase 12 Plan 12-03 — defense-in-depth grep gate for D-05 (BloomStrategy
discipline). The MTC constructors already mark `bloomStrategy` as a
`required` named parameter, so the Dart compiler enforces presence at
build time. This script is the redundant CI net that:

  * catches accidental introduction of a non-required overload,
  * catches reflection-based / generated callsites that bypass the
    compile-time check,
  * provides a fast, language-agnostic signal in CI without booting the
    Flutter analyzer.

Default policy from D-05 (informational, NOT enforced here):
  * Feed contexts (lists, scrollables, response_card_widget,
    narrative_header) → BloomStrategy.onlyIfTopOfList
  * Standalone (single card, isolated screen, modal) →
    BloomStrategy.firstAppearance

The lint does NOT enforce WHICH strategy is chosen — only that one is
explicitly named at every callsite.

Scope:
  Walks `apps/mobile/lib/` recursively, reads every `.dart` file.
  For each `MintTrameConfiance.<ctor>(` instantiation, parses the
  parenthesised argument list (paren-balanced) and verifies that
  `bloomStrategy:` appears inside.

Exclusions:
  * `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart` — the MTC
    definition itself (factories, private constructor, doc comments).
  * Any path under `apps/mobile/test/` — tests can construct arbitrary
    fixtures and may exercise edge cases.

Escape valve:
  If a single line legitimately needs to bypass this rule (e.g. a code
  generator emitting a default), prefix the line above with the comment
  `// BloomStrategy: explicit-default` and the gate will pass that hit.

Exit codes:
  0 — clean (every instantiation passes `bloomStrategy:`)
  1 — at least one instantiation missing `bloomStrategy:`

Usage:
  python3 tools/checks/no_implicit_bloom_strategy.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

SCAN_ROOT = "apps/mobile/lib"

EXCLUDE_FILES = {
    "apps/mobile/lib/widgets/trust/mint_trame_confiance.dart",
}

EXCLUDE_PREFIXES = (
    "apps/mobile/test/",
)

# Matches `MintTrameConfiance.<ctor>(` — captures position of the `(`.
CALL_RE = re.compile(r"\bMintTrameConfiance\.\w+\s*\(")

OPT_OUT_HINT = "BloomStrategy: explicit-default"


def find_arg_list_end(text: str, open_paren_idx: int) -> int:
    """Return index of the matching `)` for the `(` at `open_paren_idx`.

    Naive paren-counting that ignores string literals — adequate for
    Dart constructor argument lists in practice (no `(` or `)` inside
    type annotations or default values for our callsites). Returns -1
    if unbalanced.
    """
    depth = 0
    i = open_paren_idx
    n = len(text)
    in_str: str | None = None
    while i < n:
        ch = text[i]
        if in_str is not None:
            if ch == "\\":
                i += 2
                continue
            if ch == in_str:
                in_str = None
        else:
            if ch in ("'", '"'):
                in_str = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    return -1


def line_of(text: str, idx: int) -> int:
    return text.count("\n", 0, idx) + 1


def has_opt_out(text: str, call_start: int) -> bool:
    # Look at the line immediately above the call.
    line_start = text.rfind("\n", 0, call_start) + 1
    prev_line_end = line_start - 1
    if prev_line_end <= 0:
        return False
    prev_line_start = text.rfind("\n", 0, prev_line_end) + 1
    prev_line = text[prev_line_start:prev_line_end]
    return OPT_OUT_HINT in prev_line


def scan(repo_root: Path) -> list[tuple[str, int, str]]:
    violations: list[tuple[str, int, str]] = []
    base = repo_root / SCAN_ROOT
    if not base.exists():
        return violations
    for path in base.rglob("*.dart"):
        if not path.is_file():
            continue
        rel = path.relative_to(repo_root).as_posix()
        if rel in EXCLUDE_FILES:
            continue
        if any(rel.startswith(p) for p in EXCLUDE_PREFIXES):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for m in CALL_RE.finditer(text):
            open_paren = m.end() - 1
            close_paren = find_arg_list_end(text, open_paren)
            if close_paren < 0:
                # Unbalanced — surface as a violation so a human looks.
                lineno = line_of(text, m.start())
                violations.append((rel, lineno, "<unbalanced argument list>"))
                continue
            body = text[open_paren : close_paren + 1]
            if "bloomStrategy" in body:
                continue
            if has_opt_out(text, m.start()):
                continue
            lineno = line_of(text, m.start())
            snippet = text[m.start() : min(close_paren + 1, m.start() + 140)]
            snippet = snippet.replace("\n", " ").strip()
            violations.append((rel, lineno, snippet))
    return violations


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    violations = scan(repo_root)
    if not violations:
        print(
            "no_implicit_bloom_strategy: OK — every MintTrameConfiance "
            "instantiation passes an explicit bloomStrategy: argument"
        )
        return 0
    print(
        f"no_implicit_bloom_strategy: FAIL — {len(violations)} "
        "instantiation(s) missing explicit bloomStrategy:",
        file=sys.stderr,
    )
    for rel, lineno, snippet in violations:
        print(f"  {rel}:{lineno}: {snippet}", file=sys.stderr)
    print(
        "\nFix: add `bloomStrategy: BloomStrategy.<onlyIfTopOfList|"
        "firstAppearance|never>` to the constructor call. Default policy "
        "(D-05): feed contexts → onlyIfTopOfList, standalone → "
        "firstAppearance.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
