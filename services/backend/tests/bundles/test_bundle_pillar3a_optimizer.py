"""Golden + fattening tests for Pillar3aOptimizerBundle (Phase 93.5 Wave 2 — Plan 93.5-03 Task 5)."""
from __future__ import annotations

import re
from pathlib import Path

from app.services.coach.bundles import Pillar3aOptimizerBundle


# ---------------------------------------------------------------------------
# Wave 0 invariants (preserved)
# ---------------------------------------------------------------------------

def test_pillar3a_optimizer_golden():
    bundle = Pillar3aOptimizerBundle()
    assert bundle.name == "pillar3a-optimizer"
    assert bundle.allowed_tools == ["get_retirement_projection", "get_cross_pillar_analysis"]
    assert bundle.citation_allowlist
    for key in bundle.citation_allowlist:
        assert key.startswith(("r3a_", "opp3_", "lifd_")), (
            f"unexpected citation key: {key!r}"
        )
    assert "OPP3 art. 7" in bundle.prompt_fragment


# ---------------------------------------------------------------------------
# Wave 2 fattening
# ---------------------------------------------------------------------------

def test_pillar3a_bundle_shape_fattened():
    bundle = Pillar3aOptimizerBundle()
    assert len(bundle.prompt_fragment) >= 800, (
        f"Wave 2 ≥800 chars (H10). Got {len(bundle.prompt_fragment)}."
    )
    assert len(bundle.prompt_fragment) <= 2000, (
        f"Wave 2 ≤2000 chars budget headroom. Got {len(bundle.prompt_fragment)}."
    )


def test_pillar3a_covers_lifd_and_opp3():
    """Fragment must cite OPP3 art. 7 + LIFD art. 33 + LIFD art. 38."""
    bundle = Pillar3aOptimizerBundle()
    assert "OPP3 art. 7" in bundle.prompt_fragment
    assert "LIFD art. 33" in bundle.prompt_fragment
    assert "LIFD art. 38" in bundle.prompt_fragment
    assert "LPP art. 79b" in bundle.prompt_fragment


def test_pillar3a_no_hardcoded_chf_amounts():
    """T-93.5-11 — no `\\d{4,}\\s*CHF` ; numbers via {{cite:<key>}}."""
    bundle = Pillar3aOptimizerBundle()
    matches = re.findall(r"\d{4,}\s*CHF", bundle.prompt_fragment)
    assert not matches, (
        f"Hardcoded CHF amounts in pillar3a_optimizer: {matches}. "
        f"Use `{{{{cite:<key>}}}}` placeholders (CLAUDE.md §1)."
    )


def test_pillar3a_no_optimal_in_fragment():
    """LSFin — `optimal` MUST NOT appear in narrator output.

    The bundle's class NAME / docstring may contain `optimizer` (metadata),
    but the prompt_fragment must use `adapté` / `pertinent` / `envisageable`
    instead. Per CLAUDE.md TOP rule #1 + Plan 03 Task 5 H8 fix.
    """
    bundle = Pillar3aOptimizerBundle()
    text = bundle.prompt_fragment.lower()
    assert "optimal" not in text, (
        "banned LSFin term 'optimal' present in prompt_fragment — "
        "replace with 'adapté' or 'pertinent'"
    )


def test_pillar3a_allowed_tools_are_d20_subset():
    """C1 lock — D-20 mapping for pillar3a-optimizer."""
    bundle = Pillar3aOptimizerBundle()
    assert set(bundle.allowed_tools) == {
        "get_retirement_projection",
        "get_cross_pillar_analysis",
    }


def test_pillar3a_citation_keys_prefixed():
    bundle = Pillar3aOptimizerBundle()
    for key in bundle.citation_allowlist:
        assert key.startswith(("r3a_", "opp3_", "lifd_")), (
            f"Citation key {key!r} not prefixed by 3a/OPP3/LIFD domain"
        )


def test_pillar3a_citations_phase95_annotated():
    """H8 — ≥4 `TODO Phase 95` markers."""
    bundle_path = Path(__file__).parent.parent.parent / (
        "app/services/coach/bundles/pillar3a_optimizer.py"
    )
    text = bundle_path.read_text(encoding="utf-8")
    todo_count = text.count("TODO Phase 95")
    bundle = Pillar3aOptimizerBundle()
    assert todo_count >= 4, (
        f"Plan 03 acceptance requires ≥4 `TODO Phase 95` markers. Got {todo_count}."
    )
    assert todo_count >= len(bundle.citation_allowlist)
