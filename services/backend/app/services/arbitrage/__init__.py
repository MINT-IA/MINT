"""
Arbitrage module — Sprint S32-S33: Arbitrage Phase 1 + 2.

Provides comparative financial simulations for retirement and savings decisions:
- Rente vs Capital: compare full rente, full capital, and mixed strategies
- Allocation Annuelle: compare 3a, rachat LPP, amortissement indirect, investissement libre
- Location vs Propriete: compare renting vs buying (Sprint S33)
- Rachat vs Marche: compare LPP buyback vs market investment (Sprint S33)
- Calendrier Retraits: compare same-year vs staggered withdrawals (Sprint S33)

Components:
    - compare_rente_vs_capital(): 3-option retirement comparison
    - compare_allocation_annuelle(): up to 4-option savings allocation comparison
    - compare_location_vs_propriete(): 2-option rent vs buy comparison
    - compare_rachat_vs_marche(): 2-option buyback vs market comparison
    - compare_calendrier_retraits(): 2-option withdrawal scheduling comparison
    - Models: YearlySnapshot, TrajectoireOption, ArbitrageResult, RetirementAsset

Sources:
    - LPP art. 14 (taux de conversion minimum)
    - LPP art. 37 (choix rente/capital)
    - LPP art. 79b (rachat LPP, blocage 3 ans)
    - LIFD art. 22 (imposition des rentes)
    - LIFD art. 38 (imposition du capital de prevoyance)
    - OPP3 art. 7 (plafond 3a)
    - CO art. 253ss (bail)
    - FINMA Tragbarkeitsrechnung
"""

from app.services.arbitrage.arbitrage_models import (
    YearlySnapshot,
    TrajectoireOption,
    ArbitrageResult,
)
from app.services.arbitrage.rente_vs_capital import compare_rente_vs_capital
from app.services.arbitrage.allocation_annuelle import compare_allocation_annuelle
from app.services.arbitrage.location_vs_propriete import compare_location_vs_propriete
from app.services.arbitrage.rachat_vs_marche import compare_rachat_vs_marche
from app.services.arbitrage.calendrier_retraits import (
    compare_calendrier_retraits,
    RetirementAsset,
)

__all__ = [
    "YearlySnapshot",
    "TrajectoireOption",
    "ArbitrageResult",
    "RetirementAsset",
    "compare_rente_vs_capital",
    "compare_allocation_annuelle",
    "compare_location_vs_propriete",
    "compare_rachat_vs_marche",
    "compare_calendrier_retraits",
]
