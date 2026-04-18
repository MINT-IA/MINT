"""Tests for LLMRouter + ShadowComparator (Phase 29-06 / PRIV-07)."""
from __future__ import annotations

import asyncio
import logging
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.llm.router import LLMRequest, LLMRouter, RouteMode
from app.services.llm.shadow_comparator import ShadowComparator


def _make_resp(text: str, in_tokens: int = 5, out_tokens: int = 3):
    block = MagicMock()
    block.type = "text"
    block.text = text
    resp = MagicMock()
    resp.content = [block]
    usage = MagicMock()
    usage.input_tokens = in_tokens
    usage.output_tokens = out_tokens
    resp.usage = usage
    resp.stop_reason = "end_turn"
    return resp


@pytest.mark.asyncio
async def test_router_default_off_uses_anthropic_only():
    anthropic_client = AsyncMock()
    anthropic_client.messages.create = AsyncMock(return_value=_make_resp("A"))
    bedrock_client = MagicMock()
    bedrock_client.messages = MagicMock(return_value=_make_resp("B"))

    flags = AsyncMock()
    flags.is_enabled = AsyncMock(return_value=False)

    router = LLMRouter(
        anthropic_client=anthropic_client,
        bedrock_client=bedrock_client,
        flags=flags,
    )
    req = LLMRequest(
        model="sonnet",
        messages=[{"role": "user", "content": "hi"}],
        system="s",
        max_tokens=10,
        user_id="u1",
    )
    resp = await router.invoke(req)
    assert resp.content[0].text == "A"
    # Bedrock never called
    bedrock_client.messages.assert_not_called()


@pytest.mark.asyncio
async def test_router_shadow_fires_both_returns_anthropic(caplog):
    anthropic_client = AsyncMock()
    anthropic_client.messages.create = AsyncMock(return_value=_make_resp("A"))
    bedrock_client = MagicMock()
    bedrock_client.messages = MagicMock(return_value=_make_resp("A_shadow"))

    async def _is_enabled(flag, user_id=None):
        return flag == "BEDROCK_EU_SHADOW_ENABLED"

    flags = MagicMock()
    flags.is_enabled = AsyncMock(side_effect=_is_enabled)

    router = LLMRouter(
        anthropic_client=anthropic_client,
        bedrock_client=bedrock_client,
        flags=flags,
    )
    with caplog.at_level(logging.INFO, logger="app.services.llm.shadow_comparator"):
        resp = await router.invoke(LLMRequest(
            model="sonnet",
            messages=[{"role": "user", "content": "hi"}],
            max_tokens=10,
            user_id="u1",
        ))
    assert resp.content[0].text == "A"  # user receives anthropic
    bedrock_client.messages.assert_called_once()
    # Shadow comparator emitted diff log
    assert any("llm_shadow_diff" in r.message for r in caplog.records)


@pytest.mark.asyncio
async def test_router_primary_bedrock_succeeds():
    anthropic_client = AsyncMock()
    anthropic_client.messages.create = AsyncMock(return_value=_make_resp("A"))
    bedrock_client = MagicMock()
    bedrock_client.messages = MagicMock(return_value=_make_resp("B"))

    async def _is_enabled(flag, user_id=None):
        return flag == "BEDROCK_EU_PRIMARY_ENABLED"

    flags = MagicMock()
    flags.is_enabled = AsyncMock(side_effect=_is_enabled)

    router = LLMRouter(
        anthropic_client=anthropic_client,
        bedrock_client=bedrock_client,
        flags=flags,
    )
    resp = await router.invoke(LLMRequest(
        model="sonnet",
        messages=[{"role": "user", "content": "hi"}],
        max_tokens=10,
        user_id="u1",
    ))
    assert resp.content[0].text == "B"
    anthropic_client.messages.create.assert_not_called()


@pytest.mark.asyncio
async def test_router_primary_bedrock_falls_back_on_error():
    anthropic_client = AsyncMock()
    anthropic_client.messages.create = AsyncMock(return_value=_make_resp("A_fallback"))
    bedrock_client = MagicMock()
    bedrock_client.messages = MagicMock(side_effect=RuntimeError("bedrock down"))

    async def _is_enabled(flag, user_id=None):
        return flag == "BEDROCK_EU_PRIMARY_ENABLED"

    flags = MagicMock()
    flags.is_enabled = AsyncMock(side_effect=_is_enabled)

    router = LLMRouter(
        anthropic_client=anthropic_client,
        bedrock_client=bedrock_client,
        flags=flags,
    )
    resp = await router.invoke(LLMRequest(
        model="sonnet",
        messages=[{"role": "user", "content": "hi"}],
        max_tokens=10,
        user_id="u1",
    ))
    assert resp.content[0].text == "A_fallback"


def test_shadow_comparator_logs_metrics_no_content(caplog):
    comparator = ShadowComparator()
    anthropic_resp = _make_resp("Bonjour Julien, comment puis-je t'aider ?", 10, 5)
    bedrock_resp = _make_resp("Salut Julien, comment t'aider ?", 10, 6)
    with caplog.at_level(logging.INFO, logger="app.services.llm.shadow_comparator"):
        comparator.log(
            anthropic_resp=anthropic_resp,
            anthropic_latency_ms=1200,
            bedrock_resp=bedrock_resp,
            bedrock_latency_ms=1450,
            bedrock_error=None,
        )
    records = [r for r in caplog.records if "llm_shadow_diff" in r.message]
    assert len(records) == 1
    msg = records[0].message
    # Metrics present
    assert "similarity=" in msg
    assert "anthropic_latency_ms=1200" in msg
    assert "bedrock_latency_ms=1450" in msg
    # Content NOT leaked
    assert "Bonjour" not in msg
    assert "Salut" not in msg


def test_shadow_comparator_logs_bedrock_error():
    comparator = ShadowComparator()
    anthropic_resp = _make_resp("A")
    # Just verify no exception when bedrock_resp is None with error
    comparator.log(
        anthropic_resp=anthropic_resp,
        anthropic_latency_ms=100,
        bedrock_resp=None,
        bedrock_latency_ms=0,
        bedrock_error="Timeout",
    )


@pytest.mark.asyncio
async def test_route_mode_resolution():
    """Flag combos resolve to correct RouteMode."""
    flags = MagicMock()
    # shadow + primary both on → primary wins (more specific)
    async def _both_on(flag, user_id=None):
        return True
    flags.is_enabled = AsyncMock(side_effect=_both_on)
    router = LLMRouter(anthropic_client=MagicMock(), bedrock_client=MagicMock(), flags=flags)
    mode = await router._resolve_mode(user_id="u1")
    assert mode == RouteMode.PRIMARY_BEDROCK


# ---------------------------------------------------------------------------
# Transient-client cleanup (Sentry: RuntimeError: Event loop is closed)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_injected_anthropic_client_is_not_closed_by_router(monkeypatch):
    """Caller-owned client must survive the invocation — lifetime is not ours."""
    from app.services.llm import router as router_mod

    anthropic_client = AsyncMock()
    anthropic_client.messages.create = AsyncMock(return_value=_make_resp("A"))
    anthropic_client.close = AsyncMock()

    flags = MagicMock()
    flags.is_enabled = AsyncMock(return_value=False)

    router = LLMRouter(anthropic_client=anthropic_client, flags=flags)
    resp = await router.invoke(LLMRequest(
        model="sonnet",
        messages=[{"role": "user", "content": "hi"}],
        max_tokens=10,
    ))
    assert resp.content[0].text == "A"
    anthropic_client.close.assert_not_called()


@pytest.mark.asyncio
async def test_transient_anthropic_client_is_closed_after_invoke(monkeypatch):
    """Router-created client must be closed so its httpx transport shuts down
    inside the current event loop. Otherwise the ``asyncio.run`` bridge used
    by ``_sync_vision_call`` leaves an anyio transport to be finalized after
    loop close → RuntimeError: Event loop is closed (Sentry issue
    21a15b819e3e4ea984e9b9b348c97bc3)."""
    from app.services.llm import router as router_mod

    created = AsyncMock()
    created.messages.create = AsyncMock(return_value=_make_resp("A"))
    created.close = AsyncMock()

    monkeypatch.setattr(router_mod, "_default_anthropic_client", lambda: created)

    flags = MagicMock()
    flags.is_enabled = AsyncMock(return_value=False)

    router = LLMRouter(flags=flags)  # anthropic_client=None → transient path
    resp = await router.invoke(LLMRequest(
        model="sonnet",
        messages=[{"role": "user", "content": "hi"}],
        max_tokens=10,
    ))
    assert resp.content[0].text == "A"
    created.close.assert_awaited_once()


@pytest.mark.asyncio
async def test_transient_client_closed_even_when_api_raises(monkeypatch):
    """If the upstream call raises, the client still gets closed — otherwise
    the error path leaks the same anyio transport."""
    from app.services.llm import router as router_mod

    created = AsyncMock()
    created.messages.create = AsyncMock(side_effect=RuntimeError("api down"))
    created.close = AsyncMock()

    monkeypatch.setattr(router_mod, "_default_anthropic_client", lambda: created)

    flags = MagicMock()
    flags.is_enabled = AsyncMock(return_value=False)

    router = LLMRouter(flags=flags)
    with pytest.raises(RuntimeError, match="api down"):
        await router.invoke(LLMRequest(
            model="sonnet",
            messages=[{"role": "user", "content": "hi"}],
            max_tokens=10,
        ))
    created.close.assert_awaited_once()


@pytest.mark.asyncio
async def test_transient_client_close_failure_is_swallowed(monkeypatch, caplog):
    """A failing close() must not mask the successful upstream response.

    If close() raised, the router would leak exceptions from a finalizer
    path — that's worse than the transport lingering. Log debug, continue."""
    from app.services.llm import router as router_mod

    created = AsyncMock()
    created.messages.create = AsyncMock(return_value=_make_resp("A"))
    created.close = AsyncMock(side_effect=RuntimeError("close boom"))

    monkeypatch.setattr(router_mod, "_default_anthropic_client", lambda: created)

    flags = MagicMock()
    flags.is_enabled = AsyncMock(return_value=False)

    router = LLMRouter(flags=flags)
    with caplog.at_level(logging.DEBUG, logger="app.services.llm.router"):
        resp = await router.invoke(LLMRequest(
            model="sonnet",
            messages=[{"role": "user", "content": "hi"}],
            max_tokens=10,
        ))
    assert resp.content[0].text == "A"
    created.close.assert_awaited_once()
    assert any("transient anthropic close failed" in r.message for r in caplog.records)
