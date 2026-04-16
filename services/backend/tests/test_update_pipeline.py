"""
Tests for KnowledgeUpdatePipeline — RAG v2.

Validates update detection, source validation, report generation,
and coverage gap identification.
"""

from __future__ import annotations

from datetime import date

import pytest

from app.services.rag.knowledge_catalog import (
    KnowledgeCatalog,
    KnowledgeCategory,
    KnowledgeSource,
)
from app.services.rag.update_pipeline import KnowledgeUpdatePipeline, UpdateReport


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def full_catalog() -> list[KnowledgeSource]:
    return KnowledgeCatalog.all_sources()


@pytest.fixture
def valid_source() -> KnowledgeSource:
    return KnowledgeSource(
        id="test_valid_source",
        title="Test source valide",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 1"],
        last_updated=date(2025, 1, 1),
        language="fr",
    )


@pytest.fixture
def old_source() -> KnowledgeSource:
    return KnowledgeSource(
        id="test_old_source",
        title="Source obsolète",
        category=KnowledgeCategory.LPP,
        legal_refs=["LPP art. 14"],
        last_updated=date(2020, 1, 1),
        language="fr",
    )


@pytest.fixture
def recent_source() -> KnowledgeSource:
    return KnowledgeSource(
        id="test_recent_source",
        title="Source récente",
        category=KnowledgeCategory.PILLAR_3A,
        legal_refs=["OPP3 art. 7"],
        last_updated=date(2025, 6, 1),
        language="fr",
    )


# ---------------------------------------------------------------------------
# check_for_updates
# ---------------------------------------------------------------------------


def test_check_for_updates_identifies_old_sources(old_source, recent_source):
    """Outdated detection returns old source and not recent source."""
    catalog = [old_source, recent_source]
    cutoff = date(2025, 1, 1)
    outdated = KnowledgeUpdatePipeline.check_for_updates(catalog, cutoff)
    assert old_source.id in outdated
    assert recent_source.id not in outdated


def test_check_for_updates_empty_catalog():
    """Empty catalog returns empty list."""
    result = KnowledgeUpdatePipeline.check_for_updates([], date(2025, 1, 1))
    assert result == []


def test_check_for_updates_all_fresh(recent_source):
    """All sources newer than cutoff → no outdated sources."""
    result = KnowledgeUpdatePipeline.check_for_updates([recent_source], date(2024, 1, 1))
    assert result == []


def test_check_for_updates_all_old(old_source):
    """All sources older than cutoff → all outdated."""
    result = KnowledgeUpdatePipeline.check_for_updates([old_source], date(2025, 1, 1))
    assert old_source.id in result


def test_check_for_updates_boundary_same_date(valid_source):
    """Source exactly on cutoff date is NOT outdated (< not <=)."""
    cutoff = valid_source.last_updated  # same date
    result = KnowledgeUpdatePipeline.check_for_updates([valid_source], cutoff)
    assert valid_source.id not in result


# ---------------------------------------------------------------------------
# validate_source
# ---------------------------------------------------------------------------


def test_validate_source_valid(valid_source):
    """Valid source produces zero issues."""
    issues = KnowledgeUpdatePipeline.validate_source(valid_source)
    assert issues == []


def test_validate_source_empty_id():
    """Empty id is flagged as issue."""
    s = KnowledgeSource(
        id="",
        title="Valid title",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 1"],
        last_updated=date(2025, 1, 1),
        language="fr",
    )
    issues = KnowledgeUpdatePipeline.validate_source(s)
    assert any("id" in i.lower() for i in issues), f"Expected id issue, got: {issues}"


def test_validate_source_empty_title():
    """Empty title is flagged."""
    s = KnowledgeSource(
        id="test_empty_title",
        title="",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 1"],
        last_updated=date(2025, 1, 1),
        language="fr",
    )
    issues = KnowledgeUpdatePipeline.validate_source(s)
    assert any("title" in i.lower() for i in issues)


def test_validate_source_no_legal_refs():
    """Empty legal_refs is flagged."""
    s = KnowledgeSource(
        id="test_no_refs",
        title="Valid title",
        category=KnowledgeCategory.FISCAL,
        legal_refs=[],
        last_updated=date(2025, 1, 1),
        language="fr",
    )
    issues = KnowledgeUpdatePipeline.validate_source(s)
    assert any("legal_refs" in i.lower() for i in issues)


def test_validate_source_invalid_language():
    """A language code that is not 2 letters is flagged."""
    s = KnowledgeSource(
        id="test_bad_lang",
        title="Valid title",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 1"],
        last_updated=date(2025, 1, 1),
        language="french",  # too long
    )
    issues = KnowledgeUpdatePipeline.validate_source(s)
    assert any("language" in i.lower() for i in issues)


def test_validate_source_future_date():
    """Source updated in the future is flagged."""
    s = KnowledgeSource(
        id="test_future",
        title="Future source",
        category=KnowledgeCategory.AVS,
        legal_refs=["LAVS art. 1"],
        last_updated=date(2099, 1, 1),
        language="fr",
    )
    issues = KnowledgeUpdatePipeline.validate_source(s)
    assert any("future" in i.lower() or "last_updated" in i.lower() for i in issues)


# ---------------------------------------------------------------------------
# generate_update_report
# ---------------------------------------------------------------------------


def test_report_totals_match(full_catalog):
    """up_to_date + needs_update must equal total_sources."""
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog, date(2024, 6, 1))
    assert report.up_to_date + report.needs_update == report.total_sources


def test_report_total_sources(full_catalog):
    """Report total_sources equals catalog length."""
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog)
    assert report.total_sources == len(full_catalog)


def test_report_by_category_counts(full_catalog):
    """by_category sums equal total_sources."""
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog)
    total_from_categories = sum(report.by_category.values())
    # by_category only includes categories with sources
    assert total_from_categories == report.total_sources


def test_report_by_canton_includes_major_cantons(full_catalog):
    """Report by_canton includes ZH, GE, VS."""
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog)
    for canton in ["ZH", "GE", "VS"]:
        assert canton in report.by_canton, f"Canton {canton} not in report.by_canton"


def test_report_coverage_gaps_format(full_catalog):
    """Coverage gaps are strings with descriptive format."""
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog)
    for gap in report.coverage_gaps:
        assert isinstance(gap, str)
        # Each gap should mention "canton:" or "category:"
        assert ":" in gap, f"Unexpected gap format: {gap}"


def test_report_is_update_report_instance(full_catalog):
    """generate_update_report returns an UpdateReport instance."""
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog)
    assert isinstance(report, UpdateReport)


def test_report_federal_cantonal_split(full_catalog):
    """federal + cantonal sources equal total."""
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog)
    assert report.federal_source_count + report.cantonal_source_count == report.total_sources


def test_report_cutoff_date_stored(full_catalog):
    """Report stores the cutoff_date used."""
    cutoff = date(2025, 3, 15)
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog, cutoff)
    assert report.cutoff_date == cutoff


def test_report_no_validation_issues_in_clean_catalog(full_catalog):
    """The production catalog should have zero validation issues."""
    report = KnowledgeUpdatePipeline.generate_update_report(full_catalog)
    assert report.validation_issues == {}, (
        f"Validation issues found: {report.validation_issues}"
    )
