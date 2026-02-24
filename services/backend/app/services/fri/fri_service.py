"""
FRI Service — Sprint S38 (Shadow Mode).

Computes the Financial Resilience Index = L + F + R + S (each 0-25).

Components:
    L — Liquidity (non-linear sqrt, diminishing returns)
    F — Fiscal efficiency (weighted: 3a, rachat, amort indirect)
    R — Retirement readiness (non-linear pow 1.5)
    S — Structural risk (penalty-based)

Rules:
    - FRI is computed but NOT displayed (shadow mode).
    - Logged in snapshots for calibration.
    - MUST use financial_core calculators for inputs.
    - Never reimplement AVS/LPP/tax logic.

References:
    - ONBOARDING_ARBITRAGE_ENGINE.md § V
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 14-16 (taux de conversion)
    - LIFD art. 38 (capital withdrawal tax)
"""

import math
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional


@dataclass
class FriInput:
    """Input data for FRI computation.

    All values should come from financial_core calculators,
    never from raw user input.
    """
    # L — Liquidity
    liquid_assets: float = 0.0          # CHF in liquid savings/accounts
    monthly_fixed_costs: float = 1.0    # CHF monthly expenses (min 1 to avoid div/0)
    short_term_debt_ratio: float = 0.0  # Short-term debt / total assets (0-1)
    income_volatility: str = "low"      # "low", "medium", "high" (high = independants)

    # F — Fiscal efficiency
    actual_3a: float = 0.0              # CHF contributed to 3a this year
    max_3a: float = 7258.0             # CHF max 3a (7'258 salarie, 36'288 indep.)
    potentiel_rachat_lpp: float = 0.0   # CHF potential LPP buyback
    rachat_effectue: float = 0.0        # CHF LPP buyback completed
    taux_marginal: float = 0.0          # Marginal tax rate (0-1)
    is_property_owner: bool = False     # Owns real estate
    amort_indirect: float = 0.0         # CHF indirect amortization via 3a

    # R — Retirement readiness
    replacement_ratio: float = 0.0      # Projected retirement income / current net (0-1+)

    # S — Structural risk
    disability_gap_ratio: float = 0.0   # Gap between disability need and coverage (0-1)
    has_dependents: bool = False         # Has children or dependent spouse
    death_protection_gap_ratio: float = 0.0  # Gap in death protection coverage (0-1)
    mortgage_stress_ratio: float = 0.0  # Mortgage costs / gross income (0-1)
    concentration_ratio: float = 0.0    # Largest single asset / total net worth (0-1)
    employer_dependency_ratio: float = 0.0  # (LPP + salary) from same employer / total income

    # Metadata
    archetype: str = "swiss_native"
    age: int = 30
    canton: str = "VD"


@dataclass
class FriBreakdown:
    """FRI breakdown result."""
    liquidite: float          # L component (0-25)
    fiscalite: float          # F component (0-25)
    retraite: float           # R component (0-25)
    risque: float             # S component (0-25)
    total: float              # L + F + R + S (0-100)
    model_version: str = "1.0.0"
    computed_at: datetime = field(default_factory=datetime.now)
    confidence_score: float = 0.0
    disclaimer: str = (
        "Score de solidite financiere a titre educatif. "
        "Ne constitue pas un conseil financier (LSFin)."
    )
    sources: List[str] = field(default_factory=lambda: [
        "LAVS art. 21-29 (rente AVS)",
        "LPP art. 14-16 (taux de conversion)",
        "LIFD art. 38 (imposition du capital)",
        "FINMA circ. 2008/21 (gestion des risques)",
    ])


def _clamp(value: float, lo: float = 0.0, hi: float = 25.0) -> float:
    """Clamp value between lo and hi."""
    return max(lo, min(hi, value))


