"""Phase mint-calc-engine-v1 Plan 07 — D-CE-01 vendor-agnostic tool registry.

Public surface :

- ``ToolRegistryAdapter`` — runtime-checkable Protocol (2 methods).
- ``ToolDefinition`` — TypedDict for the per-tool entries.
- ``LatencyTier`` — ``Literal["L1", "L2", "L3"]`` for Flutter rendering surface.
- ``get_tool_registry_adapter`` — factory selector reading
  ``TOOL_REGISTRY_ADAPTER`` env (defaults to ``anthropic_defer_loading``).

The 3 concrete adapters (``anthropic_defer_loading_adapter`` /
``skill_bundle_only_adapter`` / ``manual_subset_adapter``) are wired in
``factory.py`` and re-exported here for direct DI when needed.
"""
from app.services.coach.tool_registry.adapter import (
    LatencyTier,
    ToolDefinition,
    ToolRegistryAdapter,
)

__all__ = [
    "LatencyTier",
    "ToolDefinition",
    "ToolRegistryAdapter",
]
