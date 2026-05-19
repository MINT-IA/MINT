"""
Module expatriation et frontaliers pour MINT (Sprint S23).

Chantier "Expatriation + Frontaliers" : impot a la source, quasi-resident,
regle des 90 jours, charges sociales, forfait fiscal, double imposition,
lacunes AVS, planification de depart, comparaison fiscale internationale.

Tous les calculs sont educatifs et bases sur le droit suisse (2025/2026).

Components:
    - FrontalierService: Impot a la source, quasi-resident, regle 90 jours,
      charges sociales, option LAMal (LIFD, accords bilateraux CH-UE, lois cantonales)
    - ExpatService: Forfait fiscal, double imposition, lacunes AVS,
      planification depart, comparaison fiscale (LIFD, CDI, LAVS, LPP, OPP2)

Sources:
    - LIFD art. 83-86 (impot a la source)
    - LIFD art. 14 (imposition d'apres la depense / forfait fiscal)
    - Accords bilateraux CH-UE sur la libre circulation (ALCP)
    - Reglement CE 883/2004 (coordination securite sociale)
    - LAVS art. 1a, 2 (cotisations obligatoires / volontaires)
    - LPP art. 2 (libre passage)
    - OPP2 art. 11 (prestations de libre passage)
    - CDI bilaterales (conventions de double imposition)
"""

from app.services.expat.frontalier_service import (
    FrontalierService,  # deprecated alias, kept until Plan 02-04 PR-2 per D-09
    FrontalierSegmentService,  # canonical name since Phase 02 D-09
)
from app.services.expat.expat_service import ExpatService

__all__ = [
    "FrontalierService",  # deprecated, prefer FrontalierSegmentService
    "FrontalierSegmentService",
    "ExpatService",
]
