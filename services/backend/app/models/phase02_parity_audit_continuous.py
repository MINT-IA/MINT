"""Phase02ParityAuditContinuous ORM — 30-min sampled drift persistence.

Phase mint-data-architecture-v1-02 Plan 02-03 — iter-2 B18.

ORM for the `_phase02_parity_audit_continuous` table created by alembic
p119. Populated by `services/backend/app/cron/continuous_drift_sampler.py`
running every 30 min during the PR-3a → PR-3b 7-day soak window.

The Task 2b checkpoint queries this table for the « 7-day clean window »
verification before approving PR-3b merge.
"""
from __future__ import annotations

from sqlalchemy import (
    JSON,
    BigInteger,
    Column,
    DateTime,
    Index,
    Integer,
    String,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB

from app.core.database import Base


JSONType = JSON().with_variant(JSONB(), "postgresql")
PKType = BigInteger().with_variant(Integer(), "sqlite")


class Phase02ParityAuditContinuous(Base):
    """One row per (user, sampler_run) for the 7-day drift soak."""

    __tablename__ = "_phase02_parity_audit_continuous"

    id = Column(PKType, primary_key=True, autoincrement=True)
    sampled_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    user_id_hash = Column(String(64), nullable=False)
    diff_count = Column(Integer, nullable=False, default=0)
    diff_details = Column(JSONType, nullable=False, default=dict)
    sampler_run_id = Column(String(36), nullable=False)

    __table_args__ = (
        Index(
            "ix_phase02_parity_audit_continuous_sampled",
            "sampled_at",
        ),
        Index(
            "ix_phase02_parity_audit_continuous_dirty",
            "diff_count",
            postgresql_where=text("diff_count > 0"),
            sqlite_where=text("diff_count > 0"),
        ),
    )


__all__ = ["Phase02ParityAuditContinuous"]
