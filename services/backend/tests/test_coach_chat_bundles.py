"""Phase 93.5 BUNDLE-03 — integration tests for coach_chat dual-path wiring.

Covers (per Plan 93.5-02 Task 3) :
- C4 byte-identity regression : flag OFF MUST produce byte-identical output
  to the 5 snapshot fixtures captured in Plan 93.5-01 Task 4.
- Flag ON exercises `compile_bundles` (separator + always-on content).
- Flag ON ≠ flag OFF (otherwise wiring is broken).
- Sentry breadcrumb whitelist (T-93.5-07 — no user content).
- Dual-flag combinatorial (4 combos COACH_DUAL_LLM × COACH_BUNDLE_COMPILER).
- Fallback to legacy on KeyError (Pitfall 1).
- Fallback to legacy on ValueError (H4 undeclared-slot guard).

All flag toggles use `monkeypatch.setattr` on `app.core.config.settings` so
each test is hermetic (no env var bleed).
"""
from __future__ import annotations

from unittest.mock import patch

import pytest

from app.api.v1.endpoints.coach_chat import _build_system_prompt_with_memory
from app.services.coach.claude_coach_service import build_narrator_system_prompt
from app.services.coach.coach_models import CoachContext
from tests.fixtures.narrator_legacy_snapshots._load import (
    FIXTURES,
    FIXTURE_DIR,
    load_fixture,
)


# ---------------------------------------------------------------------------
# C4 — byte-identity regression vs Plan 93.5-01 Task 4 snapshots
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("fixture_name", list(FIXTURES))
def test_flag_off_byte_identical_to_snapshot(monkeypatch, fixture_name):
    """C4 — flag OFF MUST produce byte-identical legacy output to the 5
    snapshot `.txt` fixtures captured in Plan 93.5-01 Task 4.

    Snapshots were captured pre-Wave-1 from
    `build_narrator_system_prompt(ctx, language, cash_level)` (positional
    call, mirroring the legacy production path). This test re-runs the
    same call and asserts byte-equality. If a future PR drifts the legacy
    base prompt, this test fails immediately.

    Re-capture procedure (only when intentionally modifying the legacy
    prompt) is documented in
    `tests/fixtures/narrator_legacy_snapshots/_load.py:13-24`.
    """
    from app.core.config import settings as live_settings
    monkeypatch.setattr(live_settings, "COACH_BUNDLE_COMPILER_ENABLED", False)
    monkeypatch.delenv("COACH_BUNDLE_COMPILER_ENABLED", raising=False)

    ctx, language, cash_level = load_fixture(fixture_name)
    produced = build_narrator_system_prompt(ctx, language, cash_level)

    expected_path = FIXTURE_DIR / f"{fixture_name}.txt"
    expected = expected_path.read_text(encoding="utf-8")

    if produced != expected:
        # Surface a useful diff first 200 chars on each side.
        head_p = produced[:200]
        head_e = expected[:200]
        msg = (
            f"Legacy build_narrator_system_prompt drift on fixture "
            f"{fixture_name!r}.\n"
            f"  produced[:200]={head_p!r}\n"
            f"  expected[:200]={head_e!r}\n"
            f"Re-capture procedure : see "
            f"tests/fixtures/narrator_legacy_snapshots/_load.py:13-24."
        )
        pytest.fail(msg)


# ---------------------------------------------------------------------------
# Shared fake CoachContext + settings helper
# ---------------------------------------------------------------------------


@pytest.fixture
def fake_coach_ctx() -> CoachContext:
    """Default-ish CoachContext for flag ON / OFF parity tests."""
    return CoachContext(
        archetype="swiss_native",
        canton="VD",
        age=45,
        has_debt=False,
    )


# ---------------------------------------------------------------------------
# Flag ON exercises compile_bundles
# ---------------------------------------------------------------------------


def test_flag_on_uses_compile_bundles(monkeypatch, fake_coach_ctx):
    """Flag ON → composed prompt contains the fragment separator AND
    always-on content (DOCTRINE / LSFin keyword / RÈGLES DE CONFORMITÉ)."""
    # Use dotted-string monkeypatch — resolves the settings attribute at
    # patch time against the CURRENT module state, surviving any prior
    # `importlib.reload(config)` contamination from other tests in the suite.
    monkeypatch.setattr(
        "app.core.config.settings.COACH_BUNDLE_COMPILER_ENABLED", True
    )

    prompt = _build_system_prompt_with_memory(
        coach_ctx=fake_coach_ctx,
        memory_block=None,
        language="fr",
        detected_intents={"retirement"},
    )
    # D-11 separator present.
    assert "\n\n---\n\n" in prompt
    # Always-on compliance content present (RÈGLES DE CONFORMITÉ from
    # compliance-narrator's verbatim doctrine block).
    assert (
        "RÈGLES DE CONFORMITÉ" in prompt
        or "DOCTRINE INFORMATION" in prompt
        or "compliance" in prompt.lower()
    )


def test_flag_on_differs_from_flag_off(monkeypatch, fake_coach_ctx):
    """Flag ON path MUST differ from flag OFF — otherwise the wiring is
    broken (the bundle base template differs from
    `_NARRATOR_BASE_SYSTEM_PROMPT`)."""
    from app.core.config import settings as live_settings

    monkeypatch.setattr(live_settings, "COACH_BUNDLE_COMPILER_ENABLED", False)
    prompt_off = _build_system_prompt_with_memory(
        coach_ctx=fake_coach_ctx,
        memory_block=None,
        language="fr",
        detected_intents={"retirement"},
    )

    monkeypatch.setattr(live_settings, "COACH_BUNDLE_COMPILER_ENABLED", True)
    prompt_on = _build_system_prompt_with_memory(
        coach_ctx=fake_coach_ctx,
        memory_block=None,
        language="fr",
        detected_intents={"retirement"},
    )

    assert prompt_off != prompt_on, (
        "Flag ON path produced identical prompt to flag OFF — wiring broken "
        "(check that build_narrator_system_prompt_from_bundles is actually "
        "selected when the flag is True)."
    )


# ---------------------------------------------------------------------------
# T-93.5-07 — telemetry breadcrumb whitelist
# ---------------------------------------------------------------------------


def test_flag_on_telemetry_breadcrumb_no_user_content(monkeypatch, fake_coach_ctx):
    """T-93.5-07 — Sentry breadcrumb payload MUST be exactly
    {activated_bundles, prompt_tokens, dropped_bundles}. Never user
    message content, never raw intents, never PII."""
    # Use dotted-string monkeypatch — resolves the settings attribute at
    # patch time against the CURRENT module state, surviving any prior
    # `importlib.reload(config)` contamination from other tests in the suite.
    monkeypatch.setattr(
        "app.core.config.settings.COACH_BUNDLE_COMPILER_ENABLED", True
    )

    captured: list[dict] = []

    def _capture(*args, **kwargs):
        captured.append(kwargs)

    with patch("sentry_sdk.add_breadcrumb", side_effect=_capture):
        _build_system_prompt_with_memory(
            coach_ctx=fake_coach_ctx,
            memory_block=None,
            language="fr",
            detected_intents={"retirement"},
        )

    bundle_b = next(
        (b for b in captured if b.get("category") == "coach.bundle"),
        None,
    )
    assert bundle_b is not None, (
        f"Expected coach.bundle Sentry breadcrumb, got {[b.get('category') for b in captured]}"
    )
    data = bundle_b.get("data", {}) or {}
    # Whitelist : ONLY these 3 keys are allowed.
    allowed = {"activated_bundles", "prompt_tokens", "dropped_bundles"}
    assert set(data.keys()) <= allowed, (
        f"Breadcrumb leaked unexpected keys : {set(data.keys()) - allowed}"
    )
    # Sanity : activated_bundles is a list, prompt_tokens is an int.
    assert isinstance(data.get("activated_bundles", []), list)
    assert isinstance(data.get("prompt_tokens", 0), int)


# ---------------------------------------------------------------------------
# Dual-flag combinatorial coverage (4 combos)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("dual_llm,bundle", [
    (False, False),
    (False, True),
    (True, False),
    (True, True),
])
def test_dual_flag_combinatorial_no_crash(
    monkeypatch, fake_coach_ctx, dual_llm, bundle,
):
    """4 combos × {DUAL_LLM, BUNDLE} → no crash, valid prompt produced."""
    from app.core.config import settings as live_settings
    monkeypatch.setattr(live_settings, "COACH_DUAL_LLM_ENABLED", dual_llm)
    monkeypatch.setattr(live_settings, "COACH_BUNDLE_COMPILER_ENABLED", bundle)

    prompt = _build_system_prompt_with_memory(
        coach_ctx=fake_coach_ctx,
        memory_block=None,
        language="fr",
        detected_intents={"retirement"},
    )
    assert isinstance(prompt, str)
    assert len(prompt) > 200, (
        f"Prompt suspiciously small ({len(prompt)} chars) for combo "
        f"DUAL_LLM={dual_llm} BUNDLE={bundle}"
    )


# ---------------------------------------------------------------------------
# Fallback : KeyError → legacy path takes over
# ---------------------------------------------------------------------------


def test_flag_on_fallback_on_keyerror(monkeypatch, fake_coach_ctx):
    """Pitfall 1 — `_build_prompt.format(...)` slot interpolation failure
    surfaces as `KeyError` ; the bundle path MUST fall back to legacy."""
    # Use dotted-string monkeypatch — resolves the settings attribute at
    # patch time against the CURRENT module state, surviving any prior
    # `importlib.reload(config)` contamination from other tests in the suite.
    monkeypatch.setattr(
        "app.core.config.settings.COACH_BUNDLE_COMPILER_ENABLED", True
    )

    with patch(
        "app.api.v1.endpoints.coach_chat.build_narrator_system_prompt_from_bundles",
        side_effect=KeyError("undeclared_slot"),
    ):
        prompt = _build_system_prompt_with_memory(
            coach_ctx=fake_coach_ctx,
            memory_block=None,
            language="fr",
            detected_intents={"retirement"},
        )
    # Legacy path took over — non-empty prompt produced.
    assert isinstance(prompt, str)
    assert len(prompt) > 0


