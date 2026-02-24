"""
Onboarding Models — Dataclasses for minimal profile and chiffre choc.

Sprint S31 — Onboarding Redesign.

These models define the input/output contracts for the onboarding flow:
- MinimalProfileInput: 3 required fields + optional enrichment fields
- MinimalProfileResult: full projection with confidence scoring
- ChiffreChoc: single impactful number with educational context

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
"""

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class MinimalProfileInput:
    """Input for minimal profile computation.

    Only 3 fields are required: age, gross_salary, canton.
    All other fields are optional and will be estimated with defaults
    when not provided. Each estimated field reduces confidence_score.
    """

    age: int
    gross_salary: float
    canton: str
    household_type: Optional[str] = None        # default: "single"
    current_savings: Optional[float] = None      # default: estimated from age/salary
    is_property_owner: Optional[bool] = None     # default: False
    existing_3a: Optional[float] = None          # default: 0
    existing_lpp: Optional[float] = None         # default: estimated from LPP projection


@dataclass
class MinimalProfileResult:
    """Result of the minimal profile computation.

    Contains all projected values, confidence scoring,
    and compliance fields (disclaimer, sources, enrichment_prompts).
    """

    projected_avs_monthly: float
    projected_lpp_capital: float
    projected_lpp_monthly: float
    estimated_replacement_ratio: float
    estimated_monthly_retirement: float
    estimated_monthly_expenses: float
    tax_saving_3a: float
    marginal_tax_rate: float
    months_liquidity: float
    confidence_score: float
    estimated_fields: List[str]
    archetype: str
    disclaimer: str
    sources: List[str]
    enrichment_prompts: List[str]


@dataclass
class ChiffreChoc:
    """Single impactful number with educational context.

    Represents the ONE number that will capture the user's attention
    during onboarding and motivate them to explore further.

    Categories:
        - retirement_gap: monthly gap between retirement income and expenses
        - tax_saving: annual tax saving left on the table (3a)
        - liquidity: months of financial runway
        - lpp_opportunity: LPP buyback potential
        - mortgage_stress: mortgage affordability stress
    """

    category: str
    primary_number: float
    display_text: str
    explanation_text: str
    action_text: str
    disclaimer: str
    sources: List[str]
    confidence_score: float
