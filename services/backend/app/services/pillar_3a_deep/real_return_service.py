"""
Real return calculator for Pillar 3a with marginal tax rate.

Calculates the true return of a 3a investment by accounting for:
- Annual tax deduction (the "invisible" return)
- Gross return minus management fees and inflation
- Comparison with a regular savings account (no tax deduction)

The key insight: the tax deduction is itself a form of return that most
people don't factor in. A 3a with 3% gross return and 30% marginal rate
effectively yields more than 3% when the tax savings are reinvested.

Sources:
    - LIFD art. 33 al. 1 let. e (deduction fiscale 3a)
    - OPP3 art. 1 (plafond annuel 3a lie)

Sprint S16 — Gap G1: 3a Deep.
"""

from dataclasses import dataclass, field
from typing import Callable, List

from app.constants.social_insurance import (
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
)


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil en prevoyance ni en placement au sens de la LSFin. "
    "Les rendements passes ne prejugent pas des rendements futurs. "
    "Consultez un ou une specialiste pour une analyse personnalisee."
)

# 3a annual contribution limits (imported from social_insurance)
PLAFOND_3A_SALARIE = PILIER_3A_PLAFOND_AVEC_LPP
PLAFOND_3A_INDEPENDANT = PILIER_3A_PLAFOND_SANS_LPP

# Default savings account rate (for comparison)
TAUX_EPARGNE_DEFAUT = 0.015  # 1.5% — typical Swiss savings account 2025/2026


@dataclass
class RealReturnResult:
    """Complete result of real return analysis."""

    # 3a projection
    versement_annuel: float          # Annual 3a contribution (CHF)
    total_verse: float               # Total contributions over the period (CHF)
    capital_final_3a: float          # Final 3a capital (CHF)
    rendement_net_annuel: float      # Net annual return (after fees & inflation)
    total_economies_fiscales: float  # Total tax savings over the period (CHF)

    # Real return
    rendement_reel_annualise: float  # Annualized real return including tax savings (%)
    rendement_brut: float            # Gross return input (%)
    frais_gestion: float             # Management fees input (%)
    inflation: float                 # Inflation input (%)

    # Comparison: same amount on savings account
    capital_final_epargne: float     # Final capital on savings account (CHF)
    rendement_epargne: float         # Savings account return rate (%)

    # Delta
    avantage_3a_vs_epargne: float    # 3a advantage over savings (CHF)

    # Metadata
    duree_annees: int
    taux_marginal: float

    # Compliance
    premier_eclairage: str
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


def fv_annuity_due(pmt: float, r: float, n: int) -> float:
    """Future value of an annuity-due (payments at start of period).

    Payments at instants 0, 1, ..., n-1. Capitalization at end of year n.
    FV_ord = pmt × ((1+r)^n − 1) / r
    FV_due = FV_ord × (1+r)

    Limit r → 0: FV_due ≈ pmt × n × (1+r)
    """
    if n <= 0:
        return 0.0
    if abs(r) < 1e-10:
        return pmt * n * (1 + r)
    fv_ord = pmt * ((1 + r) ** n - 1) / r
    return fv_ord * (1 + r)


def solve_rate_bisection(
    pmt: float,
    target_fv: float,
    n: int,
    tol: float = 1e-6,
    max_iter: int = 200,
) -> float:
    """Solve for r via robust bisection.

    Find r such that fv_annuity_due(pmt, r, n) = target_fv.
    Bounds: -0.9999 to 1.0, expandable to 10.0.
    """
    if n <= 0:
        return 0.0
    if pmt <= 0 or target_fv <= 0:
        return 0.0
    if n == 1:
        # FV = pmt × (1+r) → r = target_fv / pmt − 1
        return target_fv / pmt - 1

    def f(rate: float) -> float:
        return fv_annuity_due(pmt, rate, n) - target_fv

    return solve_bisection(
        f=f,
        low=-0.9999,
        high=1.0,
        tol=tol,
        max_iter=max_iter,
    )


def solve_bisection(
    f: Callable[[float], float],
    low: float,
    high: float,
    tol: float = 1e-6,
    max_iter: int = 200,
) -> float:
    """Generic robust bisection solver for monotonic functions.

    Tries to bracket the root by expanding high to [2.0, 5.0, 10.0]
    if [low, high] does not initially bracket a sign change.
    """
    lo = low
    hi = high
    f_lo = f(lo)
    f_hi = f(hi)

    if f_lo == 0:
        return lo
    if f_hi == 0:
        return hi

    if f_lo * f_hi > 0:
        for hi_candidate in (2.0, 5.0, 10.0):
            hi = hi_candidate
            f_hi = f(hi)
            if f_lo * f_hi <= 0:
                break
        else:
            raise ValueError(
                "Impossible d'encadrer la racine dans [-0.9999, 10.0]."
            )

    for _ in range(max_iter):
        mid = (lo + hi) / 2
        f_mid = f(mid)

        if abs(f_mid) <= tol or abs(hi - lo) <= 1e-12:
            return mid

        if f_lo * f_mid <= 0:
            hi = mid
            f_hi = f_mid
        else:
            lo = mid
            f_lo = f_mid

    return (lo + hi) / 2


class RealReturnService:
    """Calculate the real return of a Pillar 3a investment.

    The real return includes:
    1. Compound growth (rendement_brut - frais - inflation)
    2. Tax savings (versement x taux_marginal each year)

    Comparison baseline: same annual amount placed in a regular savings
    account with no tax deduction.

    Sources:
        - LIFD art. 33 al. 1 let. e (deduction 3a)
        - OPP3 art. 1 (plafond 3a)
    """

    def calculate_real_return(
        self,
        versement_annuel: float,
        taux_marginal: float,
        rendement_brut: float,
        frais_gestion: float,
        duree_annees: int,
        inflation: float = 0.0,
    ) -> RealReturnResult:
        """Calculate the real return of a 3a investment.

        Concept: You invest pmtGross per year in 3a at rGross = rendement_brut - frais_gestion.
        Your actual cost is pmtNet = pmtGross × (1 − taux_marginal).
        rNet is the rate you'd need on pmtNet to reach the same capital:
            fv_annuity_due(pmtNet, rNet, n) = fv_annuity_due(pmtGross, rGross, n)

        Args:
            versement_annuel: Annual 3a contribution (CHF).
            taux_marginal: Marginal tax rate (0-1).
            rendement_brut: Gross annual return (0-1), e.g. 0.04 for 4%.
            frais_gestion: Annual management fees (0-1), e.g. 0.005 for 0.5%.
            duree_annees: Investment duration in years.
            inflation: Unused (kept for API compatibility). Not subtracted.

        Returns:
            RealReturnResult with full analysis and comparison.
        """
        # Validate inputs
        versement_annuel = max(0.0, min(float(PLAFOND_3A_INDEPENDANT), versement_annuel))
        taux_marginal = max(0.0, min(0.50, taux_marginal))
        rendement_brut = max(-0.99, min(0.15, rendement_brut))
        frais_gestion = max(0.0, min(0.05, frais_gestion))
        duree_annees = max(0, min(50, duree_annees))

        # rGross = effective investment rate (no inflation subtraction)
        r_gross = max(-0.99, rendement_brut - frais_gestion)

        # Capital final 3a = fv_annuity_due(pmtGross, rGross, n)
        capital_3a = round(fv_annuity_due(versement_annuel, r_gross, duree_annees), 2)

        # Total contributions
        total_verse = round(versement_annuel * duree_annees, 2)

        # Tax savings (cumulative, not compounded)
        total_economies = round(versement_annuel * taux_marginal * duree_annees, 2)

        # Real return: equivalent rate on net-of-tax investment
        # pmtNet = versement × (1 − taux_marginal)
        # Solve: fv_annuity_due(pmtNet, rNet, n) = capital_3a
        versement_net = versement_annuel * (1 - taux_marginal)
        rendement_reel = solve_rate_bisection(
            versement_net, capital_3a, duree_annees
        )

        # Comparison: savings account at 1.5%
        taux_epargne = TAUX_EPARGNE_DEFAUT
        capital_epargne = round(fv_annuity_due(versement_annuel, taux_epargne, duree_annees), 2)

        # Advantage
        avantage = round((capital_3a + total_economies) - capital_epargne, 2)

        # Chiffre choc: compare rNet vs rGross (sans avantage fiscal)
        reel_pct = round(rendement_reel * 100, 1)
        nominal_pct = round(r_gross * 100, 1)
        premier_eclairage = (
            f"Rendement reel de ton 3a : {reel_pct}% par an "
            f"(vs {nominal_pct}% sans avantage fiscal)"
        )

        # Sources
        sources = [
            "LIFD art. 33 al. 1 let. e (deduction fiscale 3a)",
            "OPP3 art. 1 (3e pilier lie — plafond annuel)",
            "OPP3 art. 3 (conditions de retrait)",
        ]

        return RealReturnResult(
            versement_annuel=versement_annuel,
            total_verse=total_verse,
            capital_final_3a=capital_3a,
            rendement_net_annuel=round(r_gross, 5),
            total_economies_fiscales=total_economies,
            rendement_reel_annualise=rendement_reel,
            rendement_brut=rendement_brut,
            frais_gestion=frais_gestion,
            inflation=0.0,
            capital_final_epargne=capital_epargne,
            rendement_epargne=taux_epargne,
            avantage_3a_vs_epargne=avantage,
            duree_annees=duree_annees,
            taux_marginal=taux_marginal,
            premier_eclairage=premier_eclairage,
            sources=sources,
            disclaimer=DISCLAIMER,
        )
