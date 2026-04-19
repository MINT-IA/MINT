#!/usr/bin/env python3
"""CTX-03 structural lint: 10 triplets {bad → good → why} present in CLAUDE.md (D-07).

Wave 0: skeleton exits 0 with TODO. Wave 3 Plan 03 Task 3 (Phase 30.6 Advanced)
replaces the stub body with actual counter on each of the 3 markers.

Per D-07 (Phase 30.6 CONTEXT): CLAUDE.md must contain exactly 10 anti-pattern
triplets, each with three markers:
  - "❌ NEVER" — the banned pattern
  - "✅ INSTEAD" — the correct alternative
  - "⚠️ WHY" — the compliance / doctrine justification

Expected count: 10 of each marker. Any deviation = fail.

Exit codes:
  0 — clean (Wave 0: always 0)
  1 — counts do not match 10 exactly (Wave 3+)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Count ❌ NEVER / ✅ INSTEAD / ⚠️ WHY markers in CLAUDE.md, "
            "expect exactly 10 each (D-07 triplets anti-patterns)"
        )
    )
    parser.add_argument("--file", default="CLAUDE.md", help="Path to CLAUDE.md")
    args = parser.parse_args()
    target = Path(args.file)
    if not target.exists():
        print(f"triplets-lint: MISSING {args.file}", file=sys.stderr)
        return 1
    print(
        "TODO Wave 3 Plan 03 Task 3 (Phase 30.6): count ❌ NEVER (=10), "
        "✅ INSTEAD (=10), ⚠️ WHY (=10). Fail if any count ≠10. "
        "10 triplets total (D-07)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
