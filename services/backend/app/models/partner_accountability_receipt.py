"""Minimized receipt for an acting user's manual-partner LPP declaration."""

from sqlalchemy import Column, DateTime, Index, String

from app.core.database import Base


class PartnerAccountabilityReceipt(Base):
    """Dedicated receipt store; deliberately isolated from legacy consent."""

    __tablename__ = "partner_accountability_receipts"

    receipt_id = Column(String(36), primary_key=True)
    acting_principal_pseudonym = Column(String(64), nullable=True, index=True)
    subject_owner_pseudonym = Column(String(64), nullable=True)
    subject_kind = Column(String(32), nullable=True)
    accountability_kind = Column(String(64), nullable=True)
    purpose = Column(String(64), nullable=True)
    notice_version = Column(String(128), nullable=True)
    policy_version = Column(String(128), nullable=True)
    hmac_key_id = Column(String(32), nullable=True)
    declared_at = Column(DateTime(timezone=True), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    consumed_at = Column(DateTime(timezone=True), nullable=True)
    erased_at = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index(
            "ix_partner_accountability_actor_erased",
            "acting_principal_pseudonym",
            "erased_at",
        ),
    )
