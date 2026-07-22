"""
Retroactive 3a catch-up calculator (réforme OPP3 art. 7a, en vigueur 2025-01-01).

Depuis le 01.01.2025, on peut combler rétroactivement les lacunes de cotisation
au pilier 3a, mais uniquement pour les années >= 2025 (les lacunes antérieures
sont définitivement perdues), dans une fenêtre de 10 ans. Le premier rachat est
possible en 2026 (pour l'année 2025). Le montant du rachat rétroactif payable au
cours d'UNE année civile est plafonné au « petit » maximum 3a (CHF 7'258 en
2025/2026), identique que l'on soit affilié LPP ou indépendant sans LPP
(asymétrie documentée de la réforme). Le rachat suppose un revenu soumis AVS
l'année de la lacune et que le maximum 3a ordinaire de l'année courante soit déjà
versé.

Sources:
    - OPP3 art. 7a (en vigueur 2025-01-01) — rachat rétroactif
    - LIFD art. 33 al. 1 let. e — déductibilité fiscale des cotisations 3a
    - BSV/OFAS, publications annuelles — plafonds 3a historiques

Sprint S52 — 3a Retroactif. Doctrine corrigée : MINT_nosync-cli (audit 2026-07).
Avant correction, le service sommait 10 plafonds 2016-2025 (~68'863 CHF pour un
profil 10 ans), sur-estimant d'un facteur ~9.5.
"""

from dataclasses import dataclass, field
from typing import List, Optional

from app.constants.social_insurance import (
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
)

# ── Plafonds « petit » 3a (CHF) par année ───────────────────────────
# Source: BSV/OFAS, publications annuelles.
HISTORICAL_3A_LIMITS: dict[int, float] = {
    2026: 7_258.0,
    2025: 7_258.0,
    2024: 7_056.0,
    2023: 6_883.0,
    2022: 6_826.0,
    2021: 6_826.0,
    2020: 6_826.0,
    2019: 6_826.0,
    2018: 6_826.0,
    2017: 6_768.0,
    2016: 6_768.0,
}

MAX_RETROACTIVE_YEARS = 10
# Réforme OPP3 art. 7a : seules les lacunes >= 2025 sont rachetables.
RETRO_3A_FIRST_ELIGIBLE_GAP_YEAR = 2025

DISCLAIMER = (
    "Outil éducatif — ne constitue pas un conseil fiscal (LSFin). "
    "Le rachat 3a rétroactif (OPP3 art. 7a, en vigueur depuis 2025) comble "
    "les lacunes dès 2025, plafonné au petit maximum 3a par année "
    "civile. L'économie fiscale dépend de ton taux marginal réel."
)

SOURCES = [
    "OPP3 art. 7a (en vigueur 2025-01-01)",
    "LIFD art. 33 al. 1 let. e",
    "Plafonds annuels BSV/OFAS",
]


@dataclass(frozen=True)
class YearlyRetroactiveEntry:
    """One year in the retroactive catch-up plan."""
    year: int
    limit: float
    deductible: bool = True


@dataclass(frozen=True)
class Retroactive3aResult:
    """Full retroactive 3a simulation result."""
    gap_years: int
    total_retroactive: float
    total_current_year: float
    total_contribution: float
    economies_fiscales: float
    breakdown: List[YearlyRetroactiveEntry]
    premier_eclairage: str
    disclaimer: str = DISCLAIMER
    sources: List[str] = field(default_factory=lambda: list(SOURCES))


def _petit_max_for_year(year: int) -> float:
    """Petit plafond 3a (avec LPP) de l'année — plafond légal du rachat
    rétroactif payable en une année civile, identique avec ou sans LPP."""
    return HISTORICAL_3A_LIMITS.get(year, PILIER_3A_PLAFOND_AVEC_LPP)


