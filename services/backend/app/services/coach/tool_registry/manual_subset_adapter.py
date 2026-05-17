"""Phase mint-calc-engine-v1 Plan 07 Task 4 — ManualSubsetAdapter (BACKUP).

D-CE-01 backup adapter — extends Wave 1c-A2's ``_TOOL_ELIGIBLE_INTENTS``
heritage to a per-intent tool-array filter. Selection via
``TOOL_REGISTRY_ADAPTER=manual_subset``. Cheapest of the 3 adapters and
least flexible : the operator chooses an explicit allowlist mapping rather
than letting Anthropic BM25 surface or registering everything.

The intent → life_events mapping below routes each of the 6 canonical
``_INTENT_KEYWORDS`` intents (see ``coach_chat.py:1478-1522``) to the
``life_events_served`` tags emitted by the Plan 05 AST scanner. Filtering
the REGISTRY by life-event is more robust than maintaining a separate
hard-coded tool-name allowlist : when Plan 09 retrofits ``life_events_served``
on calculators, the mapping picks them up automatically.

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


# Per-intent life_events allowlist — Wave 1c-A2 heritage extended via the
# Plan 05 registry's ``life_events_served`` tags. Each intent maps to the
# subset of MINT life events it covers ; the adapter walks REGISTRY for any
# calculator served by ANY of those events.
_PER_INTENT_LIFE_EVENTS: dict[str, frozenset[str]] = {
    "retirement": frozenset({"retirement", "buyback"}),
    "taxes": frozenset({"taxes", "succession"}),
    "housing": frozenset({"housing"}),
    "debt": frozenset({"debt"}),
    "family": frozenset({"family", "marriage", "divorce"}),
    "career": frozenset({"career", "independent", "cross_border"}),
}


class ManualSubsetAdapter:
    """Backup adapter — per-intent tool-array filter via registry life_events tags.

    Implements :py:class:`app.services.coach.tool_registry.ToolRegistryAdapter`
    structurally.
    """

    def __init__(self) -> None:
        self._chip_definitions = _load_chip_emitter_descriptions()

    def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
        """Return chip-emitters + REGISTRY entries served by detected intents.

        ``turn_context["user_intents"]`` is the set of intents from
        ``_classify_user_intent`` (coach_chat.py:1525). Empty list → only the
        5 chip-emitters (defaults baseline).
        """
        intents: list[str] = list(turn_context.get("user_intents", []) or [])

        # 1. Chip-emitters always included.
        tools: list[ToolDefinition] = []
        for name in _ALWAYS_ON_TOOLS:
            if name in self._chip_definitions:
                tools.append(self._chip_definitions[name])

        # 2. Per-intent registry entries via life_events_served filter.
        allowed_events: set[str] = set()
        for intent in intents:
            allowed_events.update(_PER_INTENT_LIFE_EVENTS.get(intent, set()))

        if not allowed_events:
            return tools  # defaults baseline only

        for name, meta in REGISTRY.items():
            if name in _ALWAYS_ON_TOOLS:
                continue
            calc_events = set(meta.get("life_events_served", []) or [])
            if calc_events & allowed_events:
                tools.append(
                    {
                        "name": name,
                        "description": _per_intent_description(meta),
                        "input_schema": {
                            "type": "object",
                            "properties": {},
                            "required": [],
                        },
                    }
                )

        return tools

    def latency_tier(self, tool_name: str) -> LatencyTier:
        """Same adapter-agnostic tier mapping."""
        if tool_name in _ALWAYS_ON_TOOLS:
            return "L1"
        meta = REGISTRY.get(tool_name)
        if meta is None:
            return "L2"
        output_type = meta.get("output_type")
        if output_type in ("L1", "L2", "L3"):
            return output_type  # type: ignore[return-value]
        return "L2"


def _per_intent_description(meta: dict[str, Any]) -> str:
    name = meta.get("name", "")
    events = ", ".join(meta.get("life_events_served", []) or ["cross_cutting"])
    return (
        f"{name} — life_events_served : {events}. "
        f"ManualSubsetAdapter per-intent allowlist."
    )
