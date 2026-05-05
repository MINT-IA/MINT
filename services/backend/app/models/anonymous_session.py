"""
Anonymous session tracking model (Phase 13, extended Phase 71b).

Tracks message count per device token for rate limiting anonymous chat.
Each anonymous user gets 3 messages (lifetime) before requiring account creation.

Phase 71b: adds `eclairage_delivered` flag to ensure Premier Éclairage is
emitted exactly once per session after coach turn 2.
"""

from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Integer, String

from app.core.database import Base


class AnonymousSession(Base):
    """Tracks anonymous chat usage by device token."""

    __tablename__ = "anonymous_sessions"

    session_id = Column(String(36), primary_key=True)
    message_count = Column(Integer, default=0, nullable=False)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    # Phase 71b — Premier Éclairage one-shot flag.
    eclairage_delivered = Column(
        Boolean,
        default=False,
        nullable=False,
        server_default="0",
    )
