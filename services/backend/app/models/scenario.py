"""
Scenario model — persists simulation scenarios in PostgreSQL.

Replaces the in-memory _scenarios dict.
"""

from uuid import uuid4
from datetime import datetime
from sqlalchemy import Column, String, DateTime, JSON, ForeignKey
from app.core.database import Base


class ScenarioModel(Base):
    """Persisted simulation scenario."""
    __tablename__ = "scenarios"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    kind = Column(String, nullable=False)
    inputs = Column(JSON, nullable=True)
    outputs = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
