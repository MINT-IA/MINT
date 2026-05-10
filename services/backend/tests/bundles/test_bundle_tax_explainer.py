"""Golden + fattening tests for TaxExplainerBundle (Phase 93.5 Wave 2 — Plan 93.5-03 Task 3).

Wave 0 shipped a thin doctrine stub. Wave 2 fattens to a full FR doctrine
fragment ≥800 chars covering LIFD art. 22 / 33 / 38 + LHID, replaces
hardcoded numerical amounts with `{{cite:<key>}}` placeholders, and
annotates every `citation_allowlist` entry with `# TODO Phase 95 — pending
GroundingPack registry`.
"""
from __future__ import annotations

import re
from pathlib import Path

from app.services.coach.bundles import TaxExplainerBundle


# ---------------------------------------------------------------------------
# Wave 0 invariants (preserved)
# ---------------------------------------------------------------------------

def test_tax_explainer_golden():
    bundle = TaxExplainerBundle()
    assert bundle.name == "tax-explainer"
    assert bundle.allowed_tools == ["get_regulatory_constant", "get_cross_pillar_analysis"]
    assert bundle.citation_allowlist
    for key in bundle.citation_allowlist:
        assert key.startswith(("lifd_", "lhid_", "tax_canton_")), (
            f"unexpected citation key: {key!r}"
        )
    assert "LIFD art. 33" in bundle.prompt_fragment
    assert "LIFD art. 38" in bundle.prompt_fragment


# ---------------------------------------------------------------------------
# Wave 2 fattening
# ---------------------------------------------------------------------------

def test_tax_explainer_bundle_shape_fattened():
    bundle = TaxExplainerBundle()
    assert len(bundle.prompt_fragment) >= 800, (
        f"Wave 2 fragment must be ≥800 chars (H10). "
        f"Got {len(bundle.prompt_fragment)} chars."
    )
    assert len(bundle.prompt_fragment) <= 2000, (
        f"Wave 2 fragment must stay ≤2000 chars to keep budget headroom. "
        f"Got {len(bundle.prompt_fragment)} chars."
    )


def test_tax_explainer_covers_lifd_articles():
    """Fragment must mention LIFD art. 22 + 33 + 38 + LHID."""
    bundle = TaxExplainerBundle()
    assert "LIFD art. 22" in bundle.prompt_fragment
    assert "LIFD art. 33" in bundle.prompt_fragment
    assert "LIFD art. 38" in bundle.prompt_fragment
    assert "LHID" in bundle.prompt_fragment


def test_tax_explainer_no_hardcoded_chf_amounts():
    """T-93.5-11 — no `\\d{4,}\\s*CHF` ; numbers via {{cite:<key>}}."""
    bundle = TaxExplainerBundle()
    matches = re.findall(r"\d{4,}\s*CHF", bundle.prompt_fragment)
    assert not matches, (
        f"Hardcoded CHF amounts in tax_explainer: {matches}. "
        f"Use `{{{{cite:<key>}}}}` placeholders instead (CLAUDE.md §1)."
    )


def test_tax_explainer_allowed_tools_are_d20_subset():
    """C1 lock — D-20 mapping."""
    bundle = TaxExplainerBundle()
    assert set(bundle.allowed_tools) == {
        "get_regulatory_constant",
        "get_cross_pillar_analysis",
    }


def test_tax_explainer_citation_keys_prefixed():
    bundle = TaxExplainerBundle()
    for key in bundle.citation_allowlist:
        assert key.startswith(("lifd_", "lhid_", "tax_canton_")), (
            f"Citation key {key!r} not prefixed by tax domain"
        )


def test_tax_explainer_citations_phase95_annotated():
    """H8 — every citation has `# TODO Phase 95` inline ; ≥4 markers required."""
    bundle_path = Path(__file__).parent.parent.parent / (
        "app/services/coach/bundles/tax_explainer.py"
    )
    text = bundle_path.read_text(encoding="utf-8")
    todo_count = text.count("TODO Phase 95")
    bundle = TaxExplainerBundle()
    assert todo_count >= 4, (
        f"Plan 03 acceptance requires ≥4 `TODO Phase 95` markers. Got {todo_count}."
    )
    assert todo_count >= len(bundle.citation_allowlist), (
        f"Expected ≥{len(bundle.citation_allowlist)} `TODO Phase 95` markers "
        f"(one per citation_allowlist entry). Got {todo_count}."
    )