def test_flag_on_fallback_on_valueerror(monkeypatch, fake_coach_ctx):
    """H4 — bundle_compiler raises ValueError on undeclared slot ; the
    bundle path MUST fall back to legacy and NOT propagate the error."""
    # Use dotted-string monkeypatch — resolves the settings attribute at
    # patch time against the CURRENT module state, surviving any prior
    # `importlib.reload(config)` contamination from other tests in the suite.
    monkeypatch.setattr(
        "app.core.config.settings.COACH_BUNDLE_COMPILER_ENABLED", True
    )

    with patch(
        "app.api.v1.endpoints.coach_chat.build_narrator_system_prompt_from_bundles",
        side_effect=ValueError(
            "compile_bundles: undeclared slot(s) ['fake_slot_xyz']"
        ),
    ):
        prompt = _build_system_prompt_with_memory(
            coach_ctx=fake_coach_ctx,
            memory_block=None,
            language="fr",
            detected_intents={"retirement"},
        )
    assert isinstance(prompt, str)
    assert len(prompt) > 0


def test_flag_on_fallback_emits_breadcrumb(monkeypatch, fake_coach_ctx):
    """Fallback path emits a `coach.bundle.fallback` Sentry breadcrumb so
    the regression is visible in staging telemetry."""
    # Use dotted-string monkeypatch — resolves the settings attribute at
    # patch time against the CURRENT module state, surviving any prior
    # `importlib.reload(config)` contamination from other tests in the suite.
    monkeypatch.setattr(
        "app.core.config.settings.COACH_BUNDLE_COMPILER_ENABLED", True
    )

    captured: list[dict] = []

    def _capture(*args, **kwargs):
        captured.append(kwargs)

    with patch(
        "app.api.v1.endpoints.coach_chat.build_narrator_system_prompt_from_bundles",
        side_effect=ValueError("forced for test"),
    ), patch("sentry_sdk.add_breadcrumb", side_effect=_capture):
        _build_system_prompt_with_memory(
            coach_ctx=fake_coach_ctx,
            memory_block=None,
            language="fr",
            detected_intents={"retirement"},
        )

    fallback_b = next(
        (b for b in captured if b.get("category") == "coach.bundle.fallback"),
        None,
    )
    assert fallback_b is not None, (
        "Expected coach.bundle.fallback Sentry breadcrumb on ValueError ; "
        f"got {[b.get('category') for b in captured]}"
    )
    # Fallback breadcrumb whitelist : exc_type only.
    assert set(fallback_b.get("data", {}).keys()) <= {"exc_type"}
    assert fallback_b["data"]["exc_type"] == "ValueError"


# ---------------------------------------------------------------------------
# Empty-intent path through wiring
# ---------------------------------------------------------------------------


def test_flag_on_empty_intent_routes_through(monkeypatch, fake_coach_ctx):
    """D-14 — flag ON + `detected_intents = set()` should produce a valid
    always-on-only prompt without crashing and without falling back."""
    # Use dotted-string monkeypatch — resolves the settings attribute at
    # patch time against the CURRENT module state, surviving any prior
    # `importlib.reload(config)` contamination from other tests in the suite.
    monkeypatch.setattr(
        "app.core.config.settings.COACH_BUNDLE_COMPILER_ENABLED", True
    )

    prompt = _build_system_prompt_with_memory(
        coach_ctx=fake_coach_ctx,
        memory_block=None,
        language="fr",
        detected_intents=set(),
    )
    assert "\n\n---\n\n" in prompt
    # Always-on compliance content present.
    assert (
        "RÈGLES DE CONFORMITÉ" in prompt
        or "DOCTRINE INFORMATION" in prompt
    )


def test_flag_on_default_none_intents_treated_as_empty(monkeypatch, fake_coach_ctx):
    """When the caller forgets to pass `detected_intents`, the default
    `None` is treated as an empty set (always-on only). No crash."""
    # Use dotted-string monkeypatch — resolves the settings attribute at
    # patch time against the CURRENT module state, surviving any prior
    # `importlib.reload(config)` contamination from other tests in the suite.
    monkeypatch.setattr(
        "app.core.config.settings.COACH_BUNDLE_COMPILER_ENABLED", True
    )

    prompt = _build_system_prompt_with_memory(
        coach_ctx=fake_coach_ctx,
        memory_block=None,
        language="fr",
        # detected_intents intentionally omitted → defaults to None
    )
    assert isinstance(prompt, str)
    assert len(prompt) > 200
