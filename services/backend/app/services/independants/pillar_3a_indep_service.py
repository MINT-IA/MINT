"""
Enhanced 3a (pilier 3a) calculator for self-employed workers.

Self-employed persons WITHOUT LPP (2e pilier) benefit from a dramatically
higher 3a contribution limit: 20% of net income, up to 36'288 CHF/year
(the "grand 3a"), compared to 7'258 CHF for employees or self-employed
WITH LPP.

Sources:
    - OPP3 art. 7 al. 1 (grand 3a: 20% du revenu net, max 36'288 CHF)
    - LPP art. 4 (seuil d'acces au 2e pilier)
    - LIFD art. 33 al. 1 let. e (deduction fiscale du 3a)

Sprint S18 — Module Independants complet.
"""

from dataclasses import dataclass, field
from typing import List

from app.constants.social_insurance import (
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
    PILIER_3A_TAUX_REVENU_SANS_LPP,
)


# ---------------------------------------------------------------------------
# Constants — 2025/2026 limits (imported from social_insurance)
# ---------------------------------------------------------------------------

PLAFOND_3A_AVEC_LPP = PILIER_3A_PLAFOND_AVEC_LPP
PLAFOND_3A_SANS_LPP_MAX = PILIER_3A_PLAFOND_SANS_LPP
TAUX_GRAND_3A = PILIER_3A_TAUX_REVENU_SANS_LPP

DISCLAIMER = (
    "MINT est un outil educatif. Ce simulateur ne constitue pas un conseil "
    "fiscal ou en prevoyance au sens de la LSFin. Les economies fiscales "
    "dependent de votre situation personnelle et de la legislation cantonale. "
    "Consultez un ou une specialiste en fiscalite pour une analyse personnalisee."
)

SOURCES = [
    "OPP3 art. 7 al. 1 (grand 3a: 20% du revenu net, max 36'288 CHF)",
    "LPP art. 4 (seuil d'acces au 2e pilier)",
    "LIFD art. 33 al. 1 let. e (deduction fiscale du 3e pilier a)",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class Pillar3aIndepResult:
    """Result of 3a calculation for a self-employed person."""
    plafond_applicable: float
    economie_fiscale: float
    comparaison_salarie: float
    avantage_independant: float
    chiffre_choc: str
    disclaimer: str
    sources: List[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Pure functions
# ---------------------------------------------------------------------------

def calculer_3a_independant(
    revenu_net: float,
    affilie_lpp: bool,
    taux_marginal_imposition: float,
    canton: str = "ZH",
) -> Pillar3aIndepResult:
    """Calculate the 3a contribution limit and tax savings for a self-employed person.

    Args:
        revenu_net: Annual net self-employment income (CHF).
        affilie_lpp: Whether the person is affiliated to a voluntary LPP.
        taux_marginal_imposition: Estimated marginal tax rate (0-1).
        canton: Canton code (informational, not used for calculation).

    Returns:
        Pillar3aIndepResult with limits, savings, and comparison.
    """
    taux = max(0.0, min(1.0, taux_marginal_imposition))

    if revenu_net <= 0:
        return Pillar3aIndepResult(
            plafond_applicable=0.0,
            economie_fiscale=0.0,
            comparaison_salarie=0.0,
            avantage_independant=0.0,
            chiffre_choc=(
                "Avec un revenu nul, aucune cotisation 3a n'est possible."
            ),
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    # Calculate applicable limit
    if affilie_lpp:
        plafond = PLAFOND_3A_AVEC_LPP
    else:
        plafond_20_pct = revenu_net * TAUX_GRAND_3A
        plafond = min(plafond_20_pct, PLAFOND_3A_SANS_LPP_MAX)

    plafond = round(plafond, 2)

    # Tax savings
    economie_fiscale = round(plafond * taux, 2)

    # Comparison with employee (always uses small limit)
    comparaison_salarie = round(PLAFOND_3A_AVEC_LPP * taux, 2)

    # Advantage of being self-employed without LPP
    avantage = round(economie_fiscale - comparaison_salarie, 2)

    if affilie_lpp:
        chiffre_choc = (
            f"Avec une affiliation LPP, ton plafond 3a est de "
            f"{plafond:,.0f} CHF/an, identique a celui d'un-e salarie-e."
        )
    else:
        chiffre_choc = (
            f"En tant qu'independant-e sans LPP, tu economises "
            f"{avantage:,.0f} CHF/an d'impots en plus qu'un-e salarie-e "
            f"grace au grand 3a ({plafond:,.0f} CHF/an)."
        )

    return Pillar3aIndepResult(
        plafond_applicable=plafond,
        economie_fiscale=economie_fiscale,
        comparaison_salarie=comparaison_salarie,
        avantage_independant=avantage,
        chiffre_choc=chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )
