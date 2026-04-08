"""DocumentAuditLog model for nLPD-compliant document extraction audit trail.

Records metadata about document extractions WITHOUT storing any image data,
field values, or PII. User ID is stored as SHA-256 hash.

Requirements: DOC-08 (audit logging), COMP-04 (nLPD deletion + retention).
"""

import hashlib
from uuid import uuid4
from datetime import datetime, timezone, timedelta

from sqlalchemy import Column, String, Integer, Float, DateTime, Text

from app.core.database import Base


class DocumentAuditLog(Base):
    """Immutable audit log for document extraction attempts.

    CRITICAL: This model stores ONLY metadata. No image data, no field values,
    no source text. See COMP-04 / nLPD requirements.
    """

    __tablename__ = "document_audit_logs"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id_hash = Column(String, nullable=False, index=True)  # SHA-256 of user_id
    document_type = Column(String, nullable=False)
    field_count = Column(Integer, nullable=False, default=0)
    overall_confidence = Column(Float, nullable=False, default=0.0)
    extraction_method = Column(String, nullable=False, default="claude_vision")
    created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    deleted_at = Column(DateTime, nullable=True)  # When image was deleted from memory
    retained_until = Column(
        DateTime,
        nullable=True,
        default=lambda: datetime.now(timezone.utc) + timedelta(days=730),
    )
    classification_result = Column(String, nullable=True)  # "financial" or "non_financial"
    error_message = Column(Text, nullable=True)  # If extraction failed


def create_audit_log(
    user_id: str,
    document_type: str,
    extraction_method: str = "claude_vision",
) -> DocumentAuditLog:
    """Create a DocumentAuditLog with hashed user_id.

    Args:
        user_id: Raw user ID (will be SHA-256 hashed before storage).
        document_type: Type of document being extracted.
        extraction_method: How extraction was performed.

    Returns:
        DocumentAuditLog instance (not yet committed to DB).
    """
    now = datetime.now(timezone.utc)
    return DocumentAuditLog(
        user_id_hash=hashlib.sha256(user_id.encode()).hexdigest(),
        document_type=document_type,
        field_count=0,
        overall_confidence=0.0,
        extraction_method=extraction_method,
        created_at=now,
        retained_until=now + timedelta(days=730),
    )
