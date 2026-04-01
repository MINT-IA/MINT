"""
Household models for Couple+ billing (P6).
"""

from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import (
    Column,
    String,
    DateTime,
    Boolean,
    ForeignKey,
    UniqueConstraint,
    CheckConstraint,
    Text,
)
from sqlalchemy.orm import relationship
from app.core.database import Base


class HouseholdModel(Base):
    __tablename__ = "households"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    household_owner_user_id = Column(
        String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    billing_owner_user_id = Column(
        String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )

    household_owner = relationship("User", foreign_keys=[household_owner_user_id])
    billing_owner = relationship("User", foreign_keys=[billing_owner_user_id])
    members = relationship(
        "HouseholdMemberModel", back_populates="household", cascade="all, delete-orphan"
    )


class HouseholdMemberModel(Base):
    __tablename__ = "household_members"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_household_member_user"),
        CheckConstraint(
            "role IN ('owner', 'partner')", name="ck_household_member_role"
        ),
        CheckConstraint(
            "status IN ('pending', 'active', 'revoked')",
            name="ck_household_member_status",
        ),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    household_id = Column(
        String, ForeignKey("households.id"), nullable=False, index=True
    )
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String, nullable=False, default="owner")
    status = Column(String, nullable=False, default="pending")
    invitation_code = Column(String, nullable=True, unique=True, index=True)
    invited_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    accepted_at = Column(DateTime, nullable=True)
    cooldown_override = Column(Boolean, default=False, nullable=False)

    household = relationship("HouseholdModel", back_populates="members")
    user = relationship("User", foreign_keys=[user_id])


class AdminAuditEventModel(Base):
    """Immutable admin audit log (CO art. 958f — 10 years retention)."""
    __tablename__ = "admin_audit_events"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    admin_user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    action = Column(String, nullable=False, index=True)
    target_user_id = Column(String, nullable=False, index=True)
    reason = Column(Text, nullable=False)  # min 10 chars enforced at service level
    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
