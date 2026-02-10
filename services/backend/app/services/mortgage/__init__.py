"""
Mortgage & Real Estate module for MINT (Sprint S17).

Comprehensive Swiss mortgage simulation suite:
    - AffordabilityService: Tragbarkeitsrechnung (affordability check)
    - SaronVsFixedService: SARON vs fixed-rate comparison
    - ImputedRentalService: Eigenmietwert (imputed rental value & tax impact)
    - AmortizationService: Direct vs indirect amortization comparison
    - EplCombinedService: Combined EPL (3a + LPP) for housing equity

Sources:
    - Circulaire FINMA 2017/5 (octroi hypothecaire)
    - Directives ASB (Association Suisse des Banquiers)
    - LIFD art. 21 al. 1 let. b (valeur locative)
    - LIFD art. 32 (frais d'entretien)
    - LIFD art. 33 (interets passifs, deductions 3a)
    - LPP art. 30a-30g (EPL)
    - OPP3 art. 1 (3e pilier lie)
"""

from app.services.mortgage.affordability_service import AffordabilityService
from app.services.mortgage.saron_vs_fixed_service import SaronVsFixedService
from app.services.mortgage.imputed_rental_service import ImputedRentalService
from app.services.mortgage.amortization_service import AmortizationService
from app.services.mortgage.epl_combined_service import EplCombinedService

__all__ = [
    "AffordabilityService",
    "SaronVsFixedService",
    "ImputedRentalService",
    "AmortizationService",
    "EplCombinedService",
]
