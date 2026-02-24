"""
Tests for the Compliance Guard — Sprint S34.

25+ adversarial tests feeding deliberately non-compliant LLM outputs
to verify the 5-layer validation pipeline catches all violations.

Run: cd services/backend && python3 -m pytest tests/test_compliance_guard.py -v
"""

import pytest

from app.services.coach.compliance_guard import ComplianceGuard
from app.services.coach.coach_models import (
    ComplianceResult,
    CoachContext,
    ComponentType,
)


@pytest.fixture
def guard():
    return ComplianceGuard()


@pytest.fixture
def context_with_values():
    return CoachContext(
        first_name="Sophie",
        fri_total=62.0,
        fri_delta=4.0,
        primary_focus="retraite",
        days_since_last_visit=3,
        fiscal_season="Déclaration fiscale (mars-juin)",
        known_values={
            "score": 62.0,
            "3a_saving": 1820.0,
            "replacement_ratio": 54.0,
            "lpp_capital": 250000.0,
        },
    )


# ═══════════════════════════════════════════════════════════════════════
# Layer 1: Banned terms detection
# ═══════════════════════════════════════════════════════════════════════


class TestBannedTerms:
    """Layer 1 — Banned terms must be caught."""

    def test_catches_garanti(self, guard):
        result = guard.validate("Ton rendement est garanti à 3%.")
        assert not result.is_compliant
        assert any("garanti" in v for v in result.violations)

    def test_catches_meilleur(self, guard):
        result = guard.validate(
            "C'est le meilleur investissement que tu puisses faire."
        )
        assert not result.is_compliant
        assert any("meilleur" in v for v in result.violations)

    def test_catches_sans_risque(self, guard):
        result = guard.validate("Sans aucun risque de marché.")
        assert not result.is_compliant
        assert any("sans risque" in v for v in result.violations)

    def test_catches_optimal(self, guard):
        result = guard.validate("La stratégie optimale pour ton 3a.")
        assert not result.is_compliant
        assert any("optimal" in v for v in result.violations)

    def test_catches_tu_devrais(self, guard):
        result = guard.validate("Tu devrais faire un rachat LPP cette année.")
        assert not result.is_compliant
        assert any("tu devrais" in v.lower() for v in result.violations)

    def test_catches_parfait(self, guard):
        result = guard.validate("C'est un timing parfait pour investir.")
        assert not result.is_compliant
        assert any("parfait" in v for v in result.violations)

    def test_catches_conseiller(self, guard):
        result = guard.validate("Demande à ton conseiller bancaire.")
        assert not result.is_compliant
        assert any("conseiller" in v for v in result.violations)

    def test_catches_tu_dois(self, guard):
        result = guard.validate("Tu dois absolument ouvrir un 3a.")
        assert not result.is_compliant
        assert any("tu dois" in v.lower() for v in result.violations)

    def test_catches_nous_recommandons(self, guard):
        result = guard.validate("Nous recommandons cette stratégie.")
        assert not result.is_compliant
        assert any("nous recommandons" in v.lower() for v in result.violations)

    def test_sanitizes_single_banned_term(self, guard):
        result = guard.validate("Demande à un conseiller pour ton dossier.")
        # Single banned term → attempt sanitization, not fallback
        assert not result.use_fallback
        assert "spécialiste" in result.sanitized_text

    def test_fallback_on_multiple_banned_terms(self, guard):
        result = guard.validate(
            "C'est garanti, le meilleur et le plus certain choix."
        )
        assert result.use_fallback
        assert len(result.violations) >= 3


# ═══════════════════════════════════════════════════════════════════════
# Layer 2: Prescriptive language
# ═══════════════════════════════════════════════════════════════════════


class TestPrescriptiveLanguage:
    """Layer 2 — Prescriptive financial instructions must trigger fallback."""

    def test_catches_fais_un_rachat(self, guard):
        result = guard.validate("Fais un rachat de 10'000 CHF cette année.")
        assert result.use_fallback
        assert any("prescriptif" in v.lower() for v in result.violations)

    def test_catches_verse_sur_ton(self, guard):
        result = guard.validate("Verse sur ton 3e pilier avant décembre.")
        assert result.use_fallback

    def test_catches_achete(self, guard):
        result = guard.validate("Achète un appartement à Lausanne.")
        assert result.use_fallback

    def test_catches_vends(self, guard):
        result = guard.validate("Vends tes actions et place en obligations.")
        assert result.use_fallback

    def test_catches_choisis_la_rente(self, guard):
        result = guard.validate("Choisis la rente, c'est plus sûr.")
        assert result.use_fallback

    def test_catches_prends_le_capital(self, guard):
        result = guard.validate("Prends le capital et investis-le.")
        assert result.use_fallback

    def test_catches_priorite_absolue(self, guard):
        result = guard.validate(
            "Priorité absolue : monter à 6 mois de réserve."
        )
        assert result.use_fallback

    def test_catches_plus_important_que(self, guard):
        result = guard.validate(
            "C'est plus important que ton 3a cette année."
        )
        assert result.use_fallback


