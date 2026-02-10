"""
Module Chomage (LACI) — Sprint S19.

Calculateur d'indemnites de chomage selon la LACI et generation
de la timeline post-perte d'emploi.

Sources principales:
    - LACI art. 8 (droit a l'indemnite)
    - LACI art. 13 (periode de cotisation)
    - LACI art. 22 (montant de l'indemnite journaliere)
    - LACI art. 27 (nombre maximum d'indemnites journalieres)
    - OAC art. 37 (jours de carence)
"""

from app.services.unemployment.calculator import (
    UnemploymentCalculator,
    DISCLAIMER,
    SOURCES,
    GAIN_ASSURE_MAX,
    UNEMPLOYMENT_RATE_BASE,
    UNEMPLOYMENT_RATE_ENHANCED,
    SALARY_THRESHOLD_ENHANCED,
    DELAI_CARENCE_STANDARD,
    WORKING_DAYS_PER_MONTH,
)

__all__ = [
    "UnemploymentCalculator",
    "DISCLAIMER",
    "SOURCES",
    "GAIN_ASSURE_MAX",
    "UNEMPLOYMENT_RATE_BASE",
    "UNEMPLOYMENT_RATE_ENHANCED",
    "SALARY_THRESHOLD_ENHANCED",
    "DELAI_CARENCE_STANDARD",
    "WORKING_DAYS_PER_MONTH",
]
