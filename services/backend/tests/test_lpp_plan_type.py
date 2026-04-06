"""
Tests for LPP plan type detection (DOC-04) and source_text enforcement (DOC-09).

Tests:
    1. Plan type detection: legal, surobligatoire, 1e
    2. Conversion rate suppression for 1e plans
    3. Warning messages for 1e plans
    4. Non-LPP documents return null plan_type
    5. Source text enforcement (missing -> low confidence)
"""

import json
import pytest
from unittest.mock import patch, MagicMock

from app.schemas.document_scan import (
    ConfidenceLevel,
    DocumentType,
    ExtractedFieldConfirmation,
    VisionExtractionResponse,
    LppPlanType,
)
from app.services.document_vision_service import (
    detect_lpp_plan_type,
    extract_with_vision,
    validate_lpp_coherence,
    DOCUMENT_FIELDS,
)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. LPP Plan Type Detection (Tests 1-3)
# ═══════════════════════════════════════════════════════════════════════════════


class TestDetectLppPlanType:
    """Tests for detect_lpp_plan_type() function."""

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_detect_plan_1e_with_explicit_mention(self, mock_anthropic_cls, mock_settings):
        """Test 1: 'plan 1e' text returns LppPlanType.plan_1e with high confidence."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text='{"plan_type": "1e", "confidence": "high"}')]
        mock_client.messages.create.return_value = mock_response

        plan_type, confidence = detect_lpp_plan_type("fake_base64_image")
        assert plan_type == LppPlanType.plan_1e
        assert confidence == ConfidenceLevel.high

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_detect_standard_lpp_returns_legal(self, mock_anthropic_cls, mock_settings):
        """Test 2: Standard LPP cert returns LppPlanType.legal."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text='{"plan_type": "legal", "confidence": "high"}')]
        mock_client.messages.create.return_value = mock_response

        plan_type, confidence = detect_lpp_plan_type("fake_base64_image")
        assert plan_type == LppPlanType.legal
        assert confidence == ConfidenceLevel.high

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_detect_surobligatoire(self, mock_anthropic_cls, mock_settings):
        """Test 2b: surobligatoire plan detected correctly."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text='{"plan_type": "surobligatoire", "confidence": "medium"}')]
        mock_client.messages.create.return_value = mock_response

        plan_type, confidence = detect_lpp_plan_type("fake_base64_image")
        assert plan_type == LppPlanType.surobligatoire
        assert confidence == ConfidenceLevel.medium

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_detect_1e_with_investment_strategies(self, mock_anthropic_cls, mock_settings):
        """Test 3: 'strategies d'investissement individuelles' returns plan_1e."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text='{"plan_type": "1e", "confidence": "medium"}')]
        mock_client.messages.create.return_value = mock_response

        plan_type, confidence = detect_lpp_plan_type("fake_base64_image")
        assert plan_type == LppPlanType.plan_1e

    @patch("app.services.document_vision_service.settings")
    def test_detect_defaults_to_surobligatoire_on_error(self, mock_settings):
        """On API error, defaults to surobligatoire (safest middle ground)."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"

        with patch("app.services.document_vision_service.Anthropic", side_effect=Exception("API error")):
            plan_type, confidence = detect_lpp_plan_type("fake_base64_image")
            assert plan_type == LppPlanType.surobligatoire
            assert confidence == ConfidenceLevel.low

    @patch("app.services.document_vision_service.settings")
    def test_detect_defaults_on_missing_api_key(self, mock_settings):
        """No API key returns surobligatoire default."""
        mock_settings.ANTHROPIC_API_KEY = None

        plan_type, confidence = detect_lpp_plan_type("fake_base64_image")
        assert plan_type == LppPlanType.surobligatoire
        assert confidence == ConfidenceLevel.low


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Conversion Rate Suppression for 1e Plans (Tests 4-6)
# ═══════════════════════════════════════════════════════════════════════════════


class TestConversionRateSuppression:
    """Tests that 1e plans suppress tauxConversion extraction."""

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_1e_plan_suppresses_taux_conversion(self, mock_anthropic_cls, mock_settings):
        """Test 4: When plan_type is 1e, tauxConversion is NOT in extraction fields."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client

        # First call: plan type detection returns 1e
        # Second call: extraction returns fields WITHOUT tauxConversion
        detect_response = MagicMock()
        detect_response.content = [MagicMock(text='{"plan_type": "1e", "confidence": "high"}')]

        extract_response = MagicMock()
        extract_response.content = [MagicMock(text=json.dumps({
            "fields": [
                {"name": "avoirLppTotal", "value": 350000.0, "confidence": "high", "source_text": "Avoir total: CHF 350'000"},
            ],
            "analysis": "Plan 1e detected",
        }))]

        mock_client.messages.create.side_effect = [detect_response, extract_response]

        result = extract_with_vision("fake_base64", DocumentType.lpp_certificate)
        assert result.plan_type == "1e"
        # tauxConversion should not be in extracted fields
        field_names = [f.field_name for f in result.extracted_fields]
        assert "tauxConversion" not in field_names

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_1e_plan_includes_warning(self, mock_anthropic_cls, mock_settings):
        """Test 5: 1e plan includes plan_type_warning."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client

        detect_response = MagicMock()
        detect_response.content = [MagicMock(text='{"plan_type": "1e", "confidence": "high"}')]

        extract_response = MagicMock()
        extract_response.content = [MagicMock(text=json.dumps({
            "fields": [
                {"name": "avoirLppTotal", "value": 350000.0, "confidence": "high", "source_text": "Total: 350k"},
            ],
            "analysis": "Plan 1e",
        }))]

        mock_client.messages.create.side_effect = [detect_response, extract_response]

        result = extract_with_vision("fake_base64", DocumentType.lpp_certificate)
        assert result.plan_type == "1e"
        assert result.plan_type_warning is not None
        assert "1e" in result.plan_type_warning
        assert "capital" in result.plan_type_warning.lower()

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_legal_plan_includes_taux_conversion(self, mock_anthropic_cls, mock_settings):
        """Test 6: When plan_type is legal, tauxConversion IS included in extraction."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client

        detect_response = MagicMock()
        detect_response.content = [MagicMock(text='{"plan_type": "legal", "confidence": "high"}')]

        extract_response = MagicMock()
        extract_response.content = [MagicMock(text=json.dumps({
            "fields": [
                {"name": "avoirLppTotal", "value": 200000.0, "confidence": "high", "source_text": "Total: 200k"},
                {"name": "tauxConversion", "value": 0.068, "confidence": "high", "source_text": "Taux: 6.8%"},
            ],
            "analysis": "Standard LPP",
        }))]

        mock_client.messages.create.side_effect = [detect_response, extract_response]

        result = extract_with_vision("fake_base64", DocumentType.lpp_certificate)
        assert result.plan_type == "legal"
        field_names = [f.field_name for f in result.extracted_fields]
        assert "tauxConversion" in field_names


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Non-LPP Documents (Test 7)
# ═══════════════════════════════════════════════════════════════════════════════


