"""
Module Fiscalite cantonale — Sprint S20+.

Comparateur de charge fiscale entre les 26 cantons suisses.
Estimation simplifiee basee sur les taux effectifs publies
par l'Administration federale des contributions.

Inclut egalement:
    - le service de multiplicateurs communaux (commune_service)
    - le service d'impot sur la fortune (wealth_tax_service)
    - le service d'impot ecclesiastique (church_tax_service)

Sources principales:
    - Administration federale des contributions — Charge fiscale 2024
    - LIFD art. 36 (bareme federal)
    - LHID art. 1 (harmonisation fiscale)
    - LHID art. 2 al. 1 (autonomie communale)
    - LHID art. 14 (impot sur la fortune)
    - Lois fiscales cantonales (impot ecclesiastique)
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

from app.services.fiscal.wealth_tax_service import (
    WealthTaxService,
    WealthTaxEstimate,
    WealthTaxRanking,
    WealthTaxMoveSimulation,
    EFFECTIVE_WEALTH_TAX_RATES_500K,
    WEALTH_TAX_EXEMPTIONS,
    WEALTH_ADJUSTMENT,
    estimer_impot_fortune,
    comparer_fortune_cantons,
)

from app.services.fiscal.church_tax_service import (
    ChurchTaxService,
    ChurchTaxEstimate,
    CHURCH_TAX_RATES,
    NO_MANDATORY_CHURCH_TAX,
    estimer_impot_eglise,
)

__all__ = [
    # Cantonal comparator
    "CantonalComparator",
    "DISCLAIMER",
    "SOURCES",
    "CANTON_NAMES",
    "EFFECTIVE_RATES_100K_SINGLE",
    "INCOME_ADJUSTMENT",
    "FAMILY_ADJUSTMENTS",
    # Commune service
    "search_communes",
    "get_commune_multiplier",
    "get_commune_by_npa",
    "list_communes_by_canton",
    "get_cheapest_communes",
    "COMMUNE_DATA",
    # Wealth tax service
    "WealthTaxService",
    "WealthTaxEstimate",
    "WealthTaxRanking",
    "WealthTaxMoveSimulation",
    "EFFECTIVE_WEALTH_TAX_RATES_500K",
    "WEALTH_TAX_EXEMPTIONS",
    "WEALTH_ADJUSTMENT",
    "estimer_impot_fortune",
    "comparer_fortune_cantons",
    # Church tax service
    "ChurchTaxService",
    "ChurchTaxEstimate",
    "CHURCH_TAX_RATES",
    "NO_MANDATORY_CHURCH_TAX",
    "estimer_impot_eglise",
]
