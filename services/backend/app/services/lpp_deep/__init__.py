"""
LPP Deep Dive module for MINT (Sprint S15).

Chantier 4: "Comprendre mon 2e pilier" — advanced LPP tools.

Components:
    - RachatEchelonneService: Stepped buyback simulator (tax optimization)
    - LibrePassageService: Vested benefits advisor (job change / leaving CH)
    - EPLService: Home ownership encouragement simulator (LPP art. 30a-30g)

Sources:
    - LPP art. 79b (rachat), art. 30a-30g (EPL), art. 25e-25f (libre passage)
    - LIFD art. 33 al. 1 let. d (deduction fiscale)
    - OPP2 art. 60a (conditions de rachat), art. 5-5f (EPL)
    - LFLP art. 2-4 (libre passage)
    - OLP art. 8-10 (libre passage)
"""

from app.services.lpp_deep.rachat_echelonne_service import RachatEchelonneService
from app.services.lpp_deep.libre_passage_service import LibrePassageService
from app.services.lpp_deep.epl_service import EPLService

__all__ = [
    "RachatEchelonneService",
    "LibrePassageService",
    "EPLService",
]
