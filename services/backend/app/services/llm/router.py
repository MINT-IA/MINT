"""LLM router — single entry-point for all LLM traffic.

Phase 29-06 / PRIV-07.

Three routing modes resolved from flags per request (user-scoped):

    OFF (default)           → Anthropic direct (current behaviour)
    SHADOW                  → fire both Anthropic + Bedrock; return Anthropic; log diff
    PRIMARY_BEDROCK         → try Bedrock first; fallback to Anthropic on error

Precedence: if ``BEDROCK_EU_PRIMARY_ENABLED`` is true for the user it wins
over ``BEDROCK_EU_SHADOW_ENABLED`` (shadow is a validation stepping-stone
that becomes redundant once primary is flipped).

Dogfood allowlist: FlagsService already handles per-user Redis SET
``flags:dogfood:{flag}``. Set Julien's user_id there to shadow-test in
staging before global rollout.

Interface (matches anthropic.Client.messages.create as a drop-in
replacement for the coach and vision-guard call sites):

    response = await router.invoke(LLMRequest(...))

"""
from __future__ import annotations

import asyncio
import enum
import logging
import os
import time
from dataclasses import dataclass, field
from typing import Any, Optional

from app.services.llm.bedrock_client import BedrockClient, BedrockError
from app.services.llm.shadow_comparator import ShadowComparator

logger = logging.getLogger(__name__)


class RouteMode(enum.Enum):
    OFF = "off"
    SHADOW = "shadow"
    PRIMARY_BEDROCK = "primary_bedrock"


@dataclass
class LLMRequest:
    model: str  # "sonnet" | "haiku" | full model id
    messages: list[dict]
    system: Optional[str] = None
    max_tokens: int = 1024
    tools: Optional[list[dict]] = None
    tool_choice: Optional[dict] = None
    temperature: Optional[float] = None
    user_id: Optional[str] = None
    # Metadata only, never sent on the wire:
    purpose: Optional[str] = None  # e.g. "coach_chat", "vision_guard"


# ---------------------------------------------------------------------------
# Anthropic-direct adapter — wraps the existing client.messages.create shape
# so the router interface is symmetric with BedrockClient.
# ---------------------------------------------------------------------------


def _default_anthropic_client():
    """Return a fresh AsyncAnthropic client or None if unavailable.

    Intentionally *not* cached: tests patch ``anthropic.AsyncAnthropic`` and
    rely on fresh resolution per call. Client construction is cheap (no
    network I/O) so this has no perf cost in prod.
    """
    try:
        import anthropic  # Resolve at call time so test patches apply.
    except ImportError:  # pragma: no cover
        return None
    from app.core.config import settings
    api_key = getattr(settings, "ANTHROPIC_API_KEY", None) or os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return None
    return anthropic.AsyncAnthropic(api_key=api_key)


async def _call_anthropic(client: Any, req: LLMRequest) -> Any:
    kwargs: dict[str, Any] = {
        "model": _resolve_anthropic_model(req.model),
        "max_tokens": req.max_tokens,
        "messages": req.messages,
    }
    if req.system:
        kwargs["system"] = req.system
    if req.tools:
        kwargs["tools"] = req.tools
    if req.tool_choice:
        kwargs["tool_choice"] = req.tool_choice
    if req.temperature is not None:
        kwargs["temperature"] = req.temperature
    return await client.messages.create(**kwargs)


def _resolve_anthropic_model(model: str) -> str:
    """Map short aliases to full Anthropic model ids.

    If caller passed a fully-qualified id (e.g. ``claude-sonnet-4-5-20251022``),
    return unchanged.
    """
    alias = (model or "").lower()
    if alias in ("sonnet", "claude-sonnet", "claude-sonnet-4-5", "sonnet-4-5"):
        return os.environ.get(
            "MINT_ANTHROPIC_SONNET_MODEL_ID",
            "claude-sonnet-4-5-20251022",
        )
    if alias in ("haiku", "claude-haiku", "claude-haiku-4-5", "haiku-4-5"):
        return os.environ.get(
            "MINT_ANTHROPIC_HAIKU_MODEL_ID",
            "claude-haiku-4-5-20251022",
        )
    return model


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------


