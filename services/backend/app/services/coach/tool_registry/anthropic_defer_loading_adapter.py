"""Phase mint-calc-engine-v1 Plan 07 Task 2 — AnthropicDeferLoadingAdapter (DEFAULT).

Wires Anthropic Tool Search Tool (beta ``tool-search-tool-2025-10-19``) :

- 5 chip-emitters stay always-on (sub-500 ms L1 latency budget per CONTEXT
  §Latency contract). Their descriptions are sourced from ``coach_tools.py``
  where they already live as ``COACH_TOOLS`` entries.
- All 63 calculator entries from ``app.calculators.REGISTRY`` (Plan 05 AST
  scaffold) carry ``defer_loading: True``. Anthropic's BM25 search-tool loads
  3-5 of them just-in-time per turn — cache-preserving (initial prompt is not
  invalidated). RESEARCH §Q-A confirms this design.
- 1 ``tool_search_tool_bm25_20251119`` declaration so Sonnet 4.5 has the
  server-side BM25 retrieval primitive available.

v1 descriptions for the 52 long-tail are templated as
``"<canonical_name> — life_events_served : <events>. profile_fields_needed : <fields>."``.
This is intentional : Plan 09 (W2 tool-description rewrite, Concern A) replaces
all 63 descriptions with French LSFin-compliant keyword discipline — that's the
work that earns top-3 BM25 surfacing for French user messages. This adapter
ships the WIRING ; the description quality lands in Plan 09.

NOT wired into the coach narrator yet — see Plan 10 (W2-04 ``CoachToolResponse``
V2 ``latency_tier`` envelope) for the consumer hook. This plan is scaffolding.
"""
from __future__ import annotations

from typing import Any

from app.calculators import REGISTRY
from app.services.coach.tool_registry.adapter import (
    LatencyTier,
    ToolDefinition,
)


# 5 chip-emitters — always-on per D-CE-01 + W0 audit rows 46-50.
_ALWAYS_ON_TOOLS: frozenset[str] = frozenset(
    {
        "get_budget_status",
        "get_retirement_projection",
        "get_cross_pillar_analysis",
        "get_cap_status",
        "get_couple_optimization",
    }
)


# Anthropic Tool Search Tool — server-side BM25 retrieval. MINT only declares
# it ; Anthropic injects the search-tool implementation on the model side.
# Reference : platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
_TOOL_SEARCH_DECLARATION: ToolDefinition = {
    "type": "tool_search_tool_bm25_20251119",
    "name": "tool_search_tool_bm25",
}


# The Anthropic beta header that activates ``defer_loading`` semantics.
# Stable since Oct 2025 (~7 months). RESEARCH §Q-A.
_BETA_HEADER = "tool-search-tool-2025-10-19"


# Chip-emitter description cache — read lazily from ``coach_tools.COACH_TOOLS``
# so the source of truth stays in one file.
def _load_chip_emitter_descriptions() -> dict[str, ToolDefinition]:
    """Return ``{name: ToolDefinition}`` for the 5 always-on chip-emitters.

    Sourced from ``app.services.coach.coach_tools.COACH_TOOLS`` where the
    descriptions already live (existing wire-up at ``coach_chat.py``).
    """
    # Local import to avoid a top-of-module circular : ``coach_tools`` does
    # not import this adapter, but the adapter is imported from
    # ``services.coach`` package init in future plans.
    from app.services.coach.coach_tools import COACH_TOOLS

    chip_defs: dict[str, ToolDefinition] = {}
    for entry in COACH_TOOLS:
        name = entry.get("name")
        if name in _ALWAYS_ON_TOOLS:
            chip_defs[name] = {
                "name": name,
                "description": entry["description"],
                "input_schema": entry.get(
                    "input_schema",
                    {"type": "object", "properties": {}, "required": []},
                ),
            }
    return chip_defs


