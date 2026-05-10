"""Tests — Phase 91 Wave 0 config scaffolding.

Pins the contract that:
  - `COACH_DUAL_LLM_ENABLED` defaults to False (legacy single-LLM path).
  - The flag is a bool (not a string / "false" / 0).

The flag is NOT wired in Wave 0 — this is scaffolding only. Wave 2 will
read it in `coach_chat.py` Step 1.5 to fork between the legacy and the
dual-LLM (extractor + narrator) paths.

Spec source: `.planning/phases/91-mvp-extractor-v2/91-00-PLAN.md` Task 0.2.
"""


def test_coach_dual_llm_flag_defaults_false():
    """The dual-LLM kill-flag MUST default to False so existing deployments
    keep the legacy single-LLM behavior until the Stage 4 staging flip."""
    from app.core.config import settings

    assert settings.COACH_DUAL_LLM_ENABLED is False
    assert isinstance(settings.COACH_DUAL_LLM_ENABLED, bool)