class LLMRouter:
    """Flag-driven LLM router. Instantiate once and share (process singleton)."""

    def __init__(
        self,
        *,
        anthropic_client: Any = None,
        bedrock_client: Optional[BedrockClient] = None,
        flags: Any = None,
        shadow_comparator: Optional[ShadowComparator] = None,
    ) -> None:
        self._anthropic = anthropic_client  # may be None — resolved lazily
        self._bedrock = bedrock_client
        self._comparator = shadow_comparator or ShadowComparator()
        if flags is None:
            from app.services.flags_service import flags as _flags
            flags = _flags
        self._flags = flags

    def _get_anthropic(self) -> Any:
        # Do not cache: tests patch ``anthropic.AsyncAnthropic`` and expect
        # fresh resolution per call. The client object itself is cheap.
        if self._anthropic is not None:
            return self._anthropic
        return _default_anthropic_client()

    def _get_bedrock(self) -> Optional[BedrockClient]:
        if self._bedrock is None:
            try:
                self._bedrock = BedrockClient()
            except BedrockError as exc:
                logger.warning("llm_router: bedrock client unavailable: %s", exc)
                self._bedrock = None  # stays None; off-mode still works
        return self._bedrock

    async def _resolve_mode(self, user_id: Optional[str]) -> RouteMode:
        primary = await self._flags.is_enabled("BEDROCK_EU_PRIMARY_ENABLED", user_id)
        if primary:
            return RouteMode.PRIMARY_BEDROCK
        shadow = await self._flags.is_enabled("BEDROCK_EU_SHADOW_ENABLED", user_id)
        if shadow:
            return RouteMode.SHADOW
        return RouteMode.OFF

    async def invoke(self, request: LLMRequest) -> Any:
        """Route an LLM request. Returns an anthropic.Message-compatible response."""
        mode = await self._resolve_mode(request.user_id)

        if mode == RouteMode.OFF:
            return await self._invoke_anthropic(request)

        if mode == RouteMode.PRIMARY_BEDROCK:
            try:
                return await self._invoke_bedrock(request)
            except Exception as exc:
                logger.warning(
                    "llm_router: bedrock primary failed, falling back to anthropic: %s",
                    type(exc).__name__,
                )
                return await self._invoke_anthropic(request)

        # SHADOW: fire both in parallel, return anthropic, log diff.
        return await self._invoke_shadow(request)

    async def _invoke_anthropic(self, request: LLMRequest) -> Any:
        client = self._get_anthropic()
        if client is None:
            raise RuntimeError("anthropic client unavailable (missing API key or package)")
        return await _call_anthropic(client, request)

    async def _invoke_bedrock(self, request: LLMRequest) -> Any:
        bedrock = self._get_bedrock()
        if bedrock is None:
            raise BedrockError("bedrock client unavailable")
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None,
            lambda: bedrock.messages(
                model=request.model,
                messages=request.messages,
                system=request.system,
                max_tokens=request.max_tokens,
                tools=request.tools,
                tool_choice=request.tool_choice,
                temperature=request.temperature,
            ),
        )

    async def _invoke_shadow(self, request: LLMRequest) -> Any:
        async def _timed_anthropic():
            t0 = time.perf_counter()
            try:
                r = await self._invoke_anthropic(request)
                return r, int((time.perf_counter() - t0) * 1000), None
            except Exception as exc:
                return None, int((time.perf_counter() - t0) * 1000), str(type(exc).__name__)

        async def _timed_bedrock():
            t0 = time.perf_counter()
            try:
                r = await self._invoke_bedrock(request)
                return r, int((time.perf_counter() - t0) * 1000), None
            except Exception as exc:
                return None, int((time.perf_counter() - t0) * 1000), str(type(exc).__name__)

        (a_resp, a_ms, a_err), (b_resp, b_ms, b_err) = await asyncio.gather(
            _timed_anthropic(), _timed_bedrock()
        )

        # Log diff (metrics only)
        self._comparator.log(
            anthropic_resp=a_resp,
            anthropic_latency_ms=a_ms,
            bedrock_resp=b_resp,
            bedrock_latency_ms=b_ms,
            bedrock_error=b_err,
        )

        # Anthropic is the user-visible source of truth in shadow mode.
        if a_resp is not None:
            return a_resp
        # Anthropic failed — we still have bedrock for shadow-validation use;
        # bubble the anthropic error up so caller handles as per off-mode.
        raise RuntimeError(f"anthropic_failed: {a_err}")


# ---------------------------------------------------------------------------
# Process singleton
# ---------------------------------------------------------------------------


_router_singleton: Optional[LLMRouter] = None


def get_router() -> LLMRouter:
    global _router_singleton
    if _router_singleton is None:
        _router_singleton = LLMRouter()
    return _router_singleton


__all__ = ["LLMRequest", "LLMRouter", "RouteMode", "get_router"]
