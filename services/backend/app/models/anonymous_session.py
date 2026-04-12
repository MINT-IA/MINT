"""
Anonymous session tracking model (Phase 13).

Tracks message count per device token for rate limiting anonymous chat.
Each anonymous user gets 3 messages (lifetime) before requiring account creation.
"""

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Integer, String

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
