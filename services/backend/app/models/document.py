# At-rest encryption strategy — see docs/security/at-rest-encryption.md
# (Phase 97 W7 iter#10, T002 closed 2026-05-11).
#
# Defense-in-depth :
#   1. Production / staging DB is Railway PostgreSQL (encryption-at-rest
#      provided by Railway's managed infrastructure, AES-256 at the
#      block-storage layer). Fail-closed startup check in
#      `app/core/config.py:179-188` rejects sqlite:// in prod/staging.
#   2. The application-layer envelope module
#      (`app/services/encryption/envelope.py`, AES-256-GCM per-user DEK,
#      v2.7 / PRIV-04) is deployed and used today by
#      `document_memory_service` for `evidence_text` + `vision_raw`.
#   3. Mobile local SQLite uses SQLCipher AES-256-CBC via
#      `sqflite_sqlcipher` — see `apps/mobile/lib/services/biography`.
#
# Follow-up (separate plan, NOT a blocker for T002 close) : promoting
# this model's `extracted_fields` + `warnings` JSON columns from Layer 1
# (Railway infra) protection to additional Layer 2 (envelope) protection.
# The envelope module is ready ; the surface adoption requires an
# alembic backfill + ContextVar wiring in `endpoints/documents.py`.

"""
Document model — persists scanned/uploaded document metadata.

Replaces the in-memory _document_store dict (FIX-109).
Extracted fields stored as JSON (SQLite-compatible for CI/dev).
Raw file bytes are never stored — only extracted metadata.
"""

from uuid import uuid4
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Float, Integer, JSON, ForeignKey
from app.core.database import Base


class DocumentModel(Base):
    """Persisted document scan/upload metadata."""
    __tablename__ = "documents"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    document_type = Column(String, nullable=False)
    upload_date = Column(DateTime, default=lambda: datetime.now(timezone.utc))
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
