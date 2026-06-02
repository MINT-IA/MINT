"""FactCurrent ORM — denormalised read-side row per (user_id, field_key).

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-01 + D-19 + D-26 + D-29.

One row per (user_id, field_key) tuple. UPSERT-friendly : the projector
writes via `INSERT ... ON CONFLICT (user_id, field_key) DO UPDATE SET
value_enc=EXCLUDED.value_enc, valid_from=EXCLUDED.valid_from WHERE
EXCLUDED.valid_from > fact_current.valid_from`. The guarded WHERE makes
the UPSERT idempotent + last-writer-wins by valid_from (D-19 atomicity
combined with D-04 point-in-time immutability — older events arriving
late do NOT clobber newer state).

`value_enc` + `confidence` follow the same D-26 + D-29 Pydantic wire shapes
as `fact_event`. The two tables share a write transaction (D-19) — the
projector wraps both writes in `with session.begin()` (sync SQLAlchemy
session ; the original plan spec said async but the implementation chose
sync for parity with the rest of the backend's request-scoped session ;
QA code-reviewer polish FLAG-1 docstring correction 2026-05-19).

Read path
=========
The dominant read pattern (look up one field for one user) is covered by
the `ix_fact_current_user_field_covering` index, which on Postgres uses
`INCLUDE (value_enc, valid_from)` for index-only scans. SQLite test
fixtures use a plain composite index — index-only-scan is a Postgres
optimisation that doesn't have an SQLite analogue.

Snapshot service wiring (feature-flag-gated to OFF by default) is in
`app/services/snapshots/snapshot_service.py` and reads from this table
when `FEATURE_FLAG_FACT_CURRENT_READ` is set ; default behaviour is
unchanged until Plan 02-03 PR-2 dual-write phase flips the flag ON.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Column,
    DateTime,
    ForeignKey,
    Index,
    PrimaryKeyConstraint,
    String,
)
from sqlalchemy.dialects.postgresql import JSONB

from app.core.database import Base


# Portable JSONB shim — matches consent.py convention. JSON on SQLite,
# JSONB on Postgres.
JSONType = JSON().with_variant(JSONB(), "postgresql")


class FactCurrent(Base):
    """Denormalised read-side row : current value per (user_id, field_key)."""

    __tablename__ = "fact_current"

    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    field_key = Column(String(128), nullable=False)
    value_enc = Column(JSONType, nullable=False)
    confidence = Column(JSONType, nullable=True)
    valid_from = Column(DateTime, nullable=False)
    latest_event_id = Column(String(36), nullable=True)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    __table_args__ = (
        PrimaryKeyConstraint("user_id", "field_key"),
        # Postgres covering index (with INCLUDE) was declared raw in the
        # alembic migration. The ORM-level Index here is the SQLite
        # fallback — non-covering composite. Both are named identically
        # so reflective DDL diffs don't surface a phantom drift.
        Index(
            "ix_fact_current_user_field_covering",
            "user_id",
            "field_key",
        ),
    )
