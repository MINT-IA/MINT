"""Phase mint-calc-engine-v1 Plan 07 Task 5 — factory.py env-flag selector tests.

``get_tool_registry_adapter()`` reads ``TOOL_REGISTRY_ADAPTER`` env var and
returns the matching instance. Default is ``anthropic_defer_loading`` (D-CE-01
choice). Invalid values fall back to default with a warning log breadcrumb
(Sentry-compatible).
"""
from __future__ import annotations

import logging



def test_default_returns_anthropic_defer_loading(monkeypatch) -> None:
    """Plan acceptance Test 1 — env unset → AnthropicDeferLoadingAdapter."""
    monkeypatch.delenv("TOOL_REGISTRY_ADAPTER", raising=False)
    from app.services.coach.tool_registry.anthropic_defer_loading_adapter import (
        AnthropicDeferLoadingAdapter,
    )
    from app.services.coach.tool_registry.factory import get_tool_registry_adapter

    adapter = get_tool_registry_adapter()
    assert isinstance(adapter, AnthropicDeferLoadingAdapter)


def test_skill_bundle_only_selected(monkeypatch) -> None:
    """Plan acceptance Test 2 — env=skill_bundle_only → SkillBundleOnlyAdapter."""
    monkeypatch.setenv("TOOL_REGISTRY_ADAPTER", "skill_bundle_only")
    from app.services.coach.tool_registry.factory import get_tool_registry_adapter
    from app.services.coach.tool_registry.skill_bundle_only_adapter import (
        SkillBundleOnlyAdapter,
    )

    adapter = get_tool_registry_adapter()
    assert isinstance(adapter, SkillBundleOnlyAdapter)


def test_manual_subset_selected(monkeypatch) -> None:
    """Plan acceptance Test 3 — env=manual_subset → ManualSubsetAdapter."""
    monkeypatch.setenv("TOOL_REGISTRY_ADAPTER", "manual_subset")
    from app.services.coach.tool_registry.factory import get_tool_registry_adapter
    from app.services.coach.tool_registry.manual_subset_adapter import (
        ManualSubsetAdapter,
    )

    adapter = get_tool_registry_adapter()
    assert isinstance(adapter, ManualSubsetAdapter)


class _RecordCollector(logging.Handler):
    """Direct-attach handler — bypasses caplog/root-logger propagation games
    that other suite tests (test_profile_resolver et al.) play."""

    def __init__(self) -> None:
        super().__init__(level=logging.WARNING)
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


def test_invalid_value_falls_back_to_default_with_warning(monkeypatch) -> None:
    """Plan acceptance Test 4 — invalid env value → default + warning log.

    Direct handler-attach pattern (matching ``test_profile_resolver.py:210-228``
    convention) — bypasses ``caplog`` because the full-backend-suite has
    upstream tests that mutate root logger propagation / disabled / level
    (test_profile_resolver explicitly resets these on its own logger ; ours
    can be muted by them when running in the full suite ordering).
    """
    monkeypatch.setenv("TOOL_REGISTRY_ADAPTER", "this_does_not_exist")
    from app.services.coach.tool_registry import factory
    from app.services.coach.tool_registry.anthropic_defer_loading_adapter import (
        AnthropicDeferLoadingAdapter,
    )
    from app.services.coach.tool_registry.factory import get_tool_registry_adapter

    collector = _RecordCollector()
    factory._logger.setLevel(logging.WARNING)
    factory._logger.disabled = False
    factory._logger.propagate = True
    factory._logger.addHandler(collector)
    try:
        adapter = get_tool_registry_adapter()
    finally:
        factory._logger.removeHandler(collector)

    assert isinstance(adapter, AnthropicDeferLoadingAdapter)
    assert any(
        "this_does_not_exist" in rec.getMessage()
        and "anthropic_defer_loading" in rec.getMessage()
        for rec in collector.records
    ), (
        f"Expected warning mentioning bad value + default fallback ; "
        f"got {[r.getMessage() for r in collector.records]}"
    )
