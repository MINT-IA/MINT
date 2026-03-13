"""
BankingConsent — persistent storage for banking data access consents.

Replaces the in-memory dict in open_banking/consent_manager.py.
Follows nLPD/PSD2 requirements: explicit, granular, time-limited, revocable.

Sources:
    - nLPD art. 6 (consent principles)
    - PSD2 / bLink (90-day max consent)
"""

from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Index

from app.core.database import Base


class BankingConsentModel(Base):
    """Banking data access consent — one row per consent grant."""
    __tablename__ = "banking_consents"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    bank_id = Column(String, nullable=False)  # e.g. "ubs", "postfinance"
    bank_name = Column(String, nullable=False)
    scopes = Column(Text, nullable=False)  # JSON array: ["accounts", "balances", "transactions"]
    status = Column(String, nullable=False, default="active")  # active | revoked | expired
    granted_at = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    expires_at = Column(DateTime, nullable=False)
    revoked_at = Column(DateTime, nullable=True)

    __table_args__ = (
        Index("ix_banking_consents_user_id", "user_id"),
        Index("ix_banking_consents_status", "user_id", "status"),
    )
