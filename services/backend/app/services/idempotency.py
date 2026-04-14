"""Idempotency-Key + SHA256 response cache for document endpoints.

v2.7 Phase 27 / STAB-03.

Primary:   Idempotency-Key header (UUID v4 client-generated). Cache
           response JSON at `idempotency:{key}` TTL 24h.
Secondary: SHA256(file_bytes) fallback at `idempotency:file:{sha}` TTL 24h.

Fail-open: if Redis is unavailable, every lookup returns None and every
store is a no-op — the endpoint just processes normally.
"""
from __future__ import annotations

import hashlib
import json
import logging
import re
from typing import Any, Optional

logger = logging.getLogger(__name__)

TTL_SECONDS = 24 * 3600
_UUID_V4_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def is_valid_idempotency_key(key: Optional[str]) -> bool:
    if not key:
        return False
    return bool(_UUID_V4_RE.match(key))


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


async def _redis():
    from app.core.redis_client import get_redis
    return await get_redis()


async def lookup_by_key(idempotency_key: str) -> Optional[dict]:
    """Return cached response dict or None."""
    if not is_valid_idempotency_key(idempotency_key):
        return None
    try:
        r = await _redis()
        if r is None:
            return None
        raw = await r.get(f"idempotency:{idempotency_key}")
        if raw is None:
            return None
        return json.loads(raw)
    except Exception as exc:
        logger.warning("idempotency: lookup key failed err=%s", exc)
        return None


async def store_by_key(idempotency_key: str, response_body: dict) -> bool:
    if not is_valid_idempotency_key(idempotency_key):
        return False
    try:
        r = await _redis()
        if r is None:
            return False
        await r.set(
            f"idempotency:{idempotency_key}",
            json.dumps(response_body, default=str),
            ex=TTL_SECONDS,
        )
        return True
    except Exception as exc:
        logger.warning("idempotency: store key failed err=%s", exc)
        return False


async def lookup_by_file_sha(sha: str) -> Optional[dict]:
    try:
        r = await _redis()
        if r is None:
            return None
        raw = await r.get(f"idempotency:file:{sha}")
        if raw is None:
            return None
        return json.loads(raw)
    except Exception as exc:
        logger.warning("idempotency: lookup sha failed err=%s", exc)
        return None


async def store_by_file_sha(sha: str, response_body: dict) -> bool:
    try:
        r = await _redis()
        if r is None:
            return False
        await r.set(
            f"idempotency:file:{sha}",
            json.dumps(response_body, default=str),
            ex=TTL_SECONDS,
        )
        return True
    except Exception as exc:
        logger.warning("idempotency: store sha failed err=%s", exc)
        return False