# ═══════════════════════════════════════════════════════════════════════
# Layer 3: Hallucination detection
# ═══════════════════════════════════════════════════════════════════════


class TestHallucinationDetection:
    """Layer 3 — Hallucinated numbers must trigger fallback."""

    def test_catches_wrong_score(self, guard, context_with_values):
        result = guard.validate(
            "Ton score est à 72/100, en progression.",
            context=context_with_values,
        )
        assert result.use_fallback
        assert any("hallucination" in v.lower() for v in result.violations)

    def test_passes_correct_score(self, guard, context_with_values):
        result = guard.validate(
            "Ta solidité financière est de 62/100, en progression de 4 points.",
            context=context_with_values,
        )
        assert not result.use_fallback

    def test_catches_wrong_amount(self, guard, context_with_values):
        result = guard.validate(
            "Tu pourrais économiser CHF 3'500 d'impôt avec un 3a.",
            context=context_with_values,
        )
        # Known value: 1820, found: 3500 → deviation > 5%
        assert result.use_fallback

    def test_passes_correct_amount(self, guard, context_with_values):
        result = guard.validate(
            "Un versement 3a pourrait réduire ton impôt d'environ CHF 1'820.",
            context=context_with_values,
        )
        assert not result.use_fallback


# ═══════════════════════════════════════════════════════════════════════
# Layer 4: Disclaimer injection
# ═══════════════════════════════════════════════════════════════════════


class TestDisclaimerInjection:
    """Layer 4 — Disclaimer auto-injected when discussing projections."""

    def test_injects_disclaimer_for_projection(self, guard):
        result = guard.validate(
            "Ta projection de retraite montre un écart de CHF 2'000 par mois."
        )
        assert "éducatif" in result.sanitized_text.lower() or \
               "educatif" in result.sanitized_text.lower()

    def test_no_disclaimer_for_simple_greeting(self, guard):
        result = guard.validate(
            "Bonjour Sophie ! Content de te revoir.",
            component_type=ComponentType.greeting,
        )
        # No projection keywords → no disclaimer injection
        assert result.is_compliant

    def test_keeps_existing_disclaimer(self, guard):
        text = (
            "Ta simulation montre un écart. "
            "Outil éducatif simplifié (LSFin)."
        )
        result = guard.validate(text)
        # Already has disclaimer → don't double-inject
        count = result.sanitized_text.lower().count("outil")
        assert count == 1


# ═══════════════════════════════════════════════════════════════════════
# Layer 5: Length constraints
# ═══════════════════════════════════════════════════════════════════════


class TestLengthConstraints:
    """Layer 5 — Output truncated per component type."""

    def test_greeting_max_30_words(self, guard):
        long_greeting = " ".join(["mot"] * 50)
        result = guard.validate(
            long_greeting, component_type=ComponentType.greeting
        )
        assert len(result.sanitized_text.split()) <= 30

    def test_tip_max_120_words(self, guard):
        long_tip = ". ".join(["Ceci est une phrase"] * 30) + "."
        result = guard.validate(
            long_tip, component_type=ComponentType.tip
        )
        assert len(result.sanitized_text.split()) <= 120


# ═══════════════════════════════════════════════════════════════════════
# Edge cases
# ═══════════════════════════════════════════════════════════════════════


class TestEdgeCases:
    """Edge cases that must be handled correctly."""

    def test_empty_output_triggers_fallback(self, guard):
        result = guard.validate("")
        assert result.use_fallback
        assert any("vide" in v.lower() for v in result.violations)

    def test_whitespace_only_triggers_fallback(self, guard):
        result = guard.validate("   \n\t  ")
        assert result.use_fallback

    def test_very_long_output_triggers_truncation(self, guard):
        long_text = " ".join(["mot"] * 5000)
        result = guard.validate(long_text)
        assert len(result.sanitized_text.split()) <= 200

    def test_english_text_triggers_fallback(self, guard):
        result = guard.validate(
            "Your financial score is 62. You should invest in a pillar 3a. "
            "This would help with your retirement planning."
        )
        assert result.use_fallback
        assert any("langue" in v.lower() for v in result.violations)

    def test_compliant_text_passes(self, guard):
        result = guard.validate(
            "Dans ce scénario simulé, un versement 3a pourrait réduire "
            "ton impôt d'environ CHF 1'820."
        )
        # No context → no hallucination check; no banned terms
        assert not result.use_fallback

    def test_compliant_conditional_language_passes(self, guard, context_with_values):
        result = guard.validate(
            "Ta solidité financière est de 62/100, en progression de 4 points. "
            "Un versement 3a pourrait réduire ton impôt d'environ CHF 1'820.",
            context=context_with_values,
        )
        assert not result.use_fallback

    def test_no_context_skips_hallucination_check(self, guard):
        result = guard.validate(
            "Ton score est de 99/100, bravo !"
        )
        # No context → hallucination check skipped → passes
        assert not result.use_fallback
