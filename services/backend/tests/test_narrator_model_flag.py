"""Phase 91 Wave 4 — COACH_NARRATOR_MODEL flag tests (D-01).

Pinning the narrator-model selection contract:

- default = 'sonnet' (matches hardcoded Wave 2 behavior)
- Pydantic Literal allowlist rejects invalid values
- _NARRATOR_MODEL_MAP is single source of truth (reuses
  PRIMARY_MODEL_DEFAULT + FALLBACK_MODEL_HAIKU)
- flag-on + COACH_NARRATOR_MODEL=haiku -> resolver yields haiku model id
- flag-on + COACH_NARRATOR_MODEL=sonnet -> resolver yields sonnet model id
- flag-off -> resolver bypasses the flag and yields effective_model
  (legacy invariance pin)
- extractor stage (`_run_extractor_stage`) is independent — the literal
  'claude-sonnet-4-5-20250929' must remain hardcoded regardless of the
  narrator flag (Karpathy #3 surgical-changes pin per D-01 + RESEARCH §3).

Run:
    cd services/backend && \
    python3 -m pytest tests/test_narrator_model_flag.py -x -v
"""
from __future__ import annotations

import inspect
from unittest.mock import patch

import pytest
from pydantic import ValidationError


# ---------------------------------------------------------------------------
# Settings — Literal allowlist + default value
# ---------------------------------------------------------------------------


def test_coach_narrator_model_default_is_sonnet():
    """Default value matches today's hardcoded Wave 2 narrator behavior.

    Preserves production parity: Stage 3 eval (plan 91-05) is the explicit
    decision point that may flip the default to 'haiku' per
    ADR-20260419-v2.8-kill-policy.md.
    """
    from app.core.config import Settings

    s = Settings()
    assert s.COACH_NARRATOR_MODEL == "sonnet"


def test_coach_narrator_model_literal_rejects_invalid():
    """Pydantic Literal allowlist rejects unknown values at load time.

    Threat T-91-W4-02 (env override `COACH_NARRATOR_MODEL=evil-model`)
    is mitigated structurally: only 'sonnet' and 'haiku' are accepted.
    """
    from app.core.config import Settings

    with pytest.raises(ValidationError):
        Settings(COACH_NARRATOR_MODEL="gpt-4")


def test_coach_narrator_model_literal_accepts_haiku():
    """Symmetric to default — 'haiku' is a valid alternative."""
    from app.core.config import Settings

    s = Settings(COACH_NARRATOR_MODEL="haiku")
    assert s.COACH_NARRATOR_MODEL == "haiku"


# ---------------------------------------------------------------------------
# _NARRATOR_MODEL_MAP single source of truth
# ---------------------------------------------------------------------------


def test_narrator_model_map_is_single_source_of_truth():
    """_NARRATOR_MODEL_MAP reuses PRIMARY_MODEL_DEFAULT + FALLBACK_MODEL_HAIKU.

    Pins both:
      - the literal model ids (Anthropic deprecation surface)
      - the map entries refer to the SAME constants (no string drift)
    """
    from app.api.v1.endpoints import coach_chat

    assert coach_chat._NARRATOR_MODEL_MAP["sonnet"] == coach_chat.PRIMARY_MODEL_DEFAULT
    assert coach_chat._NARRATOR_MODEL_MAP["haiku"] == coach_chat.FALLBACK_MODEL_HAIKU
    assert coach_chat.PRIMARY_MODEL_DEFAULT == "claude-sonnet-4-5-20250929"
    assert coach_chat.FALLBACK_MODEL_HAIKU == "claude-haiku-4-5-20251001"


def test_narrator_model_map_keys_are_exactly_two():
    """Pydantic Literal mirrors the map keys — they must stay in sync."""
    from app.api.v1.endpoints import coach_chat

    assert set(coach_chat._NARRATOR_MODEL_MAP.keys()) == {"sonnet", "haiku"}


# ---------------------------------------------------------------------------
# Resolver behavior — replicates the in-handler conditional. Pinning the
# 4-line branch as a contract: the in-handler block is
#
#     _narrator_model = (
#         _NARRATOR_MODEL_MAP[settings.COACH_NARRATOR_MODEL]
#         if settings.COACH_DUAL_LLM_ENABLED
#         else effective_model
#     )
#
# These tests evaluate the same conditional with mocked settings to pin
# all four combinations (flag on/off × haiku/sonnet) without driving
# through the full /coach/chat endpoint (which has heavy fixtures).
# ---------------------------------------------------------------------------


def _resolve_narrator_model(*, dual_llm_enabled: bool, narrator_model: str,
                            effective_model: str) -> str:
    """Mirror the resolver block in coach_chat.py for direct unit testing.

    Reads the SAME _NARRATOR_MODEL_MAP from coach_chat — no duplication.
    A regression in the map (e.g. typo'd model id) flows into this test.
    """
    from app.api.v1.endpoints import coach_chat

    if dual_llm_enabled:
        return coach_chat._NARRATOR_MODEL_MAP[narrator_model]
    return effective_model


def test_flag_on_haiku_resolves_to_haiku_model_id():
    """flag-on + COACH_NARRATOR_MODEL=haiku -> haiku model id flows in."""
    out = _resolve_narrator_model(
        dual_llm_enabled=True,
        narrator_model="haiku",
        effective_model="claude-sonnet-4-5-20250929",  # ignored on flag-on
    )
    assert out == "claude-haiku-4-5-20251001"


