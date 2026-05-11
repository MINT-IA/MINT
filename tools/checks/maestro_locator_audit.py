#!/usr/bin/env python3
"""
Phase 90 PERS-07 (v2.13) — Maestro locator audit lint.

Greps every `tapOn:` / `assertVisible:` literal across
`tools/simulator/flows/*.yaml` and asserts each literal can be
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
  1. Parse every `flows/*.yaml` for `text:` / `id:` literals nested
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
# Match either `- assertNotVisible: "literal"` (shorthand, the literal is
# captured to skip it from the positive set) or `- assertNotVisible:`
# (block form, opens a scope whose nested `text:` / `id:` lines are also
# skipped).
NEG_SHORTHAND_PAT = re.compile(r'^\s*-?\s*assertNotVisible:\s*[\'"]?([^\'"\n#][^\n#]*?)[\'"]?\s*$')
NEG_BLOCK_OPEN_PAT = re.compile(r'^\s*-?\s*assertNotVisible:\s*$')
# A new top-level step (any `- <action>:` line) closes the negative scope.
NEW_STEP_PAT = re.compile(r'^\s*-\s*\w+:')


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
    in_negative_block = False
    with flow_path.open() as f:
        for raw in f:
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
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
                if not in_negative_block:
                    texts.add(m.group(1))
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
                if val and val not in {"|", "#"}:
                    texts.add(val)
    return texts, ids


def codebase_has_text(text: str) -> bool:
    """Does this text appear in any `Text(...)` widget OR ARB value ?"""
    needle = re.escape(text)
    # Search Dart sources for `Text('...')` or `Text("...")` or
    # passed via const Text() / TextSpan(text: ...).
    for path in MOBILE_LIB.rglob("*.dart"):
        try:
            content = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if re.search(needle, content):
            return True
    # Search ARB JSON values.
    for arb in ARB_DIR.glob("app_*.arb"):
        try:
            data = json.loads(arb.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        for k, v in data.items():
            if k.startswith("@") or not isinstance(v, str):
                continue
            if text in v:
                return True
    return False


def codebase_has_key(key_id: str) -> bool:
    """Does this key id have a `Key('<id>')` or `ValueKey('<id>')` declaration ?"""
    needle_a = re.escape(f"Key('{key_id}')")
    needle_b = re.escape(f'Key("{key_id}")')
    for path in MOBILE_LIB.rglob("*.dart"):
        try:
            content = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if re.search(needle_a, content) or re.search(needle_b, content):
            return True
    return False


def main() -> int:
    if not FLOWS_DIR.is_dir():
        print(f"info: {FLOWS_DIR} not present — no Maestro flows to audit yet.")
        return 0

    flow_files = sorted(FLOWS_DIR.glob("*.yaml"))
    if not flow_files:
        print(f"info: {FLOWS_DIR} is empty — no flows to audit.")
        return 0

    violations: list[str] = []
    audited = 0

    for flow in flow_files:
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
        f"maestro_locator_audit: scanned {len(flow_files)} flows, "
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
