"""
AVS/AI/APG self-employed contributions calculator.

Calculates the full AVS/AI/APG contributions for self-employed workers
using the progressive rate scale (bareme degressif) defined in RAVS art. 21.

Self-employed persons pay the FULL contribution (no employer share).
Employees pay only half (~5.3%), their employer pays the other half.

Sources:
    - LAVS art. 8 (obligation de cotiser des independants)
    - LAVS art. 8 al. 2 (cotisation minimale: 530 CHF/an)
    - LAVS art. 9 (revenu determinant)
    - RAVS art. 21-23 (bareme degressif 2025/2026)

Sprint S18 — Module Independants complet.
"""

from dataclasses import dataclass, field
from typing import List


# ---------------------------------------------------------------------------
# Constants — RAVS art. 21, bareme 2025/2026
# ---------------------------------------------------------------------------

AVS_BAREME = [
    (0,       10_100,  0.05371),
    (10_100,  17_600,  0.05828),
    (17_600,  22_200,  0.06542),
    (22_200,  27_200,  0.07158),
    (27_200,  32_300,  0.07773),
    (32_300,  37_800,  0.08386),
    (37_800,  43_200,  0.09002),
    (43_200,  48_800,  0.09610),
    (48_800,  54_300,  0.10222),
    (54_300,  60_500,  0.10413),
    (60_500,  float('inf'), 0.10600),
]

COTISATION_MINIMALE = 530.0

# Employee share for comparison: half of the full 10.6% rate
TAUX_SALARIE = 0.053  # ~5.3%

DISCLAIMER = (
    "MINT est un outil educatif. Ce simulateur ne constitue pas un conseil "
    "en matiere de cotisations sociales au sens de la LSFin. Les cotisations "
    "exactes dependent de votre caisse de compensation. Consultez un ou une "
    "specialiste pour une analyse personnalisee."
)

SOURCES = [
    "LAVS art. 8 (obligation de cotiser des independants)",
    "LAVS art. 8 al. 2 (cotisation minimale: 530 CHF/an)",
    "LAVS art. 9 (revenu determinant)",
    "RAVS art. 21-23 (bareme degressif 2025/2026)",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class AvsCotisationResult:
    """Result of AVS contribution calculation for a self-employed person."""
    cotisation_avs_ai_apg: float
    taux_effectif: float
    comparaison_salarie: float
    difference_vs_salarie: float
    chiffre_choc: str
    disclaimer: str
    sources: List[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Pure functions
# ---------------------------------------------------------------------------

def _find_rate(revenu_net: float) -> float:
    """Find the applicable AVS rate for the given net income.

    Uses the RAVS art. 21 progressive scale. Each bracket applies
    a single rate to the entire income (not marginal/stacked).
    """
    for lower, upper, rate in AVS_BAREME:
        if lower <= revenu_net < upper:
            return rate
    # Fallback (should not happen with float('inf'))
    return AVS_BAREME[-1][2]


def calculer_cotisation_avs(revenu_net_activite: float) -> AvsCotisationResult:
    """Calculate AVS/AI/APG contributions for a self-employed person.

    Args:
        revenu_net_activite: Annual net self-employment income (CHF).

    Returns:
        AvsCotisationResult with contribution details and comparison.
    """
    if revenu_net_activite <= 0:
        return AvsCotisationResult(
            cotisation_avs_ai_apg=0.0,
            taux_effectif=0.0,
            comparaison_salarie=0.0,
            difference_vs_salarie=0.0,
            chiffre_choc=(
                "Avec un revenu nul ou negatif, aucune cotisation AVS n'est due."
            ),
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    taux = _find_rate(revenu_net_activite)
    cotisation_brute = round(revenu_net_activite * taux, 2)
    cotisation = max(cotisation_brute, COTISATION_MINIMALE)
    taux_effectif = round(cotisation / revenu_net_activite, 5) if revenu_net_activite > 0 else 0.0

    # Comparison: what an employee would pay on same gross income
    # Employee pays only half the full 10.6% rate
    cotisation_salarie = round(revenu_net_activite * TAUX_SALARIE, 2)
    difference = round(cotisation - cotisation_salarie, 2)

    chiffre_choc = (
        f"En tant qu'independant-e, tu paies {cotisation:,.0f} CHF/an de cotisations "
        f"AVS/AI/APG, soit {difference:+,.0f} CHF de plus qu'un-e salarie-e "
        f"sur le meme revenu."
    )

    return AvsCotisationResult(
        cotisation_avs_ai_apg=cotisation,
        taux_effectif=taux_effectif,
        comparaison_salarie=cotisation_salarie,
        difference_vs_salarie=difference,
        chiffre_choc=chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )
