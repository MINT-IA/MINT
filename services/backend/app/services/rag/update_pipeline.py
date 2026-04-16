"""
Pipeline de mise à jour de la base de connaissances — RAG v2.

Gère la détection des sources obsolètes, la validation des sources
et la génération de rapports sur l'état du catalogue.

Usage type (annuel):
    catalog = KnowledgeCatalog.all_sources()
    pipeline = KnowledgeUpdatePipeline()
    report = pipeline.generate_update_report(catalog)
    outdated_ids = pipeline.check_for_updates(catalog, cutoff_date=date(2025, 1, 1))

Sprint S67 — RAG v2 Knowledge Pipeline.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Optional

from app.services.rag.knowledge_catalog import KnowledgeCategory, KnowledgeSource

# ---------------------------------------------------------------------------
# Threshold constants
# ---------------------------------------------------------------------------

# A canton or category is flagged as a gap if it has fewer than this many sources
_COVERAGE_GAP_THRESHOLD = 3

# All 26 Swiss cantons
_ALL_SWISS_CANTONS = [
    "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG", "FR",
    "SO", "BS", "BL", "SH", "AR", "AI", "SG", "GR", "AG", "TG",
    "TI", "VD", "VS", "NE", "GE", "JU",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class UpdateReport:
    """Report on the state of the knowledge catalog."""

    total_sources: int
    up_to_date: int
    needs_update: int
    cutoff_date: date
    by_category: dict[str, int] = field(default_factory=dict)
    by_canton: dict[str, int] = field(default_factory=dict)
    coverage_gaps: list[str] = field(default_factory=list)
    validation_issues: dict[str, list[str]] = field(default_factory=dict)
    federal_source_count: int = 0
    cantonal_source_count: int = 0


# ---------------------------------------------------------------------------
# KnowledgeUpdatePipeline
# ---------------------------------------------------------------------------


class KnowledgeUpdatePipeline:
    """Pipeline for auditing and updating the MINT knowledge catalog."""

    # ------------------------------------------------------------------
    # Public static API
    # ------------------------------------------------------------------

    @staticmethod
    def check_for_updates(
        catalog: list[KnowledgeSource],
        cutoff: Optional[date] = None,
    ) -> list[str]:
        """
        Return IDs of sources that need updating.

        A source needs updating if its last_updated date is strictly
        before the cutoff. If no cutoff is provided, uses Jan 1 of
        the current year.

        Args:
            catalog: List of KnowledgeSource objects to inspect.
            cutoff: Reference date. Sources older than this are outdated.

        Returns:
            List of source IDs that need updating.
        """
        if cutoff is None:
            cutoff = date(date.today().year, 1, 1)
        return [s.id for s in catalog if s.last_updated < cutoff]

    @staticmethod
    def validate_source(source: KnowledgeSource) -> list[str]:
        """
        Validate a knowledge source and return a list of issues.

        Checks performed:
        - id is non-empty and uses only safe characters
        - title is non-empty
        - category is a valid KnowledgeCategory
        - legal_refs is non-empty
        - language is a 2-letter ISO code
        - last_updated is not in the future

        Args:
            source: The KnowledgeSource to validate.

        Returns:
            List of issue strings. Empty list means source is valid.
        """
        issues: list[str] = []
        today = date.today()

        if not source.id or not source.id.strip():
            issues.append("id is empty")
        elif not all(c.isalnum() or c in "_-" for c in source.id):
            issues.append(f"id '{source.id}' contains invalid characters (use a-z, 0-9, _, -)")

        if not source.title or not source.title.strip():
            issues.append("title is empty")

        if not isinstance(source.category, KnowledgeCategory):
            issues.append(f"category '{source.category}' is not a valid KnowledgeCategory")

        if not source.legal_refs:
            issues.append("legal_refs is empty — every source must cite at least one legal reference")

        if not source.language or len(source.language) != 2:
            issues.append(f"language '{source.language}' must be a 2-letter ISO code")

        if source.last_updated > today:
            issues.append(f"last_updated {source.last_updated} is in the future")

        if source.canton is not None:
            if source.canton != source.canton.upper() or len(source.canton) != 2:
                issues.append(
                    f"canton '{source.canton}' must be a 2-letter uppercase code (e.g. 'ZH')"
                )

        return issues

    @staticmethod
    def generate_update_report(
        catalog: list[KnowledgeSource],
        cutoff: Optional[date] = None,
    ) -> UpdateReport:
        """
        Generate a full report on the state of the knowledge catalog.

        Args:
            catalog: List of all KnowledgeSource objects.
            cutoff: Reference date for "needs update" check.
                    Defaults to Jan 1 of current year.

        Returns:
            An UpdateReport with counts, gaps, and validation issues.
        """
        if cutoff is None:
            cutoff = date(date.today().year, 1, 1)

        outdated_ids = set(
            KnowledgeUpdatePipeline.check_for_updates(catalog, cutoff)
        )

        # Counts
        total = len(catalog)
        needs_update = len(outdated_ids)
        up_to_date = total - needs_update

        # By category
        by_category: dict[str, int] = {}
        for cat in KnowledgeCategory:
            count = sum(1 for s in catalog if s.category == cat)
            if count > 0:
                by_category[cat.value] = count

        # By canton
        by_canton: dict[str, int] = {}
        for s in catalog:
            if s.canton:
                by_canton[s.canton] = by_canton.get(s.canton, 0) + 1

        # Coverage gaps
        coverage_gaps: list[str] = []

        # Check cantons
        for canton in _ALL_SWISS_CANTONS:
            canton_count = by_canton.get(canton, 0)
            if canton_count < _COVERAGE_GAP_THRESHOLD:
                coverage_gaps.append(
                    f"canton:{canton} ({canton_count} sources, threshold={_COVERAGE_GAP_THRESHOLD})"
                )

        # Check categories
        for cat in KnowledgeCategory:
            cat_count = by_category.get(cat.value, 0)
            if cat_count < _COVERAGE_GAP_THRESHOLD:
                coverage_gaps.append(
                    f"category:{cat.value} ({cat_count} sources, threshold={_COVERAGE_GAP_THRESHOLD})"
                )

        # Validation issues
        validation_issues: dict[str, list[str]] = {}
        for s in catalog:
            issues = KnowledgeUpdatePipeline.validate_source(s)
            if issues:
                validation_issues[s.id] = issues

        federal_count = sum(1 for s in catalog if s.canton is None)
        cantonal_count = total - federal_count

        return UpdateReport(
            total_sources=total,
            up_to_date=up_to_date,
            needs_update=needs_update,
            cutoff_date=cutoff,
            by_category=by_category,
            by_canton=by_canton,
            coverage_gaps=coverage_gaps,
            validation_issues=validation_issues,
            federal_source_count=federal_count,
            cantonal_source_count=cantonal_count,
        )
