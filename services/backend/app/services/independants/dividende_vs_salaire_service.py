"""
Dividend vs Salary optimizer for SA/Sarl directors.

Compares the total tax and social security burden of distributing the SAME
pre-tax company profit pot as salary vs dividends, or a mix of both.

Both routes are compared on the same PRE-CORPORATE-TAX profit pot `B`:
- Salary route: the pot funds gross salary + employer charges (gross salary =
  pot / (1 + employer_share)); salary is fully deductible, so no corporate
  profit tax remains on that portion. Subject to AVS/AI/APG/AC (~12.5% total)
  and full income tax on the gross salary.
- Dividend route: the retained profit is NOT deductible. It is taxed at the
  effective combined corporate profit tax rate FIRST, and only the after-tax
  amount is distributed as a dividend, taxed partially at the shareholder level
  (economic double taxation). No AVS. Requalification risk if salary is too low.

The corporate profit tax was previously OMITTED, which systematically
over-stated the dividend advantage; it is now modelled explicitly.

Known simplifications (disclosed in the disclaimer, not silent):
- A single representative corporate profit tax rate (Swiss average, KPMG 2025)
  is used, not a per-canton table.
- The dividend partial-inclusion rate is a single simplified assumption applied
  to the combined marginal rate; the true federal-70% / cantonal->=50% split
  depends on the canton (the D10 band spans that legal 50-70% range).
- The charge treats social contributions as pure cost; it does not value the
  AVS/LPP entitlements the salary route builds.

Sources:
    - LIFD art. 20 al. 1bis (imposition partielle des dividendes: 70% federal,
      RFFA en vigueur 1.1.2020)
    - LHID art. 7 al. 1 (imposition partielle cantonale: minimum 50%)
    - LIFD art. 58 / LHID art. 24 (salaire excessif requalifiable en
      distribution dissimulee de benefice)
    - KPMG Clarity on Swiss Taxes 2025 (taux d'impot sur le benefice effectifs
      combines: moyenne suisse 14.4%, Zoug 11.85%, Berne 20.54%)
    - LAVS art. 14 (cotisations patronales et salariales)
    - Pratique cantonale (requalification de dividendes en salaire)

Sprint S18 — Module Independants complet.
"""

from dataclasses import dataclass, field
from typing import List


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Total employer + employee AVS/AI/APG/AC charges (approximate)
CHARGES_SOCIALES_TOTALES = 0.125  # ~12.5% combined
# Employer portion only — used to bring the salary branch back to the same
# pre-tax pot: gross salary + employer charges = pot, so gross = pot / (1 + this)
CHARGES_SOCIALES_EMPLOYEUR = 0.0625  # ~6.25%

# ── Corporate profit tax (impot sur le benefice) ────────────────────────────
# Effective COMBINED rates on PRE-TAX profit (federal 8.5% on after-tax profit
# = 7.83% effective is already folded in). Source: KPMG Clarity on Swiss Taxes
# 2025. A single representative rate is used deliberately (a per-canton table is
# forbidden by tools/checks/no_cantonal_rate_table.py and unsourceable per
# commune); the cantonal spread feeds the D10 uncertainty band only.
TAUX_IMPOT_BENEFICE_EFFECTIF = 0.144  # Swiss average (KPMG 2025)
TAUX_IMPOT_BENEFICE_MIN = 0.1185  # Zoug (lowest, optimistic band bound)
TAUX_IMPOT_BENEFICE_MAX = 0.2054  # Berne (highest, conservative band bound)

# ── Dividend partial taxation (imposition partielle) ────────────────────────
# The dividend received (after corporate tax) is only partially included in the
# shareholder's taxable income. Two legal stages:
#   - federal: 70% fixed (LIFD art. 20 al. 1bis, RFFA since 1.1.2020)
#   - cantonal: >= 50% (LHID art. 7 al. 1), varies 50-70% by canton
# Point estimate: a single SIMPLIFIED 60% inclusion applied to the combined
# marginal rate (NOT a statistical average — the true federal/cantonal weighting
# is canton-dependent). The band spans the legal 50% (cantonal minimum) to 70%
# (federal) range.
TAUX_IMPOSITION_DIVIDENDE_PARTIELLE = 0.60  # point (hypothese simplifiee)
TAUX_IMPOSITION_DIVIDENDE_CANTONAL_MIN = 0.50  # optimistic bound (LHID minimum)
TAUX_IMPOSITION_DIVIDENDE_FEDERAL = 0.70  # conservative bound (LIFD federal)

# Requalification risk threshold: if salary < this % of total, alert
SEUIL_REQUALIFICATION = 0.60  # 60%

# Minimum "reasonable" salary (practice, not hard law)
SALAIRE_MINIMUM_RAISONNABLE = 60_000.0

