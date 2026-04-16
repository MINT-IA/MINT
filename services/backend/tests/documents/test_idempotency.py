"""Phase 27-01 / Task 7: Idempotency-Key + SHA256 dedup tests."""
from __future__ import annotations

import uuid

import pytest

from app.core import redis_client
from app.services import idempotency


@pytest.fixture
def fake_redis():
    import fakeredis.aioredis as fakeaio
    client = fakeaio.FakeRedis(decode_responses=True)
    redis_client.set_redis_client_for_tests(client)
    yield client
    redis_client.reset_for_tests()


def test_uuid_v4_validation():
    assert idempotency.is_valid_idempotency_key(str(uuid.uuid4())) is True
    assert idempotency.is_valid_idempotency_key("not-a-uuid") is False
    assert idempotency.is_valid_idempotency_key("") is False
    assert idempotency.is_valid_idempotency_key(None) is False
    # UUID v1 has different version bits → should fail v4 check.
    v1 = "550e8400-e29b-11d4-a716-446655440000"
    assert idempotency.is_valid_idempotency_key(v1) is False


def test_sha256_deterministic():
    a = idempotency.sha256_hex(b"hello")
    b = idempotency.sha256_hex(b"hello")
    c = idempotency.sha256_hex(b"world")
    assert a == b
    assert a != c


@pytest.mark.asyncio
async def test_key_store_and_lookup(fake_redis):
    key = str(uuid.uuid4())
    payload = {"id": "doc_abc", "document_type": "lpp", "fields_found": 5}
    assert await idempotency.store_by_key(key, payload) is True
    got = await idempotency.lookup_by_key(key)
    assert got == payload


@pytest.mark.asyncio
async def test_key_lookup_miss_returns_none(fake_redis):
    got = await idempotency.lookup_by_key(str(uuid.uuid4()))
    assert got is None


@pytest.mark.asyncio
async def test_invalid_key_never_stored(fake_redis):
    assert await idempotency.store_by_key("not-uuid", {"x": 1}) is False
    # And lookup of that bogus key also misses.
    assert await idempotency.lookup_by_key("not-uuid") is None


@pytest.mark.asyncio
async def test_sha_store_and_lookup(fake_redis):
    sha = idempotency.sha256_hex(b"same file bytes")
    payload = {"id": "doc_xyz"}
    assert await idempotency.store_by_file_sha(sha, payload) is True
    got = await idempotency.lookup_by_file_sha(sha)
    assert got == payload


@pytest.mark.asyncio
async def test_different_files_different_sha_different_cache(fake_redis):
    sha_a = idempotency.sha256_hex(b"file a")
    sha_b = idempotency.sha256_hex(b"file b")
    await idempotency.store_by_file_sha(sha_a, {"id": "a"})
    await idempotency.store_by_file_sha(sha_b, {"id": "b"})
    assert (await idempotency.lookup_by_file_sha(sha_a))["id"] == "a"
    assert (await idempotency.lookup_by_file_sha(sha_b))["id"] == "b"


@pytest.mark.asyncio
async def test_fail_open_on_redis_outage():
    redis_client.reset_for_tests()
    redis_client._initialized = True
    redis_client._client = None
    # Store is a no-op; lookup returns None. No exceptions.
    key = str(uuid.uuid4())
    assert await idempotency.store_by_key(key, {"x": 1}) is False
    assert await idempotency.lookup_by_key(key) is None
    sha = idempotency.sha256_hex(b"abc")
    assert await idempotency.store_by_file_sha(sha, {"x": 1}) is False
    assert await idempotency.lookup_by_file_sha(sha) is None
    redis_client.reset_for_tests()


@pytest.mark.asyncio
async def test_ttl_set_on_key_store(fake_redis):
    key = str(uuid.uuid4())
    await idempotency.store_by_key(key, {"x": 1})
    ttl = await fake_redis.ttl(f"idempotency:{key}")
    # Should be positive and ~24h.
    assert 23 * 3600 < ttl <= 24 * 3600
