"""
Snapshot model — stores financial snapshots for evolution tracking.

Sources:
    - LPD (Loi sur la protection des donnees) — right to erasure
"""

from datetime import datetime
from uuid import uuid4
from sqlalchemy import Column, String, Integer, Float, DateTime, Index, text
from app.core.database import Base


class SnapshotModel(Base):
    """Financial snapshot — point-in-time capture of user's financial state."""
    __tablename__ = "snapshots"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    trigger = Column(String, nullable=False)  # quarterly, life_event, profile_update, check_in
    model_version = Column(String, default="1.0", nullable=False)

    # Core inputs
    age = Column(Integer, default=0, server_default=text("0"))
    birth_date = Column(String, nullable=True)  # ISO 8601 date string
    gross_income = Column(Float, default=0.0, server_default=text("0.0"))
    canton = Column(String, default="VD", server_default=text("'VD'"))
    archetype = Column(String, default="swiss_native", server_default=text("'swiss_native'"))
    household_type = Column(String, default="single", server_default=text("'single'"))

    # Key outputs
    replacement_ratio = Column(Float, default=0.0, server_default=text("0.0"))
    months_liquidity = Column(Float, default=0.0, server_default=text("0.0"))
    tax_saving_potential = Column(Float, default=0.0, server_default=text("0.0"))
    confidence_score = Column(Float, default=0.0, server_default=text("0.0"))
    enrichment_count = Column(Integer, default=0, server_default=text("0"))

    # FRI scores
    fri_total = Column(Float, default=0.0, server_default=text("0.0"))
    fri_l = Column(Float, default=0.0, server_default=text("0.0"))
    fri_f = Column(Float, default=0.0, server_default=text("0.0"))
    fri_r = Column(Float, default=0.0, server_default=text("0.0"))
    fri_s = Column(Float, default=0.0, server_default=text("0.0"))

    __table_args__ = (
        Index("ix_snapshots_user_created", "user_id", "created_at"),
    )
