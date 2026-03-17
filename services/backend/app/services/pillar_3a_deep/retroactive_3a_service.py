"""
Retroactive 3a catch-up calculator (NEW 2026 law).

Starting 2026, individuals can contribute retroactively to Pillar 3a
for up to 10 years of missed contributions (OPP3 art. 7 amendment).
All retroactive amounts are tax-deductible in the year of contribution.

Sources:
    - OPP3 art. 7 (2026 amendment) — retroactive catch-up rules
    - LIFD art. 33 al. 1 let. e — tax deductibility of 3a contributions
    - OFAS annual publications — historical 3a limits

Sprint S52 — 3a Retroactif.
"""

from dataclasses import dataclass, field
from typing import List

from app.constants.social_insurance import (
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
)

# ── Historical 3a limits (CHF) by year ──────────────────────────────
# Source: OFAS annual publications, OPP3 art. 7
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

DISCLAIMER = (
    "Outil \u00e9ducatif\u00a0\u2014 ne constitue pas un conseil fiscal (LSFin). "
    "Le rattrapage 3a est disponible d\u00e8s 2026 (OPP3 art. 7). "
    "L'\u00e9conomie fiscale d\u00e9pend de ton taux marginal r\u00e9el."
)

SOURCES = [
    "OPP3 art. 7 (amendement 2026)",
    "LIFD art. 33 al. 1 let. e",
    "Plafonds annuels OFAS",
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
    chiffre_choc: str
    disclaimer: str = DISCLAIMER
    sources: List[str] = field(default_factory=lambda: list(SOURCES))


def calculate_retroactive_3a(
    gap_years: int,
    taux_marginal: float,
    has_lpp: bool = True,
    reference_year: int = 2026,
) -> Retroactive3aResult:
    """Calculate retroactive 3a catch-up contribution impact.

    Args:
        gap_years: Number of years to catch up (1-10).
        taux_marginal: Marginal tax rate (0.0-1.0).
        has_lpp: Whether the user is affiliated with LPP (affects limits).
        reference_year: Year of retroactive contribution (default 2026).

    Returns:
        Retroactive3aResult with full breakdown and chiffre choc.
    """
    effective_gap = max(1, min(gap_years, MAX_RETROACTIVE_YEARS))

    breakdown: list[YearlyRetroactiveEntry] = []
    total_retroactive = 0.0

    for i in range(1, effective_gap + 1):
        year = reference_year - i
        base_limit = HISTORICAL_3A_LIMITS.get(year, 6_768.0)

        if has_lpp:
            limit = base_limit
        else:
            # Scale proportionally for "grand 3a" (sans LPP)
            ratio = PILIER_3A_PLAFOND_SANS_LPP / PILIER_3A_PLAFOND_AVEC_LPP
            limit = base_limit * ratio

        total_retroactive += limit
        breakdown.append(YearlyRetroactiveEntry(year=year, limit=limit))

    # Current year contribution (separate from retroactive)
    current_year_limit = (
        PILIER_3A_PLAFOND_AVEC_LPP if has_lpp else PILIER_3A_PLAFOND_SANS_LPP
    )
    total_contribution = total_retroactive + current_year_limit

    # Tax savings: all retroactive amounts deductible in reference year
    economies_fiscales = total_retroactive * taux_marginal

    # Chiffre choc
    savings_formatted = _format_chf(economies_fiscales)
    plural = "s" if effective_gap > 1 else ""
    chiffre_choc = (
        f"Tu peux rattraper {effective_gap}\u00a0an{plural} "
        f"d'\u00e9pargne 3a et \u00e9conomiser {savings_formatted} "
        f"d'imp\u00f4ts en {reference_year}."
    )

    return Retroactive3aResult(
        gap_years=effective_gap,
        total_retroactive=round(total_retroactive, 2),
        total_current_year=round(current_year_limit, 2),
        total_contribution=round(total_contribution, 2),
        economies_fiscales=round(economies_fiscales, 2),
        breakdown=breakdown,
        chiffre_choc=chiffre_choc,
    )


def _format_chf(amount: float) -> str:
    """Format CHF amount with Swiss apostrophe thousands separator."""
    rounded = round(amount)
    formatted = f"{rounded:,}".replace(",", "\u2019")
    return f"CHF\u00a0{formatted}"
