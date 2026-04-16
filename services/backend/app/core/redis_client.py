"""Shared async Redis client factory with fail-open semantics.

v2.7 Phase 27 (STAB-04/05/06/07): token budget, feature flags, SLO monitor,
idempotency all need atomic ops (INCRBY, GET, SET with TTL, HINCRBY). We use
the official `redis>=5.0` package's async client.

Fail-open contract:
    - If REDIS_URL is unset → client is None.
    - If Redis is unreachable at runtime → callers catch RedisError and
      implement their own fail-open policy (allow request, log warning).
    - Tests inject a fake client via `set_redis_client_for_tests(fake)`.

Lifecycle:
    - `get_redis()` is an async-safe singleton. First call creates the pool.
    - `close_redis()` is called from FastAPI shutdown hook (main.py).
"""
from __future__ import annotations

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

_client = None
_initialized = False


def _redis_url() -> Optional[str]:
    return os.environ.get("REDIS_URL") or os.environ.get("REDIS_TLS_URL")


async def get_redis():
    """Return a shared async Redis client, or None if not configured.

    Never raises — returns None on any failure so callers can fail-open.
    """
    global _client, _initialized
    if _initialized:
        return _client
    _initialized = True

    url = _redis_url()
    if not url:
        logger.info("redis_client: REDIS_URL not set, in-memory fail-open mode")
        _client = None
        return None

    try:
        import redis.asyncio as aioredis  # type: ignore
        _client = aioredis.from_url(
            url,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        logger.info("redis_client: connected to %s", url.split("@")[-1])
    except Exception as exc:  # pragma: no cover — defensive
        logger.warning("redis_client: init failed (%s), fail-open", exc)
        _client = None
    return _client


async def close_redis() -> None:
    global _client, _initialized
    if _client is not None:
        try:
            await _client.aclose()
        except Exception:  # pragma: no cover
            pass
    _client = None
    _initialized = False


def set_redis_client_for_tests(fake) -> None:
    """Inject a fake (e.g. fakeredis.aioredis.FakeRedis) for unit tests."""
    global _client, _initialized
    _client = fake
    _initialized = True


def reset_for_tests() -> None:
    global _client, _initialized
    _client = None
    _initialized = False
