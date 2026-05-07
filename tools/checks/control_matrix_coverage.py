#!/usr/bin/env python3
"""Parse docs/compliance/CONTROL_MATRIX.md and compute FinSA control coverage.

Coverage formula (Plan 97-03 Decision Option A):
  coverage = GREEN / (GREEN + AMBER + RED)
  DEFERRED rows are excluded from the denominator (future-state placeholder,
  not a compliance failure — e.g. art. 16 cost transparency pre-monetization).

Defensive normalisation (mitigates T-97-03-01 "lie via Status column"):
  * Anchor cell empty / "n/a"  -> row downgraded to RED regardless of declared Status.
  * Test ID cell empty / "n/a" -> row downgraded to AMBER regardless of declared Status.
  * DEFERRED rows opt out of both checks (n/a is intentional).

Exit codes:
  0  coverage >= --threshold (default 0.95)
  1  coverage <  threshold OR matrix file missing OR no rows parsed

Usage:
  python3 tools/checks/control_matrix_coverage.py
  python3 tools/checks/control_matrix_coverage.py --threshold 0.95
  python3 tools/checks/control_matrix_coverage.py --matrix path/to/MATRIX.md --json
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from dataclasses import dataclass

MATRIX_DEFAULT = pathlib.Path("docs/compliance/CONTROL_MATRIX.md")

# Match data rows: first cell is "art. <num>..." or "(operational)".
# Header row ("FinSA Article | ...") and separator row ("|---|---|...") are
# both rejected by this prefix.
_ROW_RE = re.compile(
    r"^\|\s*(?P<article>art\.\s*\d+[^|]*|\(operational\))\s*\|(?P<rest>.*)\|\s*$"
)
_STATUS_RE = re.compile(r"\b(GREEN|AMBER|RED|DEFERRED)\b")


@dataclass
class Row:
    article: str
    requirement: str
    control: str
    anchor: str
    test_id: str
    commit: str
    status: str
    doctrine: str


def parse(text: str) -> list[Row]:
    """Extract control rows from Markdown text. Robust to inline pipes
    inside cell content because we split on `|` and require >= 7 trailing
    cells; rows with fewer cells are skipped silently."""
    rows: list[Row] = []
    for line in text.splitlines():
        m = _ROW_RE.match(line)
        if not m:
            continue
        article = m.group("article").strip()
        cells = [c.strip() for c in m.group("rest").split("|")]
        # Header row's "article" cell would match neither "art." nor "(operational)"
        # so the regex already filters it. Separator rows ("|---|---|...") don't
        # match the article token either.
        if len(cells) < 7:
            continue
        req, ctrl, anchor, test_id, commit, status, doctrine = (cells + [""] * 7)[:7]
        rows.append(
            Row(
                article=article,
                requirement=req,
                control=ctrl,
                anchor=anchor,
                test_id=test_id,
                commit=commit,
                status=status,
                doctrine=doctrine,
            )
        )
    return rows


def _is_empty(cell: str) -> bool:
    return (not cell) or cell.lower() in ("n/a", "na", "-", "—", "(compute)")


def normalise(row: Row) -> str:
    """Auto-correct Status from anchor + test_id presence (defensive).

    DEFERRED stays DEFERRED. Otherwise: empty anchor -> RED, empty test_id ->
    AMBER, else declared Status (clamped to {GREEN, AMBER, RED}, defaulting
    to AMBER if the cell is junk)."""
    declared_match = _STATUS_RE.search(row.status)
    declared = declared_match.group(1) if declared_match else "RED"
    if declared == "DEFERRED":
        return "DEFERRED"
    if _is_empty(row.anchor):
        return "RED"
    if _is_empty(row.test_id):
        return "AMBER"
    return declared if declared in ("GREEN", "AMBER", "RED") else "AMBER"


def coverage(rows: list[Row]) -> tuple[float, dict[str, int]]:
    tally = {"GREEN": 0, "AMBER": 0, "RED": 0, "DEFERRED": 0}
    for r in rows:
        tally[normalise(r)] += 1
    in_scope = tally["GREEN"] + tally["AMBER"] + tally["RED"]
    if in_scope == 0:
        return 0.0, tally
    return tally["GREEN"] / in_scope, tally


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--threshold", type=float, default=0.95,
                    help="minimum GREEN ratio (default 0.95)")
    ap.add_argument("--matrix", type=pathlib.Path, default=MATRIX_DEFAULT,
                    help=f"path to control matrix (default {MATRIX_DEFAULT})")
    ap.add_argument("--json", action="store_true",
                    help="emit a single JSON payload on stdout")
    args = ap.parse_args(argv)

    if not args.matrix.is_file():
        print(f"::error::Matrix file not found: {args.matrix}", file=sys.stderr)
        return 1

    rows = parse(args.matrix.read_text(encoding="utf-8"))
    if not rows:
        print(f"::error::No control rows parsed from {args.matrix}", file=sys.stderr)
        return 1

    ratio, tally = coverage(rows)
    payload = {
        "matrix": str(args.matrix),
        "total_rows": len(rows),
        "tally": tally,
        "coverage": round(ratio, 4),
        "threshold": args.threshold,
        "pass": ratio >= args.threshold,
    }
    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"FinSA control matrix coverage: {ratio:.2%} (target >= {args.threshold:.0%})")
        print(
            f"  GREEN: {tally['GREEN']}  AMBER: {tally['AMBER']}  "
            f"RED: {tally['RED']}  DEFERRED: {tally['DEFERRED']}  "
            f"(total rows: {len(rows)})"
        )
        if not payload["pass"]:
            print(
                f"::error::Coverage {ratio:.2%} below threshold {args.threshold:.0%}",
                file=sys.stderr,
            )
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
