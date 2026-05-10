"""Golden test for Pillar3aOptimizerBundle (Phase 93.5 Wave 0)."""
from __future__ import annotations

from app.services.coach.bundles import Pillar3aOptimizerBundle


def test_pillar3a_optimizer_golden():
    bundle = Pillar3aOptimizerBundle()
    assert bundle.name == "pillar3a-optimizer"
    # D-20 mapping
    assert bundle.allowed_tools == ["get_retirement_projection", "get_cross_pillar_analysis"]
    # Citation prefix r3a_ (Phase 95-pending)
    assert bundle.citation_allowlist
    for key in bundle.citation_allowlist:
        assert key.startswith("r3a_"), f"unexpected citation key: {key!r}"
    # Fragment mentions the canonical doctrine (OPP3 art. 7 plafond)
    assert "OPP3 art. 7" in bundle.prompt_fragment
