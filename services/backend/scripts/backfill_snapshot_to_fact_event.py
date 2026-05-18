#!/usr/bin/env python3
"""Idempotent backfill — SnapshotModel -> fact_event + fact_current.

Phase mint-data-architecture-v1-02 Plan 02-03 PR-3a (D-05, iter-2 A9).

Reads every SnapshotModel row from the target Postgres database, derives
the canary-proven field_keys from each row's columns + the `profile_data`
shape captured at snapshot creation time, and writes them as fact_event
inserts (which atomically UPSERT fact_current via FactProjector.project_event
per D-19).

Idempotency contract
====================
A SECOND run of this script against the same target DB MUST report :
- 0 new fact_event rows
- N idempotency_skip increments (one per previously-backfilled snapshot)

The idempotency mechanism :
1. The script writes `source='snapshot_backfill_v1'` on every fact_event.
2. Before writing, it checks if a `fact_event` row already exists with the
   same (user_id, field_key, valid_from, source). If yes, increment the
   `mint_projector_idempotency_skip_total` counter and skip the write.
3. The (user_id, field_key, valid_from) tuple is the natural dedup key
   because each SnapshotModel row has a single `created_at` and a single
   per-field value at that timestamp.

Operational protocol (Task 2a checkpoint preamble)
==================================================
1. Set FF_FACT_EVENT_DUAL_WRITE=on on Railway staging (the dual-write
   helper this script depends on is otherwise OFF).
2. Run `--dry-run` first to surface row counts + estimated runtime.
3. Run `--apply` to write.
4. Run `--apply` a SECOND time to prove idempotency (delta=0 + skip counter).
5. Run `python3 tools/parity/projection_diff.py --audit-all-users
   --persist-to _phase02_parity_audit` and verify 0 diffs across 100%
   of staging users via `_phase02_parity_audit` table.
6. Surface results to Julien for Task 2a checkpoint approval.

Throttling
==========
Uses `app.core.database.get_backfill_engine()` (Plan 02-02 iter-2 B15) with
pool_size=2, max_overflow=0 — prevents exhausting Railway's connection
pool while the application runs concurrently. Backfill is intentionally
SLOW — Plan 02-03 is pre-launch, staging traffic is near-zero, and the
throttled pool prevents user-facing degradation.

Failure handling
================
- Per-snapshot errors are logged + counted ; the script continues to the
  next snapshot. The summary at the end reports total errors so they're
  not silently swallowed.
- A fatal DB error aborts with exit 2 and no partial-commit (the projector
  uses `with session.begin()` semantics).
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Optional, Tuple

logger = logging.getLogger("backfill_snapshot_to_fact_event")

# Canary-proven field_keys (Plan 02-02 T3-C : monthly_gross_income +
# pillar_3a_balance + archetype_tags + lpp_avoirs_vieillesse +
# coach_extracted_facts).
#
# Source mapping :
#   monthly_gross_income      <- SnapshotModel.gross_income (scalar column)
#   pillar_3a_balance         <- profile_data['pillar_3a_balance'] (snapshot extras — see below)
#   archetype_tags            <- profile_data['archetype_tags']
#   lpp_avoirs_vieillesse     <- profile_data['lpp_avoirs_vieillesse']
#   coach_extracted_facts     <- profile_data['coach_extracted_facts']
#
# WHY profile_data extras aren't stored on SnapshotModel :
# SnapshotModel only persists scalar outputs (gross_income, fri_*,
# replacement_ratio…). The richer fact_keys live in the request `profile_data`
# dict and are NOT stored anywhere queryable post-snapshot — they're only
# preserved indirectly via the ProjectionAuditRecord inputs_hash.
#
# IMPLICATION FOR BACKFILL :
# The backfill can ONLY recover `monthly_gross_income` from existing
# SnapshotModel rows (the scalar column). The other 4 field_keys can NOT
# be reconstructed from SnapshotModel + ProjectionAuditRecord alone.
#
# This is Karpathy #1 (surface the assumption) : the original plan said
# « idempotent backfill from SnapshotModel → fact_event » assuming the
# inputs were materialised. They're not — only outputs are. The honest
# backfill therefore covers ONE field_key (monthly_gross_income) per
# existing SnapshotModel row.
#
# Plan 02-03 PR-3a checkpoint Julien-decision : if « monthly_gross_income
# only » is acceptable for the 100%-staging-user parity audit gate,
# proceed. If not, the remaining 4 field_keys must come from a fresh
# write path (post-PR-2 dual-write, FF=on on staging), NOT from
# historical SnapshotModel rows. The fresh-write path is the intended
# substrate ; the backfill bridges the historical gap.

_SNAPSHOT_COLUMN_FIELD_KEYS = (
    # (SnapshotModel column, target field_key)
    ("gross_income", "monthly_gross_income"),
)


def _resolve_database_url() -> Optional[str]:
    """Precedence : BACKFILL_DATABASE_URL > DATABASE_URL."""
    return (
        os.environ.get("BACKFILL_DATABASE_URL", "").strip()
        or os.environ.get("DATABASE_URL", "").strip()
        or None
    )


def _build_session(url: str):
    """Build a throttled session via get_backfill_engine() (B15)."""
    # The throttled engine is a backend-only helper ; if it can't be
    # imported (script run from a stripped checkout), fall back to a
    # vanilla low-pool engine.
    try:
        from app.core.database import get_backfill_engine

        engine = get_backfill_engine(url)
    except (ImportError, AttributeError):
        from sqlalchemy import create_engine

        engine = create_engine(
            url,
            pool_size=2,
            max_overflow=0,
            pool_pre_ping=True,
        )
    from sqlalchemy.orm import sessionmaker

    return sessionmaker(bind=engine, autocommit=False, autoflush=False)


def backfill_user(
    session,
    *,
    snapshot_row,
    dry_run: bool = False,
) -> Tuple[int, int]:
    """Backfill one SnapshotModel row. Returns (wrote, skipped) counts.

    `wrote` = number of fact_event rows newly inserted for this snapshot.
    `skipped` = number of fact_event rows that already existed (idempotent skip).
    """
    from app.models.fact_event import FactEvent
    from app.services.encryption.encrypted_value_helper import encrypt_value
    from app.services.projector.fact_projector import FactEventInput, project_event

    wrote = 0
    skipped = 0
    user_id = snapshot_row.user_id
    valid_from = snapshot_row.created_at
    # Ensure valid_from is timezone-aware for downstream comparisons
    if valid_from is not None and valid_from.tzinfo is None:
        valid_from = valid_from.replace(tzinfo=timezone.utc)
    source = "snapshot_backfill_v1"

    for column_name, field_key in _SNAPSHOT_COLUMN_FIELD_KEYS:
        value = getattr(snapshot_row, column_name, None)
        if value is None:
            continue

        # Idempotency check : did we already backfill this snapshot's
        # (user_id, field_key, valid_from, source) tuple?
        existing = (
            session.query(FactEvent)
            .filter(
                FactEvent.user_id == user_id,
                FactEvent.field_key == field_key,
                FactEvent.valid_from == valid_from,
                FactEvent.source == source,
            )
            .first()
        )
        if existing is not None:
            skipped += 1
            # Increment idempotency counter (matches Plan 02-02 D-33
            # mint_projector_idempotency_skip_total semantics).
            try:
                from app.observability.counters import (
                    mint_projector_idempotency_skip_total,
                )

                mint_projector_idempotency_skip_total.inc()
            except (ImportError, AttributeError):
                pass
            continue

        if dry_run:
            wrote += 1  # report what WOULD be written
            continue

        value_enc = encrypt_value(session, user_id, value)
        event = FactEventInput(
            user_id=user_id,
            field_key=field_key,
            value_enc=value_enc,
            valid_from=valid_from,
            source=source,
        )
        project_event(session, event)
        wrote += 1

    return wrote, skipped


def run_backfill(
    *,
    url: str,
    dry_run: bool = False,
    user_id_filter: Optional[str] = None,
) -> dict:
    """Iterate SnapshotModel rows, backfill each. Return summary dict.

    `user_id_filter` : if set, only backfill snapshots for that user.
    Useful for spot-checking specific accounts before the full run.
    """
    from app.models.snapshot import SnapshotModel

    Session = _build_session(url)
    session = Session()
    total_snapshots = 0
    total_wrote = 0
    total_skipped = 0
    total_errors = 0

    try:
        query = session.query(SnapshotModel)
        if user_id_filter:
            query = query.filter(SnapshotModel.user_id == user_id_filter)
        # Stream in chunks so we don't blow up memory on a large staging
        # snapshot table.
        for snap in query.yield_per(100):
            total_snapshots += 1
            try:
                wrote, skipped = backfill_user(
                    session,
                    snapshot_row=snap,
                    dry_run=dry_run,
                )
                total_wrote += wrote
                total_skipped += skipped
            except Exception as exc:  # noqa: BLE001 - surface each row failure
                total_errors += 1
                logger.error(
                    "backfill failed snapshot_id=%s user_id=%s err=%s",
                    snap.id,
                    snap.user_id,
                    exc,
                )
                session.rollback()
    finally:
        session.close()

    return {
        "snapshots_seen": total_snapshots,
        "fact_events_written": total_wrote,
        "fact_events_skipped_idempotent": total_skipped,
        "errors": total_errors,
        "dry_run": dry_run,
        "ran_at": datetime.now(timezone.utc).isoformat(),
    }


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Idempotent backfill SnapshotModel -> fact_event + fact_current. "
            "Plan 02-03 PR-3a (D-05, iter-2 A9)."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count what WOULD be written without persisting.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually write to fact_event + fact_current. Without this OR "
             "--dry-run, the script refuses to run.",
    )
    parser.add_argument(
        "--user-id",
        default=None,
        help="Filter to a single user_id (spot-check before full run).",
    )
    parser.add_argument(
        "--database-url",
        default=None,
        help="Override env vars BACKFILL_DATABASE_URL / DATABASE_URL.",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )

    if not args.dry_run and not args.apply:
        print(
            "ERROR: must pass --dry-run or --apply explicitly. Refusing to "
            "default to write-on-empty-arg-list.",
            file=sys.stderr,
        )
        return 2

    url = args.database_url or _resolve_database_url()
    if not url:
        print(
            "ERROR: backfill_snapshot_to_fact_event requires "
            "BACKFILL_DATABASE_URL or DATABASE_URL env var (or --database-url).",
            file=sys.stderr,
        )
        return 2

    summary = run_backfill(url=url, dry_run=args.dry_run, user_id_filter=args.user_id)
    print(json.dumps(summary, indent=2, sort_keys=True))

    # Surface non-zero exit on errors so the Task 2a preamble surfaces
    # the failure mode to Julien instead of silently logging.
    return 1 if summary["errors"] > 0 else 0


__all__ = ["backfill_user", "run_backfill", "main"]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
