#!/usr/bin/env python3
"""Doctrine consistency check — Phase mint-data-architecture-v1-01 Plan 02 Task 4.

Greps the 6 doctrine files for forbidden legacy phrases that would indicate
a regression to the pre-Plan-02 doctrine (e.g. the unqualified
« Backend = source of truth pour constants et formulas » that was the original
backend.md:39 conflict). Exits non-zero on any hit ; allowlist documented inline.

Codex HIGH #1 closed alongside the atomicity gate : together they prevent
both partial co-modification AND legacy-phrase regression.

Usage : python3 tools/checks/doctrine_consistency_check.py [--repo-root ROOT]
Exit codes :
    0 — no forbidden phrase found.
    1 — at least 1 forbidden phrase found (file + phrase listed on stderr).
    2 — I/O / argparse hard failure.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List, Tuple

_DOCTRINE_FILES: Tuple[str, ...] = (
    "CLAUDE.md",
    "docs/AGENTS/backend.md",
    "docs/AGENTS/flutter.md",
    ".claude/skills/mint-flutter-dev/SKILL.md",
    ".claude/skills/mint-backend-dev/SKILL.md",
    ".planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md",
)

# FORBIDDEN_PATTERNS : each entry = (compiled regex, rationale, suggested fix).
# - Pattern 1 : legacy backend.md:39 phrasing (the conflict source).
# - Pattern 2 : unqualified « financial_core/ est SOURCE OF TRUTH. » (period-
#   terminated, missing the « pour L1 chiffrer » qualifier).
# - Pattern 3 : legacy CLAUDE.md §1 « = ★ shared calculators (source of truth) »
#   (no L1/L2 split language).
#
# Each pattern is intentionally narrow — false positives are worse than false
# negatives here, because the gate must not block unrelated edits. The phrases
# below are the EXACT historical strings that need to stay out of tree.
_FORBIDDEN_PATTERNS: List[Tuple[re.Pattern, str, str]] = [
    (
        re.compile(
            r"^- \*\*Backend = source of truth\*\* pour constants et formulas\. "
            r"Flutter mirrors, jamais n'invente\.$",
            re.MULTILINE,
        ),
        "legacy backend.md:39 phrasing (no L2-L4 split)",
        "rewrite as : « Backend = source of truth pour L2-L4 + regulatory constants »",
    ),
    (
        re.compile(
            r"financial_core/`? est SOURCE OF TRUTH\.( |$)",
            re.MULTILINE,
        ),
        "unqualified « financial_core/ est SOURCE OF TRUTH. » (missing « pour L1 chiffrer »)",
        "qualify with : « est SOURCE OF TRUTH **pour L1 chiffrer** (...) »",
    ),
    (
        re.compile(
            r"apps/mobile/lib/services/financial_core/`? = ★ shared calculators "
            r"\(source of truth\)",
        ),
        "legacy CLAUDE.md §1 « shared calculators (source of truth) » (no L1/L2 split)",
        "rewrite as : « = ★ L1 chiffrer canonical home (single-number outputs, "
        "offline-capable) ; services/backend/app/services/ = L2-L4 canonical »",
    ),
]


def _parse_args(argv: List[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Doctrine consistency check.")
    p.add_argument(
        "--repo-root",
        default=None,
        help=(
            "Path to the repo root. Defaults to 2 parents up from this script "
            "(tools/checks/doctrine_consistency_check.py → repo root)."
        ),
    )
    return p.parse_args(argv)


def main(argv: List[str]) -> int:
    args = _parse_args(argv)
    if args.repo_root is None:
        repo_root = Path(__file__).resolve().parents[2]
    else:
        repo_root = Path(args.repo_root).resolve()

    violations: List[Tuple[str, str, str]] = []

    for rel in _DOCTRINE_FILES:
        path = repo_root / rel
        if not path.is_file():
            # A missing doctrine file is the atomicity gate's responsibility, not ours.
            # Skip silently here.
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except OSError as exc:
            print(f"ERROR : {path} — {exc}", file=sys.stderr)
            return 2
        for pattern, rationale, fix in _FORBIDDEN_PATTERNS:
            if pattern.search(content):
                violations.append((rel, rationale, fix))

    if not violations:
        print(
            "doctrine_consistency_check : 0/6 doctrine files carry forbidden phrases — PASS",
            file=sys.stderr,
        )
        return 0

    print(
        f"doctrine_consistency_check : {len(violations)} legacy-phrase violation(s) found :",
        file=sys.stderr,
    )
    for rel, rationale, fix in violations:
        print(f"  {rel} — {rationale}", file=sys.stderr)
        print(f"    fix : {fix}", file=sys.stderr)
    print(
        "  See : CONTEXT.md §D-01..D-04, "
        ".planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md "
        "(calc-engine portion, Decided 2026-05-17).",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
