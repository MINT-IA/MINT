#!/usr/bin/env python3
"""CI grep gate: forbid LLM-sourced MintAlertObject / MintAlertSignal.

Phase 9 / ALERT-07 — MintAlertObject must come from rule-based sources
(AnticipationProvider, NudgeEngine, ProactiveTriggerService). It must
NEVER be constructed in a file that also imports a `claude_*_service.dart`
LLM client. This gate enforces that invariant via two-pass grep:

  1. Find every .dart file under apps/mobile/lib/ that contains
     `MintAlertObject(` or `MintAlertSignal(`.
  2. For each such file, check whether it imports any
     `claude_<name>_service.dart`. If yes — violation.

Test files (`*_test.dart`) are excluded: regression tests are allowed
to reference both APIs.

Exit codes:
  0 — clean
  1 — at least one file co-locates an alert constructor with an LLM import

Usage:
  python3 tools/checks/no_llm_alert.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

SCAN_ROOT = "apps/mobile/lib"

ALERT_PATTERN = re.compile(r"\bMintAlert(?:Object|Signal)\(")
LLM_IMPORT_PATTERN = re.compile(
    r"""import\s+['"][^'"]*claude_\w+_service\.dart['"]"""
)


def scan(repo_root: Path) -> list[tuple[str, int, str]]:
    """Return (relpath, lineno, snippet) for each violating file."""
    base = repo_root / SCAN_ROOT
    violations: list[tuple[str, int, str]] = []
    if not base.exists():
        return violations

    for path in base.rglob("*.dart"):
        if not path.is_file():
            continue
        if path.name.endswith("_test.dart"):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue

        # Quick reject: must contain an alert constructor
        if not ALERT_PATTERN.search(text):
            continue
        # Must also have an LLM service import
        if not LLM_IMPORT_PATTERN.search(text):
            continue

        # Find the first alert-constructor line for diagnostics
        for lineno, line in enumerate(text.splitlines(), start=1):
            if ALERT_PATTERN.search(line):
                rel = path.relative_to(repo_root).as_posix()
                violations.append((rel, lineno, line.strip()))
                break

    return violations


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    violations = scan(repo_root)
    if not violations:
        print(
            "no_llm_alert: OK — zero files co-locate "
            "MintAlertObject/MintAlertSignal with claude_*_service imports"
        )
        return 0

    print(
        f"no_llm_alert: FAIL — {len(violations)} ALERT-07 violation(s):",
        file=sys.stderr,
    )
    for rel, lineno, line in violations:
        snippet = line if len(line) <= 140 else line[:137] + "..."
        print(
            f"  {rel}:{lineno}: error: LLM-sourced alert forbidden — "
            f"MintAlertObject must come from AnticipationProvider/"
            f"NudgeEngine/ProactiveTriggerService (ALERT-07)",
            file=sys.stderr,
        )
        print(f"    {snippet}", file=sys.stderr)
    print(
        "\nALERT-07 rule: MintAlertObject is rule-based. LLMs (claude_*_service) "
        "may NEVER construct alerts. Move alert creation to a non-LLM provider.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
