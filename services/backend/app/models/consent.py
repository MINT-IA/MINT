"""
Consent model — stores granular consent state per user (nLPD compliant).

Each consent is independent, revocable at any time, and OFF by default.

Sources:
    - LPD art. 6 (principes de traitement)
    - nLPD art. 5 let. f (profilage)
    - LSFin art. 3 (information financiere)
"""

from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import Column, String, Boolean, DateTime, Index
from app.core.database import Base


class ConsentModel(Base):
    """Consent state — one row per (user_id, consent_type) pair."""
    __tablename__ = "consents"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, nullable=False, index=True)
    consent_type = Column(String, nullable=False)  # byok_data_sharing, snapshot_storage, notifications
    enabled = Column(Boolean, default=False, nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        Index("ix_consents_user_type", "user_id", "consent_type", unique=True),
    )
