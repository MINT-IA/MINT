"""Feature flags via Redis polling.

v2.7 Phase 27 / STAB-05.

Flags:
    - COACH_FSM_ENABLED   (phase 27 reflective retry + fallback)
    - DOCUMENTS_V2_ENABLED (phase 28)
    - PRIVACY_V2_ENABLED  (phase 29)

Storage:
    - Global: `flags:global:{flag}` = "true" / "false"
    - User dogfood: Redis SET `flags:dogfood:{flag}` contains user_ids

Resolution order for is_enabled(flag, user_id):
    1. If user_id in dogfood set → True (overrides global)
    2. Else global value (default False if unset)
    3. On Redis error → False (fail-closed — new features stay off)

In-memory cache: 60s TTL per (flag, user_id) tuple to reduce Redis round-trips.
"""
from __future__ import annotations

import logging
import time
from typing import Optional

logger = logging.getLogger(__name__)

POLL_INTERVAL_SECONDS = 60
CACHE_TTL_SECONDS = 60

REGISTERED_FLAGS = {
    "COACH_FSM_ENABLED",
    "DOCUMENTS_V2_ENABLED",
    "PRIVACY_V2_ENABLED",
}


class FlagsService:
    def __init__(self) -> None:
        self._cache: dict[tuple[str, Optional[str]], tuple[float, bool]] = {}

    async def _get_redis(self):
        from app.core.redis_client import get_redis
        return await get_redis()

    def _cache_get(self, flag: str, user_id: Optional[str]) -> Optional[bool]:
        key = (flag, user_id)
        entry = self._cache.get(key)
        if entry is None:
            return None
        ts, value = entry
        if time.time() - ts > CACHE_TTL_SECONDS:
            return None
        return value

    def _cache_set(self, flag: str, user_id: Optional[str], value: bool) -> None:
        self._cache[(flag, user_id)] = (time.time(), value)

    def invalidate(self, flag: Optional[str] = None) -> None:
        if flag is None:
            self._cache.clear()
            return
        for k in list(self._cache):
            if k[0] == flag:
                self._cache.pop(k, None)

    async def is_enabled(self, flag: str, user_id: Optional[str] = None) -> bool:
        cached = self._cache_get(flag, user_id)
        if cached is not None:
            return cached

        try:
            redis = await self._get_redis()
            if redis is None:
                self._cache_set(flag, user_id, False)
                return False

            # 1. User-scoped dogfood
            if user_id is not None:
                in_dogfood = await redis.sismember(
                    f"flags:dogfood:{flag}", user_id,
                )
                if in_dogfood:
                    self._cache_set(flag, user_id, True)
                    return True

            # 2. Global flag
            raw = await redis.get(f"flags:global:{flag}")
            value = (raw or "").lower() == "true"
            self._cache_set(flag, user_id, value)
            return value
        except Exception as exc:
            logger.warning("flags_service: redis error flag=%s err=%s", flag, exc)
            self._cache_set(flag, user_id, False)
            return False

    async def set_global(self, flag: str, value: bool) -> bool:
        """Set the global value for a flag. Returns True on success."""
        try:
            redis = await self._get_redis()
            if redis is None:
                return False
            await redis.set(f"flags:global:{flag}", "true" if value else "false")
            self.invalidate(flag)
            return True
        except Exception as exc:
            logger.warning("flags_service: set_global failed flag=%s err=%s", flag, exc)
            return False

    async def add_to_dogfood(self, flag: str, user_id: str) -> bool:
        try:
            redis = await self._get_redis()
            if redis is None:
                return False
            await redis.sadd(f"flags:dogfood:{flag}", user_id)
            self.invalidate(flag)
            return True
        except Exception as exc:
            logger.warning("flags_service: dogfood add failed flag=%s err=%s", flag, exc)
            return False

    async def remove_from_dogfood(self, flag: str, user_id: str) -> bool:
        try:
            redis = await self._get_redis()
            if redis is None:
                return False
            await redis.srem(f"flags:dogfood:{flag}", user_id)
            self.invalidate(flag)
            return True
        except Exception as exc:
            logger.warning("flags_service: dogfood rem failed flag=%s err=%s", flag, exc)
            return False

    # Back-compat shorthand used by SLO monitor.
    async def set(self, flag: str, value: bool, user_scope: Optional[str] = None) -> bool:
        if user_scope is not None:
            if value:
                return await self.add_to_dogfood(flag, user_scope)
            return await self.remove_from_dogfood(flag, user_scope)
        return await self.set_global(flag, value)


# Process-wide singleton (fail-open, safe to import anywhere)
flags = FlagsService()
