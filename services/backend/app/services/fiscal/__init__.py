"""
Module Fiscalite cantonale — Sprint S20+.

Comparateur de charge fiscale entre les 26 cantons suisses.
Estimation simplifiee basee sur les taux effectifs publies
par l'Administration federale des contributions.

Inclut egalement le service de multiplicateurs communaux
(commune_service) pour une estimation plus fine au niveau
de chaque commune.

Sources principales:
    - Administration federale des contributions — Charge fiscale 2024
    - LIFD art. 36 (bareme federal)
    - LHID art. 1 (harmonisation fiscale)
    - LHID art. 2 al. 1 (autonomie communale)
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

from app.services.fiscal.commune_service import (
    search_communes,
    get_commune_multiplier,
    get_commune_by_npa,
    list_communes_by_canton,
    get_cheapest_communes,
    COMMUNE_DATA,
)

__all__ = [
    "CantonalComparator",
    "DISCLAIMER",
    "SOURCES",
    "CANTON_NAMES",
    "EFFECTIVE_RATES_100K_SINGLE",
    "INCOME_ADJUSTMENT",
    "FAMILY_ADJUSTMENTS",
    "search_communes",
    "get_commune_multiplier",
    "get_commune_by_npa",
    "list_communes_by_canton",
    "get_cheapest_communes",
    "COMMUNE_DATA",
]