def test_flag_on_sonnet_resolves_to_sonnet_model_id():
    """Symmetric: flag-on + COACH_NARRATOR_MODEL=sonnet -> sonnet model id."""
    out = _resolve_narrator_model(
        dual_llm_enabled=True,
        narrator_model="sonnet",
        effective_model="claude-haiku-4-5-20251001",  # ignored on flag-on
    )
    assert out == "claude-sonnet-4-5-20250929"


def test_flag_off_preserves_effective_model():
    """COACH_DUAL_LLM_ENABLED=False -> COACH_NARRATOR_MODEL is IGNORED.

    Legacy invariance: agent loop receives effective_model (body.model
    OR budget tier override OR PRIMARY_MODEL_DEFAULT). Setting
    COACH_NARRATOR_MODEL=haiku must NOT leak into the flag-off path.
    """
    out = _resolve_narrator_model(
        dual_llm_enabled=False,
        narrator_model="haiku",  # would resolve to haiku ON-flag, but flag is OFF
        effective_model="claude-sonnet-4-5-20250929",
    )
    assert out == "claude-sonnet-4-5-20250929"


def test_flag_off_preserves_arbitrary_effective_model():
    """Flag-off uses whatever effective_model resolution upstream produced
    (body.model override, budget tier override, or PRIMARY_MODEL_DEFAULT).
    The resolver must not second-guess that choice.
    """
    out = _resolve_narrator_model(
        dual_llm_enabled=False,
        narrator_model="sonnet",
        effective_model="claude-haiku-4-5-20251001",  # budget-tier override case
    )
    assert out == "claude-haiku-4-5-20251001"


# ---------------------------------------------------------------------------
# Settings monkeypatch path — pins that real Settings flow through correctly
# ---------------------------------------------------------------------------


def test_settings_monkeypatch_haiku_yields_haiku_model_id():
    """End-to-end on the resolver: real settings monkeypatch + map lookup.

    Mirrors how the in-handler conditional works at runtime: read
    `settings.COACH_DUAL_LLM_ENABLED` + `settings.COACH_NARRATOR_MODEL`,
    then index `_NARRATOR_MODEL_MAP`.
    """
    from app.api.v1.endpoints import coach_chat

    with patch.object(coach_chat.settings, "COACH_DUAL_LLM_ENABLED", True), \
         patch.object(coach_chat.settings, "COACH_NARRATOR_MODEL", "haiku"):
        if coach_chat.settings.COACH_DUAL_LLM_ENABLED:
            resolved = coach_chat._NARRATOR_MODEL_MAP[
                coach_chat.settings.COACH_NARRATOR_MODEL
            ]
        else:
            resolved = "claude-sonnet-4-5-20250929"
    assert resolved == "claude-haiku-4-5-20251001"


def test_settings_monkeypatch_flag_off_ignores_narrator_model():
    """Monkeypatch flag OFF + narrator=haiku must NOT yield haiku.

    Pins the invariance contract at the settings-read level.
    """
    from app.api.v1.endpoints import coach_chat

    with patch.object(coach_chat.settings, "COACH_DUAL_LLM_ENABLED", False), \
         patch.object(coach_chat.settings, "COACH_NARRATOR_MODEL", "haiku"):
        if coach_chat.settings.COACH_DUAL_LLM_ENABLED:
            resolved = coach_chat._NARRATOR_MODEL_MAP[
                coach_chat.settings.COACH_NARRATOR_MODEL
            ]
        else:
            # Caller's effective_model would be passed through.
            resolved = "claude-sonnet-4-5-20250929"
    # Flag OFF + haiku narrator setting -> the conditional doesn't enter
    # the map branch, the upstream effective_model wins.
    assert resolved == "claude-sonnet-4-5-20250929"


# ---------------------------------------------------------------------------
# Extractor independence — Karpathy #3 surgical-changes pin
# ---------------------------------------------------------------------------


def test_extractor_stage_independent_of_narrator_flag():
    """Extractor (`_run_extractor_stage`) still hardcodes Sonnet 4.5.

    Per D-01 + RESEARCH §3: extractor stays Sonnet, narrator is the
    variable. Inspect the source of `_run_extractor_stage` to confirm
    the literal `claude-sonnet-4-5-20250929` is present and was not
    accidentally rewired through `_NARRATOR_MODEL_MAP` (which would
    mean a regression — the narrator flag must not affect extraction).
    """
    from app.api.v1.endpoints import coach_chat

    src = inspect.getsource(coach_chat._run_extractor_stage)
    assert "claude-sonnet-4-5-20250929" in src, (
        "Extractor model regression — must remain hardcoded Sonnet "
        "regardless of COACH_NARRATOR_MODEL flag (D-01 + RESEARCH §3)."
    )
    assert "_NARRATOR_MODEL_MAP" not in src, (
        "Extractor must NOT consult _NARRATOR_MODEL_MAP — that map is "
        "narrator-only. Regressing this conflates the two LLM roles "
        "(Karpathy #3 surgical-changes violation)."
    )
    assert "COACH_NARRATOR_MODEL" not in src, (
        "Extractor must NOT read COACH_NARRATOR_MODEL — extractor model "
        "is hardcoded Sonnet (D-01 + RESEARCH §3)."
    )
