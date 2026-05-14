"""Wave 1a D-02 — Python port of Flutter CoupleOptimizer.

Plan-00 shipped this package as an empty marker; plan-04 fills it with
the 1:1 port of ``apps/mobile/lib/services/financial_core/couple_optimizer.dart``.
"""

from app.services.couple_optimizer.couple_optimizer import (
    AvsCoupleCapResult,
    CoupleAnalysisResult,
    CoupleOptimizationResult,
    CoupleOptimizer,
    CoupleWinner,
    MarriagePenaltyResult,
)

__all__ = [
    "AvsCoupleCapResult",
    "CoupleAnalysisResult",
    "CoupleOptimizationResult",
    "CoupleOptimizer",
    "CoupleWinner",
    "MarriagePenaltyResult",
]
