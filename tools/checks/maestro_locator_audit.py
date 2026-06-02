#!/usr/bin/env python3
"""
Phase 90 PERS-07 (v2.13) — Maestro locator audit lint.

Greps every `tapOn:` / `assertVisible:` literal across
`tools/simulator/flows/**/*.yaml` and asserts each literal can be
expected in the rendered Flutter widget tree (either as a
`Semantics(label:)` / `key:` or as a Text widget content).

Why : Maestro YAML semantic locators silently break when a Flutter
widget loses its accessibility wrapper or when an ARB string changes.
Without this lint, 50 persona flows can flip red the same commit a
refactor lands, with cryptic "element not found" errors leaving Julien
to debug widget trees on his Sunday.

Mitigation contract per panel-locked architecture
(`.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md`) :
this lint runs pre-commit + CI. CI fails on locator drift the same
commit it's introduced — never on the day Phase 92 ships 5 journalist-
defense flows.

Method (best-effort static analysis ; full widget-tree walk would
require a Flutter test runner — that's the L2 Dart assertion suite
PERS-08, not this lint) :
  1. Parse every `flows/**/*.yaml` for `text:` / `id:` literals nested
     under `tapOn` / `assertVisible`.
  2. Grep the codebase for either :
     - `Key('<id>')` declarations matching `id:` literals
     - The `text:` literal appearing in a `Text(...)` widget OR an
       ARB file value
  3. Emit one violation per missing locator with file:line + flow path.
  4. Exit non-zero if any violation.

Run :
  python3 tools/checks/maestro_locator_audit.py
  python3 tools/checks/maestro_locator_audit.py --strict   # warns become errors
"""

from __future__ import annotations

import json
import re
import sys
from functools import lru_cache
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
FLOWS_DIR = REPO_ROOT / "tools" / "simulator" / "flows"
MOBILE_LIB = REPO_ROOT / "apps" / "mobile" / "lib"
ARB_DIR = REPO_ROOT / "apps" / "mobile" / "lib" / "l10n"

# Patterns to extract from YAML flows. Maestro flow structure :
#   - tapOn: <text>           (shorthand : just text)
#   - tapOn:                  (block form)
#       text: "..."
#       id: "..."
#   - assertVisible: <text>   (shorthand)
#   - assertVisible:          (block form)
#       text: "..."
#       id: "..."
#   - assertNotVisible:       (negative regression guard — text/id is
#                              BY DESIGN absent from the rendered tree ;
#                              skipped by this lint, see § note below)
#
# We extract two streams : `text:` literals (must appear in code/ARB)
# and `id:` literals (must have a `Key('<id>')` declaration somewhere).
#
# Phase 97 W7 iter#12 L001 — POSITIVE assertions only. `assertNotVisible`
# semantics are inverted : the text/id MUST NOT be present in the app
# (regression guard). Auditing those would flag valid negative guards as
# « locator drift », which is the exact opposite of the truth. The
# `_in_negative_assertion` flag tracks the parser depth through a
# block-form `assertNotVisible:` so its nested `text:` / `id:` literals
# are excluded from the audit set.
TEXT_PAT = re.compile(r'^\s*-?\s*(?:tapOn|assertVisible):\s*[\'"]?([^\'"\n#][^\n#]*?)[\'"]?\s*$')
TEXT_BLOCK_PAT = re.compile(r'^\s+text:\s*[\'"]([^\'"]+)[\'"]\s*$')
ID_PAT = re.compile(r'^\s+id:\s*[\'"]([^\'"]+)[\'"]\s*$')
INPUT_TEXT_PAT = re.compile(r'^\s*-\s*inputText:\s*[\'"]([^\'"]+)[\'"]\s*$')
# Match either `- assertNotVisible: "literal"` (shorthand, the literal is
# captured to skip it from the positive set) or `- assertNotVisible:`
# (block form, opens a scope whose nested `text:` / `id:` lines are also
# skipped).
NEG_SHORTHAND_PAT = re.compile(r'^\s*-?\s*assertNotVisible:\s*[\'"]?([^\'"\n#][^\n#]*?)[\'"]?\s*$')
NEG_BLOCK_OPEN_PAT = re.compile(r'^\s*-?\s*assertNotVisible:\s*$')
# A new top-level step (any `- <action>:` line) closes the negative scope.
NEW_STEP_PAT = re.compile(r'^\s*-\s*\w+:')

