"""
Coach shared models — Sprint S34 + S35.

Data classes for compliance validation, coach context, hallucination detection,
and narrative generation results.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional


class ComponentType(str, Enum):
    """Type of coach output component, each with length constraints."""
    greeting = "greeting"                # max 30 words
    score_summary = "score_summary"      # max 80 words
    tip = "tip"                          # max 120 words
    chiffre_choc = "chiffre_choc"        # max 100 words
    scenario = "scenario"                # max 150 words
    enrichment_guide = "enrichmentGuide" # max 150 words — data block conversational guide
    general = "general"                  # max 200 words


# Word limits per component type
COMPONENT_WORD_LIMITS = {
    ComponentType.greeting: 30,
    ComponentType.score_summary: 80,
    ComponentType.tip: 120,
    ComponentType.chiffre_choc: 100,
    ComponentType.scenario: 150,
    ComponentType.enrichment_guide: 150,
    ComponentType.general: 200,
}


@dataclass
class ComplianceResult:
    """Result of compliance validation on LLM output."""
    is_compliant: bool
    sanitized_text: str              # Cleaned version (if salvageable)
    violations: List[str] = field(default_factory=list)
    use_fallback: bool = False       # If True, discard LLM output entirely


@dataclass
class CoachContext:
    """Context passed to compliance guard and narrative generation.

    Contains financial_core outputs — NEVER raw amounts.
    All values are pre-computed by financial_core calculators.

    Extended in S35 with archetype, behavioral, and temporal fields
    to support the Coach Narrative Service.
    """
    first_name: str = "utilisateur"
    archetype: str = "swiss_native"
    age: int = 30
    canton: str = "VD"
    # Financial state (aggregated, never raw)
    fri_total: float = 0.0
    fri_delta: float = 0.0
    primary_focus: str = ""
    replacement_ratio: float = 0.0
    months_liquidity: float = 0.0
    tax_saving_potential: float = 0.0
    confidence_score: float = 0.0
    # Temporal
    days_since_last_visit: int = 0
    fiscal_season: str = ""    # "3a_deadline", "tax_declaration", ""
    upcoming_event: str = ""
    # Behavioral
    check_in_streak: int = 0
    last_milestone: str = ""
    # Known numerical values for hallucination detection
    known_values: dict = field(default_factory=dict)


@dataclass
class CoachNarrativeResult:
    """Result of the Coach Narrative Service — 4 independent components.

    Each component is generated independently and validated through
    ComplianceGuard before reaching the user.

    Sources:
        - LSFin art. 3 (quality of financial information)
        - LPD art. 6 (data processing principles)
    """
    greeting: str
    score_summary: str
    tip_narrative: str
    chiffre_choc_reframe: str
    used_fallback: Dict[str, bool] = field(default_factory=dict)
    disclaimer: str = ""
    sources: List[str] = field(default_factory=list)


@dataclass
class HallucinatedNumber:
    """A number found in LLM output that doesn't match known values."""
    found_text: str          # Original text fragment
    found_value: float       # Parsed numeric value
    closest_key: str         # Which known value it was compared against
    closest_value: float     # The expected value
    deviation_pct: float     # How much it deviates (as percentage)
