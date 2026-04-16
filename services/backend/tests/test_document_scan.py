"""Tests for document scan confirmation + Vision extraction endpoints.

Covers:
- POST /api/v1/documents/scan-confirmation
- POST /api/v1/documents/extract-vision
- DocumentScanConfirmation schema validation
- VisionExtractionRequest schema validation
- Confidence delta calculation
- Field validation ranges
"""

import pytest
from app.schemas.document_scan import (
    DocumentType,
    ConfidenceLevel,
    ExtractedFieldConfirmation,
    DocumentScanConfirmation,
    VisionExtractionRequest,
    VisionExtractionResponse,
)
from app.services.document_vision_service import (
    _validate_fields,
    _compute_overall_confidence,
    _build_extraction_prompt,
    DOCUMENT_FIELDS,
)


# ═══════════════════════════════════════════════════════════
#  SCHEMA TESTS
# ═══════════════════════════════════════════════════════════

class TestDocumentScanSchemas:
    """Test Pydantic schema validation for scan confirmation."""

    def test_scan_confirmation_valid(self):
        body = DocumentScanConfirmation(
            document_type=DocumentType.lpp_certificate,
            confirmed_fields=[
                ExtractedFieldConfirmation(
                    field_name="avoirLppTotal",
                    value=350000.0,
                    confidence=ConfidenceLevel.high,
                    source_text="Avoir de vieillesse: CHF 350'000",
                ),
            ],
            overall_confidence=0.92,
        )
        assert body.document_type == DocumentType.lpp_certificate
        assert len(body.confirmed_fields) == 1
        assert body.confirmed_fields[0].value == 350000.0

    def test_scan_confirmation_all_doc_types(self):
        for doc_type in DocumentType:
            body = DocumentScanConfirmation(
                document_type=doc_type,
                confirmed_fields=[],
                overall_confidence=0.5,
            )
            assert body.document_type == doc_type

    def test_confidence_range_validation(self):
        with pytest.raises(Exception):
            DocumentScanConfirmation(
                document_type=DocumentType.lpp_certificate,
                confirmed_fields=[],
                overall_confidence=1.5,  # > 1.0
            )

    def test_vision_request_valid(self):
        req = VisionExtractionRequest(
            document_type=DocumentType.tax_declaration,
            image_base64="iVBORw0KGgo...",
            canton="VD",
            language_hint="fr",
        )
        assert req.document_type == DocumentType.tax_declaration
        assert req.canton == "VD"

    def test_vision_response_model(self):
        resp = VisionExtractionResponse(
            document_type=DocumentType.avs_extract,
            extracted_fields=[
                ExtractedFieldConfirmation(
                    field_name="anneesContribution",
                    value=38,
                    confidence=ConfidenceLevel.high,
                ),
            ],
            overall_confidence=0.85,
        )
        assert len(resp.extracted_fields) == 1
        assert resp.extraction_method == "claude_vision"


# ═══════════════════════════════════════════════════════════
#  FIELD VALIDATION TESTS
# ═══════════════════════════════════════════════════════════

class TestFieldValidation:
    """Test Swiss-specific field range validation."""

    def test_lpp_valid_ranges(self):
        fields = [
            ExtractedFieldConfirmation(
                field_name="avoirLppTotal",
                value=350000.0,
                confidence=ConfidenceLevel.high,
            ),
            ExtractedFieldConfirmation(
                field_name="tauxConversion",
                value=0.068,  # 6.8% — within range
                confidence=ConfidenceLevel.high,
            ),
        ]
        valid = _validate_fields(fields, DocumentType.lpp_certificate)
        assert len(valid) == 2
        assert all(f.confidence == ConfidenceLevel.high for f in valid)

    def test_lpp_out_of_range_downgrades_confidence(self):
        fields = [
            ExtractedFieldConfirmation(
                field_name="tauxConversion",
                value=0.15,  # 15% — WAY too high for Switzerland
                confidence=ConfidenceLevel.high,
            ),
        ]
        valid = _validate_fields(fields, DocumentType.lpp_certificate)
        assert len(valid) == 1
        assert valid[0].confidence == ConfidenceLevel.low  # Downgraded

    def test_avs_years_valid(self):
        fields = [
            ExtractedFieldConfirmation(
                field_name="anneesContribution",
                value=38,
                confidence=ConfidenceLevel.high,
            ),
        ]
        valid = _validate_fields(fields, DocumentType.avs_extract)
        assert valid[0].confidence == ConfidenceLevel.high

    def test_avs_years_out_of_range(self):
        fields = [
            ExtractedFieldConfirmation(
                field_name="anneesContribution",
                value=50,  # > 44 max
                confidence=ConfidenceLevel.high,
            ),
        ]
        valid = _validate_fields(fields, DocumentType.avs_extract)
        assert valid[0].confidence == ConfidenceLevel.low

    def test_unknown_field_downgraded(self):
        fields = [
            ExtractedFieldConfirmation(
                field_name="unknownField",
                value=42.0,
                confidence=ConfidenceLevel.high,
            ),
        ]
        valid = _validate_fields(fields, DocumentType.lpp_certificate)
        assert valid[0].confidence == ConfidenceLevel.low

    def test_string_fields_skip_range_check(self):
        fields = [
            ExtractedFieldConfirmation(
                field_name="planType",
                value="complet",
                confidence=ConfidenceLevel.medium,
            ),
        ]
        valid = _validate_fields(fields, DocumentType.lpp_plan)
        assert valid[0].confidence == ConfidenceLevel.medium  # Unchanged


