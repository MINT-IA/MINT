"""
Module Premier emploi — Sprint S19.

Service d'onboarding pour le premier emploi: decomposition salariale,
recommandations 3a, comparaison franchise LAMal, checklist.

Sources principales:
    - LAVS art. 5 (cotisations AVS employes)
    - LACI art. 3 (cotisation chomage)
    - LPP art. 2, 7, 8, 16 (prevoyance professionnelle)
    - OPP3 art. 7 (plafond 3a salaries)
    - LAMal art. 61-65 (franchises et primes)
"""

from app.services.first_job.onboarding_service import (
    FirstJobOnboardingService,
    DISCLAIMER,
    SOURCES,
    AVS_AI_APG_RATE,
    AC_RATE,
    AANP_RATE,
    LPP_ENTRY_THRESHOLD,
    LPP_COORDINATION_DEDUCTION,
    LPP_MIN_COORDINATED,
    PILLAR_3A_LIMIT,
    LAMAL_FRANCHISES,
    LAMAL_QUOTE_PART_MAX,
)

__all__ = [
    "FirstJobOnboardingService",
    "DISCLAIMER",
    "SOURCES",
    "AVS_AI_APG_RATE",
    "AC_RATE",
    "AANP_RATE",
    "LPP_ENTRY_THRESHOLD",
    "LPP_COORDINATION_DEDUCTION",
    "LPP_MIN_COORDINATED",
    "PILLAR_3A_LIMIT",
    "LAMAL_FRANCHISES",
    "LAMAL_QUOTE_PART_MAX",
]
