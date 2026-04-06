"""
Magic link token model for passwordless authentication.
"""

from uuid import uuid4
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Boolean
from app.core.database import Base


class MagicLinkTokenModel(Base):
    """Single-use magic link tokens for passwordless login."""

    __tablename__ = "magic_link_tokens"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    email = Column(String, nullable=False, index=True)
    token_hash = Column(String, unique=True, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, nullable=False, default=False)
    used_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
