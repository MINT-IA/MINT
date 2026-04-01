"""
Billing models: subscriptions, entitlements, transactions, webhook events.
"""

from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import (
    Column,
    String,
    DateTime,
    Boolean,
    ForeignKey,
    Integer,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class SubscriptionModel(Base):
    __tablename__ = "subscriptions"
    __table_args__ = (
        UniqueConstraint("user_id", "source", name="uq_subscription_user_source"),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    tier = Column(String, nullable=False, default="free")  # free | coach
    status = Column(
        String, nullable=False, default="inactive"
    )  # inactive | active | trialing | past_due | canceled
    source = Column(String, nullable=False, default="stripe")  # stripe | apple | google
    is_trial = Column(Boolean, nullable=False, default=False)
    current_period_end = Column(DateTime, nullable=True)
    external_customer_id = Column(String, nullable=True, index=True)
    external_subscription_id = Column(String, nullable=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    last_event_at = Column(DateTime, nullable=True)
    updated_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )

    user = relationship("User")
    entitlements = relationship(
        "EntitlementModel", back_populates="subscription", cascade="all, delete-orphan"
    )
    transactions = relationship(
        "BillingTransactionModel",
        back_populates="subscription",
        cascade="all, delete-orphan",
    )


class EntitlementModel(Base):
    __tablename__ = "entitlements"
    __table_args__ = (
        UniqueConstraint("user_id", "feature_key", name="uq_entitlement_user_feature"),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    subscription_id = Column(
        String, ForeignKey("subscriptions.id"), nullable=True, index=True
    )
    feature_key = Column(String, nullable=False, index=True)
    is_active = Column(Boolean, nullable=False, default=False)
    granted_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )

    subscription = relationship("SubscriptionModel", back_populates="entitlements")
    user = relationship("User")


class BillingTransactionModel(Base):
    __tablename__ = "billing_transactions"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    subscription_id = Column(
        String, ForeignKey("subscriptions.id"), nullable=False, index=True
    )
    provider_transaction_id = Column(String, nullable=True, index=True)
    amount_cents = Column(Integer, nullable=False, default=0)
    currency = Column(String, nullable=False, default="chf")
    status = Column(String, nullable=False, default="succeeded")
    raw_payload = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    subscription = relationship("SubscriptionModel", back_populates="transactions")


class BillingWebhookEventModel(Base):
    __tablename__ = "billing_webhook_events"
    __table_args__ = (
        UniqueConstraint("provider", "event_id", name="uq_billing_provider_event"),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    provider = Column(String, nullable=False, index=True)  # stripe | apple | google
    event_id = Column(String, nullable=False, index=True)
    event_type = Column(String, nullable=False, index=True)
    subscription_id = Column(String, ForeignKey("subscriptions.id"), nullable=True, index=True)
    outcome = Column(String, nullable=False, default="applied")  # applied | skipped_duplicate | skipped_stale
    is_processed = Column(Boolean, nullable=False, default=False)
    payload = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
