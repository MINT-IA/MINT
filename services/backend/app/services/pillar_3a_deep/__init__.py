"""
Pillar 3a Deep Dive module for MINT (Sprint S16).

Gap G1: "3a Deep" — multi-account strategy, real return analysis,
and provider comparison (fintech vs bank vs insurance).

Components:
    - MultiAccountService: Staggered withdrawal simulator (tax optimization)
    - RealReturnService: Real return calculator with marginal tax rate
    - ProviderComparatorService: Compare 3a providers (fintech, bank, insurance)

Sources:
    - OPP3 (Ordonnance sur le 3e pilier)
    - LIFD art. 33 al. 1 let. e (deduction fiscale 3a)
    - LIFD art. 38 (imposition prestations en capital)
"""

from app.services.pillar_3a_deep.multi_account_service import MultiAccountService
from app.services.pillar_3a_deep.real_return_service import RealReturnService
from app.services.pillar_3a_deep.provider_comparator_service import ProviderComparatorService

__all__ = [
    "MultiAccountService",
    "RealReturnService",
    "ProviderComparatorService",
]
