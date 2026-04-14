"""
Coach insight model — cross-session memory persistence.

CoachInsightRecord stores facts, decisions, and preferences that the coach
LLM discovers during conversation via the save_insight tool. These are
loaded into the system prompt on subsequent sessions so the coach remembers
what the user told it.

Sources:
    - CTX-02: save_insight persistence
    - CTX-03: insight memory block injection
    - LPD art. 6 (protection des donnees)
"""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import Column, DateTime, ForeignKey, Index, String, Text

from app.core.database import Base


class CoachInsightRecord(Base):
    """Persistent storage for coach-discovered user insights.

    Each record represents a single fact, decision, or preference the user
    shared during a coaching session. Deduplication is by (user_id, topic):
    if the same topic is saved again, the existing record is updated.

    Per CTX-02: the coach saves insights naturally during conversation.
    Per CTX-03: saved insights are loaded into the system prompt for the
    next session so the coach can reference them without re-asking.
    """

    __tablename__ = "coach_insights"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    topic = Column(String, nullable=False)  # "revenu", "canton", "3a", etc.
    summary = Column(Text, nullable=False)  # "Salaire ~120k CHF/an"
    insight_type = Column(
        String, nullable=False, default="fact"
    )  # "fact", "decision", "preference"
    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_coach_insights_user_topic", "user_id", "topic"),
    )
