"""
Audit event model for security/compliance traceability.
"""

from uuid import uuid4
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Text
from app.core.database import Base


class AuditEventModel(Base):
    """Immutable-style audit log row for sensitive actions."""

    __tablename__ = "audit_events"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, nullable=True, index=True)
    # Hotfix C 2026-05-17 — sha256(user_id) so the audit row survives nLPD
    # erasure on the user record without re-identification risk. Plaintext
    # user_id kept for one deprecation window; a follow-up migration will
    # NULL it after writers stop reading it.
    user_id_hash = Column(String(64), nullable=True, index=True)
    actor_email = Column(String, nullable=True)
    event_type = Column(String, nullable=False, index=True)
    status = Column(String, nullable=False, default="success")
    source = Column(String, nullable=False, default="api")
    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    details_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