class TestNonLppPlanType:
    """Tests that non-LPP documents have null plan_type."""

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_salary_certificate_has_null_plan_type(self, mock_anthropic_cls, mock_settings):
        """Test 7: Salary certificate has plan_type=None."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client

        extract_response = MagicMock()
        extract_response.content = [MagicMock(text=json.dumps({
            "fields": [
                {"name": "salaireBrutAnnuel", "value": 120000.0, "confidence": "high", "source_text": "Salaire: 120k"},
            ],
            "analysis": "Salary cert",
        }))]

        mock_client.messages.create.return_value = extract_response

        result = extract_with_vision("fake_base64", DocumentType.salary_certificate)
        assert result.plan_type is None
        assert result.plan_type_warning is None


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Source Text Enforcement (DOC-09) (Tests 8-10)
# ═══════════════════════════════════════════════════════════════════════════════


class TestSourceTextEnforcement:
    """Tests for DOC-09: every field must have non-empty source_text."""

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_missing_source_text_degrades_to_low(self, mock_anthropic_cls, mock_settings):
        """Test 8: Field with source_text=None gets low confidence."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client

        extract_response = MagicMock()
        extract_response.content = [MagicMock(text=json.dumps({
            "fields": [
                {"name": "salaireBrutAnnuel", "value": 120000.0, "confidence": "high"},
            ],
            "analysis": "Missing source_text",
        }))]

        mock_client.messages.create.return_value = extract_response

        result = extract_with_vision("fake_base64", DocumentType.salary_certificate)
        field = next(f for f in result.extracted_fields if f.field_name == "salaireBrutAnnuel")
        assert field.confidence == ConfidenceLevel.low
        assert field.source_text is not None
        assert "[non fourni" in field.source_text

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_empty_source_text_degrades_to_low(self, mock_anthropic_cls, mock_settings):
        """Test 9: Field with source_text='' gets low confidence."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client

        extract_response = MagicMock()
        extract_response.content = [MagicMock(text=json.dumps({
            "fields": [
                {"name": "salaireBrutAnnuel", "value": 120000.0, "confidence": "high", "source_text": ""},
            ],
            "analysis": "Empty source_text",
        }))]

        mock_client.messages.create.return_value = extract_response

        result = extract_with_vision("fake_base64", DocumentType.salary_certificate)
        field = next(f for f in result.extracted_fields if f.field_name == "salaireBrutAnnuel")
        assert field.confidence == ConfidenceLevel.low

    @patch("app.services.document_vision_service.settings")
    @patch("app.services.document_vision_service.Anthropic")
    def test_valid_source_text_preserves_confidence(self, mock_anthropic_cls, mock_settings):
        """Test 10: Field with valid source_text preserves its confidence."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "test-model"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client

        extract_response = MagicMock()
        extract_response.content = [MagicMock(text=json.dumps({
            "fields": [
                {"name": "salaireBrutAnnuel", "value": 120000.0, "confidence": "high", "source_text": "Salaire brut: CHF 120'000"},
            ],
            "analysis": "With source text",
        }))]

        mock_client.messages.create.return_value = extract_response

        result = extract_with_vision("fake_base64", DocumentType.salary_certificate)
        field = next(f for f in result.extracted_fields if f.field_name == "salaireBrutAnnuel")
        assert field.confidence == ConfidenceLevel.high
        assert field.source_text == "Salaire brut: CHF 120'000"


# ═══════════════════════════════════════════════════════════════════════════════
# 5. LppPlanType Enum (Tests)
# ═══════════════════════════════════════════════════════════════════════════════


class TestLppPlanTypeEnum:
    """Tests for LppPlanType enum values."""

    def test_enum_has_three_values(self):
        """LppPlanType enum has exactly 3 values."""
        assert len(LppPlanType) == 3

    def test_enum_values(self):
        """LppPlanType enum values are correct."""
        assert LppPlanType.legal.value == "legal"
        assert LppPlanType.surobligatoire.value == "surobligatoire"
        assert LppPlanType.plan_1e.value == "1e"
