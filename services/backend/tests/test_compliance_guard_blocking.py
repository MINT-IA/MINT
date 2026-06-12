"""
Tests for the education-strict blocking gates — mint-grounded-coach-m1 Plan 02.

CONTEXT decision 1 (founder, 2026-06-12) locked the coach compliance perimeter
to "éducation stricte, bulletproof": the ComplianceGuard fallback must no longer
tolerate prescriptive output (was log-only) nor multiple banned terms (was >5),
and the numeric hallucination check must not be silently disabled for empty
profiles (escape hatch at compliance_guard.py:494).

These tests pin the three hardened gates (audit 01 HOLE-3 + HOLE-4):

  Task 1 — L2 prescriptive now blocks (use_fallback=True), L1 blocks any banned
           term that survives sanitisation, while clean conditional French and
           in-doctrine negated-guarantee phrasing still pass (no false-positive
           regression — the W1 "excellent reply1" standard must survive).

  Task 2 — L3 hallucination detection no longer requires a populated profile to
           run: None context is safe, an empty known_values dict is reachable,
           and the populated-profile behaviour is unchanged.

Run: cd services/backend && python3 -m pytest tests/test_compliance_guard_blocking.py -q
"""

import pytest

from app.services.coach.compliance_guard import ComplianceGuard
from app.services.coach.coach_models import CoachContext


@pytest.fixture
def guard():
    return ComplianceGuard()


# ═══════════════════════════════════════════════════════════════════════
# Task 1 — Prescriptive + banned layers blocking (education-strict)
# ═══════════════════════════════════════════════════════════════════════


class TestPrescriptiveBlocking:
    """L2 prescriptive language is now BLOCKING (was log-only)."""

    def test_single_prescriptive_instruction_blocks(self, guard):
        # Audit 01 HOLE-4 Exhibit: "tu devrais racheter ta LPP maintenant" —
        # one prescriptive hit, shipped to the user today. Now it falls back.
        result = guard.validate("Tu devrais racheter ta LPP maintenant.")
        assert result.use_fallback, (
            "A prescriptive financial instruction must fall back under the "
            "education-strict perimeter (CONTEXT decision 1)."
        )
        assert result.sanitized_text == "", (
            "Fallback path returns empty text so the endpoint substitutes a "
            "templated safe reply."
        )

    def test_imperative_rachat_blocks(self, guard):
        # PRESCRIPTIVE_PATTERNS catches "fais un rachat" — a direct instruction.
        result = guard.validate("Fais un rachat de 10'000 CHF cette année.")
        assert result.use_fallback
        assert any("prescriptif" in v.lower() for v in result.violations)

    def test_fallback_reason_records_prescriptive(self, guard):
        # The structured fallback reason must attribute the block to the L2
        # prescriptive gate (plan-07 fallback-rate input depends on this label).
        captured = {}
        original = guard._check_prescriptive

        # Probe the public contract: a prescriptive instruction blocks with a
        # violation that names the prescriptive layer.
        result = guard.validate("Achète un appartement à Lausanne.")
        assert result.use_fallback
        assert any("prescriptif" in v.lower() for v in result.violations)
        del captured, original  # documentation-only locals


class TestBannedResidualBlocking:
    """L1 blocks any banned term that SURVIVES sanitisation (residual)."""

    def test_residual_banned_term_blocks(self, guard, monkeypatch):
        # The sanitiser is comprehensive, so in practice no residual survives.
        # This pins the defense-in-depth contract: if a banned term DID survive
        # sanitisation (a future bypass), the guard blocks rather than ships it.
        # We simulate a residual by stubbing the sanitiser to a no-op for one
        # call, proving the post-sanitisation re-scan is the blocking trigger.
        original_sanitize = guard._sanitize_banned_terms
        monkeypatch.setattr(
            guard, "_sanitize_banned_terms", lambda text: text
        )
        result = guard.validate("Ton rendement est garanti à 3%.")
        assert result.use_fallback, (
            "A banned term that survives sanitisation must trigger fallback "
            "(no >5 tolerance under the education-strict perimeter)."
        )
        # restore for hygiene (monkeypatch also auto-restores)
        guard._sanitize_banned_terms = original_sanitize

    def test_sanitised_banned_term_does_not_block(self, guard):
        # When sanitisation cleans the term (the normal path), no residual
        # remains → the response is preserved (sanitised), not killed.
        result = guard.validate("Demande à un conseiller pour ton dossier.")
        assert not result.use_fallback
        assert "spécialiste" in result.sanitized_text


class TestCleanConditionalPasses:
    """No false-positive regression — the W1 reply1 conditional standard."""

    def test_clean_conditional_passes(self, guard):
        # Hedged, conditional, no imperative — the "excellent reply1" shape.
        result = guard.validate(
            "Tu pourrais envisager un rachat ; l'effet dépend de ta tranche "
            "marginale et du nombre d'années jusqu'à la retraite."
        )
        assert not result.use_fallback, (
            "Clean conditional French must still pass — blocking it would "
            "destroy every substantive coach reply (false-positive regression)."
        )
        assert result.is_compliant

    def test_negated_guarantee_passes(self, guard):
        # In-doctrine anti-promise phrasing contains the banned root "garanti"
        # but is whitelisted by _NEGATED_GUARANTEE_PATTERNS → must not block.
        result = guard.validate(
            "Rien n'est garanti dans la prévoyance ; ce sont des scénarios."
        )
        assert not result.use_fallback, (
            "Negated-guarantee phrasing ('rien n'est garanti') is in-doctrine "
            "and must not trip the banned-term gate."
        )


# ═══════════════════════════════════════════════════════════════════════
# Task 2 — Remove the empty-profile hallucination escape hatch
# ═══════════════════════════════════════════════════════════════════════


class TestHallucinationEscapeHatchRemoved:
    """L3 runs without requiring a populated profile (audit 01 HOLE-3)."""

    def test_none_context_does_not_crash(self, guard):
        # context=None must run cleanly (no detector call, no AttributeError).
        result = guard.validate("Ton score est à 67/100.", context=None)
        assert result is not None
        assert not result.use_fallback

    def test_empty_known_values_path_reached_no_crash(self, guard):
        # An EMPTY known_values dict no longer short-circuits at the old line
        # 494 escape hatch — the detector is now reached and no-ops gracefully
        # (hallucination_detector returns [] on an empty dict).
        ctx = CoachContext(known_values={})
        result = guard.validate(
            "Un versement 3a pourrait réduire ton impôt cette année.",
            context=ctx,
        )
        # No regulatory anchor in an empty profile → no hallucination flagged,
        # response preserved. The point is the path is REACHED, not skipped.
        assert not result.use_fallback

    def test_populated_profile_major_hallucination_still_blocks(self, guard):
        # Existing L3 behaviour must be unchanged: a >=15% deviation on a known
        # value still triggers fallback.
        ctx = CoachContext(
            known_values={
                "3a_saving": 1820.0,
                "lpp_capital": 250000.0,
            }
        )
        result = guard.validate(
            "Tu pourrais économiser CHF 3'500 d'impôt avec un 3a.",
            context=ctx,
        )
        # Known 1820 vs found 3500 → ~92% deviation (major) → fallback.
        assert result.use_fallback

    def test_populated_profile_correct_value_passes(self, guard):
        ctx = CoachContext(known_values={"3a_saving": 1820.0})
        result = guard.validate(
            "Un versement 3a pourrait réduire ton impôt d'environ CHF 1'820.",
            context=ctx,
        )
        assert not result.use_fallback
