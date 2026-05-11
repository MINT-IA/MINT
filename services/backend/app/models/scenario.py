"""
Scenario model — persists simulation scenarios in PostgreSQL.

Replaces the in-memory _scenarios dict.

Phase 95 DAG-INVALIDATION (2026-05-10) :
- inputs_hash : SHA256 hex (64 chars) of RFC 8785 canonical JSON of the
  inputs that produced this scenario (per services/backend/app/services/
  coach/inputs_hash.py). Nullable for backward compat — existing rows
  remain NULL until the next projection touch.
- superseded_by : UUID7 (36 chars) pointing at the scenario that replaces
  this one when inputs mutate (per services/backend/app/services/coach/
  projection_id.py). Time-ordered, lexical sort = chronological.
"""

from uuid import uuid4
from datetime import datetime, timezone
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
    # Phase 95 DAG-INVALIDATION — see module docstring.
    inputs_hash = Column(String(64), nullable=True)
    superseded_by = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
