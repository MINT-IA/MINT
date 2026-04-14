"""Phase 27-01 / Task 4: TokenBudget tests — 4 tiers + Redis fail-open.

Uses fakeredis.aioredis.FakeRedis as a drop-in via set_redis_client_for_tests.
"""
from __future__ import annotations

import pytest

from app.core import redis_client
from app.services.coach.token_budget import (
    DAILY_LIMIT_TOKENS_DEFAULT,
    HARD_CAP_MESSAGE_FR,
    TokenBudget,
)


@pytest.fixture
def fake_redis():
    import fakeredis.aioredis as fakeaio
    client = fakeaio.FakeRedis(decode_responses=True)
    redis_client.set_redis_client_for_tests(client)
    yield client
    redis_client.reset_for_tests()


@pytest.mark.asyncio
async def test_normal_tier_fresh_user(fake_redis):
    b = TokenBudget()
    state = await b.current_state("u1")
    assert state.tier == "normal"
    assert state.used == 0
    assert "sonnet" in state.recommended_model.lower()
    assert state.truncate_context is False
    assert state.hard_cap_message is None


@pytest.mark.asyncio
async def test_soft_cap_at_80_percent(fake_redis):
    b = TokenBudget(daily_limit_tokens=10_000)
    await b.consume("u1", 8_100)
    state = await b.current_state("u1")
    assert state.tier == "soft_cap"
    assert "haiku" in state.recommended_model.lower()
    assert state.truncate_context is False


@pytest.mark.asyncio
async def test_truncate_tier_at_95_percent(fake_redis):
    b = TokenBudget(daily_limit_tokens=10_000)
    await b.consume("u1", 9_600)
    state = await b.current_state("u1")
    assert state.tier == "truncate"
    assert state.truncate_context is True


@pytest.mark.asyncio
async def test_hard_cap_at_100_percent(fake_redis):
    b = TokenBudget(daily_limit_tokens=10_000)
    await b.consume("u1", 10_500)
    state = await b.current_state("u1")
    assert state.tier == "hard_cap"
    assert state.hard_cap_message == HARD_CAP_MESSAGE_FR


@pytest.mark.asyncio
async def test_consume_atomic_increments(fake_redis):
    b = TokenBudget(daily_limit_tokens=100_000)
    s1 = await b.consume("u1", 1000)
    s2 = await b.consume("u1", 500)
    assert s1.used == 1000
    assert s2.used == 1500


@pytest.mark.asyncio
async def test_fail_open_when_redis_unavailable():
    """No REDIS_URL + no fake client → state=normal, consume is a no-op."""
    redis_client.reset_for_tests()
    redis_client._initialized = True
    redis_client._client = None
    b = TokenBudget()
    state = await b.current_state("u1")
    assert state.tier == "normal"
    assert state.used == 0
    # Consume must not raise
    state2 = await b.consume("u1", 5000)
    assert state2.tier == "normal"
    redis_client.reset_for_tests()


@pytest.mark.asyncio
async def test_per_user_isolation(fake_redis):
    b = TokenBudget(daily_limit_tokens=10_000)
    await b.consume("alice", 9_000)
    await b.consume("bob", 100)
    alice = await b.current_state("alice")
    bob = await b.current_state("bob")
    assert alice.tier == "soft_cap"
    assert bob.tier == "normal"


@pytest.mark.asyncio
async def test_default_limit_is_50k():
    assert DAILY_LIMIT_TOKENS_DEFAULT == 50_000