# ═══════════════════════════════════════════════════════════
#  CONFIDENCE COMPUTATION TESTS
# ═══════════════════════════════════════════════════════════

class TestConfidenceComputation:
    """Test overall confidence calculation."""

    def test_all_high_confidence(self):
        fields = [
            ExtractedFieldConfirmation(
                field_name="a", value=1.0, confidence=ConfidenceLevel.high,
            ),
            ExtractedFieldConfirmation(
                field_name="b", value=2.0, confidence=ConfidenceLevel.high,
            ),
        ]
        assert _compute_overall_confidence(fields) == 1.0

    def test_mixed_confidence(self):
        fields = [
            ExtractedFieldConfirmation(
                field_name="a", value=1.0, confidence=ConfidenceLevel.high,
            ),
            ExtractedFieldConfirmation(
                field_name="b", value=2.0, confidence=ConfidenceLevel.low,
            ),
        ]
        result = _compute_overall_confidence(fields)
        assert 0.5 < result < 0.8  # Average of 1.0 and 0.25

    def test_empty_fields_zero_confidence(self):
        assert _compute_overall_confidence([]) == 0.0


# ═══════════════════════════════════════════════════════════
#  EXTRACTION PROMPT TESTS
# ═══════════════════════════════════════════════════════════

class TestExtractionPrompt:
    """Test prompt generation for Claude Vision."""

    def test_lpp_prompt_contains_fields(self):
        prompt = _build_extraction_prompt(
            DocumentType.lpp_certificate, "VD", "fr",
        )
        assert "avoirLppTotal" in prompt
        assert "tauxConversion" in prompt
        assert "rachatMaximum" in prompt

    def test_avs_prompt_contains_fields(self):
        prompt = _build_extraction_prompt(
            DocumentType.avs_extract, None, "de",
        )
        assert "anneesContribution" in prompt
        assert "renteEstimee" in prompt

    def test_prompt_includes_canton(self):
        prompt = _build_extraction_prompt(
            DocumentType.tax_declaration, "GE", "fr",
        )
        assert "GE" in prompt

    def test_prompt_language_hint(self):
        prompt = _build_extraction_prompt(
            DocumentType.lpp_certificate, None, "de",
        )
        assert "allemand" in prompt

    def test_all_doc_types_have_fields(self):
        for doc_type in DocumentType:
            fields = DOCUMENT_FIELDS.get(doc_type, [])
            assert len(fields) > 0, f"No fields for {doc_type.value}"


# ═══════════════════════════════════════════════════════════
#  ENDPOINT WIRING TESTS (02-01 Task 2)
# ═══════════════════════════════════════════════════════════

from unittest.mock import patch  # noqa: E402
from app.schemas.document_scan import DocumentClassificationResult  # noqa: E402


class TestExtractVisionEndpointWiring:
    """Test classification + audit + finally-block deletion wiring in extract-vision."""

    @patch("app.services.document_vision_service.classify_document")
    def test_non_financial_document_returns_422(self, mock_classify):
        """Non-financial document rejected with 422 before extraction."""
        mock_classify.return_value = DocumentClassificationResult(
            is_financial=False,
            detected_type="receipt",
            confidence=ConfidenceLevel.high,
            rejection_reason="Not a Swiss financial document",
        )

        # Import fresh to pick up the mock
        from app.api.v1.endpoints.documents import _classify_and_reject_if_needed

        rejection = _classify_and_reject_if_needed("iVBORFAKE_IMAGE")
        assert rejection is not None
        assert "ne semble pas" in rejection.lower() or "document financier" in rejection.lower()

    @patch("app.services.document_vision_service.classify_document")
    def test_financial_document_passes_classification(self, mock_classify):
        """Financial document passes classification gate."""
        mock_classify.return_value = DocumentClassificationResult(
            is_financial=True,
            detected_type="lpp_certificate",
            confidence=ConfidenceLevel.high,
        )

        from app.api.v1.endpoints.documents import _classify_and_reject_if_needed

        rejection = _classify_and_reject_if_needed("iVBORFAKE_IMAGE")
        assert rejection is None

    def test_audit_log_import_available(self):
        """DocumentAuditLog and create_audit_log are importable."""
        from app.models.document_audit import DocumentAuditLog, create_audit_log
        assert DocumentAuditLog is not None
        assert create_audit_log is not None

    def test_classify_document_import_in_endpoint(self):
        """classify_document is imported in documents endpoint module."""
        import app.api.v1.endpoints.documents as docs_module
        assert hasattr(docs_module, 'classify_document') or hasattr(docs_module, '_classify_and_reject_if_needed')

    def test_finally_block_exists_in_endpoint(self):
        """The extract-vision endpoint source contains a finally block."""
        import inspect
        from app.api.v1.endpoints.documents import extract_with_claude_vision
        source = inspect.getsource(extract_with_claude_vision)
        assert "finally" in source, "extract-vision endpoint must have a finally block"
        assert "deleted_at" in source, "finally block must set deleted_at"

    def test_image_cleanup_in_endpoint(self):
        """The extract-vision endpoint explicitly clears image_base64."""
        import inspect
        from app.api.v1.endpoints.documents import extract_with_claude_vision
        source = inspect.getsource(extract_with_claude_vision)
        assert 'image_base64' in source and '""' in source, \
            "endpoint must clear image_base64 to empty string"
