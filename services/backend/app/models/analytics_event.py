"""
Analytics event model for tracking user behavior and app usage.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, ForeignKey, Index, Integer, String, Text
from app.core.database import Base


class AnalyticsEvent(Base):
    """Analytics event table for tracking user interactions."""
    __tablename__ = "analytics_events"
    __table_args__ = (
        Index("ix_analytics_user_timestamp", "user_id", "timestamp"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    event_name = Column(String, nullable=False, index=True)  # e.g. "screen_view", "wizard_started"
    event_category = Column(String, nullable=False, index=True)  # "navigation", "engagement", "conversion", "error"
    event_data = Column(Text, nullable=True)  # JSON string with extra data
    session_id = Column(String, nullable=True, index=True)  # anonymous session UUID
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)  # optional, if logged in
    screen_name = Column(String, nullable=True, index=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    app_version = Column(String, nullable=True)
    platform = Column(String, nullable=True)  # "ios", "android", "web"
