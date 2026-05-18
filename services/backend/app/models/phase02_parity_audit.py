"""Phase02ParityAudit ORM — staging-only checkpoint-evidence persistence.

Phase mint-data-architecture-v1-02 Plan 02-03 — iter-2 B14.

ORM for the `_phase02_parity_audit` table created by alembic p118. Used by
the Task 2a checkpoint preamble : `projection_diff.py --audit-all-users
--persist-to _phase02_parity_audit` writes one row per audited staging
user, and Julien verifies the row counts before approving PR-3a merge.

The table is staging-only at runtime — no production code path queries it.
The ORM exists so that the persistence side of `--audit-all-users` can
write via SQLAlchemy rather than raw INSERT statements (consistency with
the rest of the backend codebase).
"""
from __future__ import annotations

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    Column,
    DateTime,
    Index,
    Integer,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB

from app.core.database import Base


JSONType = JSON().with_variant(JSONB(), "postgresql")

# Portable autoincrement PK : SQLite only auto-allocates on INTEGER PRIMARY KEY,
# so we use BigInteger().with_variant(Integer(), "sqlite") to keep Postgres
# BIGSERIAL semantics in prod while making the SQLite test fallback work.
PKType = BigInteger().with_variant(Integer(), "sqlite")


class Phase02ParityAudit(Base):
    """One row per audited (user, audit_run) for the Plan 02-03 100%% audit."""

    __tablename__ = "_phase02_parity_audit"

    id = Column(PKType, primary_key=True, autoincrement=True)
    audited_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    user_id_hash = Column(String(64), nullable=False)
    diff_detected = Column(Boolean, nullable=False, default=False)
    diff_details = Column(JSONType, nullable=False, default=dict)
    audit_run_id = Column(String(36), nullable=False)

    __table_args__ = (
        Index(
            "ix_phase02_parity_audit_run",
            "audit_run_id",
            "diff_detected",
        ),
        Index(
            "ix_phase02_parity_audit_audited_at",
            "audited_at",
        ),
    )


__all__ = ["Phase02ParityAudit"]
