"""Phase mint-calc-engine-v1 Plan 07 Task 1 — Protocol + ToolDefinition contract tests.

Vendor-agnostic ``ToolRegistryAdapter`` abstraction per D-CE-01. The Protocol
guarantees that future provider pivots (Anthropic deprecation, OpenAI / Bedrock
fallback) have a single 50-LOC surface to swap — the calculator definitions
themselves stay provider-agnostic.

Tested invariants :
1. Public symbols importable from ``app.services.coach.tool_registry``.
2. Structural Protocol satisfaction via ``runtime_checkable`` ``isinstance``.
3. ``ToolDefinition`` TypedDict accepts the Anthropic-shape kwargs
   (``defer_loading`` optional, ``type`` optional for tool_search declaration).
"""
from __future__ import annotations

from typing import Any


def test_public_symbols_importable() -> None:
    """The 3 public names import cleanly from the package surface."""
    from app.services.coach.tool_registry import (  # noqa: F401
        LatencyTier,
        ToolDefinition,
        ToolRegistryAdapter,
    )


def test_protocol_satisfied_by_minimal_class() -> None:
    """A class with the 2 required methods satisfies the Protocol structurally."""
    from app.services.coach.tool_registry import ToolRegistryAdapter

    class _Stub:
        def register_tools(self, turn_context: dict[str, Any]) -> list[dict]:
            return []

        def latency_tier(self, tool_name: str) -> str:
            return "L1"

    assert isinstance(_Stub(), ToolRegistryAdapter)


def test_tool_definition_accepts_anthropic_shape() -> None:
    """``ToolDefinition`` accepts ``name`` / ``description`` / ``input_schema`` /
    ``defer_loading`` / ``type`` — the full Anthropic Tool Search Tool kwargset.
    """
    from app.services.coach.tool_registry import ToolDefinition

    chip_emitter: ToolDefinition = {
        "name": "get_budget_status",
        "description": "Budget status.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    }
    deferred: ToolDefinition = {
        "name": "divorce_simulator",
        "description": "Divorce.",
        "input_schema": {"type": "object"},
        "defer_loading": True,
    }
    tool_search: ToolDefinition = {
        "type": "tool_search_tool_bm25_20251119",
        "name": "tool_search_tool_bm25",
    }

    # The TypedDict is structural ; we assert the dicts hold the expected keys.
    assert chip_emitter["name"] == "get_budget_status"
    assert deferred["defer_loading"] is True
    assert tool_search["type"] == "tool_search_tool_bm25_20251119"
