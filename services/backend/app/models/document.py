# TODO(P0-INFRA): Database is currently unencrypted SQLite.
# PII (salary, pension data) stored in plaintext JSON columns.
# Migration to encrypted PostgreSQL required before production launch.
# See: services/backend/app/core/database.py

"""
Document model — persists scanned/uploaded document metadata.

Replaces the in-memory _document_store dict (FIX-109).
Extracted fields stored as JSON (SQLite-compatible for CI/dev).
Raw file bytes are never stored — only extracted metadata.
"""

from uuid import uuid4
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Float, Integer, JSON, ForeignKey
from app.core.database import Base


class DocumentModel(Base):
    """Persisted document scan/upload metadata."""
    __tablename__ = "documents"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    document_type = Column(String, nullable=False)
    upload_date = Column(DateTime, default=datetime.utcnow)
    confidence = Column(Float, default=0.0)
    fields_found = Column(Integer, default=0)
    fields_total = Column(Integer, default=0)
    extracted_fields = Column(JSON, nullable=True)
    warnings = Column(JSON, nullable=True)
    extraction_method = Column(String, default="ocr_mlkit")
    overall_confidence = Column(Float, default=0.0)

    def to_dict(self):
        """Convert to dict (backward compat with _document_store)."""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "document_type": self.document_type,
            "upload_date": self.upload_date.isoformat() if self.upload_date else None,
            "confidence": self.confidence,
            "fields_found": self.fields_found,
            "fields_total": self.fields_total,
            "extracted_fields": self.extracted_fields or {},
            "warnings": self.warnings or [],
        }
