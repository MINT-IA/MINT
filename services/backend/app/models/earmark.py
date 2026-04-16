"""
Earmark and provenance models — coach intelligence layer.

ProvenanceRecord tracks who recommended a financial product to the user.
EarmarkTag tags money with relational/emotional meaning (non-fungibility).

These models support the coach's ability to:
    - Ask naturally who recommended a product (provenance tracking)
    - Respect that users mentally separate their monies (earmarking)
    - Reference stored provenance in future conversations
    - Display earmarked funds separately, never aggregated

Sources:
    - INTL-01: Provenance tracking via conversation
    - INTL-02: Provenance memory injection
    - INTL-03: Earmark detection and persistence
    - INTL-04: Earmark memory injection
    - LPD art. 6 (protection des donnees)
"""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import Column, DateTime, ForeignKey, Index, String, Text

from app.core.database import Base


class ProvenanceRecord(Base):
    """Record of who recommended a financial product to the user.

    Stores role descriptors ("mon banquier", "Uncle Patrick"), not real names.
    Per INTL-01: the coach asks naturally during conversation, never as a form.
    """

    __tablename__ = "provenance_records"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    product_type = Column(
        String, nullable=False
    )  # "3a", "lpp", "assurance_vie", "hypotheque", etc.
    recommended_by = Column(
        String, nullable=False
    )  # "mon banquier", "Uncle Patrick", etc.
    institution = Column(
        String, nullable=True
    )  # "UBS", "PostFinance", etc.
    context_note = Column(Text, nullable=True)  # optional context from conversation
    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )

    __table_args__ = (
        Index("ix_provenance_records_user_product", "user_id", "product_type"),
    )


class EarmarkTag(Base):
    """Tag money with relational or emotional meaning.

    Respects that money is NOT fungible for users: "l'argent de mamie",
    "le compte pour les enfants", "mon heritage".

    Per INTL-03: amount_hint is String (not numeric) because users say
    "environ 50k" not "50000.00". Store the approximate expression as-is.
    """

    __tablename__ = "earmark_tags"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    label = Column(
        String, nullable=False
    )  # "l'argent de mamie", "le compte pour les enfants"
    source_description = Column(
        Text, nullable=True
    )  # "heritage de grand-mere en 2019"
    amount_hint = Column(
        String, nullable=True
    )  # approximate: "environ 50k", "~30'000"
    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )

    __table_args__ = (
        Index("ix_earmark_tags_user_label", "user_id", "label"),
    )
