"""ORM — opérations twin-read C1 (idempotence par clé d'opération).

Migration : alembic/versions/p127_twin_read_operations.py.
"""

from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, String, Text

from app.core.database import Base


class TwinReadOperation(Base):
    """Réponse validée stockée par clé d'opération — le rejeu la resert."""

    __tablename__ = "twin_read_operations"

    operation_key = Column(String(64), primary_key=True)
    session_id = Column(String(36), nullable=False, index=True)
    answer = Column(Text, nullable=False)
    claims_json = Column(Text, nullable=False)
    quota_consumed = Column(Boolean, nullable=False)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
