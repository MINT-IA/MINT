"""mint-grounded-coach-m1 Plan 07 (WS-C) — façade-resolution post-state.

Pins the binding activate-or-delete resolution for the three dark coach
gates (CONTEXT decision 4, NEVER #6). After Plan 07, NO flag-OFF dead guard
remains:

- COACH_CITATION_GATE_ENABLED → ACTIVATED (default True), its narrator-stage
  consumer reachable on the live single-LLM path (the citation grammar is
  appended to `build_system_prompt`'s output so the activated gate has a
  narrator instructed to emit citations).
- COACH_DUAL_LLM_ENABLED → DELETED (flag absent from Settings; the dual-LLM
  extractor stage + narrator branch collapsed to the legacy single-LLM path).
- COACH_BUNDLE_COMPILER_ENABLED → DELETED (flag absent from Settings; the
  bundle-compiler consumer branches removed; the gate uses the global
  CITATION_REGISTRY allowlist).
- COACH_NARRATOR_MODEL → DELETED (only consumed by the dual-LLM model branch).

Decision input (cited in the Plan 07 SUMMARY): the observed `fallback_reasons`
counts from Plan 02 (38.5% on an adversarial-skewed probe, dominated by
`prescriptive_blocked`) and Plan 04 (zero incremental fallback on clean
definitional shapes), plus the `racheter` word-boundary false-positive fix.
"""
from __future__ import annotations

import pathlib

from app.core.config import Settings, settings

_COACH_CHAT = (
    pathlib.Path(__file__).resolve().parent.parent
    / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
)
_CONFIG = (
    pathlib.Path(__file__).resolve().parent.parent / "app" / "core" / "config.py"
)


# ---------------------------------------------------------------------------
# Removed flags are ABSENT from Settings (no dark toggle remains).
# ---------------------------------------------------------------------------


def test_dual_llm_flag_removed_from_settings():
    """COACH_DUAL_LLM_ENABLED must no longer be a Settings field."""
    assert not hasattr(settings, "COACH_DUAL_LLM_ENABLED")
    assert "COACH_DUAL_LLM_ENABLED" not in Settings.model_fields


def test_bundle_compiler_flag_removed_from_settings():
    """COACH_BUNDLE_COMPILER_ENABLED must no longer be a Settings field."""
    assert not hasattr(settings, "COACH_BUNDLE_COMPILER_ENABLED")
    assert "COACH_BUNDLE_COMPILER_ENABLED" not in Settings.model_fields


def test_narrator_model_flag_removed_from_settings():
    """COACH_NARRATOR_MODEL (dual-LLM-only) must no longer be a Settings field."""
    assert not hasattr(settings, "COACH_NARRATOR_MODEL")
    assert "COACH_NARRATOR_MODEL" not in Settings.model_fields


def test_no_dark_flag_reference_remains_in_coach_chat_source():
    """No functional `settings.<removed-flag>` reference survives in the
    coach_chat endpoint (comments naming the removal are allowed)."""
    src = _COACH_CHAT.read_text(encoding="utf-8")
    assert "settings.COACH_DUAL_LLM_ENABLED" not in src
    assert "settings.COACH_BUNDLE_COMPILER_ENABLED" not in src
    assert "settings.COACH_NARRATOR_MODEL" not in src
    assert "_NARRATOR_MODEL_MAP" not in src


# ---------------------------------------------------------------------------
# Citation gate ACTIVATED — default ON + reachable consumer + rollback.
# ---------------------------------------------------------------------------


def test_citation_gate_flag_activated_by_default():
    """The citation gate is ACTIVE by default (Plan 07 activation)."""
    assert settings.COACH_CITATION_GATE_ENABLED is True
    assert Settings().COACH_CITATION_GATE_ENABLED is True


def test_citation_gate_rollback_switch_still_binds(monkeypatch):
    """`COACH_CITATION_GATE_ENABLED=false` env still binds to False — the
    documented rollback to the byte-identical OFF narrator path."""
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "false")
    assert Settings().COACH_CITATION_GATE_ENABLED is False


def test_citation_gate_consumer_reachable_on_live_path():
    """The gate's bypass branch reads the flag, and the live system-prompt
    builder appends the citation grammar when the flag is ON — proving the
    consumer is reachable (not dead) on the single-LLM path."""
    src = _COACH_CHAT.read_text(encoding="utf-8")
    # The wrapper bypass branch still gates on the flag.
    assert "if not settings.COACH_CITATION_GATE_ENABLED:" in src
    # The live builder appends the closed-world citation grammar when ON.
    assert "if settings.COACH_CITATION_GATE_ENABLED:" in src
    assert "build_intent_scoped_citation_grammar" in src
    assert "CITATION_GRAMMAR_FRAGMENT" in src


def test_live_path_narrator_prompt_includes_citation_grammar_when_active():
    """End-to-end (in-process): when the gate is ON (default), the assembled
    narrator system prompt instructs the model to emit citations — without
    this the activated gate would REJECT every uncited number and fall back."""
    from app.api.v1.endpoints.coach_chat import _build_system_prompt_with_memory
    from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT

    assert settings.COACH_CITATION_GATE_ENABLED is True
    prompt = _build_system_prompt_with_memory(
        None,
        memory_block=None,
        language="fr",
        cash_level=3,
        detected_intents=None,
    )
    # The full (cold-start, no-intent) citation grammar fragment is present.
    assert CITATION_GRAMMAR_FRAGMENT in prompt


def test_live_path_prompt_omits_citation_grammar_when_rolled_back(monkeypatch):
    """Rollback parity: with the gate OFF, the live prompt does NOT append
    the citation grammar (byte-identical-to-legacy property preserved)."""
    from app.api.v1.endpoints.coach_chat import _build_system_prompt_with_memory
    from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT

    monkeypatch.setattr(settings, "COACH_CITATION_GATE_ENABLED", False)
    prompt = _build_system_prompt_with_memory(
        None,
        memory_block=None,
        language="fr",
        cash_level=3,
        detected_intents=None,
    )
    assert CITATION_GRAMMAR_FRAGMENT not in prompt


def test_gate_allowlist_falls_back_to_global_registry():
    """The bundle-compiler compile-time allowlist was removed — the wrapper
    unconditionally passes None, so the gate uses the global registry."""
    src = _COACH_CHAT.read_text(encoding="utf-8")
    assert "_gate_allowlist = None" in src
