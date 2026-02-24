"""
Onboarding module — Sprint S31: Onboarding Redesign.

Provides minimal profile computation and chiffre choc selection
for the new onboarding flow. Only 3 inputs required (age, salary, canton)
to produce a compelling financial snapshot.

Components:
    - MinimalProfileService: compute_minimal_profile()
    - ChiffreChocSelector: select_chiffre_choc()
    - Models: MinimalProfileInput, MinimalProfileResult, ChiffreChoc

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
"""

from app.services.onboarding.onboarding_models import (
    MinimalProfileInput,
    MinimalProfileResult,
    ChiffreChoc,
)
from app.services.onboarding.minimal_profile_service import compute_minimal_profile
from app.services.onboarding.chiffre_choc_selector import select_chiffre_choc

__all__ = [
    "MinimalProfileInput",
    "MinimalProfileResult",
    "ChiffreChoc",
    "compute_minimal_profile",
    "select_chiffre_choc",
]
