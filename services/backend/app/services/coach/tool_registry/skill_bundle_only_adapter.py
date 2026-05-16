"""Phase mint-calc-engine-v1 Plan 07 Task 3 — SkillBundleOnlyAdapter (FALLBACK).

D-CE-01 fallback for the day Anthropic deprecates ``tool-search-tool-2025-10-19``
or MINT pivots to a provider without Tool Search support (Bedrock — see
RESEARCH §Q-A failure mode 2). Registers ALL calculators as always-on with no
``defer_loading`` key. Accepts the context-bloat tradeoff explicitly (Liu 2024
lost-in-the-middle risk acknowledged + documented per CONTEXT D-CE-01).

Selection via ``TOOL_REGISTRY_ADAPTER=skill_bundle_only`` env var.

NOT wired into the coach narrator yet — see Plan 10 (W2-04 ``CoachToolResponse``
V2 ``latency_tier`` envelope) for the consumer hook.
"""
from __future__ import annotations

from typing import Any

from app.calculators import REGISTRY
from app.services.coach.tool_registry.adapter import (
    LatencyTier,
    ToolDefinition,
)
from app.services.coach.tool_registry.anthropic_defer_loading_adapter import (
    _ALWAYS_ON_TOOLS,
    _load_chip_emitter_descriptions,
)


class SkillBundleOnlyAdapter:
    """Fallback adapter — all calculators always-on via bundle-compiled prompts.

    Implements :py:class:`app.services.coach.tool_registry.ToolRegistryAdapter`
    structurally (no inheritance — ``runtime_checkable`` Protocol).
    """

    def __init__(self) -> None:
        # Reuse the Anthropic adapter's chip-emitter loader — single source
        # of truth for the 5 descriptions, sourced from ``COACH_TOOLS``.
        self._chip_definitions = _load_chip_emitter_descriptions()

    def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
        """Return EVERY tool always-on. Intents in ``turn_context`` are
        ignored — fallback mode is blanket registration."""
        tools: list[ToolDefinition] = []

        # 1. Chip-emitters with their canonical coach_tools.py descriptions.
        for name in _ALWAYS_ON_TOOLS:
            if name in self._chip_definitions:
                tools.append(self._chip_definitions[name])

        # 2. All long-tail calculators always-on, NO defer_loading key.
        for name, meta in REGISTRY.items():
            if name in _ALWAYS_ON_TOOLS:
                continue
            tools.append(
                {
                    "name": name,
                    "description": _bundle_compatible_description(meta),
                    "input_schema": {
                        "type": "object",
                        "properties": {},
                        "required": [],
                    },
                }
            )

        return tools

    def latency_tier(self, tool_name: str) -> LatencyTier:
        """Same tier mapping as AnthropicDeferLoadingAdapter — adapter-agnostic
        Flutter rendering surface."""
        if tool_name in _ALWAYS_ON_TOOLS:
            return "L1"
        meta = REGISTRY.get(tool_name)
        if meta is None:
            return "L2"
        output_type = meta.get("output_type")
        if output_type in ("L1", "L2", "L3"):
            return output_type  # type: ignore[return-value]
        return "L2"


def _bundle_compatible_description(meta: dict[str, Any]) -> str:
    """v1 description — templated from registry metadata. Plan 09 LSFin rewrite
    applies to ALL adapters' descriptions equally (single source of truth in
    ``bundle_compiler.py`` prompt scaffolding)."""
    name = meta.get("name", "")
    events = ", ".join(meta.get("life_events_served", []) or ["cross_cutting"])
    return (
        f"{name} — life_events_served : {events}. "
        f"Bundle-compiled prompt scaffolding (Plan 09 LSFin rewrite pending)."
    )
