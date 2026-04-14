"""
Commitment device models — implementation intentions & pre-mortem entries.

Implementation intentions follow the WHEN/WHERE/IF-THEN pattern from
behavioral economics (Gollwitzer, 1999). Pre-mortem entries capture
risk scenarios before irrevocable financial decisions (Klein, 2007).

Sources:
    - CMIT-01: Implementation intentions after Layer 4 insights
    - CMIT-05: Pre-mortem protocol for irrevocable decisions
    - CMIT-06: Persistence in DB for CoachContext injection
    - LPD art. 6 (protection des données)
"""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import Column, DateTime, ForeignKey, Index, String, Text

from app.core.database import Base


class CommitmentDevice(Base):
    """WHEN/WHERE/IF-THEN implementation intention linked to a user."""

    __tablename__ = "commitment_devices"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    type = Column(String, nullable=False, default="implementation_intention")
    when_text = Column(Text, nullable=False)
    where_text = Column(Text, nullable=False)
    if_then_text = Column(Text, nullable=False)
    status = Column(
        String, nullable=False, default="pending"
    )  # pending, completed, dismissed
    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    reminder_at = Column(DateTime, nullable=True)

    __table_args__ = (
        Index("ix_commitment_devices_user_status", "user_id", "status"),
    )


class PreMortemEntry(Base):
    """User-generated risk scenario before an irrevocable decision."""

    __tablename__ = "pre_mortem_entries"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    decision_type = Column(
        String, nullable=False
    )  # epl, capital_withdrawal, pillar_3a_closure
    decision_context = Column(Text, nullable=True)
    user_response = Column(Text, nullable=False)
    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )

    __table_args__ = (
        Index("ix_pre_mortem_entries_user_type", "user_id", "decision_type"),
    )
