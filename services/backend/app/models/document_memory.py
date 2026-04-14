"""DocumentMemory ORM — re-uploaded documents surface a differential.

v2.7 Phase 28 / DOC-01 (Document Memory v1).

When a user re-uploads a document MINT has already seen (same fingerprint:
hash of doc_class + issuer + layout signature), the coach surfaces what
changed since the last upload ("+9'847 CHF since 2025") instead of
saying "Nouveau document".

Layout deviation: the plan listed app/db/models/ but this project's
SQLAlchemy convention is app/models/ (next to all other models).

JSON column type chosen for cross-DB compatibility (SQLite for tests/dev,
Postgres in prod). Postgres-only JSONB indexing can be added in a
follow-up if query patterns require it.
"""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Index,
    JSON,
    String,
    UniqueConstraint,
)

from app.core.database import Base


class DocumentMemory(Base):
    """Per-user, per-fingerprint memory of uploaded documents."""

    __tablename__ = "document_memory"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    fingerprint = Column(String(128), nullable=False, index=True)
    doc_type = Column(String, nullable=False)
    issuer = Column(String, nullable=True)
    last_seen_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    # field_history: list[{date: iso8601, fields: {field_name: value}}]
    field_history = Column(JSON, nullable=False, default=list)

    __table_args__ = (
        UniqueConstraint("user_id", "fingerprint", name="uq_document_memory_user_fp"),
        Index("ix_document_memory_user_fp", "user_id", "fingerprint"),
    )
