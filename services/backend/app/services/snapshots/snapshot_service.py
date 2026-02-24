"""
Snapshot Service — Pure functions for financial snapshot CRUD.

Sprint S33 — Snapshot System.

In-memory storage for now (will be replaced by DB in production).

Provides:
- create_snapshot(): Create a new financial snapshot from profile data
- get_snapshots(): Get recent snapshots for a user (reverse chronological)
- delete_all_snapshots(): Delete all snapshots for a user (LPD compliance)
- get_evolution(): Get time series of a specific metric

Sources:
    - LPD (Loi sur la protection des donnees) — right to erasure
"""

import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any

from app.services.snapshots.snapshot_models import (
    FinancialSnapshot,
    VALID_TRIGGERS,
)


# ═══════════════════════════════════════════════════════════════════════════════
# In-memory storage (will be replaced by DB in production)
# ═══════════════════════════════════════════════════════════════════════════════

_snapshots: Dict[str, List[FinancialSnapshot]] = {}


def _clear_all() -> None:
    """Clear all in-memory snapshots (for testing only)."""
    _snapshots.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# CRUD operations
# ═══════════════════════════════════════════════════════════════════════════════

def create_snapshot(
    user_id: str,
    trigger: str,
    profile_data: Dict[str, Any],
) -> FinancialSnapshot:
    """Create a new financial snapshot from profile data.

    Args:
        user_id: User identifier.
        trigger: What triggered this snapshot ("quarterly", "life_event",
                 "profile_update", "check_in").
        profile_data: Dictionary with profile fields. Supported keys:
            - age (int)
            - gross_income (float)
            - canton (str)
            - archetype (str)
            - household_type (str)
            - replacement_ratio (float)
            - months_liquidity (float)
            - tax_saving_potential (float)
            - confidence_score (float)
            - enrichment_count (int)
            - fri_total, fri_l, fri_f, fri_r, fri_s (float)

    Returns:
        The created FinancialSnapshot.

    Raises:
        ValueError: If trigger is not a valid trigger type.
    """
    if trigger not in VALID_TRIGGERS:
        raise ValueError(
            f"Invalid trigger '{trigger}'. Must be one of: {', '.join(sorted(VALID_TRIGGERS))}"
        )

    snapshot = FinancialSnapshot(
        id=str(uuid.uuid4()),
        user_id=user_id,
        created_at=datetime.now(timezone.utc).isoformat(),
        trigger=trigger,
        model_version="1.0",
        age=profile_data.get("age", 0),
        gross_income=profile_data.get("gross_income", 0.0),
        canton=profile_data.get("canton", "VD"),
        archetype=profile_data.get("archetype", "swiss_native"),
        household_type=profile_data.get("household_type", "single"),
        replacement_ratio=profile_data.get("replacement_ratio", 0.0),
        months_liquidity=profile_data.get("months_liquidity", 0.0),
        tax_saving_potential=profile_data.get("tax_saving_potential", 0.0),
        confidence_score=profile_data.get("confidence_score", 0.0),
        enrichment_count=profile_data.get("enrichment_count", 0),
        fri_total=profile_data.get("fri_total", 0.0),
        fri_l=profile_data.get("fri_l", 0.0),
        fri_f=profile_data.get("fri_f", 0.0),
        fri_r=profile_data.get("fri_r", 0.0),
        fri_s=profile_data.get("fri_s", 0.0),
    )

    if user_id not in _snapshots:
        _snapshots[user_id] = []
    _snapshots[user_id].append(snapshot)

    return snapshot


def get_snapshots(user_id: str, limit: int = 10) -> List[FinancialSnapshot]:
    """Get recent snapshots for a user, in reverse chronological order.

    Args:
        user_id: User identifier.
        limit: Maximum number of snapshots to return (default 10).

    Returns:
        List of FinancialSnapshot, most recent first.
    """
    user_snaps = _snapshots.get(user_id, [])
    # Sort by created_at descending (most recent first)
    sorted_snaps = sorted(user_snaps, key=lambda s: s.created_at, reverse=True)
    return sorted_snaps[:limit]


def delete_all_snapshots(user_id: str) -> int:
    """Delete all snapshots for a user (LPD compliance — right to erasure).

    Args:
        user_id: User identifier.

    Returns:
        Number of snapshots deleted.
    """
    if user_id not in _snapshots:
        return 0
    count = len(_snapshots[user_id])
    del _snapshots[user_id]
    return count


def get_evolution(
    user_id: str,
    field: str = "replacement_ratio",
) -> List[Dict[str, Any]]:
    """Get time series of a specific metric for evolution tracking.

    Returns data points in chronological order (oldest first).

    Args:
        user_id: User identifier.
        field: The metric field to track. Must be a valid FinancialSnapshot
               attribute. Default: "replacement_ratio".

    Returns:
        List of dicts with "date", "value", and "trigger" keys.

    Raises:
        ValueError: If field is not a valid FinancialSnapshot attribute.
    """
    # Validate field
    valid_fields = {
        "replacement_ratio", "months_liquidity", "tax_saving_potential",
        "confidence_score", "enrichment_count",
        "fri_total", "fri_l", "fri_f", "fri_r", "fri_s",
        "gross_income", "age",
    }
    if field not in valid_fields:
        raise ValueError(
            f"Invalid field '{field}'. Must be one of: {', '.join(sorted(valid_fields))}"
        )

    user_snaps = _snapshots.get(user_id, [])
    # Sort chronologically (oldest first) for time series
    sorted_snaps = sorted(user_snaps, key=lambda s: s.created_at)

    return [
        {
            "date": s.created_at,
            "value": getattr(s, field, 0.0),
            "trigger": s.trigger,
        }
        for s in sorted_snaps
    ]
