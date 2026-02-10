"""
Module famille pour MINT (Sprint S22).

Chantier "Evenements de vie — Famille" : mariage, naissance, concubinage.

Simulateurs d'impact financier pour les 3 derniers evenements de vie
du roadmap MINT. Tous les calculs sont educatifs et base sur le droit
suisse (2025/2026).

Components:
    - MariageService: Impact fiscal du mariage, regimes matrimoniaux,
      rente de survivant (LIFD, CC, LAVS, LPP)
    - NaissanceService: Conge parental APG, allocations familiales,
      deductions fiscales enfants, impact carriere (LAPG, LAFam, LIFD)
    - ConcubinageService: Comparaison mariage vs concubinage, succession,
      checklist protection concubins (CC, LIFD, LAVS, LPP)

Sources:
    - LIFD art. 9, 33, 35, 36 (imposition des couples, deductions)
    - CC art. 181, 221, 247 (regimes matrimoniaux)
    - LAVS art. 29sexies (splitting AVS)
    - LPP art. 19, 20 (rente de survivant)
    - LAPG art. 16d-16l (conge maternite/paternite)
    - LAFam art. 3 (allocations familiales)
"""

from app.services.family.mariage_service import MariageService
from app.services.family.naissance_service import NaissanceService
from app.services.family.concubinage_service import ConcubinageService

__all__ = [
    "MariageService",
    "NaissanceService",
    "ConcubinageService",
]
