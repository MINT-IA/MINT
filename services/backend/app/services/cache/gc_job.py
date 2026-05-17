"""
Phase mint-calc-engine-v1 W3 Plan 16 — Finding 4 GC daily job.

Bounds `scenarios` table growth by deleting rows where :
    superseded_by IS NOT NULL AND created_at < now() - interval '<N> days'

The predicate matches Plan 13 cache_writer's chain semantics : a row becomes
`superseded_by IS NOT NULL` when a newer compute for the same (profile_id,
kind) key with a different `inputs_hash` arrives. The GC trims chains older
than the 30-day audit window. Plan 13 cache_reader already filters
`superseded_by IS NULL`, so deleting superseded rows is INVISIBLE to readers.

Designed for Railway scheduled-deploy (cron) execution — per RESEARCH §Q-E
recommendation : Railway scheduler guarantees 1× execution per tick, sidestep
the 2-replica DELETE race APScheduler would create.

Dry-run mode reports the would-be-deleted count without mutating the DB,
intended for first-run validation before Julien activates the cron.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.scenario import ScenarioModel

_logger = logging.getLogger(__name__)


def purge_superseded_scenarios(
    db: Session,
    max_age_days: int = 30,
    dry_run: bool = False,
) -> int:
    """Delete `scenarios` rows with `superseded_by IS NOT NULL` older than `max_age_days`.

    Args:
        db: SQLAlchemy sync session.
        max_age_days: TTL window in days. Rows with `created_at < now() -
            max_age_days days` are eligible. Default 30 per CONTEXT.md
            (Finding 4 mitigation, 30-day audit window).
        dry_run: when True, returns the count of would-be-deleted rows
            without mutating the DB.

    Returns:
        Count of deleted rows (or would-be-deleted if dry_run=True).

    Notes:
        - Predicate is `ScenarioModel.superseded_by.isnot(None)` : LIVE rows
          (`superseded_by IS NULL`) are NEVER touched, regardless of age.
          This protects the current cache view.
        - Plan 15 warm-marker rows that have been superseded by a later
          real compute become eligible for GC under this same predicate ;
          warm-marker rows that are still LIVE (never superseded) are
          protected like any other live row.
        - `synchronize_session=False` is safe here because the GC runs as a
          standalone process (no ORM-tracked objects in scope).
        - The DELETE is a single transaction. For MINT-scale tables (~5.8M
          rows projected at 100 DAU × 57 calcs × 1 year), the daily delete
          volume is ~daily-write-rate ; chunking is not needed at this scale.
          If table grows past ~100K eligible rows in a single run, revisit.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=max_age_days)

    base_query = db.query(ScenarioModel).filter(
        ScenarioModel.superseded_by.isnot(None),
        ScenarioModel.created_at < cutoff,
    )

    if dry_run:
        count = base_query.count()
        _logger.info(
            "GC dry-run: %d rows would be purged (cutoff=%s, max_age_days=%d)",
            count,
            cutoff.isoformat(),
            max_age_days,
        )
        return count

    deleted_count = base_query.delete(synchronize_session=False)
    db.commit()
    _logger.info(
        "GC: %d rows purged (cutoff=%s, max_age_days=%d)",
        deleted_count,
        cutoff.isoformat(),
        max_age_days,
    )
    return deleted_count
