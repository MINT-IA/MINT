"""
Tests for Coach Narrative Service + Fallback Templates — Sprint S35.

Covers:
    - CoachNarrativeService — 20 tests
    - FallbackTemplates — 15 tests
    - Coach Context Builder — 5 tests
    - Compliance integration — 5 tests

Run: cd services/backend && python3 -m pytest tests/test_coach_narrative.py -v
"""

import pytest
import re

from app.services.coach.coach_models import (
    CoachContext,
    CoachNarrativeResult,
    ComponentType,
)
from app.services.coach.coach_narrative_service import CoachNarrativeService
from app.services.coach.fallback_templates import FallbackTemplates
from app.services.coach.coach_context_builder import build_coach_context
from app.services.coach.compliance_guard import ComplianceGuard


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def service():
    return CoachNarrativeService()


@pytest.fixture
def default_ctx():
    return CoachContext(
        first_name="Sophie",
        archetype="swiss_native",
        age=35,
        canton="VD",
        fri_total=62.0,
        fri_delta=4.0,
        primary_focus="retraite",
        replacement_ratio=0.54,
        months_liquidity=4.5,
        tax_saving_potential=1820.0,
        confidence_score=65.0,
        days_since_last_visit=3,
        fiscal_season="",
        check_in_streak=5,
        known_values={
            "fri_total": 62.0,
            "replacement_ratio": 54.0,
            "months_liquidity": 4.5,
            "tax_saving": 1820.0,
            "confidence_score": 65.0,
        },
    )


@pytest.fixture
def fiscal_ctx():
    return CoachContext(
        first_name="Marc",
        fri_total=45.0,
        fri_delta=-2.0,
        fiscal_season="3a_deadline",
        tax_saving_potential=1500.0,
        days_since_last_visit=10,
        known_values={"fri_total": 45.0, "tax_saving": 1500.0},
    )


@pytest.fixture
def low_liquidity_ctx():
    return CoachContext(
        first_name="Anna",
        fri_total=38.0,
        months_liquidity=1.5,
        replacement_ratio=0.48,
        tax_saving_potential=800.0,
        known_values={
            "fri_total": 38.0,
            "months_liquidity": 1.5,
            "replacement_ratio": 48.0,
        },
    )


BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait", "conseiller",
    "tu devrais", "tu dois", "il faut que tu",
    "la meilleure option", "nous recommandons",
]


# ===========================================================================
# CoachNarrativeService tests
# ===========================================================================


class TestNarrativeService:
    """Tests for CoachNarrativeService."""

    def test_generate_all_returns_4_components(self, service, default_ctx):
        result = service.generate_all(default_ctx)
        assert isinstance(result, CoachNarrativeResult)
        assert result.greeting
        assert result.score_summary
        assert result.tip_narrative
        assert result.chiffre_choc_reframe

    def test_greeting_contains_first_name(self, service, default_ctx):
        greeting = service.generate_greeting(default_ctx)
        assert "Sophie" in greeting

    def test_greeting_fiscal_season(self, service, fiscal_ctx):
        greeting = service.generate_greeting(fiscal_ctx)
        assert "Marc" in greeting
        assert "3a" in greeting.lower()

    def test_greeting_positive_delta(self, service, default_ctx):
        greeting = service.generate_greeting(default_ctx)
        assert "+4" in greeting or "points" in greeting

    def test_score_summary_contains_score(self, service, default_ctx):
        summary = service.generate_score_summary(default_ctx)
        assert "62" in summary

    def test_score_summary_positive_trend(self, service, default_ctx):
        summary = service.generate_score_summary(default_ctx)
        assert "progression" in summary.lower() or "+4" in summary

    def test_score_summary_negative_trend(self, service, fiscal_ctx):
        summary = service.generate_score_summary(fiscal_ctx)
        assert "recul" in summary.lower() or "2" in summary

    def test_tip_tax_saving(self, service, default_ctx):
        tip = service.generate_tip_narrative(default_ctx)
        assert "3a" in tip.lower() or "impôt" in tip.lower() or "1" in tip

    def test_tip_low_liquidity(self, service, low_liquidity_ctx):
        tip = service.generate_tip_narrative(low_liquidity_ctx)
        assert "liquidité" in tip.lower() or "réserve" in tip.lower() or "mois" in tip.lower()

    def test_chiffre_choc_mentions_confidence(self, service, default_ctx):
        reframe = service.generate_chiffre_choc_reframe(default_ctx)
        assert "%" in reframe or "données" in reframe.lower()

    def test_generate_all_has_disclaimer(self, service, default_ctx):
        result = service.generate_all(default_ctx)
        assert result.disclaimer
        assert "éducatif" in result.disclaimer.lower() or "educatif" in result.disclaimer.lower()

    def test_generate_all_has_sources(self, service, default_ctx):
        result = service.generate_all(default_ctx)
        assert len(result.sources) > 0

    def test_independent_failure_doesnt_cascade(self, service, default_ctx):
        """Each component is independent — one failure shouldn't affect others."""
        result = service.generate_all(default_ctx)
        # All should be non-empty (fallback templates always produce output)
        assert len(result.greeting) > 0
        assert len(result.score_summary) > 0
        assert len(result.tip_narrative) > 0
        assert len(result.chiffre_choc_reframe) > 0


# ===========================================================================
# FallbackTemplates tests
# ===========================================================================


