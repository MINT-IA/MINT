"""Golden test for LppProjectorBundle (Phase 93.5 Wave 0)."""
from __future__ import annotations

from app.services.coach.bundles import LppProjectorBundle


def test_lpp_projector_golden():
    bundle = LppProjectorBundle()
    assert bundle.name == "lpp-projector"
    # D-20 mapping
    assert bundle.allowed_tools == ["get_retirement_projection", "get_cross_pillar_analysis"]
    # Citation prefix lpp_ (Phase 95-pending)
    assert bundle.citation_allowlist
    for key in bundle.citation_allowlist:
        assert key.startswith("lpp_"), f"unexpected citation key: {key!r}"
    # Fragment mentions the canonical doctrine (LPP art. 14 al. 2 — taux conversion 6.8%)
    assert "LPP art. 14" in bundle.prompt_fragment
    assert "6.8%" in bundle.prompt_fragment
