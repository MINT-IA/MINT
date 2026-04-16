"""LLM routing package (Phase 29-06 / PRIV-07).

All LLM traffic MUST flow through ``LLMRouter``. Direct use of
``anthropic.Anthropic`` or ``anthropic.AsyncAnthropic`` outside this package
is forbidden (CI gate: ``scripts/check_llm_direct_calls.py``).

Public API:
    - BedrockClient: eu-central-1 Bedrock wrapper mirroring anthropic.messages.create
    - LLMRouter: flag-driven router (off | shadow | primary_bedrock)
    - ShadowComparator: scrubbed metrics-only diff logger
    - LLMRequest / LLMResponse: request/response types
"""
from app.services.llm.bedrock_client import BedrockClient, BedrockError
from app.services.llm.router import LLMRequest, LLMRouter, RouteMode, get_router
from app.services.llm.shadow_comparator import ShadowComparator

__all__ = [
    "BedrockClient",
    "BedrockError",
    "LLMRequest",
    "LLMRouter",
    "RouteMode",
    "ShadowComparator",
    "get_router",
]
