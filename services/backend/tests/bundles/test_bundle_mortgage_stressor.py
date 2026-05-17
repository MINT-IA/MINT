"""Golden + fattening tests for MortgageStressorBundle (Phase 93.5 Wave 2 — Plan 93.5-03 Task 2).

Wave 0 (Plan 01) shipped a thin doctrine stub. Wave 2 fattens it to a full
FR doctrine fragment (≥800 chars), removes hardcoded CHF amounts in favor
of `{{cite:<key>}}` placeholders, annotates each `citation_allowlist` entry
with a `# TODO Phase 95 — pending GroundingPack registry` inline comment.
"""
from __future__ import annotations

import re
from pathlib import Path

from app.services.coach.bundles import MortgageStressorBundle


# ---------------------------------------------------------------------------
# Wave 0 invariants (preserved from previous test version)
# ---------------------------------------------------------------------------

def test_mortgage_stressor_golden():
    """D-20 lock + canonical name + safe-mode slot carried."""
    bundle = MortgageStressorBundle()
    assert bundle.name == "mortgage-stressor"
    assert bundle.allowed_tools == [
        "get_budget_status",
        "get_cap_status",
        "get_regulatory_constant",
    ]
    assert bundle.citation_allowlist
    # Slot interpolated by `_build_prompt` when ctx.has_debt is True.
    assert "{safe_mode_protocol}" in bundle.prompt_fragment
    # Mechanical doctrine markers preserved.
    assert "FINMA" in bundle.prompt_fragment
    assert "33%" in bundle.prompt_fragment


# ---------------------------------------------------------------------------
# Wave 2 fattening (Plan 93.5-03 Task 2)
# ---------------------------------------------------------------------------

def test_mortgage_stressor_bundle_shape_fattened():
    """Wave 2 — fragment ≥800 chars, ≤2000 chars, FINMA/tragbarkeit/LTV cited."""
    bundle = MortgageStressorBundle()
    assert len(bundle.prompt_fragment) >= 800, (
        f"Wave 2 fragment must be ≥800 chars (H10 fix). "
        f"Got {len(bundle.prompt_fragment)} chars."
    )
    assert len(bundle.prompt_fragment) <= 2000, (
        f"Wave 2 fragment must stay ≤2000 chars to keep budget headroom. "
        f"Got {len(bundle.prompt_fragment)} chars."
    )
    fragment_lower = bundle.prompt_fragment.lower()
    assert "finma" in fragment_lower
    assert "tragbarkeit" in fragment_lower
    assert "LTV" in bundle.prompt_fragment  # LTV is an uppercase acronym


def test_mortgage_stressor_no_hardcoded_chf_amounts():
    """T-93.5-11 — no `\\d{4,}\\s*CHF` in fragment ; numbers via {{cite:<key>}}."""
    bundle = MortgageStressorBundle()
    matches = re.findall(r"\d{4,}\s*CHF", bundle.prompt_fragment)
    assert not matches, (
        f"Hardcoded CHF amounts in mortgage_stressor: {matches}. "
        f"Use `{{{{cite:<key>}}}}` placeholders instead (CLAUDE.md §1, T-93.5-12)."
    )


def test_mortgage_stressor_safe_mode_slot_carried():
    """The `{safe_mode_protocol}` slot must remain present after fattening."""
    bundle = MortgageStressorBundle()
    assert "{safe_mode_protocol}" in bundle.prompt_fragment


def test_mortgage_stressor_allowed_tools_are_d20_subset():
    """C1 lock — D-20 mapping for mortgage-stressor (CONTEXT D-20)."""
    bundle = MortgageStressorBundle()
    assert set(bundle.allowed_tools) == {
        "get_budget_status",
        "get_cap_status",
        "get_regulatory_constant",
    }


def test_mortgage_stressor_citation_keys_prefixed():
    """Citations must be prefixed by mortgage domain (Wave 2 contract)."""
    bundle = MortgageStressorBundle()
    valid_prefixes = (
        "finma_",
        "mortgage_",
        "amortissement_",
        "ltv_",
        "tragbarkeit_",
        "ratio_",  # Wave 0 already shipped `ratio_endettement_max_33pct`
    )
    for key in bundle.citation_allowlist:
        assert key.startswith(valid_prefixes), (
            f"Citation key {key!r} not prefixed by mortgage domain "
            f"(allowed: {valid_prefixes})"
        )


def test_mortgage_stressor_citations_phase95_annotated():
    """H8 — every citation_allowlist entry has `# TODO Phase 95` inline comment."""
    bundle_path = Path(__file__).parent.parent.parent / (
        "app/services/coach/bundles/mortgage_stressor.py"
    )
    text = bundle_path.read_text(encoding="utf-8")
    todo_count = text.count("TODO Phase 95")
    bundle = MortgageStressorBundle()
    assert todo_count >= len(bundle.citation_allowlist), (
        f"Expected ≥{len(bundle.citation_allowlist)} `TODO Phase 95` markers "
        f"(one per citation_allowlist entry). Got {todo_count}."
    )
