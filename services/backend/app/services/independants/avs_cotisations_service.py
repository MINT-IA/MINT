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

from app.constants.social_insurance import (
    AVS_BAREME_INDEPENDANT,
    AVS_COTISATION_MIN_INDEPENDANT,
    AVS_COTISATION_SALARIE,
    AVS_SEUIL_REVENU_MIN_INDEPENDANT,
)

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
    premier_eclairage: str
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
    for lower, upper, rate in AVS_BAREME_INDEPENDANT:
        if lower <= revenu_net < upper:
            return rate
    # Fallback (should not happen with float('inf'))
    return AVS_BAREME_INDEPENDANT[-1][2]


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
            premier_eclairage=(
                "Avec un revenu nul ou negatif, aucune cotisation AVS n'est due."
            ),
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    # Sous le seuil (CHF 10'100), la loi prévoit une cotisation minimale FIXE
    # (LAVS art. 8 al. 2) — pas un taux appliqué au revenu. Le barème RAVS
    # art. 21 ne commence qu'à 10'100 (audit T02-F17, MINT_nosync-iy5).
    if revenu_net_activite < AVS_SEUIL_REVENU_MIN_INDEPENDANT:
        cotisation = AVS_COTISATION_MIN_INDEPENDANT
    else:
        taux = _find_rate(revenu_net_activite)
        cotisation_brute = round(revenu_net_activite * taux, 2)
        cotisation = max(cotisation_brute, AVS_COTISATION_MIN_INDEPENDANT)
    taux_effectif = round(cotisation / revenu_net_activite, 5) if revenu_net_activite > 0 else 0.0

    # Comparison: what an employee would pay on same gross income
    # Employee pays only half the full 10.6% rate
    cotisation_salarie = round(revenu_net_activite * AVS_COTISATION_SALARIE, 2)
    difference = round(cotisation - cotisation_salarie, 2)

    # Sur le sliver 10'000-10'100 (cotisation minimale fixe), la difference
    # peut etre negative — "-3 CHF de plus" serait absurde (review Codex
    # MINT_nosync-iy5). La copy suit le signe.
    if difference >= 0:
        comparaison = (
            f"soit {difference:+,.0f} CHF de plus qu'un-e salarie-e "
            f"sur le meme revenu."
        )
    else:
        comparaison = (
            f"soit {abs(difference):,.0f} CHF de moins qu'un-e salarie-e "
            f"sur le meme revenu."
        )
    premier_eclairage = (
        f"En tant qu'independant-e, tu paies {cotisation:,.0f} CHF/an de cotisations "
        f"AVS/AI/APG, {comparaison}"
    )

    return AvsCotisationResult(
        cotisation_avs_ai_apg=cotisation,
        taux_effectif=taux_effectif,
        comparaison_salarie=cotisation_salarie,
        difference_vs_salarie=difference,
        premier_eclairage=premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )
