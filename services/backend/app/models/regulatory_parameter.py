"""Regulatory parameter model — single source of truth for Swiss financial constants.

Each RegulatoryParameter stores a single constant with full provenance:
    - Legal source (law article, ordinance, circular)
    - Temporal validity (effective_from / effective_to)
    - Jurisdiction (CH-wide or cantonal)
    - Review date for freshness tracking

Architecture:
    - Backend is source of truth (CLAUDE.md §4).
    - All calculators consume constants via RegulatoryRegistry.get().
    - Flutter mirrors via API sync, never invents constants.

Sources:
    - decisions/ADR-20260223-unified-financial-engine.md
    - CLAUDE.md §5 (Business Rules — Key Constants)
"""

from dataclasses import dataclass, field
from datetime import date
from typing import Optional


@dataclass
class RegulatoryParameter:
    """A single Swiss financial regulatory constant with metadata.

    Attributes:
        key: Dotted path, e.g. "pillar3a.max_with_lpp".
        value: Numeric or boolean value (stored as float; booleans as 1.0/0.0).
        unit: Physical unit — CHF, percent, years, days, ratio, boolean, count.
        jurisdiction: "CH" for federal, or canton code ("ZH", "GE", etc.).
        effective_from: Date the parameter became effective.
        effective_to: None means still active; set when superseded.
        tax_year: Tax year if relevant (e.g., 2025 for 3a limits).
        source_url: URL to the official source document.
        source_title: Human-readable source reference (e.g. "LPP art. 14").
        source_type: One of: law, ordinance, circular, faq, estimate.
        description: Brief explanation of the parameter.
        reviewed_at: Date of last human review (for freshness checks).
        notes: Additional context or caveats.
    """

    key: str
    value: float
    unit: str = "CHF"
    jurisdiction: str = "CH"
    effective_from: date = field(default_factory=lambda: date(2025, 1, 1))
    effective_to: Optional[date] = None
    tax_year: Optional[int] = None
    source_url: str = ""
    source_title: str = ""
    source_type: str = "law"
    description: str = ""
    reviewed_at: Optional[date] = None
    notes: str = ""

    def is_active(self, on_date: Optional[date] = None) -> bool:
        """Check if this parameter is active on a given date (default: today)."""
        check_date = on_date or date.today()
        if check_date < self.effective_from:
            return False
        if self.effective_to is not None and check_date > self.effective_to:
            return False
        return True

    def is_stale(self, max_age_days: int = 90) -> bool:
        """Check if the parameter needs review (reviewed_at older than max_age_days)."""
        if self.reviewed_at is None:
            return True
        return (date.today() - self.reviewed_at).days > max_age_days

    def to_dict(self) -> dict:
        """Serialize to a JSON-compatible dict for API responses."""
        return {
            "key": self.key,
            "value": self.value,
            "unit": self.unit,
            "jurisdiction": self.jurisdiction,
            "effectiveFrom": self.effective_from.isoformat(),
            "effectiveTo": self.effective_to.isoformat() if self.effective_to else None,
            "taxYear": self.tax_year,
            "sourceUrl": self.source_url,
            "sourceTitle": self.source_title,
            "sourceType": self.source_type,
            "description": self.description,
            "reviewedAt": self.reviewed_at.isoformat() if self.reviewed_at else None,
            "notes": self.notes,
        }
