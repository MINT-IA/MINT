"""Phase 27-01 / Task 3: Graceful model fallback (Sonnet→Haiku) tests.

Verifies:
  1. CoachUpstreamError on primary → retry with Haiku, flag degraded=True.
  2. asyncio.TimeoutError on primary → retry with Haiku.
  3. Success on primary → degraded=False, model_used=Sonnet.
  4. Already on Haiku → no fallback retry.
  5. Provider != claude → no fallback retry.
"""
from __future__ import annotations

import asyncio

import pytest

from app.api.v1.endpoints.coach_chat import (
    FALLBACK_MODEL_HAIKU,
    PRIMARY_MODEL_DEFAULT,
    _call_with_fallback,
)
from app.services.rag.llm_client import CoachUpstreamError


class _StubOrchestrator:
    def __init__(self, primary_exc=None, slow_primary=False):
        self.primary_exc = primary_exc
        self.slow_primary = slow_primary
        self.calls: list[dict] = []

    async def query(self, **kwargs):
        self.calls.append(kwargs)
        model = kwargs.get("model") or PRIMARY_MODEL_DEFAULT
        # First call is always primary. Second is haiku fallback.
        is_first_call = len(self.calls) == 1
        if is_first_call:
            if self.slow_primary:
                await asyncio.sleep(30)  # will trigger timeout
            if self.primary_exc is not None:
                raise self.primary_exc
            return {"answer": "primary ok", "model": model}
        return {"answer": "haiku ok", "model": model}


def _kwargs(**overrides):
    base = dict(
        question="hi",
        api_key="sk-test",
        provider="claude",
        model=None,
        profile_context=None,
        language="fr",
        tools=[],
        system_prompt="sp",
        user_id="u1",
        conversation_history=[{"role": "user", "content": "x"}] * 12,
    )
    base.update(overrides)
    return base


@pytest.mark.asyncio
async def test_primary_success_no_fallback():
    orch = _StubOrchestrator()
    result, meta = await _call_with_fallback(orch, **_kwargs())
    assert result["answer"] == "primary ok"
    assert meta["degraded"] is False
    assert meta["model_used"] == PRIMARY_MODEL_DEFAULT
    assert len(orch.calls) == 1


@pytest.mark.asyncio
async def test_upstream_error_falls_back_to_haiku():
    orch = _StubOrchestrator(primary_exc=CoachUpstreamError("boom", status=529))
    result, meta = await _call_with_fallback(orch, **_kwargs())
    assert result["answer"] == "haiku ok"
    assert meta["degraded"] is True
    assert meta["model_used"] == FALLBACK_MODEL_HAIKU
    assert len(orch.calls) == 2
    # Truncation: second (Haiku) call got at most FALLBACK_HISTORY_MAX_TURNS.
    haiku_hist = orch.calls[1]["conversation_history"]
    assert haiku_hist is not None
    assert len(haiku_hist) <= 10


@pytest.mark.asyncio
async def test_primary_timeout_falls_back(monkeypatch):
    # Force a fast timeout to make the test quick.
    from app.api.v1.endpoints import coach_chat as cc
    monkeypatch.setattr(cc, "FALLBACK_TIMEOUT_SECONDS", 0.05)
    orch = _StubOrchestrator(slow_primary=True)
    result, meta = await _call_with_fallback(orch, **_kwargs())
    assert meta["degraded"] is True
    assert meta["model_used"] == FALLBACK_MODEL_HAIKU
    assert result["answer"] == "haiku ok"


@pytest.mark.asyncio
async def test_already_haiku_no_retry():
    orch = _StubOrchestrator(primary_exc=CoachUpstreamError("x", status=503))
    with pytest.raises(CoachUpstreamError):
        await _call_with_fallback(orch, **_kwargs(model=FALLBACK_MODEL_HAIKU))
    assert len(orch.calls) == 1


@pytest.mark.asyncio
async def test_non_claude_provider_no_retry():
    orch = _StubOrchestrator(primary_exc=CoachUpstreamError("x", status=503))
    with pytest.raises(CoachUpstreamError):
        await _call_with_fallback(orch, **_kwargs(provider="openai"))
    assert len(orch.calls) == 1