def _templated_description_for(meta: dict[str, Any]) -> str:
    """v1 templated description — Plan 09 rewrites to LSFin-grade French keyword
    discipline. The template surfaces ``life_events_served`` + name so BM25 has
    SOMETHING to match against until Plan 09 lands."""
    name = meta.get("name", "")
    events = ", ".join(meta.get("life_events_served", []) or ["cross_cutting"])
    fields = ", ".join(meta.get("profile_fields_needed", [])[:5])
    return (
        f"{name} — life_events_served : {events}. "
        f"profile_fields_needed : {fields}. "
        f"v1 templated description — Plan 09 LSFin keyword rewrite pending."
    )


def _templated_input_schema_for(meta: dict[str, Any]) -> dict[str, Any]:
    """v1 input schema — empty object until Plan 09 walks each calculator's
    Pydantic request schema and produces a proper JSON Schema. This is enough
    for BM25 indexing on ``description`` ; Sonnet 4.5 will not invoke a
    deferred tool with this empty schema in v1 (Plan 10 wires the dispatcher).
    """
    return {
        "type": "object",
        "properties": {},
        "required": [],
    }


class AnthropicDeferLoadingAdapter:
    """D-CE-01 default — Anthropic Tool Search Tool with per-tool defer_loading.

    Implements :py:class:`app.services.coach.tool_registry.ToolRegistryAdapter`
    structurally (no inheritance needed — ``runtime_checkable`` Protocol).
    """

    def __init__(self) -> None:
        # Cache the chip-emitter definitions at construction time so the
        # ``coach_tools`` import happens once, not per ``register_tools`` call.
        self._chip_definitions = _load_chip_emitter_descriptions()

    # ─── ToolRegistryAdapter protocol ──────────────────────────────────────

    def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
        """Return the full Anthropic ``tools`` array for the current turn.

        Shape :
        - 5 chip-emitters always-on (no ``defer_loading`` key — Anthropic
          default False).
        - 63 long-tail calculators with ``defer_loading: True``.
        - 1 ``tool_search_tool_bm25_20251119`` declaration.
        """
        tools: list[ToolDefinition] = []

        # 1. Always-on chip-emitters (5).
        for name in _ALWAYS_ON_TOOLS:
            if name in self._chip_definitions:
                tools.append(self._chip_definitions[name])

        # 2. Long-tail deferred calculators (63 from REGISTRY).
        for name, meta in REGISTRY.items():
            if name in _ALWAYS_ON_TOOLS:
                # Belt-and-suspenders : the AST scanner doesn't emit chip
                # emitters today (verified Plan 05 SUMMARY), but if a future
                # scanner widening picks them up, the always-on path wins.
                continue
            tools.append(
                {
                    "name": name,
                    "description": _templated_description_for(meta),
                    "input_schema": _templated_input_schema_for(meta),
                    "defer_loading": True,
                }
            )

        # 3. Tool Search Tool declaration.
        tools.append(_TOOL_SEARCH_DECLARATION)

        return tools

    def latency_tier(self, tool_name: str) -> LatencyTier:
        """Map a tool name to its Flutter rendering surface tier.

        - Chip-emitters → L1 (sub-500 ms atomic surface).
        - Long-tail calc in REGISTRY → ``output_type`` from registry metadata
          (Plan 05 emits ``L1`` for all today ; Plan 09 retrofits L2/L3).
        - Unknown → ``L2`` default (narrative loader 2-8 s).
        """
        if tool_name in _ALWAYS_ON_TOOLS:
            return "L1"
        meta = REGISTRY.get(tool_name)
        if meta is None:
            return "L2"
        output_type = meta.get("output_type")
        if output_type in ("L1", "L2", "L3"):
            return output_type  # type: ignore[return-value]
        # L4 invariants are surfaced via dedicated endpoint (Plan 04), not
        # via the tool-registry latency surface — map L4 → L2 for routing.
        return "L2"

    # ─── Anthropic-specific extension ──────────────────────────────────────

    @property
    def beta_header(self) -> str:
        """The ``anthropic-beta`` header value to add to ``messages.create()``.

        Pinned at ``tool-search-tool-2025-10-19``. If Anthropic ships v2026-XX,
        ONLY this property updates — other adapters are immune.
        """
        return _BETA_HEADER
