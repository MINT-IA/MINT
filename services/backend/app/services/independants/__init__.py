"""
Module Independants complet — Sprint S18.

5 services specialises pour les travailleurs et travailleuses independant-e-s
en Suisse. Couvre les cotisations AVS, l'assurance IJM, le 3a elargi,
l'optimisation salaire/dividende, et le LPP volontaire.

Sources principales:
    - LAVS art. 8-9, RAVS art. 21-23 (cotisations AVS independants)
    - LAMal art. 67-77 (IJM facultative)
    - OPP3 art. 7 (grand 3a: 20% du revenu, max 36'288 CHF)
    - LIFD art. 20 (imposition des dividendes)
    - LPP art. 44-46 (affiliation facultative)
"""

from app.services.independants.avs_cotisations_service import (
    calculer_cotisation_avs,
    AvsCotisationResult,
)
from app.services.independants.ijm_service import (
    simuler_ijm,
    IjmResult,
)
from app.services.independants.pillar_3a_indep_service import (
    calculer_3a_independant,
    Pillar3aIndepResult,
)
from app.services.independants.dividende_vs_salaire_service import (
    simuler_dividende_vs_salaire,
    DividendeVsSalaireResult,
)
from app.services.independants.lpp_volontaire_service import (
    simuler_lpp_volontaire,
    LppVolontaireResult,
)

__all__ = [
    "calculer_cotisation_avs",
    "AvsCotisationResult",
    "simuler_ijm",
    "IjmResult",
    "calculer_3a_independant",
    "Pillar3aIndepResult",
    "simuler_dividende_vs_salaire",
    "DividendeVsSalaireResult",
    "simuler_lpp_volontaire",
    "LppVolontaireResult",
]
