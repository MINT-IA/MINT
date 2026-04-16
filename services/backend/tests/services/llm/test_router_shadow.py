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
