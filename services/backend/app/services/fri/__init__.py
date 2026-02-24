"""
FRI (Financial Resilience Index) — Sprint S38 (Shadow Mode).

Computes FRI = L + F + R + S (each 0-25, total 0-100).
Logged in snapshots. NOT displayed to users yet.

References:
    - ONBOARDING_ARBITRAGE_ENGINE.md § V
    - CLAUDE.md (constants)
"""

from app.services.fri.fri_service import FriService, FriBreakdown, FriInput

__all__ = ["FriService", "FriBreakdown", "FriInput"]
