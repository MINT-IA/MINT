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
    """Regional voice markers should match the canton (Phase 6 / REGIONAL-04).

    Post-refactor: regional voice flows through `RegionalMicrocopy.identity_block`
    with VS as the Romande anchor (D-05). VD/GE/NE/JU/FR all resolve to VS.
    """

    def test_vs_regional_markers_present(self):
        """VS canton (Romande anchor) includes Romande regional markers."""
        ctx = _make_ctx(intent="firstJob", canton="VS")
        prompt = build_system_prompt(ctx=ctx)
        assert "Romande" in prompt
        assert "REGIONAL IDENTITY" in prompt

    def test_zh_regional_markers_present(self):
        """ZH canton includes Deutschschweiz markers."""
        ctx = _make_ctx(intent="firstJob", canton="ZH")
        prompt = build_system_prompt(ctx=ctx)
        assert "Deutschschweiz" in prompt
        assert "REGIONAL IDENTITY" in prompt

    def test_romande_markers_absent_for_zh(self):
        """ZH canton does NOT include Romande markers."""
        ctx = _make_ctx(intent="firstJob", canton="ZH")
        prompt = build_system_prompt(ctx=ctx)
        assert "Romande" not in prompt

    def test_zh_markers_absent_for_vs(self):
        """VS canton does NOT include Deutschschweiz markers."""
        ctx = _make_ctx(intent="firstJob", canton="VS")
        prompt = build_system_prompt(ctx=ctx)
        assert "Deutschschweiz" not in prompt

    def test_vd_resolves_to_vs_anchor(self):
        """D-05: VD (Romande secondary) resolves to VS Romande anchor, NOT a VD-labeled block."""
        ctx_vd = _make_ctx(intent="firstJob", canton="VD")
        prompt_vd = build_system_prompt(ctx=ctx_vd)
        ctx_vs = _make_ctx(intent="firstJob", canton="VS")
        prompt_vs = build_system_prompt(ctx=ctx_vs)
        # Both should carry the same Romande identity block
        assert "Romande" in prompt_vd
        assert "anchor: VS" in prompt_vd
        # And VD must NOT introduce a Vaud-specific dedicated block
        assert "anchor: VD" not in prompt_vd
        assert "Romande" in prompt_vs

    def test_secondary_canton_resolves_to_primary(self):
        """NE (Romande secondary) resolves to VS anchor per D-05 flip."""
        ctx = _make_ctx(intent="firstJob", canton="NE")
        prompt = build_system_prompt(ctx=ctx)
        assert "Romande" in prompt
        assert "anchor: VS" in prompt
