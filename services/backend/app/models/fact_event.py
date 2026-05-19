"""FactEvent ORM — append-only event log row.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-19 + D-26 + D-27 + D-28.

One row per write of a single (user_id, field_key) fact. The table is
PARTITION BY HASH (user_id) PARTITIONS 8 on Postgres (see alembic migration
p98_fact_event_projection). At the ORM level, partitioning is transparent —
the Postgres planner routes INSERT to the correct partition by `user_id`.

Append-only invariant
=====================
This ORM intentionally exposes NO update method, NO upsert helper, and the
canonical write path is `FactProjector.project_event` (which only emits
INSERT). The DB-level enforcement (`REVOKE UPDATE, DELETE FROM PUBLIC` in
the alembic migration) is the structural guard ; this ORM is the
ergonomic guard.

`value_enc` matches the Pydantic D-26 EncryptedValue wire shape :
{ ct, iv, tag, alg, dek_id, enc_v }. Validation happens at the helper layer
(`app/services/encryption/encrypted_value_helper.py`) before the dict reaches
this ORM.

`confidence` matches the Pydantic D-29 EnhancedConfidence wire shape :
{ c, a, f, u, score, enrichmentPrompts }. NULL means "not yet attributed".

Deliberately in `app/models/` (project convention).
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
)
from sqlalchemy.dialects.postgresql import JSONB

from app.core.database import Base


# Portable JSONB shim — matches consent.py convention. JSON on SQLite,
# JSONB on Postgres.
JSONType = JSON().with_variant(JSONB(), "postgresql")


class FactEvent(Base):
    """Append-only event log row for a single (user_id, field_key) fact.

    The class does NOT expose update / upsert helpers — the canonical write
    path is INSERT-only via FactProjector. Code that mutates an existing
    fact_event row violates the D-27 append-only invariant.
    """

    __tablename__ = "fact_event"

    # Composite PK (event_id, user_id) — Postgres v14+ requires the
    # partition-key column (user_id, partitioned by HASH) to be part of any
    # UNIQUE / PRIMARY KEY on fact_event. event_id is a UUID7 so collisions
    # across users are practically zero ; the composite PK is functionally
    # equivalent to a unique constraint on event_id alone while satisfying
    # the partition rule. See p98_fact_event_projection.py for the matching
    # migration DDL.
    event_id = Column(String(36), primary_key=True, nullable=False)
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    field_key = Column(String(128), nullable=False)
    value_enc = Column(JSONType, nullable=False)
    confidence = Column(JSONType, nullable=True)
    valid_from = Column(DateTime, nullable=False)
    recorded_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    source = Column(String(64), nullable=False)
    event_version = Column(Integer, nullable=False, default=1)

    __table_args__ = (
        # Per-user-and-field replay index (event-log replay path).
        Index(
            "ix_fact_event_user_field_valid",
            "user_id",
            "field_key",
            "valid_from",
        ),
    )
