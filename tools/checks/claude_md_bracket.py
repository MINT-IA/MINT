#!/usr/bin/env python3
"""CTX-03 structural lint: 5 critical rules bracket TOP + BOTTOM of CLAUDE.md (D-06).

Wave 0: skeleton exits 0 with TODO. Wave 3 Plan 03 (Phase 30.6 Advanced) replaces
the stub body with actual top-40L + bottom-40L scanning.

Per D-06 (Phase 30.6 CONTEXT): 5 critical rules MUST appear in BOTH the first 40
lines AND the last 40 lines of CLAUDE.md so agents see them even when runtime
truncates the middle (lost-in-the-middle mitigation, Panel C).

Exit codes:
  0 — clean (Wave 0: always 0)
  1 — violations (Wave 3+: rules missing from top or bottom bracket)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

EXPECTED_RULES = [
    "banned terms",
    "accents",
    "retirement",
    "financial_core",
    "i18n",
]


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Assert 5 critical rules appear in TOP (first 40L) AND BOTTOM "
            "(last 40L) of CLAUDE.md (D-06 — lost-in-the-middle mitigation)"
        )
    )
    parser.add_argument("--file", default="CLAUDE.md", help="Path to CLAUDE.md (default: ./CLAUDE.md)")
    args = parser.parse_args()
    target = Path(args.file)
    if not target.exists():
        print(f"bracket-lint: MISSING {args.file}", file=sys.stderr)
        return 1
    print(
        "TODO Wave 3 Plan 03 Task 2 (Phase 30.6): grep top 40L + bottom 40L "
        f"for the {len(EXPECTED_RULES)} rules (case-insensitive): "
        f"{', '.join(EXPECTED_RULES)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