class FriService:
    """Computes the Financial Resilience Index (FRI).

    FRI = L + F + R + S, each component 0-25, total 0-100.

    This is a pure computation service with no side effects.
    All inputs should be pre-computed by financial_core calculators.
    """

    MODEL_VERSION = "1.0.0"

    @staticmethod
    def compute_liquidity(inp: FriInput) -> float:
        """L — Liquidity component (0-25).

        Non-linear (sqrt): first months of emergency fund matter most.
        Going from 0→1 month is critical, 5→6 is marginal.

        Penalties:
            - Short-term debt ratio > 30%: -4
            - High income volatility (independants): -3
        """
        monthly_costs = max(inp.monthly_fixed_costs, 1.0)
        months_cover = inp.liquid_assets / monthly_costs

        # sqrt for diminishing returns
        l_score = 25.0 * min(1.0, math.sqrt(months_cover / 6.0))

        # Penalties
        if inp.short_term_debt_ratio > 0.30:
            l_score -= 4.0
        if inp.income_volatility == "high":
            l_score -= 3.0

        return _clamp(l_score)

    @staticmethod
    def compute_fiscal(inp: FriInput) -> float:
        """F — Fiscal efficiency component (0-25).

        Weighted average (when rachat applicable):
            - 60% utilisation 3a
            - 25% utilisation rachat LPP (only if taux marginal > 25%)
            - 15% utilisation amort indirect

        When rachat is NOT applicable (taux marginal <= 25% or no potential):
            - Weights redistribute: 80% 3a, 20% amort indirect
            - This avoids penalizing users for rationally skipping rachat.
        """
        # 3a utilization (0-1)
        max_3a = max(inp.max_3a, 1.0)
        utilisation_3a = min(1.0, inp.actual_3a / max_3a)

        # Rachat LPP utilization (conditional on marginal rate)
        rachat_applicable = (inp.potentiel_rachat_lpp > 0 and inp.taux_marginal > 0.25)
        utilisation_rachat = 0.0
        if rachat_applicable:
            utilisation_rachat = min(1.0, inp.rachat_effectue / inp.potentiel_rachat_lpp)

        # Amort indirect utilization
        if inp.is_property_owner:
            utilisation_amort = 1.0 if inp.amort_indirect > 0 else 0.0
        else:
            utilisation_amort = 1.0  # No property → no penalty

        if rachat_applicable:
            f_score = 25.0 * (
                0.60 * utilisation_3a
                + 0.25 * utilisation_rachat
                + 0.15 * utilisation_amort
            )
        else:
            # Redistribute rachat weight to 3a (80%) and amort (20%)
            f_score = 25.0 * (
                0.80 * utilisation_3a
                + 0.20 * utilisation_amort
            )

        return _clamp(f_score)

    @staticmethod
    def compute_retirement(inp: FriInput) -> float:
        """R — Retirement readiness component (0-25).

        Non-linear (pow 1.5): Being at 60% replacement is much better
        than 30%, but 80% vs 70% is marginal.

        Target replacement ratio: 70% (Swiss standard benchmark).
        """
        target = 0.70
        ratio = max(0.0, inp.replacement_ratio)
        r_score = 25.0 * min(1.0, math.pow(ratio / target, 1.5))

        return _clamp(r_score)

    @staticmethod
    def compute_structural_risk(inp: FriInput) -> float:
        """S — Structural risk component (0-25).

        Starts at 25, penalties subtracted:
            - Disability gap > 20%: -6
            - Death protection gap > 30% (if dependents): -6
            - Mortgage stress > 36% (above FINMA 1/3 guideline): -5
            - Concentration > 70% (single asset dominance): -4
            - Employer dependency > 80%: -4
        """
        s_score = 25.0

        if inp.disability_gap_ratio > 0.20:
            s_score -= 6.0
        if inp.has_dependents and inp.death_protection_gap_ratio > 0.30:
            s_score -= 6.0
        if inp.mortgage_stress_ratio > 0.36:
            s_score -= 5.0
        if inp.concentration_ratio > 0.70:
            s_score -= 4.0
        if inp.employer_dependency_ratio > 0.80:
            s_score -= 4.0

        return _clamp(s_score)

    @classmethod
    def compute(cls, inp: FriInput, confidence_score: float = 0.0) -> FriBreakdown:
        """Compute full FRI breakdown.

        Args:
            inp: FriInput with all financial indicators.
            confidence_score: Profile completeness score (0-100).

        Returns:
            FriBreakdown with L, F, R, S components and total.
        """
        l = cls.compute_liquidity(inp)
        f = cls.compute_fiscal(inp)
        r = cls.compute_retirement(inp)
        s = cls.compute_structural_risk(inp)

        return FriBreakdown(
            liquidite=round(l, 2),
            fiscalite=round(f, 2),
            retraite=round(r, 2),
            risque=round(s, 2),
            total=round(l + f + r + s, 2),
            model_version=cls.MODEL_VERSION,
            confidence_score=confidence_score,
        )
