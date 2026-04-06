"""Tests for pre-extraction document classification (DOC-10).

Covers classify_document() which uses Claude Vision to determine
whether an uploaded image is a Swiss financial document before
running full extraction.
"""

import pytest
from unittest.mock import patch, MagicMock

from app.schemas.document_scan import DocumentClassificationResult, ConfidenceLevel

# All tests that call classify_document need to patch settings.ANTHROPIC_API_KEY
# because the function checks it before using the Anthropic client.
_SETTINGS_PATCH = "app.services.document_vision_service.settings"


class TestClassifyDocument:
    """Test classify_document() classification logic."""

    @patch("app.services.document_vision_service.Anthropic")
    @patch(_SETTINGS_PATCH)
    def test_financial_document_detected(self, mock_settings, mock_anthropic_cls):
        """LPP certificate returns is_financial=True."""
        from app.services.document_vision_service import classify_document

        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-3-haiku-20240307"

        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [
            MagicMock(text='{"is_financial": true, "detected_type": "lpp_certificate", "confidence": "high"}')
        ]
        mock_client.messages.create.return_value = mock_response

        result = classify_document("iVBORw0KGgoFAKE_IMAGE_DATA")

        assert result.is_financial is True
        assert result.detected_type == "lpp_certificate"
        assert result.confidence == ConfidenceLevel.high

    @patch("app.services.document_vision_service.Anthropic")
    @patch(_SETTINGS_PATCH)
    def test_non_financial_receipt_rejected(self, mock_settings, mock_anthropic_cls):
        """Restaurant receipt returns is_financial=False."""
        from app.services.document_vision_service import classify_document

        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-3-haiku-20240307"

        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [
            MagicMock(text='{"is_financial": false, "detected_type": "receipt", "confidence": "high"}')
        ]
        mock_client.messages.create.return_value = mock_response

        result = classify_document("iVBORw0KGgoFAKE_RECEIPT_DATA")

        assert result.is_financial is False
        assert result.rejection_reason is not None

    @patch("app.services.document_vision_service.Anthropic")
    @patch(_SETTINGS_PATCH)
    def test_selfie_photo_rejected(self, mock_settings, mock_anthropic_cls):
        """Selfie/landscape photo returns is_financial=False."""
        from app.services.document_vision_service import classify_document

        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-3-haiku-20240307"

        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [
            MagicMock(text='{"is_financial": false, "detected_type": "photo", "confidence": "high"}')
        ]
        mock_client.messages.create.return_value = mock_response

        result = classify_document("/9j/4AAQSkZJFAKE_SELFIE_DATA")

        assert result.is_financial is False

    @patch("app.services.document_vision_service.Anthropic")
    @patch(_SETTINGS_PATCH)
    def test_fail_open_on_api_error(self, mock_settings, mock_anthropic_cls):
        """API error fails open (returns is_financial=True)."""
        from app.services.document_vision_service import classify_document

        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-3-haiku-20240307"

        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.side_effect = Exception("API timeout")

        result = classify_document("iVBORw0KGgoFAKE_IMAGE_DATA")

        assert result.is_financial is True
        assert result.confidence == ConfidenceLevel.low

    @patch("app.services.document_vision_service.Anthropic")
    @patch(_SETTINGS_PATCH)
    def test_all_financial_types_detected(self, mock_settings, mock_anthropic_cls):
        """All supported Swiss financial doc types return is_financial=True."""
        from app.services.document_vision_service import classify_document

        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-3-haiku-20240307"

        financial_types = [
            "lpp_certificate", "salary_certificate",
            "pillar_3a_attestation", "avs_extract",
        ]

        for doc_type in financial_types:
            mock_client = MagicMock()
            mock_anthropic_cls.return_value = mock_client
            mock_response = MagicMock()
            mock_response.content = [
                MagicMock(text=f'{{"is_financial": true, "detected_type": "{doc_type}", "confidence": "high"}}')
            ]
            mock_client.messages.create.return_value = mock_response

            result = classify_document("iVBORw0KGgoFAKE")
            assert result.is_financial is True, f"Failed for {doc_type}"

    @patch("app.services.document_vision_service.Anthropic")
    @patch(_SETTINGS_PATCH)
    def test_malformed_json_fails_open(self, mock_settings, mock_anthropic_cls):
        """Malformed JSON from Claude fails open."""
        from app.services.document_vision_service import classify_document

        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-3-haiku-20240307"

        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [
            MagicMock(text="This is not JSON at all")
        ]
        mock_client.messages.create.return_value = mock_response

        result = classify_document("iVBORw0KGgoFAKE")

        assert result.is_financial is True  # fail-open
        assert result.confidence == ConfidenceLevel.low

    def test_no_api_key_fails_open(self):
        """Missing API key fails open gracefully."""
        from app.services.document_vision_service import classify_document

        with patch(_SETTINGS_PATCH) as mock_settings:
            mock_settings.ANTHROPIC_API_KEY = None
            result = classify_document("iVBORw0KGgoFAKE")

        assert result.is_financial is True
        assert result.confidence == ConfidenceLevel.low


class TestDocumentClassificationResultSchema:
    """Test DocumentClassificationResult schema."""

    def test_create_financial_result(self):
        result = DocumentClassificationResult(
            is_financial=True,
            detected_type="lpp_certificate",
            confidence=ConfidenceLevel.high,
        )
        assert result.is_financial is True
        assert result.rejection_reason is None

    def test_create_non_financial_result(self):
        result = DocumentClassificationResult(
            is_financial=False,
            detected_type="receipt",
            confidence=ConfidenceLevel.high,
            rejection_reason="Not a Swiss financial document",
        )
        assert result.is_financial is False
        assert result.rejection_reason is not None
