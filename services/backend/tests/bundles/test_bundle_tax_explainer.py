"""Golden test for TaxExplainerBundle (Phase 93.5 Wave 0)."""
from __future__ import annotations

from app.services.coach.bundles import TaxExplainerBundle


def test_tax_explainer_golden():
    bundle = TaxExplainerBundle()
    assert bundle.name == "tax-explainer"
    # D-20 mapping
    assert bundle.allowed_tools == ["get_regulatory_constant", "get_cross_pillar_analysis"]
    # Citation prefix lifd_ or lhid_ (Phase 95-pending)
    assert bundle.citation_allowlist
    for key in bundle.citation_allowlist:
        assert key.startswith(("lifd_", "lhid_")), f"unexpected citation key: {key!r}"
    # Fragment mentions canonical doctrine (LIFD art. 33 + LIFD art. 38)
    assert "LIFD art. 33" in bundle.prompt_fragment
    assert "LIFD art. 38" in bundle.prompt_fragment
