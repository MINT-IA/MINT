"""Golden test for ComplianceNarratorBundle (Phase 93.5 Wave 0)."""
from __future__ import annotations

from app.services.coach.bundles import ComplianceNarratorBundle


def test_compliance_narrator_golden():
    bundle = ComplianceNarratorBundle()
    # Identity
    assert bundle.name == "compliance-narrator"
    assert isinstance(bundle.prompt_fragment, str)
    # D-20 : doctrine-only, no tool calls
    assert bundle.allowed_tools == []
    # No citation list (the bundle does not emit numbers ; it forbids wrong outputs)
    assert bundle.citation_allowlist == []
    # Owned slots — at minimum {banned_terms}, {check_in_protocol}, {routing_rules}
    fragment = bundle.prompt_fragment
    assert "{banned_terms}" in fragment
    assert "{check_in_protocol}" in fragment
    assert "{routing_rules}" in fragment
