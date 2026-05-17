"""Golden test for LifeEventRouterBundle (Phase 93.5 Wave 0)."""
from __future__ import annotations

from app.services.coach.bundles import LifeEventRouterBundle


def test_life_event_router_golden():
    bundle = LifeEventRouterBundle()
    # Identity
    assert bundle.name == "life-event-router"
    # D-20 mapping
    assert bundle.allowed_tools == ["get_budget_status", "get_retirement_projection"]
    assert bundle.citation_allowlist == []
    # Owns 3 of the 7 legacy slots
    fragment = bundle.prompt_fragment
    assert "{regional_identity}" in fragment
    assert "{lifecycle_awareness}" in fragment
    assert "{plan_awareness}" in fragment
    # Verbatim catalog blocks present (substrings from claude_coach_service.py)
    assert "EVENEMENTS DE VIE (18" in fragment
    assert "ARCHETYPES (8" in fragment
    assert "COUPLE DISSYMETRIQUE" in fragment
