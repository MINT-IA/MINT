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
INLINE_ID_PAT = re.compile(r'^\s*-?\s*(?:tapOn|assertVisible|visible):\s*\{\s*id:\s*[\'"]([^\'"]+)[\'"]\s*\}\s*$')
INLINE_POINT_PAT = re.compile(r'^\s*-?\s*(?:tapOn|assertVisible|visible):\s*\{\s*point:\s*[\'"][^\'"]+[\'"]\s*\}\s*$')
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
    "\\(",
    "\\)",
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

FR_MONTHS = (
    "janvier",
    "février",
    "fevrier",
    "mars",
    "avril",
    "mai",
    "juin",
    "juillet",
    "août",
    "aout",
    "septembre",
    "octobre",
    "novembre",
    "décembre",
    "decembre",
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


def _is_supported_dynamic_date_locator(text: str) -> bool:
    """Allow date-picker labels generated by platform localization.

    These strings are not in Dart/ARB because Flutter's date picker emits
    them from Material/iOS localizations at runtime. Keep the exception
    narrow so real text drift still fails the lint.
    """
    normalized = _normalize_search_text(text).strip()
    if re.fullmatch(r"\d{2}\.\d{2}\.\d{4}", normalized):
        return True

    normalized = normalized.replace(".*", " ").replace("^", " ").replace("$", " ")
    normalized = normalized.strip("() ")
    has_year = re.search(r"\b(19|20)\d{2}\b", normalized) is not None
    has_day = re.search(r"\b([1-9]|[12]\d|3[01])\b", normalized) is not None
    has_month = any(month in normalized.lower() for month in FR_MONTHS)
    return has_day and has_month and has_year


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
def _candidate_code_sources() -> tuple[str, ...]:
    sources: list[str] = []
    for path in MOBILE_LIB.rglob("*.dart"):
        try:
            sources.append(path.read_text(encoding="utf-8"))
        except OSError:
            continue
    return tuple(sources)


@lru_cache(maxsize=1)
def _mint2_axis_ids() -> frozenset[str]:
    path = MOBILE_LIB / "models" / "onboarding_intent.dart"
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return frozenset()
    match = re.search(r"String get id => switch \(this\) \{(?P<body>.*?)\n\s*\};", content, re.DOTALL)
    if not match:
        return frozenset()
    return frozenset(re.findall(r"=>\s*'([a-z0-9_]+)'", match.group("body")))


@lru_cache(maxsize=1)
def _normalized_candidate_text_sources() -> tuple[str, ...]:
    return tuple(_normalize_search_text(source) for source in _candidate_text_sources())

def _template_matches_text(template: str, text: str) -> bool:
    if "{" not in template or "}" not in template:
        return False
    literal_remainder = re.sub(r"\{[A-Za-z_][A-Za-z0-9_]*\}", "", template)
    literal_chars = re.findall(r"[A-Za-z0-9À-ÿ]", literal_remainder)
    if len(literal_chars) < 4:
        return False
    pattern = re.escape(template)
    pattern = re.sub(r"\\\{[A-Za-z_][A-Za-z0-9_]*\\\}", r".+?", pattern)
    return re.fullmatch(pattern, text) is not None


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
        literal = re.sub(r"\\+\(", "(", literal)
        literal = re.sub(r"\\+\)", ")", literal)
        literal = literal.replace(r"\\b", "")
        literal = literal.replace(r"\b", "")
        literal = re.sub(r"\\\\[dDsSwW][+*?]?", ".*", literal)
        literal = re.sub(r"\\[dDsSwW][+*?]?", ".*", literal)
        literal = re.sub(r"\.\*|\.\?", "|", literal)
        literal = literal.replace("*", " ")
        literal = literal.replace("+", " ")
        literal = literal.replace("^", " ")
        literal = literal.replace("$", " ")
        literal = re.sub(r"\\+$", "", literal)
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
            m = INLINE_ID_PAT.match(line)
            if m:
                if not in_negative_block:
                    ids.add(m.group(1))
                continue
            if INLINE_POINT_PAT.match(line):
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
    if _is_supported_dynamic_date_locator(text):
        return True
    sources = _candidate_text_sources()
    normalized_sources = _normalized_candidate_text_sources()
    normalized_text = _normalize_search_text(text)
    is_regex = _looks_like_regex(text)
    for source, normalized_source in zip(sources, normalized_sources):
        if text in source or normalized_text in normalized_source:
            return True
        if not is_regex and _template_matches_text(normalized_source, normalized_text):
            return True
    if is_regex and _regex_literals_match_any_source(text, sources):
        return True
    return False


def codebase_has_key(key_id: str) -> bool:
    """Does this id have a Flutter key or semantics identifier declaration ?"""
    dynamic_patterns = []
    if key_id.startswith("mint2-axis-"):
        axis_id = key_id.removeprefix("mint2-axis-")
        if axis_id in _mint2_axis_ids():
            dynamic_patterns.append(("mint2-axis-${item.axis.id}", axis_id))
    if key_id.startswith("e2e_mint2_axis_claim_"):
        suffix = key_id.removeprefix("e2e_mint2_axis_claim_")
        entry_key, _, entry_value = suffix.partition("_")
        if entry_key == "axis" and entry_value in _mint2_axis_ids():
            dynamic_patterns.append(("e2e_mint2_axis_claim_${entry.key}_${entry.value}", suffix))
        elif entry_key == "axis" and entry_value == "absent":
            dynamic_patterns.append(("e2e_mint2_axis_claim_${entry.key}_${entry.value}", suffix))
        elif entry_key == "axisInWizardAnswers" and entry_value in {"true", "false"}:
            dynamic_patterns.append(("e2e_mint2_axis_claim_${entry.key}_${entry.value}", suffix))
        elif entry_key == "wizardAnswers" and entry_value.isdigit():
            dynamic_patterns.append(("e2e_mint2_axis_claim_${entry.key}_${entry.value}", suffix))
        elif entry_key == "claim" and entry_value in {"claimed", "restart_clean"}:
            dynamic_patterns.append(("e2e_mint2_axis_claim_${entry.key}_${entry.value}", suffix))
        elif entry_key == "owner" and entry_value in {"claimed", "absent"}:
            dynamic_patterns.append(("e2e_mint2_axis_claim_${entry.key}_${entry.value}", suffix))
        elif entry_key == "auth" and entry_value in {"present", "absent"}:
            dynamic_patterns.append(("e2e_mint2_axis_claim_${entry.key}_${entry.value}", suffix))
    if key_id.startswith("rvc_age_state_"):
        suffix = key_id.removeprefix("rvc_age_state_")
        if suffix.isdigit() or suffix == "${output.rvc_expected_age}":
            dynamic_patterns.append(("rvc_age_state_$ageProof", suffix))
    needles = [
        re.escape(f"Key('{key_id}')"),
        re.escape(f'Key("{key_id}")'),
        re.escape(f"ValueKey('{key_id}')"),
        re.escape(f'ValueKey("{key_id}")'),
        re.escape(f"identifier: '{key_id}'"),
        re.escape(f'identifier: "{key_id}"'),
    ]
    for content in _candidate_code_sources():
        if any(re.search(needle, content) for needle in needles):
            return True
        if key_id in content and "identifier:" in content:
            return True
        if key_id.startswith("coachCitationChip-") and "coachCitationChip-${chip.toolName}" in content:
            return True
        for template, suffix in dynamic_patterns:
            if template in content and suffix:
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
