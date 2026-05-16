"""Phase mint-calc-engine-v1 Plan 07 Task 5 — factory env-flag selector.

``get_tool_registry_adapter()`` reads the ``TOOL_REGISTRY_ADAPTER`` env var and
returns the matching adapter instance per D-CE-01. Default is
``anthropic_defer_loading`` (Anthropic Tool Search Tool + defer_loading).

Operator-controlled selection :
- Unset / ``anthropic_defer_loading`` → :class:`AnthropicDeferLoadingAdapter`
- ``skill_bundle_only`` → :class:`SkillBundleOnlyAdapter` (fallback)
- ``manual_subset`` → :class:`ManualSubsetAdapter` (backup)
- Anything else → default + warning log breadcrumb (Sentry-compatible)

The factory is the single integration point that ``coach_chat.py`` (Plan 10
W2-04 wire-up) will call. Calling it twice creates two instances ; the v1
contract is a fresh instance per call (cheap construction, no global state).
"""
from __future__ import annotations

import logging
import os

from app.services.coach.tool_registry.adapter import ToolRegistryAdapter
from app.services.coach.tool_registry.anthropic_defer_loading_adapter import (
    AnthropicDeferLoadingAdapter,
)
from app.services.coach.tool_registry.manual_subset_adapter import (
    ManualSubsetAdapter,
)
from app.services.coach.tool_registry.skill_bundle_only_adapter import (
    SkillBundleOnlyAdapter,
)


_DEFAULT_ADAPTER_NAME = "anthropic_defer_loading"

_logger = logging.getLogger(__name__)


_ADAPTERS: dict[str, type] = {
    "anthropic_defer_loading": AnthropicDeferLoadingAdapter,
    "skill_bundle_only": SkillBundleOnlyAdapter,
    "manual_subset": ManualSubsetAdapter,
}


def get_tool_registry_adapter() -> ToolRegistryAdapter:
    """Return the adapter instance selected by ``TOOL_REGISTRY_ADAPTER`` env.

    Falls back to ``anthropic_defer_loading`` (D-CE-01 default) on unknown
    values, emitting a WARNING log that Sentry breadcrumbs auto-capture.
    """
    name = os.getenv("TOOL_REGISTRY_ADAPTER", _DEFAULT_ADAPTER_NAME)
    cls = _ADAPTERS.get(name)
    if cls is None:
        _logger.warning(
            "Unknown TOOL_REGISTRY_ADAPTER=%r ; falling back to default %r",
            name,
            _DEFAULT_ADAPTER_NAME,
        )
        cls = _ADAPTERS[_DEFAULT_ADAPTER_NAME]
    return cls()