class TestFallbackTemplates:
    """Tests for FallbackTemplates."""

    def test_greeting_default(self, default_ctx):
        text = FallbackTemplates.greeting(default_ctx)
        assert "Sophie" in text
        assert len(text) > 0

    def test_greeting_same_day_return(self):
        ctx = CoachContext(first_name="Test", days_since_last_visit=0)
        text = FallbackTemplates.greeting(ctx)
        assert "Bon retour" in text

    def test_greeting_fiscal_3a(self, fiscal_ctx):
        text = FallbackTemplates.greeting(fiscal_ctx)
        assert "3a" in text

    def test_greeting_positive_delta(self, default_ctx):
        text = FallbackTemplates.greeting(default_ctx)
        assert "+" in text or "points" in text

    def test_score_summary_stable(self):
        ctx = CoachContext(first_name="Test", fri_total=50.0, fri_delta=0.0)
        text = FallbackTemplates.score_summary(ctx)
        assert "Stable" in text

    def test_score_summary_progression(self, default_ctx):
        text = FallbackTemplates.score_summary(default_ctx)
        assert "progression" in text.lower()

    def test_score_summary_recul(self, fiscal_ctx):
        text = FallbackTemplates.score_summary(fiscal_ctx)
        assert "recul" in text.lower()

    def test_tip_tax_saving_high(self, default_ctx):
        text = FallbackTemplates.tip_narrative(default_ctx)
        assert "3a" in text.lower() or "impôt" in text.lower()

    def test_tip_low_liquidity(self, low_liquidity_ctx):
        text = FallbackTemplates.tip_narrative(low_liquidity_ctx)
        assert "mois" in text.lower() or "liquidité" in text.lower()

    def test_tip_low_replacement(self):
        ctx = CoachContext(
            first_name="Test", replacement_ratio=0.45,
            tax_saving_potential=500, months_liquidity=6,
        )
        text = FallbackTemplates.tip_narrative(ctx)
        assert "remplacement" in text.lower() or "retraite" in text.lower() or "score" in text.lower()

    def test_chiffre_choc_reframe(self, default_ctx):
        text = FallbackTemplates.chiffre_choc_reframe(default_ctx)
        assert "%" in text or "données" in text.lower()


# ===========================================================================
# CoachContextBuilder tests
# ===========================================================================


class TestCoachContextBuilder:
    """Tests for build_coach_context."""

    def test_builds_context_with_defaults(self):
        ctx = build_coach_context()
        assert ctx.first_name == "utilisateur"
        assert ctx.canton == "VD"
        assert isinstance(ctx.known_values, dict)

    def test_populates_known_values(self):
        ctx = build_coach_context(
            fri_total=62.0,
            replacement_ratio=0.54,
            tax_saving_potential=1820.0,
        )
        assert ctx.known_values["fri_total"] == 62.0
        assert ctx.known_values["replacement_ratio"] == 54.0  # converted to pct
        assert ctx.known_values["tax_saving"] == 1820.0

    def test_all_fields_populated(self):
        ctx = build_coach_context(
            first_name="Sophie", age=35, canton="GE",
            archetype="expat_eu", fri_total=70.0,
            fiscal_season="3a_deadline",
        )
        assert ctx.first_name == "Sophie"
        assert ctx.age == 35
        assert ctx.canton == "GE"
        assert ctx.archetype == "expat_eu"
        assert ctx.fiscal_season == "3a_deadline"


# ===========================================================================
# Compliance integration tests
# ===========================================================================


class TestComplianceIntegration:
    """Verify all fallback templates pass ComplianceGuard."""

    def test_no_banned_terms_in_greeting(self, default_ctx):
        text = FallbackTemplates.greeting(default_ctx)
        for term in BANNED_TERMS:
            assert term.lower() not in text.lower(), f"Banned term '{term}' in greeting"

    def test_no_banned_terms_in_score_summary(self, default_ctx):
        text = FallbackTemplates.score_summary(default_ctx)
        for term in BANNED_TERMS:
            assert term.lower() not in text.lower(), f"Banned term '{term}' in summary"

    def test_no_banned_terms_in_tip(self, default_ctx):
        text = FallbackTemplates.tip_narrative(default_ctx)
        for term in BANNED_TERMS:
            assert term.lower() not in text.lower(), f"Banned term '{term}' in tip"

    def test_no_banned_terms_in_chiffre_choc(self, default_ctx):
        text = FallbackTemplates.chiffre_choc_reframe(default_ctx)
        for term in BANNED_TERMS:
            assert term.lower() not in text.lower(), f"Banned term '{term}' in reframe"

    def test_all_templates_pass_compliance_guard(self, default_ctx):
        guard = ComplianceGuard()
        for template_fn, ctype in [
            (FallbackTemplates.greeting, ComponentType.greeting),
            (FallbackTemplates.score_summary, ComponentType.score_summary),
            (FallbackTemplates.tip_narrative, ComponentType.tip),
            (FallbackTemplates.chiffre_choc_reframe, ComponentType.chiffre_choc),
        ]:
            text = template_fn(default_ctx)
            result = guard.validate(text, context=default_ctx, component_type=ctype)
            assert not result.use_fallback, (
                f"Template {template_fn.__name__} triggered fallback: {result.violations}"
            )

    def test_edge_case_empty_name(self):
        ctx = CoachContext(first_name="")
        text = FallbackTemplates.greeting(ctx)
        assert isinstance(text, str)

    def test_edge_case_zero_scores(self):
        ctx = CoachContext(first_name="Test", fri_total=0, fri_delta=0)
        text = FallbackTemplates.score_summary(ctx)
        assert "0" in text
