#!/usr/bin/env python3
"""ESTV oracle freshness lint — CALC-03 D-13 (CONTEXT 92.5 D-13).

Reads `services/backend/tests/fixtures/estv_oracle_2025.jsonl` and prints a
stderr WARN for any vector whose `expected_capture_date` is older than
14 months. WARN-only: exit code 0 even on stale vectors. Annual capture
cadence + occasional ESTV downtime should not block CI (CONTEXT D-13).

To make this strict (FAIL on stale), pass --strict — currently NOT used
by any workflow ; reserved for a future opt-in once the capture cadence
is mechanical.

Mirrors `tools/checks/accent_lint_fr.py` style: argparse + stderr
machine-readable lines + clean exit codes.

Exit codes:
  0  — clean OR stale-but-WARN-only OR fixture missing/empty (graceful)
  1  — strict mode + stale vectors found, OR JSON parse error in fixture

Threshold: 14-month staleness per CONTEXT 92.5 D-13 (~ 14 * 30 = 420 days).
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

DEFAULT_FIXTURE = Path("services/backend/tests/fixtures/estv_oracle_2025.jsonl")
THRESHOLD_DAYS = 14 * 30  # 14-month threshold per CONTEXT 92.5 D-13 (≈420 days).


def _parse_iso(s: str) -> date:
    return datetime.strptime(s, "%Y-%m-%d").date()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="ESTV oracle freshness lint (CALC-03 D-13, WARN-only by default).",
    )
    parser.add_argument("--fixture", type=Path, default=DEFAULT_FIXTURE)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero on stale vectors (default WARN-only per CONTEXT D-13).",
    )
    parser.add_argument(
        "--seed-now-iso",
        type=str,
        default=None,
        help="Override 'today' for testing (YYYY-MM-DD).",
    )
    args = parser.parse_args()

    today = _parse_iso(args.seed_now_iso) if args.seed_now_iso else date.today()
    cutoff = today - timedelta(days=THRESHOLD_DAYS)

    if not args.fixture.exists():
        print(
            f"[freshness] fixture missing at {args.fixture} — nothing to check "
            "(CALC-03 D-13)",
            file=sys.stderr,
        )
        return 0

    text = args.fixture.read_text(encoding="utf-8").strip()
    if not text:
        print(
            f"[freshness] fixture empty at {args.fixture} — run "
            "capture_estv_oracle.py to populate (manual annual cadence, "
            "see services/backend/tests/scripts/README.md)",
            file=sys.stderr,
        )
        return 0

    stale: list[tuple[str, str]] = []
    for line in text.splitlines():
        if not line.strip():
            continue
        try:
            v = json.loads(line)
        except json.JSONDecodeError as exc:
            # Malformed fixture is a hard error — exit 1 even without --strict.
            print(
                f"[freshness] FAIL — JSON parse error in {args.fixture}: {exc}",
                file=sys.stderr,
            )
            return 1
        cap_iso = v.get("expected_capture_date")
        vid = v.get("id", "?")
        if not cap_iso:
            stale.append((vid, "missing expected_capture_date"))
            continue
        try:
            cap_date = _parse_iso(cap_iso)
        except ValueError:
            stale.append((vid, f"invalid expected_capture_date: {cap_iso!r}"))
            continue
        if cap_date < cutoff:
            stale.append(
                (vid, f"captured {cap_iso} (>{THRESHOLD_DAYS // 30} months)"),
            )

    if stale:
        for vid, reason in stale:
            print(f"[freshness] STALE {vid} — {reason}", file=sys.stderr)
        print(
            f"[freshness] {len(stale)} stale vector(s) in {args.fixture}. "
            "Re-run capture_estv_oracle.py at the next ESTV publication cycle "
            "(Nov-Dec).",
            file=sys.stderr,
        )
        if args.strict:
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