DISCLAIMER = (
    "MINT est un outil educatif. Ce simulateur ne constitue pas un conseil "
    "fiscal ou juridique au sens de la LSFin. L'optimisation fiscale via "
    "le split salaire/dividende depend de la pratique cantonale et ne peut "
    "pas etre consideree comme acquise dans tous les cas. Le risque de "
    "requalification fiscale existe. Consultez un ou une specialiste en "
    "fiscalite et droit des societes pour une analyse personnalisee."
)

SOURCES = [
    "LIFD art. 20 al. 1bis (imposition partielle des dividendes: 70% federal, "
    "RFFA en vigueur 1.1.2020)",
    "LHID art. 7 al. 1 (imposition partielle cantonale: minimum 50%)",
    "LIFD art. 58 / LHID art. 24 (salaire excessif requalifiable en "
    "distribution dissimulee de benefice)",
    "KPMG Clarity on Swiss Taxes 2025 (impot sur le benefice effectif combine: "
    "moyenne suisse 14.4%, Zoug 11.85%, Berne 20.54%)",
    "LAVS art. 14 (cotisations patronales et salariales)",
    "Pratique cantonale en matiere de requalification de dividendes",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class GrapheDataPoint:
    """A single data point for the sensitivity curve."""
    split_salaire: float       # Salary proportion (0-1)
    charge_totale: float       # Total tax + social charges (CHF)


@dataclass
class DividendeVsSalaireResult:
    """Result of the dividend vs salary simulation.

    `economies` is the point estimate (representative corporate tax + 60%
    simplified dividend inclusion). `economies_optimiste` and
    `economies_conservatrice` are the D10 uncertainty band bounds:
    - optimiste: lowest corporate tax (Zoug) + cantonal-minimum inclusion (50%)
    - conservatrice: highest corporate tax (Berne) + federal inclusion (70%)
    """
    charge_totale_salaire: float
    charge_totale_dividende: float
    charge_totale_tout_dividende: float
    split_optimal_indicatif: float
    economies: float
    economies_optimiste: float
    economies_conservatrice: float
    alerte_requalification: bool
    graphe_data: List[GrapheDataPoint] = field(default_factory=list)
    premier_eclairage: str = ""
    disclaimer: str = DISCLAIMER
    sources: List[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Pure functions
# ---------------------------------------------------------------------------

def _calculer_charge_split(
    benefice: float,
    part_salaire: float,
    taux_marginal: float,
    taux_impot_benefice: float = TAUX_IMPOT_BENEFICE_EFFECTIF,
    part_imposable_dividende: float = TAUX_IMPOSITION_DIVIDENDE_PARTIELLE,
) -> float:
    """Total fiscal + social charge for a salary/dividend split on ONE pre-tax pot.

    Both branches consume the same pre-tax profit pot `benefice`:
    - Salary branch: the pot funds gross salary + employer charges, so
      gross_salary = pot / (1 + employer_share). Charge = employer + employee
      social charges + income tax on the gross salary (salary is deductible, so
      no corporate profit tax remains on that portion).
    - Dividend branch: the retained profit is taxed at the corporate profit tax
      rate first, then only the after-tax amount is distributed and partially
      taxed at the shareholder level (economic double taxation).

    Args:
        benefice: Pre-tax profit pot (CHF).
        part_salaire: Proportion routed as salary (0-1).
        taux_marginal: Estimated personal marginal income tax rate (0-1).
        taux_impot_benefice: Effective combined corporate profit tax rate.
        part_imposable_dividende: Taxable share of the distributed dividend.

    Returns:
        Total charge in CHF (the part of the pot that does NOT reach the owner).
    """
    pot_salaire = benefice * part_salaire
    profit_residuel = benefice * (1 - part_salaire)

    # Salary branch — same-pot normalization (Codex ruling 2026-07-31 D2):
    # gross salary + employer charges = pot, so charge = pot * (total social +
    # income tax) / (1 + employer share).
    charge_salaire = (
        pot_salaire
        * (CHARGES_SOCIALES_TOTALES + taux_marginal)
        / (1 + CHARGES_SOCIALES_EMPLOYEUR)
    )

    # Dividend branch — corporate profit tax FIRST, then partial personal tax on
    # the net distributed dividend.
    impot_benefice = profit_residuel * taux_impot_benefice
    dividende_net = profit_residuel * (1 - taux_impot_benefice)
    impot_dividende = dividende_net * part_imposable_dividende * taux_marginal

    return round(charge_salaire + impot_benefice + impot_dividende, 2)


def _economie_optimale(
    benefice: float,
    taux_marginal: float,
    taux_impot_benefice: float,
    part_imposable_dividende: float,
) -> float:
    """Theoretical gap between the all-salary scenario and the cheapest split.

    NOT a realizable or recommended optimum: the charge is affine in the split,
    so the theoretical minimum sits at a boundary. The real arbitrage is bounded
    by the requalification risk, surfaced separately.
    """
    charge_tout_salaire = _calculer_charge_split(
        benefice, 1.0, taux_marginal,
        taux_impot_benefice, part_imposable_dividende,
    )
    best = min(
        _calculer_charge_split(
            benefice, pct / 100.0, taux_marginal,
            taux_impot_benefice, part_imposable_dividende,
        )
        for pct in range(0, 101)
    )
    return round(charge_tout_salaire - best, 2)


def simuler_dividende_vs_salaire(
    benefice_disponible: float,
    part_salaire: float,
    taux_marginal: float,
    canton: str = "ZH",
) -> DividendeVsSalaireResult:
    """Simulate dividend vs salary split optimization.

    Args:
        benefice_disponible: Total available profit to distribute (CHF).
        part_salaire: Proposed salary proportion (0-1).
        taux_marginal: Estimated marginal income tax rate (0-1).
        canton: Canton code (informational).

    Returns:
        DividendeVsSalaireResult with charges, optimal split, and alerts.
    """
    taux = max(0.0, min(1.0, taux_marginal))
    part = max(0.0, min(1.0, part_salaire))

    if benefice_disponible <= 0:
        return DividendeVsSalaireResult(
            charge_totale_salaire=0.0,
            charge_totale_dividende=0.0,
            charge_totale_tout_dividende=0.0,
            split_optimal_indicatif=0.0,
            economies=0.0,
            economies_optimiste=0.0,
            economies_conservatrice=0.0,
            alerte_requalification=False,
            graphe_data=[],
            premier_eclairage="Avec un benefice nul, aucune optimisation n'est possible.",
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    # Scenario 1: 100% salary
    charge_tout_salaire = _calculer_charge_split(benefice_disponible, 1.0, taux)

    # Scenario 2: proposed split
    charge_split_propose = _calculer_charge_split(benefice_disponible, part, taux)

    # Scenario 3: 100% dividend (theoretical, high requalification risk)
    charge_tout_dividende = _calculer_charge_split(benefice_disponible, 0.0, taux)

    # Find indicative optimal split (brute-force over 1% steps)
    best_split = 0.0
    best_charge = float('inf')
    for pct in range(0, 101):
        s = pct / 100.0
        c = _calculer_charge_split(benefice_disponible, s, taux)
        if c < best_charge:
            best_charge = c
            best_split = s

    # Economies vs all-salary (point estimate).
    economies = round(charge_tout_salaire - best_charge, 2)

    # D10 uncertainty band — the corporate tax rate and the dividend inclusion
    # rate are canton-dependent. Optimistic bound: lowest corporate tax (Zoug) +
    # cantonal-minimum inclusion (50%). Conservative bound: highest corporate tax
    # (Berne) + federal inclusion (70%).
    economies_optimiste = _economie_optimale(
        benefice_disponible, taux,
        TAUX_IMPOT_BENEFICE_MIN, TAUX_IMPOSITION_DIVIDENDE_CANTONAL_MIN,
    )
    economies_conservatrice = _economie_optimale(
        benefice_disponible, taux,
        TAUX_IMPOT_BENEFICE_MAX, TAUX_IMPOSITION_DIVIDENDE_FEDERAL,
    )

    # Requalification alert. `salaire_propose` uses the pot portion as a
    # practice proxy for the "reasonable salary" the authorities expect (a rough
    # heuristic, not a precise legal computation).
    salaire_propose = benefice_disponible * part
    alerte_requalification = (
        part < SEUIL_REQUALIFICATION
        or salaire_propose < SALAIRE_MINIMUM_RAISONNABLE
    )

    # Sensitivity curve (10% steps)
    graphe_data = []
    for pct in range(0, 101, 10):
        s = pct / 100.0
        c = _calculer_charge_split(benefice_disponible, s, taux)
        graphe_data.append(GrapheDataPoint(split_salaire=s, charge_totale=c))

    premier_eclairage = (
        f"En comparant un versement 100% salaire a une distribution en "
        f"dividende (impot sur le benefice inclus), l'ecart de charge fiscale "
        f"et sociale pourrait atteindre entre {economies_conservatrice:,.0f} et "
        f"{economies_optimiste:,.0f} CHF/an selon le canton et la part imposable "
        f"retenue. Estimation centrale: {economies:,.0f} CHF/an."
    )

    return DividendeVsSalaireResult(
        charge_totale_salaire=charge_tout_salaire,
        charge_totale_dividende=charge_split_propose,
        charge_totale_tout_dividende=charge_tout_dividende,
        split_optimal_indicatif=round(best_split, 2),
        economies=economies,
        economies_optimiste=economies_optimiste,
        economies_conservatrice=economies_conservatrice,
        alerte_requalification=alerte_requalification,
        graphe_data=graphe_data,
        premier_eclairage=premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )
