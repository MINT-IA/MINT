"""
FRI (Financial Resilience Index) — Sprint S38 (Shadow) + S39 (Beta Display).

Computes FRI = L + F + R + S (each 0-25, total 0-100).
S38: Shadow mode (logged in snapshots, not displayed).
S39: Beta display (shown if confidence >= 50%, with display rules).

References:
    - ONBOARDING_ARBITRAGE_ENGINE.md § V
    - CLAUDE.md (constants)
"""

from app.services.fri.fri_service import FriService, FriBreakdown, FriInput
from app.services.fri.fri_display_service import FriDisplayService, FriDisplayResult

__all__ = [
    "FriService",
    "FriBreakdown",
    "FriInput",
    "FriDisplayService",
    "FriDisplayResult",
]
