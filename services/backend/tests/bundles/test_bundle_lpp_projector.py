"""Golden + fattening tests for LppProjectorBundle (Phase 93.5 Wave 2 — Plan 93.5-03 Task 4)."""
from __future__ import annotations

import re
from pathlib import Path

from app.services.coach.bundles import LppProjectorBundle


# ---------------------------------------------------------------------------
# Wave 0 invariants (preserved)
# ---------------------------------------------------------------------------

def test_lpp_projector_golden():
    bundle = LppProjectorBundle()
    assert bundle.name == "lpp-projector"
    assert bundle.allowed_tools == ["get_retirement_projection", "get_cross_pillar_analysis"]
    assert bundle.citation_allowlist
    for key in bundle.citation_allowlist:
        assert key.startswith(("lpp_", "opp2_", "lavs_")), (
            f"unexpected citation key: {key!r}"
        )
    assert "LPP art. 14" in bundle.prompt_fragment
    assert "6.8%" in bundle.prompt_fragment


# ---------------------------------------------------------------------------
# Wave 2 fattening
# ---------------------------------------------------------------------------

def test_lpp_projector_bundle_shape_fattened():
    bundle = LppProjectorBundle()
    assert len(bundle.prompt_fragment) >= 800, (
        f"Wave 2 ≥800 chars (H10). Got {len(bundle.prompt_fragment)}."
    )
    assert len(bundle.prompt_fragment) <= 2000, (
        f"Wave 2 ≤2000 chars budget headroom. Got {len(bundle.prompt_fragment)}."
    )


def test_lpp_covers_articles():
    """Fragment must mention LPP art. 14 + 19 + OPP2 art. 1."""
    bundle = LppProjectorBundle()
    assert "LPP art. 14" in bundle.prompt_fragment
    assert "LPP art. 19" in bundle.prompt_fragment
    assert "OPP2 art. 1" in bundle.prompt_fragment


def test_lpp_no_hardcoded_amounts():
    """T-93.5-11 — no `\\d{4,}\\s*CHF` ; numbers via {{cite:<key>}}."""
    bundle = LppProjectorBundle()
    matches = re.findall(r"\d{4,}\s*CHF", bundle.prompt_fragment)
    assert not matches, (
        f"Hardcoded CHF amounts in lpp_projector: {matches}. "
        f"Use `{{{{cite:<key>}}}}` placeholders (CLAUDE.md §1)."
    )


def test_lpp_allowed_tools_are_d20_subset():
    """C1 lock — D-20 mapping for lpp-projector."""
    bundle = LppProjectorBundle()
    assert set(bundle.allowed_tools) == {
        "get_retirement_projection",
        "get_cross_pillar_analysis",
    }


def test_lpp_citation_keys_prefixed():
    bundle = LppProjectorBundle()
    for key in bundle.citation_allowlist:
        assert key.startswith(("lpp_", "opp2_", "lavs_")), (
            f"Citation key {key!r} not prefixed by LPP/OPP2/LAVS domain"
        )


def test_lpp_citations_phase95_annotated():
    """H8 — ≥4 `TODO Phase 95` markers."""
    bundle_path = Path(__file__).parent.parent.parent / (
        "app/services/coach/bundles/lpp_projector.py"
    )
    text = bundle_path.read_text(encoding="utf-8")
    todo_count = text.count("TODO Phase 95")
    bundle = LppProjectorBundle()
    assert todo_count >= 4, (
        f"Plan 03 acceptance requires ≥4 `TODO Phase 95` markers. Got {todo_count}."
    )
    assert todo_count >= len(bundle.citation_allowlist)
