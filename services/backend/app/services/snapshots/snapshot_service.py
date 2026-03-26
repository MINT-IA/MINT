"""
Snapshot Service — Financial snapshot CRUD with DB persistence.

Sprint S33 — Snapshot System (DB persistence added S31+).

Supports:
- DB persistence via SQLAlchemy session (production)
- In-memory fallback when no DB session provided (testing)

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
from typing import Dict, List, Any

from app.services.snapshots.snapshot_models import (
    FinancialSnapshot,
    VALID_TRIGGERS,
)


# ═══════════════════════════════════════════════════════════════════════════════
# In-memory fallback (used when no DB session is provided)
# ═══════════════════════════════════════════════════════════════════════════════

# WARNING (V12-3): In-memory storage — data will not survive restart.
# Feature-gated pending DB migration (see migrations/004_snapshots.sql).
# When db=None, all CRUD operations use this dict as fallback.
_snapshots: Dict[str, List[FinancialSnapshot]] = {}


def _clear_all() -> None:
    """Clear all in-memory snapshots (for testing only)."""
    _snapshots.clear()


def _snapshot_to_dataclass(row) -> FinancialSnapshot:
    """Convert a SnapshotModel DB row to a FinancialSnapshot dataclass."""
    return FinancialSnapshot(
        id=row.id,
        user_id=row.user_id,
        created_at=row.created_at.isoformat() if isinstance(row.created_at, datetime) else str(row.created_at),
        trigger=row.trigger,
        model_version=row.model_version or "1.0",
        age=row.age or 0,
        gross_income=row.gross_income or 0.0,
        canton=row.canton or "VD",
        archetype=row.archetype or "swiss_native",
        household_type=row.household_type or "single",
        replacement_ratio=row.replacement_ratio or 0.0,
        months_liquidity=row.months_liquidity or 0.0,
        tax_saving_potential=row.tax_saving_potential or 0.0,
        confidence_score=row.confidence_score or 0.0,
        enrichment_count=row.enrichment_count or 0,
        fri_total=row.fri_total or 0.0,
        fri_l=row.fri_l or 0.0,
        fri_f=row.fri_f or 0.0,
        fri_r=row.fri_r or 0.0,
        fri_s=row.fri_s or 0.0,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# CRUD operations
# ═══════════════════════════════════════════════════════════════════════════════

def create_snapshot(
    user_id: str,
    trigger: str,
    profile_data: Dict[str, Any],
    db=None,
) -> FinancialSnapshot:
    """Create a new financial snapshot from profile data.

    Args:
        user_id: User identifier.
        trigger: What triggered this snapshot ("quarterly", "life_event",
                 "profile_update", "check_in").
        profile_data: Dictionary with profile fields.
        db: Optional SQLAlchemy session. If provided, persists to DB.

    Returns:
        The created FinancialSnapshot.

    Raises:
        ValueError: If trigger is not a valid trigger type.
    """
    if trigger not in VALID_TRIGGERS:
        raise ValueError(
            f"Invalid trigger '{trigger}'. Must be one of: {', '.join(sorted(VALID_TRIGGERS))}"
        )

    snapshot_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    if db is not None:
        from app.models.snapshot import SnapshotModel
        row = SnapshotModel(
            id=snapshot_id,
            user_id=user_id,
            created_at=now,
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
        db.add(row)
        db.commit()
        db.refresh(row)
        return _snapshot_to_dataclass(row)

    # In-memory fallback
    snapshot = FinancialSnapshot(
        id=snapshot_id,
        user_id=user_id,
        created_at=now.isoformat(),
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


def get_snapshots(user_id: str, limit: int = 10, db=None) -> List[FinancialSnapshot]:
    """Get recent snapshots for a user, in reverse chronological order.

    Args:
        user_id: User identifier.
        limit: Maximum number of snapshots to return (default 10).
        db: Optional SQLAlchemy session.

    Returns:
        List of FinancialSnapshot, most recent first.
    """
    if db is not None:
        from app.models.snapshot import SnapshotModel
        rows = (
            db.query(SnapshotModel)
            .filter(SnapshotModel.user_id == user_id)
            .order_by(SnapshotModel.created_at.desc())
            .limit(limit)
            .all()
        )
        return [_snapshot_to_dataclass(r) for r in rows]

    # In-memory fallback
    user_snaps = _snapshots.get(user_id, [])
    sorted_snaps = sorted(user_snaps, key=lambda s: s.created_at, reverse=True)
    return sorted_snaps[:limit]


def delete_all_snapshots(user_id: str, db=None) -> int:
    """Delete all snapshots for a user (LPD compliance — right to erasure).

    Args:
        user_id: User identifier.
        db: Optional SQLAlchemy session.

    Returns:
        Number of snapshots deleted.
    """
    if db is not None:
        from app.models.snapshot import SnapshotModel
        count = (
            db.query(SnapshotModel)
            .filter(SnapshotModel.user_id == user_id)
            .delete()
        )
        db.commit()
        return count

    # In-memory fallback
    if user_id not in _snapshots:
        return 0
    count = len(_snapshots[user_id])
    del _snapshots[user_id]
    return count


def get_evolution(
    user_id: str,
    field: str = "replacement_ratio",
    db=None,
) -> List[Dict[str, Any]]:
    """Get time series of a specific metric for evolution tracking.

    Returns data points in chronological order (oldest first).

    Args:
        user_id: User identifier.
        field: The metric field to track. Default: "replacement_ratio".
        db: Optional SQLAlchemy session.

    Returns:
        List of dicts with "date", "value", and "trigger" keys.

    Raises:
        ValueError: If field is not a valid FinancialSnapshot attribute.
    """
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

    if db is not None:
        from app.models.snapshot import SnapshotModel
        rows = (
            db.query(SnapshotModel)
            .filter(SnapshotModel.user_id == user_id)
            .order_by(SnapshotModel.created_at.asc())
            .all()
        )
        return [
            {
                "date": r.created_at.isoformat() if isinstance(r.created_at, datetime) else str(r.created_at),
                "value": getattr(r, field, 0.0),
                "trigger": r.trigger,
            }
            for r in rows
        ]

    # In-memory fallback
    user_snaps = _snapshots.get(user_id, [])
    sorted_snaps = sorted(user_snaps, key=lambda s: s.created_at)

    return [
        {
            "date": s.created_at,
            "value": getattr(s, field, 0.0),
            "trigger": s.trigger,
        }
        for s in sorted_snaps
    ]
