"""Phase mint-calc-engine-v1 Plan 07 — D-CE-01 vendor-agnostic ToolRegistryAdapter Protocol.

The Protocol is the single 50-LOC surface that future provider pivots
(Anthropic deprecation, OpenAI / Bedrock fallback) need to swap. Calculator
definitions stay provider-agnostic — see ``app.calculators._registry`` (Plan 05).

Three concrete adapters live next to this Protocol :

- ``AnthropicDeferLoadingAdapter`` — DEFAULT. Anthropic Tool Search Tool
  (beta header ``tool-search-tool-2025-10-19``) + per-tool ``defer_loading``
  flag. 5 chip-emitters stay always-on (L1 budget) ; 52 long-tail are deferred.
- ``SkillBundleOnlyAdapter`` — FALLBACK. All 57 calculators always registered
  via bundle-compiled prompts (accepts the context-bloat tradeoff explicitly).
- ``ManualSubsetAdapter`` — BACKUP. Per-intent allowlist extends the
  Wave 1c-A2 ``_TOOL_ELIGIBLE_INTENTS`` heritage to a tool-array filter.

Selection is operator-controlled via the ``TOOL_REGISTRY_ADAPTER`` env var
(see ``factory.py`` ; default ``anthropic_defer_loading``).
"""
from __future__ import annotations

from typing import Any, Literal, Protocol, TypedDict, runtime_checkable


# Lucidity tier for Flutter rendering surface — aligns with
# ``app/models/lucidity/_payload.py`` ``LucidityLevel`` (Plan 04).
# L1 = atomic chip / sub-500ms ; L2-L3 = narrative loader / 2-8 s.
LatencyTier = Literal["L1", "L2", "L3"]


class ToolDefinition(TypedDict, total=False):
    """Vendor-neutral tool descriptor.

    Adapters that target Anthropic populate ``name`` / ``description`` /
    ``input_schema`` / ``defer_loading``. The Tool Search Tool declaration
    uses ``type`` + ``name`` only. Non-Anthropic adapters ignore the
    Anthropic-specific keys.
    """

    name: str
    description: str
    input_schema: dict[str, Any]
    # Anthropic-specific : ``tool-search-tool-2025-10-19`` beta header marker.
    defer_loading: bool
    # Anthropic Tool Search Tool declaration : carries ``type`` instead of
    # ``input_schema`` (server-side tool, no MINT code beyond declaration).
    type: str


@runtime_checkable
class ToolRegistryAdapter(Protocol):
    """Vendor-agnostic tool registration contract.

    Implementations live alongside this module :
    ``anthropic_defer_loading_adapter.py`` (default),
    ``skill_bundle_only_adapter.py`` (fallback),
    ``manual_subset_adapter.py`` (backup).

    The Protocol is ``runtime_checkable`` so callers can ``isinstance`` against
    it for dependency-injection wiring without forcing a concrete base class.
    """

    def register_tools(self, turn_context: dict[str, Any]) -> list[ToolDefinition]:
        """Return the tools array for the current turn.

        ``turn_context`` carries adapter-specific knobs (e.g. detected
        ``user_intents`` for ``ManualSubsetAdapter``). Adapters that do not
        consume the context simply ignore it.
        """
        ...

    def latency_tier(self, tool_name: str) -> LatencyTier:
        """Inform the Flutter rendering surface : chip (L1) vs narrative
        loader (L2 / L3).
        """
        ...
