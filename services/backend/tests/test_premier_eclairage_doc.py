"""Tests for document-specific premier eclairage generation (DOC-07).

Tests the 4-layer insight engine applied to extracted document data:
Layer 1: Factual extraction
Layer 2: Human translation
Layer 3: Personal perspective
Layer 4: Questions to ask

Uses mocked Claude API responses.
"""

import json
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.schemas.document_scan import (
    ConfidenceLevel,
    DocumentType,
    ExtractedFieldConfirmation,
    PremierEclairageRequest,
    PremierEclairageResponse,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _mock_claude_response(text: str) -> MagicMock:
    """Create a mock Anthropic messages.create() response."""
    mock_resp = MagicMock()
    mock_content = MagicMock()
    mock_content.text = text
    mock_resp.content = [mock_content]
    return mock_resp


def _sample_lpp_fields():
    return [
        ExtractedFieldConfirmation(
            field_name="avoirLppTotal",
            value=70377.0,
            confidence=ConfidenceLevel.high,
            source_text="Avoir de vieillesse total: CHF 70'377",
        ),
        ExtractedFieldConfirmation(
            field_name="tauxConversion",
            value=6.8,
            confidence=ConfidenceLevel.high,
            source_text="Taux de conversion: 6.8%",
        ),
        ExtractedFieldConfirmation(
            field_name="rachatMax",
            value=539414.0,
            confidence=ConfidenceLevel.medium,
            source_text="Rachat max: CHF 539'414",
        ),
    ]


def _sample_salary_fields():
    return [
        ExtractedFieldConfirmation(
            field_name="salaireBrut",
            value=122207.0,
            confidence=ConfidenceLevel.high,
            source_text="Salaire brut annuel: CHF 122'207",
        ),
        ExtractedFieldConfirmation(
            field_name="deductionAVS",
            value=6476.97,
            confidence=ConfidenceLevel.high,
            source_text="AVS: CHF 6'476.97",
        ),
    ]


_MOCK_CLAUDE_JSON = json.dumps({
    "factual_extraction": "Ton certificat LPP montre un avoir de CHF 70'377 avec un taux de conversion de 6.8%.",
    "human_translation": "Cela signifie qu'a la retraite, cet avoir pourrait te donner environ CHF 399 par mois.",
    "personal_perspective": "Avec un rachat max de CHF 539'414, tu as une marge importante pour optimiser ta prevoyance.",
    "questions_to_ask": [
        "Demande a ta caisse : le taux de 6.8% s'applique-t-il a l'ensemble de ton avoir ou seulement a la part obligatoire ?",
        "Quel est le taux technique utilise pour projeter ton avoir a 65 ans ?",
    ],
})


# ---------------------------------------------------------------------------
# Test: generate_document_insight function
# ---------------------------------------------------------------------------


class TestGenerateDocumentInsight:
    """Tests for the generate_document_insight() function."""

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_lpp_extraction_returns_all_4_layers(self, mock_anthropic_cls, mock_settings):
        """Test 1: LPP extraction data returns PremierEclairageResponse with all 4 layers."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.return_value = _mock_claude_response(_MOCK_CLAUDE_JSON)

        from app.api.v1.endpoints.documents import generate_document_insight

        result = generate_document_insight(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            canton="VS",
        )

        assert isinstance(result, PremierEclairageResponse)
        assert result.factual_extraction
        assert result.human_translation
        assert result.personal_perspective
        assert len(result.questions_to_ask) >= 1

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_salary_returns_income_mention(self, mock_anthropic_cls, mock_settings):
        """Test 2: Salary certificate data returns insight mentioning salary/income."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        salary_json = json.dumps({
            "factual_extraction": "Ton salaire brut annuel est de CHF 122'207.",
            "human_translation": "Cela represente environ CHF 10'184 par mois avant deductions.",
            "personal_perspective": "Ta deduction AVS de CHF 6'477 finance ta rente future.",
            "questions_to_ask": ["Verifie que ton employeur cotise bien au taux LPP correct."],
        })
        mock_client.messages.create.return_value = _mock_claude_response(salary_json)

        from app.api.v1.endpoints.documents import generate_document_insight

        result = generate_document_insight(
            document_type=DocumentType.salary_certificate,
            extracted_fields=_sample_salary_fields(),
            canton="VS",
        )

        assert "salaire" in result.factual_extraction.lower() or "122" in result.factual_extraction

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_1e_plan_includes_capital_warning_context(self, mock_anthropic_cls, mock_settings):
        """Test 3: 1e plan type includes capital-only warning context in prompt."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.return_value = _mock_claude_response(_MOCK_CLAUDE_JSON)

        from app.api.v1.endpoints.documents import generate_document_insight

        generate_document_insight(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            plan_type="1e",
            canton="VS",
        )

        # Verify the prompt sent to Claude includes 1e warning
        call_args = mock_client.messages.create.call_args
        messages = call_args.kwargs.get("messages") or call_args[1].get("messages")
        prompt_text = str(messages)
        assert "1e" in prompt_text.lower()

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_returns_disclaimer_with_lsfin(self, mock_anthropic_cls, mock_settings):
        """Test 4: Response includes disclaimer field with LSFin mention."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.return_value = _mock_claude_response(_MOCK_CLAUDE_JSON)

        from app.api.v1.endpoints.documents import generate_document_insight

        result = generate_document_insight(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            canton="VS",
        )

        assert "LSFin" in result.disclaimer or "lsfin" in result.disclaimer.lower()

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_returns_sources_with_legal_refs(self, mock_anthropic_cls, mock_settings):
        """Test 5: Response includes sources field with legal references."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.return_value = _mock_claude_response(_MOCK_CLAUDE_JSON)

        from app.api.v1.endpoints.documents import generate_document_insight

        result = generate_document_insight(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            canton="VS",
        )

        assert len(result.sources) >= 1
        sources_text = " ".join(result.sources).lower()
        assert "lpp" in sources_text or "art" in sources_text

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_fallback_on_claude_failure(self, mock_anthropic_cls, mock_settings):
        """Test 7: Empty/failed Claude response returns graceful fallback insight."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.side_effect = Exception("API timeout")

        from app.api.v1.endpoints.documents import generate_document_insight

        result = generate_document_insight(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            canton="VS",
        )

        # Fallback should still return valid response
        assert isinstance(result, PremierEclairageResponse)
        assert result.factual_extraction  # Should have field summary
        assert result.disclaimer  # Always present

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_response_has_human_translation_personal_perspective_questions(
        self, mock_anthropic_cls, mock_settings
    ):
        """Test 8: PremierEclairageResponse includes all required fields."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.return_value = _mock_claude_response(_MOCK_CLAUDE_JSON)

        from app.api.v1.endpoints.documents import generate_document_insight

        result = generate_document_insight(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            canton="VS",
        )

        assert hasattr(result, "human_translation")
        assert hasattr(result, "personal_perspective")
        assert hasattr(result, "questions_to_ask")
        assert isinstance(result.questions_to_ask, list)

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_prompt_includes_doctrine(self, mock_anthropic_cls, mock_settings):
        """Test 9: Prompt includes 'Mint eclaire, Mint ne juge pas' doctrine."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.return_value = _mock_claude_response(_MOCK_CLAUDE_JSON)

        from app.api.v1.endpoints.documents import generate_document_insight

        generate_document_insight(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            canton="VS",
        )

        call_args = mock_client.messages.create.call_args
        messages = call_args.kwargs.get("messages") or call_args[1].get("messages")
        prompt_text = str(messages)
        assert "eclaire" in prompt_text.lower()

    @patch("app.api.v1.endpoints.documents.settings")
    @patch("app.api.v1.endpoints.documents.Anthropic")
    def test_no_banned_terms_in_response(self, mock_anthropic_cls, mock_settings):
        """Test 10: Response complies with ComplianceGuard (no banned terms)."""
        mock_settings.ANTHROPIC_API_KEY = "test-key"
        mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"
        mock_client = MagicMock()
        mock_anthropic_cls.return_value = mock_client
        mock_client.messages.create.return_value = _mock_claude_response(_MOCK_CLAUDE_JSON)

        from app.api.v1.endpoints.documents import generate_document_insight

        result = generate_document_insight(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            canton="VS",
        )

        banned = ["garanti", "sans risque", "optimal", "meilleur", "parfait"]
        all_text = (
            result.factual_extraction
            + result.human_translation
            + result.personal_perspective
        ).lower()
        for term in banned:
            assert term not in all_text, f"Banned term '{term}' found in response"

    def test_no_api_key_returns_fallback(self):
        """Test: Without API key, generate_document_insight returns fallback."""
        with patch("app.api.v1.endpoints.documents.settings") as mock_settings:
            mock_settings.ANTHROPIC_API_KEY = ""
            mock_settings.COACH_MODEL = "claude-sonnet-4-20250514"

            from app.api.v1.endpoints.documents import generate_document_insight

            result = generate_document_insight(
                document_type=DocumentType.lpp_certificate,
                extracted_fields=_sample_lpp_fields(),
                canton="VS",
            )

            assert isinstance(result, PremierEclairageResponse)
            assert result.factual_extraction
            assert result.disclaimer


# ---------------------------------------------------------------------------
# Test: PremierEclairage schemas
# ---------------------------------------------------------------------------


class TestPremierEclairageSchemas:
    """Tests for PremierEclairageRequest and PremierEclairageResponse schemas."""

    def test_request_schema_has_required_fields(self):
        req = PremierEclairageRequest(
            document_type=DocumentType.lpp_certificate,
            extracted_fields=_sample_lpp_fields(),
            overall_confidence=0.85,
        )
        assert req.document_type == DocumentType.lpp_certificate
        assert len(req.extracted_fields) == 3
        assert req.overall_confidence == 0.85

    def test_response_schema_has_all_layers(self):
        resp = PremierEclairageResponse(
            factual_extraction="Facts here",
            human_translation="Plain language here",
            personal_perspective="Personal insight here",
            questions_to_ask=["Question 1"],
            disclaimer="Outil educatif (LSFin)",
            sources=["LPP art. 14"],
        )
        assert resp.factual_extraction == "Facts here"
        assert resp.disclaimer == "Outil educatif (LSFin)"
        assert len(resp.sources) == 1
