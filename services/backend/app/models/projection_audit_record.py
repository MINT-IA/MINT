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
    """Append-only audit row per persisted projection output.

    Plan 02-02 W1 continuation-4 D-12 + D-MOB-03 extension :
    8 new columns (source / app_version / observed_at /
    anonymous_session_id / local_event_id / app_lifecycle_state /
    client_ts / server_received_ts) + UNIQUE(anonymous_session_id,
    observed_at) WHERE anonymous_session_id IS NOT NULL for the Mobile
    L1 audit handshake (iter-2 A6 replay-safety). The original Hotfix B
    audit columns (user_id_hash / computed_at / projection_type /
    projection_id / constants_version_hash / scenario_inputs_hash /
    output_hash / lsfin_disclaimer_shown) are preserved unchanged. New
    rows from `/v1/audit/mobile-session-{start,link}` write source !=
    'projection' and populate the Mobile L1 columns ; existing writers
    (snapshot_service) continue to write source='projection' by default
    (server-default).
    """

    __tablename__ = "projection_audit_records"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id_hash = Column(String(64), nullable=False)
    computed_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    # D-12 : `source` widened from 'snapshot' / 'projection' to also
    # accept 'mobile_session_start' / 'mobile_session_warm_resume' for
    # Mobile L1 audit ingestion. server-default 'projection' preserves
    # existing writer semantics.
    source = Column(
        String(32),
        nullable=False,
        default="projection",
        server_default="projection",
    )
    projection_type = Column(String(32), nullable=False)  # "snapshot" | "mobile_l1" | future projection kinds
    projection_id = Column(String, nullable=False)  # id of the projection row OR anonymous_session_id for mobile_l1
    constants_version_hash = Column(String(64), nullable=False)
    scenario_inputs_hash = Column(String(64), nullable=False)
    output_hash = Column(String(64), nullable=False)
    lsfin_disclaimer_shown = Column(Boolean, default=False, nullable=False)

    # ── D-12 + D-MOB-03 Mobile L1 audit columns (all nullable, populated
    # only by the /v1/audit/mobile-session-* endpoints) ──
    app_version = Column(String(32), nullable=True)
    observed_at = Column(DateTime(timezone=True), nullable=True)
    anonymous_session_id = Column(String(36), nullable=True)
    local_event_id = Column(String(64), nullable=True)
    app_lifecycle_state = Column(String(32), nullable=True)
    client_ts = Column(DateTime(timezone=True), nullable=True)
    server_received_ts = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        # Composite index covers the two dominant query patterns: per-user
        # audit retrieval and time-window scans for compliance reports.
        Index("ix_projection_audit_user_computed", "user_id_hash", "computed_at"),
        # D-12 + iter-2 A6 : UNIQUE on (anonymous_session_id, observed_at).
        # Postgres uses a PARTIAL unique (declared in alembic p113 with
        # `WHERE anonymous_session_id IS NOT NULL`) so existing snapshot
        # audit rows (NULL anonymous_session_id) remain unaffected. The
        # ORM-side Index here is the SQLite-fallback / reflective-DDL
        # parity anchor (same name as the Postgres partial index).
        Index(
            "uq_proj_audit_anon_observed",
            "anonymous_session_id",
            "observed_at",
            unique=True,
        ),
    )
