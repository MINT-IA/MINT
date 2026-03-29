"""
Token blacklist model for JWT JTI persistence.

Blocks token replay attacks by tracking revoked JTIs.
"""

from datetime import datetime
from sqlalchemy import Column, String, DateTime, Index
from app.core.database import Base


class TokenBlacklist(Base):
    """Blacklisted JWT tokens identified by their JTI claim."""

    __tablename__ = "token_blacklist"

    jti = Column(String(64), primary_key=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    blacklisted_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        Index("ix_token_blacklist_expires_at", "expires_at"),
    )
