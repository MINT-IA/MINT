"""
Tests for KnowledgeCatalog — RAG v2.

Validates catalog completeness, uniqueness of IDs,
cantonal coverage, category coverage, and the outdated filter.
"""

from __future__ import annotations

from datetime import date

import pytest

from app.services.rag.knowledge_catalog import (
    KnowledgeCatalog,
    KnowledgeCategory,
    KnowledgeSource,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def all_sources() -> list[KnowledgeSource]:
    return KnowledgeCatalog.all_sources()


@pytest.fixture(scope="module")
def all_ids(all_sources) -> list[str]:
    return [s.id for s in all_sources]


# ---------------------------------------------------------------------------
# Basic catalog tests
# ---------------------------------------------------------------------------


def test_catalog_has_at_least_100_sources(all_sources):
    """Catalog must have at least 100 sources."""
    assert len(all_sources) >= 100, (
        f"Expected >= 100 sources, got {len(all_sources)}"
    )


def test_all_sources_returns_list(all_sources):
    """all_sources() returns a non-empty list of KnowledgeSource."""
    assert isinstance(all_sources, list)
    assert len(all_sources) > 0
    for s in all_sources:
        assert isinstance(s, KnowledgeSource)


def test_no_duplicate_ids(all_ids):
    """All source IDs must be unique."""
    unique_ids = set(all_ids)
    assert len(all_ids) == len(unique_ids), (
        f"Duplicate IDs found: {[x for x in all_ids if all_ids.count(x) > 1]}"
    )


def test_all_sources_have_non_empty_ids(all_sources):
    """Every source must have a non-empty id."""
    for s in all_sources:
        assert s.id and s.id.strip(), f"Source has empty id: {s}"


def test_all_sources_have_non_empty_titles(all_sources):
    """Every source must have a non-empty title."""
    for s in all_sources:
        assert s.title and s.title.strip(), f"Source {s.id} has empty title"


def test_all_sources_have_valid_categories(all_sources):
    """Every source category must be a valid KnowledgeCategory."""
    valid_cats = set(KnowledgeCategory)
    for s in all_sources:
        assert s.category in valid_cats, (
            f"Source {s.id} has invalid category: {s.category}"
        )


def test_all_sources_have_legal_refs(all_sources):
    """Every source must cite at least one legal reference."""
    for s in all_sources:
        assert s.legal_refs and len(s.legal_refs) > 0, (
            f"Source {s.id} has no legal_refs"
        )


def test_all_sources_have_last_updated(all_sources):
    """Every source must have a last_updated date."""
    for s in all_sources:
        assert isinstance(s.last_updated, date), (
            f"Source {s.id} has invalid last_updated: {s.last_updated}"
        )


def test_all_sources_have_language(all_sources):
    """Every source must have a 2-letter language code."""
    for s in all_sources:
        assert s.language and len(s.language) == 2, (
            f"Source {s.id} has invalid language: {s.language}"
        )


# ---------------------------------------------------------------------------
# Category coverage
# ---------------------------------------------------------------------------


def test_all_categories_have_sources():
    """Every KnowledgeCategory must have at least 1 source."""
    for cat in KnowledgeCategory:
        sources = KnowledgeCatalog.by_category(cat)
        assert len(sources) >= 1, f"Category {cat.value} has no sources"


def test_by_category_avs():
    """AVS category must have multiple sources."""
    avs = KnowledgeCatalog.by_category(KnowledgeCategory.AVS)
    assert len(avs) >= 5


def test_by_category_lpp():
    """LPP category must have multiple sources."""
    lpp = KnowledgeCatalog.by_category(KnowledgeCategory.LPP)
    assert len(lpp) >= 5


def test_by_category_pillar_3a():
    """PILLAR_3A category must have multiple sources."""
    sources = KnowledgeCatalog.by_category(KnowledgeCategory.PILLAR_3A)
    assert len(sources) >= 3


def test_by_category_cantonal():
    """CANTONAL category must have sources for all major cantons."""
    cantonal = KnowledgeCatalog.by_category(KnowledgeCategory.CANTONAL)
    assert len(cantonal) >= 20


# ---------------------------------------------------------------------------
# Cantonal coverage
# ---------------------------------------------------------------------------


def test_cantonal_sources_cover_at_least_11_cantons():
    """At least 11 major cantons must have cantonal sources."""
    cantons = KnowledgeCatalog.unique_cantons()
    assert len(cantons) >= 11, (
        f"Expected >= 11 cantons, got {len(cantons)}: {cantons}"
    )


def test_major_cantons_have_sources():
    """ZH, GE, VD, VS, ZG must each have at least 1 source."""
    for canton in ["ZH", "GE", "VD", "VS", "ZG"]:
        sources = KnowledgeCatalog.by_canton(canton)
        assert len(sources) >= 1, f"Canton {canton} has no sources"


def test_by_canton_unknown_returns_empty():
    """by_canton for an unknown canton returns an empty list."""
    result = KnowledgeCatalog.by_canton("XX")
    assert result == []


def test_by_canton_case_insensitive():
    """by_canton should work regardless of letter case."""
    upper = KnowledgeCatalog.by_canton("ZH")
    lower = KnowledgeCatalog.by_canton("zh")
    assert len(upper) == len(lower)
    assert upper == lower


# ---------------------------------------------------------------------------
# Federal vs cantonal split
# ---------------------------------------------------------------------------


def test_federal_sources_exist():
    """There must be federal (non-cantonal) sources."""
    federal = KnowledgeCatalog.federal_sources()
    assert len(federal) >= 30


def test_federal_sources_have_no_canton():
    """Federal sources must all have canton=None."""
    for s in KnowledgeCatalog.federal_sources():
        assert s.canton is None, f"Federal source {s.id} unexpectedly has canton={s.canton}"


# ---------------------------------------------------------------------------
# Outdated detection
# ---------------------------------------------------------------------------


def test_outdated_with_far_future_cutoff():
    """All sources are outdated relative to a far-future date."""
    all_sources = KnowledgeCatalog.all_sources()
    outdated = KnowledgeCatalog.outdated(date(2035, 1, 1))
    assert len(outdated) == len(all_sources)


def test_outdated_with_past_cutoff():
    """No sources are outdated relative to a very old date."""
    outdated = KnowledgeCatalog.outdated(date(2000, 1, 1))
    assert len(outdated) == 0


def test_outdated_returns_correct_subset():
    """Outdated detection returns only sources before cutoff."""
    cutoff = date(2025, 7, 1)
    outdated = KnowledgeCatalog.outdated(cutoff)
    all_sources = KnowledgeCatalog.all_sources()
    for s in outdated:
        assert s.last_updated < cutoff, (
            f"Source {s.id} (updated {s.last_updated}) should not be outdated before {cutoff}"
        )
    for s in all_sources:
        if s.last_updated >= cutoff:
            assert s not in outdated, (
                f"Source {s.id} (updated {s.last_updated}) should not be in outdated list"
            )


def test_unique_cantons_returns_sorted():
    """unique_cantons() returns sorted list."""
    cantons = KnowledgeCatalog.unique_cantons()
    assert cantons == sorted(cantons)
