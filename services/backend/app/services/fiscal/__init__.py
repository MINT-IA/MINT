"""
Module Fiscalite cantonale — Sprint S20.

Comparateur de charge fiscale entre les 26 cantons suisses.
Estimation simplifiee basee sur les taux effectifs publies
par l'Administration federale des contributions.

Sources principales:
    - Administration federale des contributions — Charge fiscale 2024
    - LIFD art. 36 (bareme federal)
    - LHID art. 1 (harmonisation fiscale)
"""

from app.services.fiscal.cantonal_comparator import (
    CantonalComparator,
    DISCLAIMER,
    SOURCES,
    CANTON_NAMES,
    EFFECTIVE_RATES_100K_SINGLE,
    INCOME_ADJUSTMENT,
    FAMILY_ADJUSTMENTS,
)

__all__ = [
    "CantonalComparator",
    "DISCLAIMER",
    "SOURCES",
    "CANTON_NAMES",
    "EFFECTIVE_RATES_100K_SINGLE",
    "INCOME_ADJUSTMENT",
    "FAMILY_ADJUSTMENTS",
]
