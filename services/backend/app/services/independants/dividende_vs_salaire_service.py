"""
Dividend vs Salary optimizer for SA/Sarl directors.

Compares the total tax and social security burden of distributing
company profit as salary vs dividends, or a mix of both.

Key trade-offs:
- Salary: subject to AVS/AI/APG/AC (~12.5% total), full income tax
- Dividend: partial taxation (50% at federal level for >= 10% participation),
  no AVS, but risk of requalification if salary is too low
- Impot anticipe 35% on dividends (refundable via tax return)

Sources:
    - LIFD art. 20 al. 1bis (imposition partielle des dividendes: 50% federal)
    - LIFD art. 17-18 (revenu d'activite lucrative)
    - LAVS art. 14 (cotisations patronales)
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
# Employee portion only (for salary tax base)
CHARGES_SOCIALES_EMPLOYE = 0.0625  # ~6.25%

# Dividend partial taxation at federal level for qualifying participation (>=10%)
TAUX_IMPOSITION_DIVIDENDE_FEDERAL = 0.50  # 50% of dividend is taxable

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
    "LIFD art. 20 al. 1bis (imposition partielle des dividendes: 50% federal)",
    "LIFD art. 17-18 (revenu d'activite lucrative dependante)",
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
    """Result of the dividend vs salary simulation."""
    charge_totale_salaire: float
    charge_totale_dividende: float
    charge_totale_tout_dividende: float
    split_optimal_indicatif: float
    economies: float
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
) -> float:
    """Calculate total fiscal and social charge for a given salary/dividend split.

    Args:
        benefice: Total available profit (CHF).
        part_salaire: Proportion allocated as salary (0-1).
        taux_marginal: Estimated marginal income tax rate (0-1).

    Returns:
        Total charge in CHF.
    """
    salaire = benefice * part_salaire
    dividende = benefice * (1 - part_salaire)

    # Salary charges: social contributions + income tax on full salary
    charges_sociales = salaire * CHARGES_SOCIALES_TOTALES
    impot_salaire = salaire * taux_marginal

    # Dividend charges: partial taxation (50% taxable at marginal rate), no AVS
    # Corporate tax is assumed already paid; this is the personal tax on distribution
    dividende_imposable = dividende * TAUX_IMPOSITION_DIVIDENDE_FEDERAL
    impot_dividende = dividende_imposable * taux_marginal

    return round(charges_sociales + impot_salaire + impot_dividende, 2)


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

    # Economies vs all-salary
    economies = round(charge_tout_salaire - best_charge, 2)

    # Requalification alert
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
        f"En optimisant le split salaire/dividende, tu peux potentiellement "
        f"reduire ta charge fiscale et sociale de {economies:,.0f} CHF/an "
        f"par rapport a un versement 100% salaire."
    )

    return DividendeVsSalaireResult(
        charge_totale_salaire=charge_tout_salaire,
        charge_totale_dividende=charge_split_propose,
        charge_totale_tout_dividende=charge_tout_dividende,
        split_optimal_indicatif=round(best_split, 2),
        economies=economies,
        alerte_requalification=alerte_requalification,
        graphe_data=graphe_data,
        premier_eclairage=premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )
