"""
ExternalDataSource — cache for external API responses.

Stores fetched data from institutional APIs (bLink, caisse de pension, AVS)
with TTL-based expiry. Avoids redundant API calls and enables offline fallback.

Sources:
    - nLPD art. 6 (data minimization, purpose limitation)
    - PSD2 (max 4 API calls/day per consent)
"""

from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Index

from app.core.database import Base


class ExternalDataSourceModel(Base):
    """Cached external API response — one row per (user, source_type) pair."""
    __tablename__ = "external_data_sources"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    source_type = Column(String, nullable=False)  # blink_accounts, blink_balances, caisse_pension, avs_extract
    cached_response = Column(Text, nullable=False)  # JSON string
    fetched_at = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    expires_at = Column(DateTime, nullable=False)

    __table_args__ = (
        Index("ix_external_data_sources_user_source", "user_id", "source_type", unique=True),
        Index("ix_external_data_sources_expires", "expires_at"),
    )
