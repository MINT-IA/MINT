"""
Retirement planning module for MINT (Sprint S21).

Chantier "Retraite complete" — Complete retirement planning tools.

Components:
    - AvsEstimationService: AVS pension estimation (anticipation, normal, deferral)
    - LppConversionService: LPP capital vs rente comparison at retirement
    - RetirementBudgetService: Retirement budget reconciliation + PC eligibility

Sources:
    - LAVS art. 21-29 (rente de vieillesse AVS)
    - LAVS art. 21bis (anticipation), art. 21ter (ajournement)
    - LPP art. 14 (taux de conversion 6.8%)
    - LIFD art. 38 (imposition prestations en capital)
    - OPC (prestations complementaires cantonales)
"""

from app.services.retirement.avs_estimation_service import AvsEstimationService
from app.services.retirement.lpp_conversion_service import LppConversionService
from app.services.retirement.retirement_budget_service import RetirementBudgetService

__all__ = [
    "AvsEstimationService",
    "LppConversionService",
    "RetirementBudgetService",
]
