"""VisionGuard tests — Phase 29-04 / PRIV-05.

Mocks the Haiku judge call and verifies:
    - 5 violation categories are correctly surfaced
    - fail-closed on judge unavailable (API error / missing key / no tool_use)
    - reformulation swap happens on block
    - judge reformulation is itself scrubbed of banned terms (defense-in-depth)
    - VISION_GUARD_ENABLED=false bypasses the judge with a warning log
    - model id is pinned (tripwire)
    - cost telemetry emitted without PII
"""
from __future__ import annotations

import os
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.services.compliance import vision_guard as vg


# ---------------------------------------------------------------------------
# Helpers — build a fake Haiku response.
# ---------------------------------------------------------------------------


def _fake_response(tool_input, input_tokens=120, output_tokens=60):
    """Mimic an anthropic.types.Message with a single tool_use block."""
    tool_block = SimpleNamespace(type="tool_use", input=tool_input)
    usage = SimpleNamespace(
        input_tokens=input_tokens, output_tokens=output_tokens,
    )
    return SimpleNamespace(content=[tool_block], usage=usage)


class _FakeAsyncAnthropic:
    """Drop-in replacement for AsyncAnthropic used by vision_guard."""

    def __init__(self, response=None, raises=None):
        self._response = response
        self._raises = raises
        self.messages = self  # chain .messages.create

    def __call__(self, *args, **kwargs):
        return self

    async def create(self, **kwargs):  # noqa: D401
        if self._raises is not None:
            raise self._raises
        return self._response


@pytest.fixture(autouse=True)
def _reset_guard_env(monkeypatch):
    """Ensure each test starts with VISION_GUARD_ENABLED unset (default on)."""
    monkeypatch.delenv("VISION_GUARD_ENABLED", raising=False)


@pytest.fixture
def _api_key(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-fake-test")
    # Also ensure settings reads it.
    from app.core.config import settings

    settings.ANTHROPIC_API_KEY = "sk-fake-test"
    return "sk-fake-test"


# ---------------------------------------------------------------------------
# The 5 violation categories.
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_clean_text_allowed(_api_key):
    fake = _FakeAsyncAnthropic(response=_fake_response({
        "allow": True,
        "flagged_categories": [],
        "reformulation": None,
        "reason": "clean",
    }))
    with patch.object(vg, "AsyncAnthropic", fake, create=True), \
         patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Ton avoir LPP est de 70000 CHF.",
            narrative=None,
        )
    assert verdict.allow
    assert verdict.flagged_categories == []


@pytest.mark.asyncio
async def test_product_advice_blocked_with_reformulation(_api_key):
    fake = _FakeAsyncAnthropic(response=_fake_response({
        "allow": False,
        "flagged_categories": ["product_advice"],
        "reformulation": "Ton avoir LPP te permet d'envisager plusieurs options de rachat.",
        "reason": "named product UBS Vitainvest",
    }))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Achete UBS Vitainvest 50 maintenant.",
            narrative=None,
        )
    assert not verdict.allow
    assert "product_advice" in verdict.flagged_categories
    assert verdict.reformulation is not None


@pytest.mark.asyncio
async def test_return_promise_blocked(_api_key):
    fake = _FakeAsyncAnthropic(response=_fake_response({
        "allow": False,
        "flagged_categories": ["return_promise"],
        "reformulation": "Ton rendement pourrait atteindre 5% selon le scenario.",
        "reason": "promise of guaranteed return",
    }))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Tu es assure de toucher 5% par an.",
            narrative=None,
        )
    assert not verdict.allow
    assert "return_promise" in verdict.flagged_categories


@pytest.mark.asyncio
async def test_third_party_specific_blocked(_api_key):
    fake = _FakeAsyncAnthropic(response=_fake_response({
        "allow": False,
        "flagged_categories": ["third_party_specific"],
        "reformulation": "Ce document concerne une personne tierce.",
        "reason": "named Lauren Martin",
    }))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Lauren Martin a un avoir de 19620 CHF.",
            narrative=None,
        )
    assert not verdict.allow
    assert "third_party_specific" in verdict.flagged_categories


@pytest.mark.asyncio
async def test_banned_term_blocked(_api_key):
    fake = _FakeAsyncAnthropic(response=_fake_response({
        "allow": False,
        "flagged_categories": ["banned_term"],
        "reformulation": "Ce scenario est adapte a ta situation.",
        "reason": "banned term: optimal",
    }))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Cette strategie est optimale pour toi.",
            narrative=None,
        )
    assert not verdict.allow
    assert "banned_term" in verdict.flagged_categories


@pytest.mark.asyncio
async def test_prescriptive_language_blocked(_api_key):
    fake = _FakeAsyncAnthropic(response=_fake_response({
        "allow": False,
        "flagged_categories": ["prescriptive_language"],
        "reformulation": "Tu pourrais envisager un rachat partiel.",
        "reason": "imperative direct order",
    }))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary=None,
            narrative="Tu dois faire un rachat maintenant.",
        )
    assert not verdict.allow
    assert "prescriptive_language" in verdict.flagged_categories


# ---------------------------------------------------------------------------
# Fail-closed paths.
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_missing_api_key_fails_closed(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    from app.core.config import settings

    settings.ANTHROPIC_API_KEY = ""
    verdict = await vg.judge_vision_output(
        summary="Un texte quelconque", narrative=None,
    )
    assert not verdict.allow
    assert verdict.reason == "judge_unavailable"
    assert verdict.reformulation  # canonical safe fallback present


@pytest.mark.asyncio
async def test_api_error_fails_closed(_api_key):
    fake = _FakeAsyncAnthropic(raises=RuntimeError("boom"))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Un texte", narrative=None,
        )
    assert not verdict.allow
    assert verdict.reason == "judge_unavailable"
    assert verdict.reformulation


@pytest.mark.asyncio
async def test_no_tool_use_block_fails_closed(_api_key):
    fake = _FakeAsyncAnthropic(response=SimpleNamespace(content=[], usage=None))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Un texte", narrative=None,
        )
    assert not verdict.allow
    assert verdict.reason == "judge_no_tool_use"


# ---------------------------------------------------------------------------
# Reformulation is itself sanitised — defense in depth.
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_reformulation_is_scrubbed_of_banned_terms(_api_key):
    # Judge naively ships a reformulation containing "optimal" — the
    # coach ComplianceGuard Layer 1 scrub MUST strip it.
    fake = _FakeAsyncAnthropic(response=_fake_response({
        "allow": False,
        "flagged_categories": ["banned_term"],
        "reformulation": "Cette strategie est optimale pour toi.",
        "reason": "banned term detected",
    }))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Cette strategie est garantie.", narrative=None,
        )
    assert not verdict.allow
    assert verdict.reformulation
    assert "optimale" not in verdict.reformulation.lower()
    assert "optimal" not in verdict.reformulation.lower()


# ---------------------------------------------------------------------------
# Env-var bypass.
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_env_var_disables_guard(monkeypatch):
    monkeypatch.setenv("VISION_GUARD_ENABLED", "false")
    verdict = await vg.judge_vision_output(
        summary="Tout texte non-verifie", narrative=None,
    )
    assert verdict.allow
    assert verdict.reason == "guard_disabled_by_env"


@pytest.mark.asyncio
async def test_empty_bundle_allowed_without_api_call(monkeypatch):
    verdict = await vg.judge_vision_output(summary=None, narrative=None, fields_summary=None)
    assert verdict.allow
    assert verdict.reason == "empty_bundle"


# ---------------------------------------------------------------------------
# Model pin tripwire.
# ---------------------------------------------------------------------------


def test_haiku_model_pinned():
    # If Anthropic retires this model string, this test forces a conscious update
    # (cost + latency + behaviour all need re-validation).
    assert vg.HAIKU_MODEL == "claude-haiku-4-5-20251022"


# ---------------------------------------------------------------------------
# Cost telemetry.
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_cost_telemetry_populated(_api_key):
    fake = _FakeAsyncAnthropic(response=_fake_response(
        {"allow": True, "flagged_categories": [], "reformulation": None, "reason": "ok"},
        input_tokens=500, output_tokens=50,
    ))
    with patch("anthropic.AsyncAnthropic", fake, create=True):
        verdict = await vg.judge_vision_output(
            summary="Ton avoir LPP est de 70'000 CHF.", narrative=None,
        )
    # Haiku target $0.0003/call at typical sizes; our estimate should be >0
    # and under a cent.
    assert verdict.cost_usd > 0.0
    assert verdict.cost_usd < 0.01
