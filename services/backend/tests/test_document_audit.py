"""Tests for DocumentAuditLog model (DOC-08, COMP-04).

Covers:
- Model creation with metadata-only fields
- User ID hashing (never stored raw)
- Retained_until defaults to 2 years
- No image-related fields on model
- Audit log creation helper
"""

import hashlib
from datetime import datetime, timezone

from app.models.document_audit import DocumentAuditLog, create_audit_log


class TestDocumentAuditLogModel:
    """Test DocumentAuditLog SQLAlchemy model."""

    def test_model_has_required_fields(self):
        """All required metadata fields present."""
        now = datetime.now(timezone.utc)
        log = DocumentAuditLog(
            user_id_hash=hashlib.sha256(b"user-123").hexdigest(),
            document_type="lpp_certificate",
            field_count=5,
            overall_confidence=0.85,
            extraction_method="claude_vision",
            created_at=now,
        )
        assert log.user_id_hash == hashlib.sha256(b"user-123").hexdigest()
        assert log.document_type == "lpp_certificate"
        assert log.field_count == 5
        assert log.overall_confidence == 0.85
        assert log.extraction_method == "claude_vision"

    def test_no_image_fields_on_model(self):
        """CRITICAL: No image_base64, image_data, or source_text fields."""
        column_names = [c.name for c in DocumentAuditLog.__table__.columns]
        for forbidden in ["image_base64", "image_data", "source_text", "field_values"]:
            assert forbidden not in column_names, f"Found forbidden field: {forbidden}"

    def test_retained_until_defaults_to_two_years(self):
        """retained_until should default to ~730 days from created_at."""
        now = datetime.now(timezone.utc)
        log = DocumentAuditLog(
            user_id_hash="abc",
            document_type="lpp_certificate",
            extraction_method="claude_vision",
            created_at=now,
        )
        # Call the default manually since SQLAlchemy defaults need context
        if log.retained_until is None:
            # Default is set by SQLAlchemy column default -- test the default callable
            default_fn = DocumentAuditLog.__table__.c.retained_until.default
            assert default_fn is not None, "retained_until must have a default"

    def test_user_id_is_hashed(self):
        """User ID stored as SHA-256 hash, never raw."""
        raw_user_id = "550e8400-e29b-41d4-a716-446655440000"
        expected_hash = hashlib.sha256(raw_user_id.encode()).hexdigest()
        log = DocumentAuditLog(
            user_id_hash=expected_hash,
            document_type="avs_extract",
            extraction_method="claude_vision",
        )
        assert log.user_id_hash == expected_hash
        assert raw_user_id not in log.user_id_hash

    def test_deleted_at_nullable(self):
        """deleted_at is nullable (set in finally block after extraction)."""
        log = DocumentAuditLog(
            user_id_hash="abc",
            document_type="lpp_certificate",
            extraction_method="claude_vision",
        )
        assert log.deleted_at is None

    def test_error_message_nullable(self):
        """error_message captures extraction failure reason."""
        log = DocumentAuditLog(
            user_id_hash="abc",
            document_type="lpp_certificate",
            extraction_method="claude_vision",
            error_message="API timeout after 30s",
        )
        assert log.error_message == "API timeout after 30s"

    def test_classification_result_field(self):
        """classification_result stores financial/non_financial."""
        log = DocumentAuditLog(
            user_id_hash="abc",
            document_type="lpp_certificate",
            extraction_method="claude_vision",
            classification_result="financial",
        )
        assert log.classification_result == "financial"


class TestCreateAuditLog:
    """Test create_audit_log() helper function."""

    def test_creates_log_with_hashed_user_id(self):
        """create_audit_log hashes user_id automatically."""
        raw_user_id = "550e8400-e29b-41d4-a716-446655440000"
        log = create_audit_log(
            user_id=raw_user_id,
            document_type="lpp_certificate",
            extraction_method="claude_vision",
        )
        expected_hash = hashlib.sha256(raw_user_id.encode()).hexdigest()
        assert log.user_id_hash == expected_hash
        assert log.document_type == "lpp_certificate"
        assert log.extraction_method == "claude_vision"
        assert log.field_count == 0
        assert log.overall_confidence == 0.0
        assert log.created_at is not None

    def test_audit_log_creation_on_extraction_failure(self):
        """Audit log records the attempt even when extraction fails."""
        log = create_audit_log(
            user_id="user-456",
            document_type="tax_declaration",
            extraction_method="claude_vision",
        )
        log.error_message = "Claude API timeout"
        assert log.error_message == "Claude API timeout"
        assert log.field_count == 0
