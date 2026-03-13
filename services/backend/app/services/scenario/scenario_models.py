"""
Dataclass models for Scenario Narration + Annual Refresh — Sprint S37.

Pure data containers; no business logic here.
"""

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class ScenarioInput:
    """Input from ForecasterService.project() — one of 3 scenarios."""

    label: str  # "prudent", "base", "optimiste"
    annual_return: float  # e.g. 0.01, 0.045, 0.07
    capital_final: float  # CHF at retirement
    monthly_income: float  # CHF estimated monthly income at retirement
    replacement_ratio: float = 0.0  # 0.0-1.0


@dataclass
class NarratedScenario:
    """A single narrated scenario with educational text."""

    label: str
    narrative: str  # Max 150 words, French, educational
    annual_return_pct: float  # e.g. 1.0, 4.5, 7.0
    capital_final: float
    monthly_income: float


@dataclass
class ScenarioNarrationResult:
    """Result of narrating all 3 scenarios."""

    scenarios: List[NarratedScenario]
    disclaimer: str
    sources: List[str]
    uncertainty_mentioned: bool = True


@dataclass
class RefreshQuestion:
    """A question in the annual refresh flow."""

    key: str  # e.g., "salary_changed"
    label: str  # French text
    question_type: str  # "slider", "yes_no", "select", "text"
    current_value: Optional[str] = None  # Pre-filled
    options: List[str] = field(default_factory=list)  # For "select" type


@dataclass
class AnnualRefreshResult:
    """Result of annual refresh detection."""

    refresh_needed: bool
    months_since_update: int
    questions: List[RefreshQuestion]
    disclaimer: str = (
        "Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin)."
    )
    sources: List[str] = field(default_factory=lambda: ["LSFin art. 3"])
