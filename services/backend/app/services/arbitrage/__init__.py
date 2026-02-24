"""
Arbitrage module — Sprint S32: Arbitrage Phase 1.

Provides comparative financial simulations for retirement and savings decisions:
- Rente vs Capital: compare full rente, full capital, and mixed strategies
- Allocation Annuelle: compare 3a, rachat LPP, amortissement indirect, investissement libre

Components:
    - compare_rente_vs_capital(): 3-option retirement comparison
    - compare_allocation_annuelle(): up to 4-option savings allocation comparison
    - Models: YearlySnapshot, TrajectoireOption, ArbitrageResult

Sources:
    - LPP art. 14 (taux de conversion minimum)
    - LPP art. 37 (choix rente/capital)
    - LPP art. 79b (rachat LPP, blocage 3 ans)
    - LIFD art. 22 (imposition des rentes)
    - LIFD art. 38 (imposition du capital de prevoyance)
    - OPP3 art. 7 (plafond 3a)
"""

from app.services.arbitrage.arbitrage_models import (
    YearlySnapshot,
    TrajectoireOption,
    ArbitrageResult,
)
from app.services.arbitrage.rente_vs_capital import compare_rente_vs_capital
from app.services.arbitrage.allocation_annuelle import compare_allocation_annuelle

__all__ = [
    "YearlySnapshot",
    "TrajectoireOption",
    "ArbitrageResult",
    "compare_rente_vs_capital",
    "compare_allocation_annuelle",
]
