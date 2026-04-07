"""
Tests for firstJob coach prompt with 4-layer insight engine.

Validates that build_system_prompt correctly includes:
- 4-layer engine instructions for all intents
- firstJob-specific context when intent is firstJob/premierEmploi
- VD regional voice markers when canton is VD
- ZH regional voice markers when canton is ZH
- No cross-contamination between regional markers
"""


from app.services.coach.claude_coach_service import build_system_prompt
from app.services.coach.coach_models import CoachContext


def _make_ctx(intent: str = "", canton: str = "VD", age: int = 22) -> CoachContext:
    """Create a minimal CoachContext for testing."""
    return CoachContext(
        intent=intent,
        canton=canton,
        age=age,
    )


class TestFourLayerEngine:
    """The 4-layer insight engine should always be present."""

    def test_four_layer_engine_present_without_context(self):
        """4-layer engine is included even with no CoachContext."""
        prompt = build_system_prompt(ctx=None)
        assert "4-LAYER INSIGHT ENGINE" in prompt
        assert "FACTUAL EXTRACTION" in prompt
        assert "HUMAN TRANSLATION" in prompt
        assert "PERSONAL PERSPECTIVE" in prompt
        assert "QUESTIONS TO ASK" in prompt

    def test_four_layer_engine_present_with_context(self):
        """4-layer engine is included when CoachContext is provided."""
        ctx = _make_ctx(intent="firstJob", canton="VD")
        prompt = build_system_prompt(ctx=ctx)
        assert "4-LAYER INSIGHT ENGINE" in prompt
        assert "FACTUAL EXTRACTION" in prompt

    def test_four_layer_engine_present_for_retirement(self):
        """4-layer engine is included for retirement intent (not just firstJob)."""
        ctx = _make_ctx(intent="retirement", canton="VD")
        prompt = build_system_prompt(ctx=ctx)
        assert "4-LAYER INSIGHT ENGINE" in prompt
        assert "FACTUAL EXTRACTION" in prompt


class TestFirstJobContext:
    """firstJob-specific context should only appear for firstJob intents."""

    def test_firstjob_context_present_for_firstjob_intent(self):
        """firstJob intent triggers CONTEXTE PREMIER EMPLOI section."""
        ctx = _make_ctx(intent="firstJob", canton="VD")
        prompt = build_system_prompt(ctx=ctx)
        assert "CONTEXTE PREMIER EMPLOI" in prompt
        assert "premier emploi" in prompt.lower()
        assert "3a" in prompt.lower() or "3e pilier" in prompt.lower()

    def test_firstjob_context_present_for_premier_emploi_chip(self):
        """intentChipPremierEmploi chip key also triggers firstJob context."""
        ctx = _make_ctx(intent="intentChipPremierEmploi", canton="GE")
        prompt = build_system_prompt(ctx=ctx)
        assert "CONTEXTE PREMIER EMPLOI" in prompt

    def test_firstjob_context_absent_for_retirement(self):
        """Retirement intent does NOT trigger firstJob context."""
        ctx = _make_ctx(intent="retirement", canton="VD")
        prompt = build_system_prompt(ctx=ctx)
        assert "CONTEXTE PREMIER EMPLOI" not in prompt

    def test_firstjob_context_absent_for_empty_intent(self):
        """Empty intent does NOT trigger firstJob context."""
        ctx = _make_ctx(intent="", canton="VD")
        prompt = build_system_prompt(ctx=ctx)
        assert "CONTEXTE PREMIER EMPLOI" not in prompt


class TestRegionalVoice:
    """Regional voice markers should match the canton."""

    def test_vd_regional_markers_present(self):
        """VD canton includes Vaud regional markers."""
        ctx = _make_ctx(intent="firstJob", canton="VD")
        prompt = build_system_prompt(ctx=ctx)
        assert "Vaud" in prompt
        assert "COULEUR REGIONALE" in prompt

    def test_zh_regional_markers_present(self):
        """ZH canton includes Zurich regional markers."""
        ctx = _make_ctx(intent="firstJob", canton="ZH")
        prompt = build_system_prompt(ctx=ctx)
        assert "Zuerich" in prompt or "ZH" in prompt
        assert "COULEUR REGIONALE" in prompt

    def test_vd_markers_absent_for_zh(self):
        """ZH canton does NOT include VD markers."""
        ctx = _make_ctx(intent="firstJob", canton="ZH")
        prompt = build_system_prompt(ctx=ctx)
        assert "Vaud" not in prompt
        assert "Morges" not in prompt

    def test_zh_markers_absent_for_vd(self):
        """VD canton does NOT include ZH markers."""
        ctx = _make_ctx(intent="firstJob", canton="VD")
        prompt = build_system_prompt(ctx=ctx)
        assert "Zuerich" not in prompt
        assert "Bahnhofstrasse" not in prompt

    def test_secondary_canton_resolves_to_primary(self):
        """NE (secondary) resolves to VD (primary) regional voice."""
        ctx = _make_ctx(intent="firstJob", canton="NE")
        prompt = build_system_prompt(ctx=ctx)
        assert "Vaud" in prompt
        assert "COULEUR REGIONALE" in prompt
