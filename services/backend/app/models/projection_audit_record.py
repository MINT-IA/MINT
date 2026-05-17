"""ProjectionAuditRecord — append-only LSFin advice audit log (Hotfix B 2026-05-17).

Stores tamper-evident metadata about every persisted projection shown to a
user, so that the regulatory snapshot + user-fact inputs that produced the
output can be reconstructed for advice documentation (LSFin retention
obligation, ~10y).

Append-only at the DB level: the accompanying alembic migration runs
`REVOKE UPDATE, DELETE ON projection_audit_records FROM PUBLIC` (and from
the explicit `app_role` if present) on Postgres. SQLite test path keeps
INSERT-only by convention (no role-level GRANT in SQLite).

PII boundary: `user_id_hash` is sha256(user_id), never plaintext, so the
audit row can outlive the user record under nLPD right-of-erasure without
re-identification risk.

Writers should be added per projection surface (see snapshot_service.py
for the snapshot pathway). Do NOT instantiate elsewhere without
recomputing the three hashes — that's the whole point of the table.
"""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import Boolean, Column, DateTime, Index, String

from app.core.database import Base


class ProjectionAuditRecord(Base):
    """Append-only audit row per persisted projection output."""

    __tablename__ = "projection_audit_records"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id_hash = Column(String(64), nullable=False)
    computed_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    projection_type = Column(String(32), nullable=False)  # "snapshot" | future projection kinds
    projection_id = Column(String, nullable=False)  # id of the projection row in its own table
    constants_version_hash = Column(String(64), nullable=False)
    scenario_inputs_hash = Column(String(64), nullable=False)
    output_hash = Column(String(64), nullable=False)
    lsfin_disclaimer_shown = Column(Boolean, default=False, nullable=False)

    __table_args__ = (
        # Composite index covers the two dominant query patterns: per-user
        # audit retrieval and time-window scans for compliance reports.
        Index("ix_projection_audit_user_computed", "user_id_hash", "computed_at"),
    )
