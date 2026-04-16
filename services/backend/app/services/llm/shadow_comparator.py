"""Shadow-mode diff comparator (Phase 29-06 / PRIV-07).

Compares Anthropic-direct and Bedrock-EU responses and emits a structured
log line with METRICS ONLY. Never logs response bodies — the comparator is
run inside the request loop and log volume is large.

Metrics emitted (space-separated key=value pairs inside ``llm_shadow_diff``
so log-filter Presidio scrub passes cleanly):
    - similarity: sequence-matcher ratio (0.00–1.00)
    - anthropic_latency_ms / bedrock_latency_ms
    - anthropic_out_tokens / bedrock_out_tokens
    - stop_reason_match: bool
    - tool_use_match: bool (both sides emitted a tool_use block?)
    - error: string tag if bedrock raised
"""
from __future__ import annotations

import difflib
import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)


def _extract_text(resp: Any) -> str:
    if resp is None:
        return ""
    parts: list[str] = []
    for block in getattr(resp, "content", None) or []:
        btype = getattr(block, "type", None)
        if btype == "text":
            parts.append(getattr(block, "text", "") or "")
    return "".join(parts).strip()


def _has_tool_use(resp: Any) -> bool:
    for block in getattr(resp, "content", None) or []:
        if getattr(block, "type", None) == "tool_use":
            return True
    return False


def _out_tokens(resp: Any) -> int:
    usage = getattr(resp, "usage", None)
    return int(getattr(usage, "output_tokens", 0) or 0) if usage else 0


class ShadowComparator:
    """Stateless diff logger. Safe to instantiate once and share."""

    def log(
        self,
        *,
        anthropic_resp: Any,
        anthropic_latency_ms: int,
        bedrock_resp: Any,
        bedrock_latency_ms: int,
        bedrock_error: Optional[str] = None,
    ) -> None:
        a_text = _extract_text(anthropic_resp)
        b_text = _extract_text(bedrock_resp)

        if bedrock_error is not None or not b_text:
            similarity = 0.0
        else:
            similarity = difflib.SequenceMatcher(None, a_text, b_text).ratio()

        tool_use_match = _has_tool_use(anthropic_resp) == _has_tool_use(bedrock_resp)
        stop_match = (
            getattr(anthropic_resp, "stop_reason", None)
            == getattr(bedrock_resp, "stop_reason", None)
        )

        logger.info(
            "llm_shadow_diff "
            "similarity=%.3f "
            "anthropic_latency_ms=%d bedrock_latency_ms=%d "
            "anthropic_out_tokens=%d bedrock_out_tokens=%d "
            "stop_reason_match=%s tool_use_match=%s error=%s",
            similarity,
            anthropic_latency_ms, bedrock_latency_ms,
            _out_tokens(anthropic_resp), _out_tokens(bedrock_resp),
            stop_match, tool_use_match,
            bedrock_error or "none",
        )


__all__ = ["ShadowComparator"]
