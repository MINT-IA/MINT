"""
Snapshots module — Sprint S33: Financial Snapshots.

Provides financial snapshot creation and evolution tracking:
- create_snapshot(): Create a new financial snapshot from profile data
- get_snapshots(): Get recent snapshots for a user
- delete_all_snapshots(): Delete all snapshots (LPD compliance)
- get_evolution(): Get time series of a specific metric

Components:
    - FinancialSnapshot: Core snapshot dataclass
    - snapshot_service: CRUD operations (in-memory for now)

Sources:
    - LPD (Loi sur la protection des donnees) — right to erasure
"""

from app.services.snapshots.snapshot_models import FinancialSnapshot
from app.services.snapshots.snapshot_service import (
    create_snapshot,
    get_snapshots,
    delete_all_snapshots,
    get_evolution,
)

__all__ = [
    "FinancialSnapshot",
    "create_snapshot",
    "get_snapshots",
    "delete_all_snapshots",
    "get_evolution",
]
