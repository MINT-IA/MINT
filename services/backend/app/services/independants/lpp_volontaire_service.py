"""
Voluntary LPP (2e pilier) simulator for self-employed workers.

Self-employed persons can voluntarily join a LPP pension fund via their
professional association or a collective foundation. Unlike employees,
they pay the FULL contribution (employer + employee share).

Sources:
    - LPP art. 4 (seuil d'acces au 2e pilier)
    - LPP art. 44 (affiliation facultative des independants)
    - LPP art. 46 (conditions d'affiliation facultative)
    - LPP art. 16 (bonifications de vieillesse par tranche d'age)
    - LPP art. 8 (salaire coordonne)
    - LIFD art. 33 al. 1 let. d (deduction fiscale des cotisations LPP)

Sprint S18 — Module Independants complet.
"""

from dataclasses import dataclass, field
from typing import List, Tuple

from app.constants.social_insurance import (
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MIN,
    LPP_SALAIRE_COORDONNE_MAX,
    LPP_BONIFICATIONS_VIEILLESSE,
    LPP_TAUX_INTERET_MIN,
    AVS_AGE_REFERENCE_HOMME,
    get_lpp_bonification_rate,
)


# ---------------------------------------------------------------------------
# Constants — from app.constants.social_insurance (centralized source of truth)
# ---------------------------------------------------------------------------

# Coordination deduction (LPP art. 8)
DEDUCTION_COORDINATION = LPP_DEDUCTION_COORDINATION
# Minimum coordinated salary
SALAIRE_COORDONNE_MINIMUM = LPP_SALAIRE_COORDONNE_MIN
# Maximum insured salary (LPP art. 8)
SALAIRE_COORDONNE_MAXIMUM = LPP_SALAIRE_COORDONNE_MAX

# Age-based contribution rates (LPP art. 16)
# These are the TOTAL rates (employer + employee), all paid by the self-employed
BONIFICATIONS_VIEILLESSE: List[Tuple[int, int, float]] = list(LPP_BONIFICATIONS_VIEILLESSE)

# Retirement age
AGE_RETRAITE = AVS_AGE_REFERENCE_HOMME
# LPP minimum interest rate (centralized value is in %, convert to fraction)
TAUX_INTERET_LPP = LPP_TAUX_INTERET_MIN / 100  # 1.25% -> 0.0125

DISCLAIMER = (
    "MINT est un outil educatif. Ce simulateur ne constitue pas un conseil "
    "en prevoyance au sens de la LSFin. Les cotisations et prestations LPP "
    "effectives dependent du reglement de la caisse de pension choisie. "
    "Consultez un ou une specialiste en prevoyance professionnelle pour "
    "une analyse personnalisee."
)

SOURCES = [
    "LPP art. 4 (seuil d'acces au 2e pilier)",
    "LPP art. 44 (affiliation facultative des independants)",
    "LPP art. 16 (bonifications de vieillesse par tranche d'age)",
    "LPP art. 8 (salaire coordonne: deduction 26'460, min 3'780)",
    "LIFD art. 33 al. 1 let. d (deduction fiscale des cotisations LPP)",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class LppVolontaireResult:
    """Result of voluntary LPP simulation for a self-employed person."""
    salaire_coordonne: float
    cotisation_annuelle: float
    economie_fiscale: float
    comparaison_sans_lpp: float
    taux_bonification: float
    premier_eclairage: str
    disclaimer: str
    sources: List[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Pure functions
# ---------------------------------------------------------------------------

def _get_bonification_rate(age: int) -> float:
    """Get the LPP contribution rate for the given age.

    Returns 0 if the age is outside the insured range (25-65).
    """
    return get_lpp_bonification_rate(age)


def _calculer_salaire_coordonne(revenu_net: float) -> float:
    """Calculate the coordinated salary (salaire coordonne).

    LPP art. 8: revenu - deduction de coordination, with minimum and maximum.
    """
    if revenu_net <= DEDUCTION_COORDINATION:
        return SALAIRE_COORDONNE_MINIMUM

    coordonne = revenu_net - DEDUCTION_COORDINATION
    coordonne = max(coordonne, SALAIRE_COORDONNE_MINIMUM)
    coordonne = min(coordonne, SALAIRE_COORDONNE_MAXIMUM)
    return round(coordonne, 2)


def _estimer_capital_perdu_sans_lpp(
    revenu_net: float,
    age: int,
) -> float:
    """Estimate the annual retirement capital lost by not having LPP.

    Simplified: cotisation * (1 + taux_interet)^(years_to_retirement) / years_to_retirement
    This gives the annualized capital accumulation missed per year of non-affiliation.
    """
    if age >= AGE_RETRAITE or age < 25:
        return 0.0

    salaire_coordonne = _calculer_salaire_coordonne(revenu_net)
    taux = _get_bonification_rate(age)
    cotisation_annuelle = salaire_coordonne * taux
    annees_restantes = AGE_RETRAITE - age

    # Simple compound estimate: what this year's contribution would grow to
    capital_futur = cotisation_annuelle * ((1 + TAUX_INTERET_LPP) ** annees_restantes)
    return round(capital_futur, 2)


def simuler_lpp_volontaire(
    revenu_net: float,
    age: int,
    taux_marginal: float,
) -> LppVolontaireResult:
    """Simulate voluntary LPP affiliation for a self-employed person.

    Args:
        revenu_net: Annual net self-employment income (CHF).
        age: Age of the person.
        taux_marginal: Estimated marginal tax rate (0-1).

    Returns:
        LppVolontaireResult with contributions, tax savings, and comparison.
    """
    taux = max(0.0, min(1.0, taux_marginal))

    if revenu_net <= 0 or age < 25 or age > AGE_RETRAITE:
        return LppVolontaireResult(
            salaire_coordonne=0.0,
            cotisation_annuelle=0.0,
            economie_fiscale=0.0,
            comparaison_sans_lpp=0.0,
            taux_bonification=0.0,
            premier_eclairage=(
                "Avec un revenu nul ou un age hors de la tranche LPP (25-65), "
                "l'affiliation volontaire n'est pas applicable."
            ),
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    salaire_coordonne = _calculer_salaire_coordonne(revenu_net)
    taux_bonification = _get_bonification_rate(age)
    cotisation_annuelle = round(salaire_coordonne * taux_bonification, 2)

    # Tax savings: full contribution is deductible
    economie_fiscale = round(cotisation_annuelle * taux, 2)

    # Comparison: annual retirement capital lost without LPP
    comparaison_sans_lpp = _estimer_capital_perdu_sans_lpp(revenu_net, age)

    premier_eclairage = (
        f"Sans LPP volontaire, tu perds {comparaison_sans_lpp:,.0f} CHF/an "
        f"de capitalisation retraite (cotisation + interets cumules)."
    )

    return LppVolontaireResult(
        salaire_coordonne=salaire_coordonne,
        cotisation_annuelle=cotisation_annuelle,
        economie_fiscale=economie_fiscale,
        comparaison_sans_lpp=comparaison_sans_lpp,
        taux_bonification=taux_bonification,
        premier_eclairage=premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )
