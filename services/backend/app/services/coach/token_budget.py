"""Token budget per user/day with soft-cap graceful degradation.

v2.7 Phase 27 / STAB-04.

Tiers (by ratio used/limit):
    - normal       [0.00, 0.80) → Sonnet, no truncation
    - soft_cap     [0.80, 0.95) → switch to Haiku
    - truncate     [0.95, 1.00) → switch to Haiku + drop RAG context
    - hard_cap     [1.00,  ∞  ) → calm decline, no LLM call

Backing store: Redis key `coach:budget:{user_id}:{YYYY-MM-DD}` with TTL 48h.
Fail-open: if Redis unavailable, allow request and return tier=normal.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Literal, Optional

logger = logging.getLogger(__name__)

DAILY_LIMIT_TOKENS_DEFAULT = 50_000
SOFT_CAP_RATIO = 0.80
TRUNCATE_RATIO = 0.95
HARD_CAP_RATIO = 1.00

TTL_SECONDS = 48 * 3600  # 48h — safe margin for timezone skew

# Model targets per tier
_MODEL_PRIMARY = "claude-sonnet-4-5-20250929"
_MODEL_HAIKU = "claude-haiku-4-5-20251001"


Tier = Literal["normal", "soft_cap", "truncate", "hard_cap"]


@dataclass
class BudgetState:
    used: int
    limit: int
    ratio: float
    tier: Tier
    recommended_model: str
    truncate_context: bool
    hard_cap_message: Optional[str] = None


def _today_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _classify(ratio: float) -> Tier:
    if ratio >= HARD_CAP_RATIO:
        return "hard_cap"
    if ratio >= TRUNCATE_RATIO:
        return "truncate"
    if ratio >= SOFT_CAP_RATIO:
        return "soft_cap"
    return "normal"


HARD_CAP_MESSAGE_FR = (
    "On a déjà bien avancé aujourd'hui. Repose-toi, je t'attends demain."
)


class TokenBudget:
    """Per-user daily token budget with Redis-backed atomic counters."""

    def __init__(
        self,
        daily_limit_tokens: int = DAILY_LIMIT_TOKENS_DEFAULT,
    ) -> None:
        self.daily_limit = daily_limit_tokens

    def _key(self, user_id: str) -> str:
        return f"coach:budget:{user_id}:{_today_utc()}"

    async def _get_redis(self):
        from app.core.redis_client import get_redis
        return await get_redis()

    async def current_state(self, user_id: str) -> BudgetState:
        """Read current usage without incrementing. Fail-open on Redis error."""
        used = await self._safe_get(user_id)
        return self._state_from_used(used)

    async def consume(self, user_id: str, tokens: int) -> BudgetState:
        """Atomically INCRBY tokens and return the new state. Fail-open."""
        if tokens <= 0:
            return await self.current_state(user_id)
        used = await self._safe_incrby(user_id, tokens)
        return self._state_from_used(used)

    def _state_from_used(self, used: int) -> BudgetState:
        ratio = used / self.daily_limit if self.daily_limit > 0 else 0.0
        tier = _classify(ratio)
        if tier in ("soft_cap", "truncate", "hard_cap"):
            model = _MODEL_HAIKU
        else:
            model = _MODEL_PRIMARY
        return BudgetState(
            used=used,
            limit=self.daily_limit,
            ratio=round(ratio, 4),
            tier=tier,
            recommended_model=model,
            truncate_context=(tier in ("truncate", "hard_cap")),
            hard_cap_message=HARD_CAP_MESSAGE_FR if tier == "hard_cap" else None,
        )

    async def _safe_get(self, user_id: str) -> int:
        try:
            redis = await self._get_redis()
            if redis is None:
                return 0
            raw = await redis.get(self._key(user_id))
            return int(raw) if raw else 0
        except Exception as exc:
            logger.warning("token_budget: redis GET failed user=%s err=%s", user_id, exc)
            return 0

    async def _safe_incrby(self, user_id: str, tokens: int) -> int:
        try:
            redis = await self._get_redis()
            if redis is None:
                return 0  # fail-open: pretend no usage yet
            key = self._key(user_id)
            new_val = await redis.incrby(key, tokens)
            await redis.expire(key, TTL_SECONDS)
            return int(new_val)
        except Exception as exc:
            logger.warning("token_budget: redis INCRBY failed user=%s err=%s", user_id, exc)
            return 0