def calculate_retroactive_3a(
    gap_years: int,
    taux_marginal: float,
    has_lpp: bool = True,
    revenu_net_annuel: Optional[float] = None,
    reference_year: int = 2026,
) -> Retroactive3aResult:
    """Calculate retroactive 3a catch-up contribution impact.

    Doctrine (OPP3 art. 7a) : seules les lacunes >= 2025 sont rachetables, dans
    une fenêtre de 10 ans ; le total rétroactif payable en ``reference_year`` est
    plafonné à un « petit » maximum 3a, avec ou sans LPP.

    Args:
        gap_years: Nombre d'années de lacune demandées (borné aux années éligibles).
        taux_marginal: Taux marginal (0.0-1.0), clampé à 0.60.
        has_lpp: Affiliation LPP — n'affecte QUE la cotisation courante, pas le rachat.
        revenu_net_annuel: Utilisé seulement sans LPP (cap 20% sur l'année courante).
        reference_year: Année du rachat (défaut 2026).

    Returns:
        Retroactive3aResult avec le breakdown et le premier éclairage.
    """
    effective_taux = max(0.0, min(taux_marginal, 0.60))

    # ── Cotisation ordinaire de l'année courante (séparée du rachat) ──
    if has_lpp:
        current_year_limit = PILIER_3A_PLAFOND_AVEC_LPP
    elif revenu_net_annuel is not None:
        current_year_limit = min(
            max(0.0, revenu_net_annuel * 0.20),
            PILIER_3A_PLAFOND_SANS_LPP,
        )
    else:
        current_year_limit = PILIER_3A_PLAFOND_SANS_LPP

    # ── Années de lacune ÉLIGIBLES pour un rachat effectué en reference_year ──
    # Seulement >= 2025 (réforme) et dans la fenêtre de 10 ans.
    earliest = max(
        RETRO_3A_FIRST_ELIGIBLE_GAP_YEAR, reference_year - MAX_RETROACTIVE_YEARS
    )
    requested = [reference_year - i for i in range(1, max(1, gap_years) + 1)]
    eligible = sorted(
        {y for y in requested if earliest <= y <= reference_year - 1}
    )  # ascendant = lacunes les plus anciennes d'abord (fenêtre 10 ans)

    # ── Rachat rétroactif : plafonné au petit max TOTAL sur l'année civile ──
    annual_cap = _petit_max_for_year(reference_year)
    # Sans LPP à revenu nul : aucune capacité de rachat (pas de revenu à cotiser).
    if not has_lpp and revenu_net_annuel is not None and current_year_limit <= 0:
        annual_cap = 0.0

    breakdown: list[YearlyRetroactiveEntry] = []
    total_retroactive = 0.0
    for year in eligible:  # plus anciennes d'abord (proches de sortir de la fenêtre)
        if total_retroactive >= annual_cap:
            break
        room = annual_cap - total_retroactive
        amount = min(_petit_max_for_year(year), room)
        if amount <= 0:
            continue
        total_retroactive += amount
        breakdown.append(YearlyRetroactiveEntry(year=year, limit=round(amount, 2)))
    breakdown = list(reversed(breakdown))  # affichage : plus récentes d'abord

    total_contribution = total_retroactive + current_year_limit
    economies_fiscales = total_retroactive * effective_taux

    n = len(breakdown)
    savings_formatted = _format_chf(economies_fiscales)
    if n == 0:
        premier_eclairage = (
            f"En {reference_year}, aucune année de lacune 3a n'est encore "
            f"rachetable (le rachat rétroactif s'applique aux lacunes dès "
            f"2025)."
        )
    else:
        plural = "s" if n > 1 else ""
        premier_eclairage = (
            f"Tu peux rattraper {n} an{plural} d'épargne 3a et "
            f"économiser {savings_formatted} d'impôts en {reference_year}."
        )

    return Retroactive3aResult(
        gap_years=n,
        total_retroactive=round(total_retroactive, 2),
        total_current_year=round(current_year_limit, 2),
        total_contribution=round(total_contribution, 2),
        economies_fiscales=round(economies_fiscales, 2),
        breakdown=breakdown,
        premier_eclairage=premier_eclairage,
    )


def _format_chf(amount: float) -> str:
    """Format CHF amount with Swiss apostrophe thousands separator."""
    rounded = round(amount)
    formatted = f"{rounded:,}".replace(",", "’")
    return f"CHF {formatted}"
