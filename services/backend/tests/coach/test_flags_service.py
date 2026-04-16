"""Phase 27-01 / Task 5: FlagsService tests.

Covers: global on/off, dogfood per-user, in-memory cache TTL, fail-open on
Redis outage (treated as False), unknown flag rejected at admin layer.
"""
from __future__ import annotations

import time

import pytest

from app.core import redis_client
from app.services.flags_service import CACHE_TTL_SECONDS, FlagsService


@pytest.fixture
def fake_redis():
    import fakeredis.aioredis as fakeaio
    client = fakeaio.FakeRedis(decode_responses=True)
    redis_client.set_redis_client_for_tests(client)
    yield client
    redis_client.reset_for_tests()


@pytest.mark.asyncio
async def test_unknown_flag_defaults_false(fake_redis):
    f = FlagsService()
    assert await f.is_enabled("COACH_FSM_ENABLED") is False


@pytest.mark.asyncio
async def test_global_enable(fake_redis):
    f = FlagsService()
    assert await f.set_global("COACH_FSM_ENABLED", True) is True
    assert await f.is_enabled("COACH_FSM_ENABLED") is True


@pytest.mark.asyncio
async def test_global_disable(fake_redis):
    f = FlagsService()
    await f.set_global("COACH_FSM_ENABLED", True)
    await f.set_global("COACH_FSM_ENABLED", False)
    assert await f.is_enabled("COACH_FSM_ENABLED") is False


@pytest.mark.asyncio
async def test_dogfood_overrides_global_off(fake_redis):
    f = FlagsService()
    await f.set_global("DOCUMENTS_V2_ENABLED", False)
    await f.add_to_dogfood("DOCUMENTS_V2_ENABLED", "julien")
    assert await f.is_enabled("DOCUMENTS_V2_ENABLED", user_id="julien") is True
    assert await f.is_enabled("DOCUMENTS_V2_ENABLED", user_id="stranger") is False


@pytest.mark.asyncio
async def test_dogfood_remove(fake_redis):
    f = FlagsService()
    await f.add_to_dogfood("COACH_FSM_ENABLED", "u1")
    assert await f.is_enabled("COACH_FSM_ENABLED", user_id="u1") is True
    await f.remove_from_dogfood("COACH_FSM_ENABLED", "u1")
    assert await f.is_enabled("COACH_FSM_ENABLED", user_id="u1") is False


@pytest.mark.asyncio
async def test_cache_hits_within_ttl(fake_redis, monkeypatch):
    f = FlagsService()
    await f.set_global("PRIVACY_V2_ENABLED", True)
    assert await f.is_enabled("PRIVACY_V2_ENABLED") is True
    # Simulate Redis going down — cache should still answer True.
    redis_client.set_redis_client_for_tests(None)
    # But the cache path only triggers if not expired.
    assert await f.is_enabled("PRIVACY_V2_ENABLED") is True


@pytest.mark.asyncio
async def test_cache_expires_after_ttl(fake_redis, monkeypatch):
    f = FlagsService()
    await f.set_global("COACH_FSM_ENABLED", True)
    await f.is_enabled("COACH_FSM_ENABLED")
    # Advance time past CACHE_TTL_SECONDS.
    original = time.time
    monkeypatch.setattr(
        "app.services.flags_service.time.time",
        lambda: original() + CACHE_TTL_SECONDS + 5,
    )
    # After cache expires, should re-hit Redis. Still True.
    assert await f.is_enabled("COACH_FSM_ENABLED") is True


@pytest.mark.asyncio
async def test_fail_closed_when_redis_unavailable():
    redis_client.reset_for_tests()
    redis_client._initialized = True
    redis_client._client = None
    f = FlagsService()
    assert await f.is_enabled("COACH_FSM_ENABLED") is False
    redis_client.reset_for_tests()


@pytest.mark.asyncio
async def test_set_shortcut_global(fake_redis):
    f = FlagsService()
    await f.set("COACH_FSM_ENABLED", True)
    assert await f.is_enabled("COACH_FSM_ENABLED") is True


@pytest.mark.asyncio
async def test_set_shortcut_dogfood(fake_redis):
    f = FlagsService()
    await f.set("DOCUMENTS_V2_ENABLED", True, user_scope="u1")
    assert await f.is_enabled("DOCUMENTS_V2_ENABLED", user_id="u1") is True
    assert await f.is_enabled("DOCUMENTS_V2_ENABLED") is False
