#!/usr/bin/env python3
"""Phase mint-calc-engine-v1 W3 Plan 16 — Finding 4 GC standalone runner.

Intended for Railway scheduled-deploy (cron) execution, recommended schedule
``0 3 * * *`` (daily 03:00 UTC, low-traffic window). Standalone shim around
`app.services.cache.gc_job.purge_superseded_scenarios` :

Usage:
    python services/backend/scripts/run_gc.py
    python services/backend/scripts/run_gc.py --dry-run
    python services/backend/scripts/run_gc.py --max-age-days 60
    python services/backend/scripts/run_gc.py --dry-run --max-age-days 30

Exit codes:
    0 — GC completed successfully (or dry-run reported count cleanly).
    1 — Exception during DB connection or GC predicate execution.

Per RESEARCH §Q-E, Railway cron > APScheduler because Railway guarantees
1× execution per tick (no 2-replica DELETE race).
"""

from __future__ import annotations

import argparse
import logging
import os
import sys

# Ensure the `app` package is importable when invoked as `python scripts/run_gc.py`
# from any cwd (Railway invokes from /app in the Docker image ; local repo dev
# may invoke from services/backend/ or the repo root). The parent of `scripts/`
# is services/backend/, which contains the `app/` package.
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.dirname(_SCRIPT_DIR)
if _BACKEND_DIR not in sys.path:
    sys.path.insert(0, _BACKEND_DIR)

# Initialise root logger BEFORE importing app code so app-side handlers attach.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

from app.core.database import SessionLocal  # noqa: E402 — after logging init
from app.services.cache.gc_job import purge_superseded_scenarios  # noqa: E402


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="run_gc",
        description=(
            "Daily GC for `scenarios` table — deletes superseded rows older "
            "than max-age-days. Runs as Railway scheduled deploy."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report would-be-deleted count without mutating the DB.",
    )
    parser.add_argument(
        "--max-age-days",
        type=int,
        default=30,
        help="TTL window in days (default: 30 per Finding 4 mitigation).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)

    db = SessionLocal()
    try:
        count = purge_superseded_scenarios(
            db,
            max_age_days=args.max_age_days,
            dry_run=args.dry_run,
        )
        verb = "would be " if args.dry_run else ""
        print(
            f"GC complete: {count} rows {verb}purged "
            f"(max_age_days={args.max_age_days}, dry_run={args.dry_run})."
        )
        return 0
    except Exception as exc:  # pragma: no cover — startup/connection path
        print(f"GC FAILED: {exc}", file=sys.stderr)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
