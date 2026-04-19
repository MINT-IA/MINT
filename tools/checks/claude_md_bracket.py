#!/usr/bin/env python3
"""CTX-03 structural lint: 5 critical rules bracket TOP (first 40L) AND BOTTOM (last 40L) of CLAUDE.md (D-06).

Implements the Liu 2024 lost-in-the-middle mitigation: critical rules MUST appear
in BOTH the first 40 lines AND the last 40 lines of CLAUDE.md so agents see them
even when runtime truncates the middle.

Per D-06 (Phase 30.6 CONTEXT) the 5 rules are:
  1. Banned terms (LSFin compliance)
  2. Accents 100% FR mandatory
  3. Retirement framing prohibition (MINT ≠ retirement app)
  4. Financial_core reuse mandatory
  5. i18n required (AppLocalizations)

Exit codes:
  0 — clean (all 5 rules present in TOP and BOTTOM windows)
  1 — violations (≥1 rule missing from either window) or file missing
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

WINDOW_LINES = 40

# D-06: 5 critical rules; each keyword is grep-friendly and matches the canonical
# phrasing shipped in Task 1 (TOP section + BOTTOM section of CLAUDE.md).
RULE_KEYWORDS: dict[str, re.Pattern[str]] = {
    "banned_terms":   re.compile(r"\bbanned\s*terms\b", re.IGNORECASE),
    "accents":        re.compile(r"\baccents?\b|100%\s*FR", re.IGNORECASE),
    "retirement":     re.compile(r"retirement|retraite.*app|retraite-first|≠\s*retirement", re.IGNORECASE),
    "financial_core": re.compile(r"financial_core", re.IGNORECASE),
    "i18n":           re.compile(r"\bi18n\b|AppLocalizations", re.IGNORECASE),
}


def check_window(window_label: str, lines: list[str]) -> list[str]:
    """Returns a list of rule_id labels missing from the `lines` window."""
    block = "\n".join(lines)
    return [
        f"{rule_id} (in {window_label})"
        for rule_id, pat in RULE_KEYWORDS.items()
        if not pat.search(block)
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

    lines = target.read_text(encoding="utf-8").splitlines()
    if len(lines) < 2 * WINDOW_LINES:
        print(
            f"bracket-lint: FAIL — {args.file} has {len(lines)} lines; "
            f"cannot bracket {WINDOW_LINES}+{WINDOW_LINES} (need ≥{2 * WINDOW_LINES})",
            file=sys.stderr,
        )
        return 1

    top = lines[:WINDOW_LINES]
    bottom = lines[-WINDOW_LINES:]

    problems = check_window("TOP", top) + check_window("BOTTOM", bottom)
    if problems:
        print(
            f"bracket-lint: FAIL — missing rules in CLAUDE.md brackets (D-06):",
            file=sys.stderr,
        )
        for m in problems:
            print(f"  missing: {m}", file=sys.stderr)
        return 1

    print(f"bracket-lint: OK — 5/5 rules present in TOP and BOTTOM of {args.file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
