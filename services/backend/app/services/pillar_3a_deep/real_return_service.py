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
from typing import List


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil en prevoyance ni en placement au sens de la LSFin. "
    "Les rendements passes ne prejugent pas des rendements futurs. "
    "Consultez un ou une specialiste pour une analyse personnalisee."
)

# 3a annual contribution limits (2025/2026)
PLAFOND_3A_SALARIE = 7_258       # Salarie affilie LPP
PLAFOND_3A_INDEPENDANT = 36_288  # Independant sans LPP (20% du revenu net, max)

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
    chiffre_choc: str
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


def _future_value_annuity(pmt: float, r: float, n: int) -> float:
    """Future value of an annuity-due (payments at start of period).

    FV = pmt × ((1+r)^n − 1) / r × (1+r)
    """
    if abs(r) < 1e-10:
        return pmt * n
    factor = (1 + r) ** n - 1
    return pmt * (factor / r) * (1 + r)


def _solve_irr(pmt: float, target_fv: float, n: int) -> float:
    """Solve IRR via bisection.

    Find r such that annuity-due FV(pmt, r, n) = target_fv.
    """
    if pmt <= 0 or target_fv <= 0 or n <= 0:
        return 0.0
    if n == 1:
        return max(0.0, min(1.0, target_fv / pmt - 1))

    lo, hi = -0.05, 0.50
    for _ in range(60):
        mid = (lo + hi) / 2
        fv = _future_value_annuity(pmt, mid, n)
        if fv < target_fv:
            lo = mid
        else:
            hi = mid
    return max(-0.05, min(0.50, (lo + hi) / 2))


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
        inflation: float = 0.01,
    ) -> RealReturnResult:
        """Calculate the real return of a 3a investment.

        Args:
            versement_annuel: Annual 3a contribution (CHF).
            taux_marginal: Marginal tax rate (0-1).
            rendement_brut: Gross annual return (0-1), e.g. 0.04 for 4%.
            frais_gestion: Annual management fees (0-1), e.g. 0.005 for 0.5%.
            duree_annees: Investment duration in years.
            inflation: Annual inflation rate (0-1), default 1%.

        Returns:
            RealReturnResult with full analysis and comparison.
        """
        # Validate inputs
        versement_annuel = max(0.0, min(float(PLAFOND_3A_INDEPENDANT), versement_annuel))
        taux_marginal = max(0.0, min(0.50, taux_marginal))
        rendement_brut = max(-0.10, min(0.15, rendement_brut))
        frais_gestion = max(0.0, min(0.05, frais_gestion))
        duree_annees = max(1, min(50, duree_annees))
        inflation = max(0.0, min(0.10, inflation))

        # 1. Net annual return (after fees and inflation)
        rendement_net = rendement_brut - frais_gestion - inflation

        # 2. Compound 3a capital (annual contributions growing at net rate)
        capital_3a = 0.0
        for _ in range(duree_annees):
            capital_3a = (capital_3a + versement_annuel) * (1 + rendement_net)
        capital_3a = round(capital_3a, 2)

        # 3. Total contributions
        total_verse = round(versement_annuel * duree_annees, 2)

        # 4. Annual tax savings = versement * taux_marginal
        economie_fiscale_annuelle = round(versement_annuel * taux_marginal, 2)
        total_economies = round(economie_fiscale_annuelle * duree_annees, 2)

        # 5. Real return: IRR on out-of-pocket investment
        # You pay versement × (1 − taux_marginal) each year, but the full
        # versement grows inside the 3a. The "real return" is the rate you'd
        # need on your net investment to reach the same capital_3a.
        # Solved via bisection.
        versement_net = versement_annuel * (1 - taux_marginal)
        rendement_reel = _solve_irr(versement_net, capital_3a, duree_annees)
        rendement_reel = round(rendement_reel, 5)

        # 6. Comparison: same amount on savings account (no tax deduction)
        taux_epargne = TAUX_EPARGNE_DEFAUT
        capital_epargne = 0.0
        for _ in range(duree_annees):
            capital_epargne = (capital_epargne + versement_annuel) * (1 + taux_epargne - inflation)
        capital_epargne = round(capital_epargne, 2)

        # 7. Advantage
        avantage = round((capital_3a + total_economies) - capital_epargne, 2)

        # 8. Chiffre choc
        reel_pct = round(rendement_reel * 100, 1)
        epargne_pct = round((taux_epargne - inflation) * 100, 1)
        chiffre_choc = (
            f"Rendement reel de ton 3a : {reel_pct}% par an "
            f"(vs {epargne_pct}% sans avantage fiscal)"
        )

        # 9. Sources
        sources = [
            "LIFD art. 33 al. 1 let. e (deduction fiscale 3a)",
            "OPP3 art. 1 (3e pilier lie — plafond annuel)",
            "OPP3 art. 3 (conditions de retrait)",
        ]

        return RealReturnResult(
            versement_annuel=versement_annuel,
            total_verse=total_verse,
            capital_final_3a=capital_3a,
            rendement_net_annuel=round(rendement_net, 5),
            total_economies_fiscales=total_economies,
            rendement_reel_annualise=rendement_reel,
            rendement_brut=rendement_brut,
            frais_gestion=frais_gestion,
            inflation=inflation,
            capital_final_epargne=capital_epargne,
            rendement_epargne=taux_epargne,
            avantage_3a_vs_epargne=avantage,
            duree_annees=duree_annees,
            taux_marginal=taux_marginal,
            chiffre_choc=chiffre_choc,
            sources=sources,
            disclaimer=DISCLAIMER,
        )
