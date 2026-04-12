"""
Onboarding module — Sprint S31: Onboarding Redesign.

Provides minimal profile computation and premier éclairage selection
for the new onboarding flow. Only 3 inputs required (age, salary, canton)
to produce a compelling financial snapshot.

Components:
    - MinimalProfileService: compute_minimal_profile()
    - PremierEclairageSelector: select_premier_eclairage()
    - Models: MinimalProfileInput, MinimalProfileResult, PremierEclairage

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
"""

from app.services.onboarding.onboarding_models import (
    MinimalProfileInput,
    MinimalProfileResult,
    PremierEclairage,
)
from app.services.onboarding.minimal_profile_service import compute_minimal_profile
from app.services.onboarding.premier_eclairage_selector import select_premier_eclairage

__all__ = [
    "MinimalProfileInput",
    "MinimalProfileResult",
    "PremierEclairage",
    "compute_minimal_profile",
    "select_premier_eclairage",
]
