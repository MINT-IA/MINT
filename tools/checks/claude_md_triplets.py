#!/usr/bin/env python3
"""CTX-03 structural lint: exactly 10 triplets {bad → good → why} in CLAUDE.md (D-07).

Per D-07 (Phase 30.6 CONTEXT) CLAUDE.md must contain exactly 10 anti-pattern
triplets, each with three markers:
  - "❌ NEVER" — the banned pattern
  - "✅ INSTEAD" — the correct alternative
  - "⚠️ WHY" — the compliance / doctrine justification

Expected count: 10 of each marker. Any deviation = fail.

The 10 NEVERs are ordered by empirical violation frequency (from MEMORY.md
feedback_*.md analysis):
  #1 hardcode strings  #2 hardcode colors  #3 duplicate calc logic
  #4 retirement framing  #5 banned terms  #6 code-without-reading
  #7 assume swiss_native  #8 promise returns  #9 projection w/o confidence
  #10 skip tests

Exit codes:
  0 — clean (all 3 marker counts = 10 exactly)
  1 — counts do not match or file missing
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

EXPECTED_COUNT = 10
MARKERS: dict[str, str] = {
    "bad":  "❌ NEVER",
    "good": "✅ INSTEAD",
    "why":  "⚠️ WHY",
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Count ❌ NEVER / ✅ INSTEAD / ⚠️ WHY markers in CLAUDE.md, "
            "expect exactly 10 each (D-07 — 10 triplets anti-patterns)"
        )
    )
    parser.add_argument("--file", default="CLAUDE.md", help="Path to CLAUDE.md")
    args = parser.parse_args()

    target = Path(args.file)
    if not target.exists():
        print(f"triplets-lint: MISSING {args.file}", file=sys.stderr)
        return 1

    text = target.read_text(encoding="utf-8")
    counts = {key: text.count(marker) for key, marker in MARKERS.items()}

    problems = [
        f"{MARKERS[key]}: found {counts[key]}, expected {EXPECTED_COUNT}"
        for key in MARKERS
        if counts[key] != EXPECTED_COUNT
    ]

    if problems:
        print(
            f"triplets-lint: FAIL — triplet marker count mismatch in {args.file} (D-07):",
            file=sys.stderr,
        )
        for m in problems:
            print(f"  {m}", file=sys.stderr)
        return 1

    print(
        f"triplets-lint: OK — {EXPECTED_COUNT}/{EXPECTED_COUNT}/{EXPECTED_COUNT} "
        f"triplets in {args.file}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