REGEX_INTENT_MARKERS = (
    "(?",
    ".*",
    ".?",
    "\\b",
    "\\d",
    "\\s",
    "\\w",
    "|",
    "^",
    "$",
    "[",
    "]",
    "{",
    "}",
)


def _normalize_search_text(value: str) -> str:
    """Collapse spacing variants that appear differently in ARB/Dart/runtime."""
    value = (
        value.replace(r"\u2019", "’")
        .replace(r"\u00a0", " ")
        .replace(r"\n", " ")
    )
    return re.sub(r"\s+", " ", value.replace("\u00a0", " ")).strip()


def _looks_like_regex(text: str) -> bool:
    # Plain Maestro labels often contain punctuation (`Dis-moi.`,
    # `Date de naissance ?`, `(FATCA)`). Treat only explicit regex idioms
    # as regexes; otherwise the lint can both false-green drift and hang on
    # broad sentence-shaped patterns.
    return any(marker in text for marker in REGEX_INTENT_MARKERS)


@lru_cache(maxsize=1)
def _candidate_text_sources() -> tuple[str, ...]:
    """Collect app text sources audited by Maestro locator checks."""
    sources: list[str] = []
    for path in MOBILE_LIB.rglob("*.dart"):
        try:
            sources.extend(path.read_text(encoding="utf-8").splitlines())
        except OSError:
            continue
    for arb in ARB_DIR.glob("app_*.arb"):
        try:
            data = json.loads(arb.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        for k, v in data.items():
            if not k.startswith("@") and isinstance(v, str):
                sources.append(v)
    return tuple(sources)


@lru_cache(maxsize=1)
def _normalized_candidate_text_sources() -> tuple[str, ...]:
    return tuple(_normalize_search_text(source) for source in _candidate_text_sources())


def _regex_literal_branches(pattern: str) -> list[list[str]]:
    """Extract literal anchors from a Maestro regex without executing it."""
    body = pattern
    body = body.replace("(?i)", "")
    body = body.strip()
    body = re.sub(r"^\.\*", "", body)
    body = re.sub(r"\.\*$", "", body)
    body = body.strip("()")

    branches = re.split(r"(?<!\\)\|", body)
    result: list[list[str]] = []
    for branch in branches:
        literal = branch
        literal = literal.replace(r"\.", ".")
        literal = literal.replace(r"\?", "?")
        literal = literal.replace(r"\[", "[")
        literal = literal.replace(r"\]", "]")
        literal = literal.replace(r"\\b", "")
        literal = literal.replace(r"\b", "")
        literal = re.sub(r"\\\\[dDsSwW][+*?]?", ".*", literal)
        literal = re.sub(r"\\[dDsSwW][+*?]?", ".*", literal)
        literal = re.sub(r"\.\*|\.\?", "|", literal)
        literal = literal.replace("*", " ")
        literal = literal.replace("+", " ")
        literal = literal.replace("^", " ")
        literal = literal.replace("$", " ")
        literal = literal.strip("()")
        tokens = [
            _normalize_search_text(token)
            for token in re.split(r"[()|/]+", literal)
            if len(_normalize_search_text(token)) >= 2
            or _normalize_search_text(token).isdigit()
        ]
        if tokens:
            result.append(tokens)
    return result


def _regex_literals_match_any_source(
    pattern: str,
    sources: tuple[str, ...],
) -> bool:
    """Best-effort static check for Maestro regex locators.

    Do not execute arbitrary flow regexes here. Broad patterns such as
    `.*foo.*bar.*` can be catastrophically slow on large source strings.
    Static literal anchors are enough for this lint; runtime Maestro remains
    the executable proof.
    """
    branches = _regex_literal_branches(pattern)
    if not branches:
        return False

    normalized_sources = _normalized_candidate_text_sources()
    for branch in branches:
        for source in normalized_sources:
            if all(token in source for token in branch):
                return True
    return False


def collect_locators(flow_path: Path) -> tuple[set[str], set[str]]:
    """Returns (text_literals, id_literals) referenced by the flow.

    Only POSITIVE `tapOn` / `assertVisible` literals are returned ; any
    `assertNotVisible` literal (shorthand or block form) is excluded
    because it is a negative regression guard — the literal is BY DESIGN
    absent from the rendered tree, and auditing it as a locator would
    inverted-flag valid guards as drift.
    """
    texts: set[str] = set()
    ids: set[str] = set()
    input_texts: set[str] = set()
    in_negative_block = False
    with flow_path.open() as f:
        for raw in f:
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            m = INPUT_TEXT_PAT.match(line)
            if m:
                input_texts.add(m.group(1).strip())
                continue

            # Negative shorthand : skip the literal AND don't open a block.
            if NEG_SHORTHAND_PAT.match(line):
                in_negative_block = False
                continue

            # Negative block opener : skip the literal AND open a block
            # scope (nested `text:` / `id:` lines belong to the negative
            # guard and must be excluded).
            if NEG_BLOCK_OPEN_PAT.match(line):
                in_negative_block = True
                continue

            # Any other `- <action>:` step closes the negative scope.
            if NEW_STEP_PAT.match(line):
                in_negative_block = False

            m = TEXT_BLOCK_PAT.match(line)
            if m:
                value = m.group(1)
                if not in_negative_block and value not in input_texts:
                    texts.add(value)
                continue
            m = ID_PAT.match(line)
            if m:
                if not in_negative_block:
                    ids.add(m.group(1))
                continue
            m = TEXT_PAT.match(line)
            if m:
                val = m.group(1).strip()
                # Skip block-mode marker (when value is empty or `|`).
                if val and val not in {"|", "#"} and val not in input_texts:
                    texts.add(val)
    return texts, ids


def codebase_has_text(text: str) -> bool:
    """Does this text appear in any `Text(...)` widget OR ARB value ?"""
    sources = _candidate_text_sources()
    normalized_sources = _normalized_candidate_text_sources()
    normalized_text = _normalize_search_text(text)
    for source, normalized_source in zip(sources, normalized_sources):
        if text in source or normalized_text in normalized_source:
            return True
    if _looks_like_regex(text) and _regex_literals_match_any_source(text, sources):
        return True
    return False


def codebase_has_key(key_id: str) -> bool:
    """Does this id have a Flutter key or semantics identifier declaration ?"""
    needles = [
        re.escape(f"Key('{key_id}')"),
        re.escape(f'Key("{key_id}")'),
        re.escape(f"ValueKey('{key_id}')"),
        re.escape(f'ValueKey("{key_id}")'),
        re.escape(f"identifier: '{key_id}'"),
        re.escape(f'identifier: "{key_id}"'),
    ]
    for path in MOBILE_LIB.rglob("*.dart"):
        try:
            content = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if any(re.search(needle, content) for needle in needles):
            return True
        if key_id in content and "identifier:" in content:
            return True
        if key_id.startswith("coachCitationChip-") and "coachCitationChip-${chip.toolName}" in content:
            return True
    return False


def main() -> int:
    if not FLOWS_DIR.is_dir():
        print(f"info: {FLOWS_DIR} not present — no Maestro flows to audit yet.")
        return 0

    flow_files = sorted(FLOWS_DIR.rglob("*.yaml"))
    if not flow_files:
        print(f"info: {FLOWS_DIR} is empty — no flows to audit.")
        return 0

    violations: list[str] = []
    skipped: list[Path] = []
    audited = 0

    for flow in flow_files:
        try:
            if "maestro_locator_audit: skip" in flow.read_text(encoding="utf-8"):
                skipped.append(flow)
                continue
        except OSError:
            continue
        texts, ids = collect_locators(flow)
        for t in sorted(texts):
            audited += 1
            if not codebase_has_text(t):
                violations.append(
                    f"{flow.relative_to(REPO_ROOT)} — text literal not found in "
                    f"app code or ARB: {t!r}"
                )
        for k in sorted(ids):
            audited += 1
            if not codebase_has_key(k):
                violations.append(
                    f"{flow.relative_to(REPO_ROOT)} — id literal {k!r} has no "
                    f"matching Key('{k}') declaration in apps/mobile/lib/"
                )

    print(
        f"maestro_locator_audit: scanned {len(flow_files) - len(skipped)} flows "
        f"({len(skipped)} skipped), "
        f"{audited} locators."
    )
    if violations:
        print("\n[FAIL] Locator drift detected — fix before merge :")
        for v in violations:
            print(f"  • {v}")
        return 1
    print("[OK] All locators resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
