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
from typing import Dict, List, Any, Optional

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
        import hashlib
        import json

        from app.models.snapshot import SnapshotModel
        from app.models.projection_audit_record import ProjectionAuditRecord
        from app.services.regulatory.registry import RegulatoryRegistry

        # Hotfix B 2026-05-17 — stamp the snapshot with the regulatory
        # version hash that was active at compute time. Enables LSFin
        # reconstruction of the inputs that produced this projection.
        constants_hash = RegulatoryRegistry.instance().version_hash(on_date=now.date())

        row = SnapshotModel(
            id=snapshot_id,
            user_id=user_id,
            created_at=now,
            trigger=trigger,
            model_version="1.0",
            constants_version_hash=constants_hash,
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

        # Hotfix B 2026-05-17 — append-only LSFin advice audit trail.
        # Hashes are computed before the commit so the audit row and the
        # snapshot land in the same transaction.
        inputs_canonical = json.dumps(
            {k: v for k, v in profile_data.items() if not k.startswith("_")},
            sort_keys=True,
            separators=(",", ":"),
            default=str,
        )
        inputs_hash = hashlib.sha256(inputs_canonical.encode("utf-8")).hexdigest()
        output_canonical = json.dumps(
            {
                "replacement_ratio": row.replacement_ratio,
                "months_liquidity": row.months_liquidity,
                "tax_saving_potential": row.tax_saving_potential,
                "confidence_score": row.confidence_score,
                "fri_total": row.fri_total,
                "fri_l": row.fri_l,
                "fri_f": row.fri_f,
                "fri_r": row.fri_r,
                "fri_s": row.fri_s,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
        output_hash = hashlib.sha256(output_canonical.encode("utf-8")).hexdigest()
        user_id_hash = hashlib.sha256(user_id.encode("utf-8")).hexdigest()

        audit_row = ProjectionAuditRecord(
            user_id_hash=user_id_hash,
            computed_at=now,
            projection_type="snapshot",
            projection_id=snapshot_id,
            constants_version_hash=constants_hash,
            scenario_inputs_hash=inputs_hash,
            output_hash=output_hash,
            lsfin_disclaimer_shown=False,  # endpoint owns this signal; conservative default
        )
        db.add(audit_row)

        # ── Phase 02 Plan 02-03 PR-2 (D-05) — dual-write under feature flag ──
        # When FF_FACT_EVENT_DUAL_WRITE is ON (default OFF), every scalar /
        # JSONB / nullable / TOAST-blob fact from profile_data that has a
        # canary-proven field_key (Plan 02-02 D-25 + D-34) is projected to
        # fact_event + fact_current atomically inside the same transaction
        # via project_event() (D-19 atomicity).
        #
        # Field-key surface (5 canary-proven shapes from Plan 02-02 T3-C) :
        #   profile_data['gross_income']         -> 'monthly_gross_income'
        #   profile_data['pillar_3a_balance']    -> 'pillar_3a_balance'
        #   profile_data['archetype_tags']       -> 'archetype_tags'
        #   profile_data['lpp_avoirs_vieillesse']-> 'lpp_avoirs_vieillesse'
        #   profile_data['coach_extracted_facts']-> 'coach_extracted_facts'
        #
        # Substrate adaptation (Karpathy #1 — assumption surfacing) :
        # The Plan 02-03 <interfaces> section assumed every SnapshotModel
        # scalar column maps 1:1 to a fact_type. Reality : only `gross_income`
        # is a SnapshotModel column ; the other 4 canary field_keys live in
        # profile_data only. The minimal dual-write surface is therefore the
        # 5 canary-proven field_keys, read from profile_data (or row for the
        # gross_income case).
        #
        # The projector uses session.begin_nested() when the caller is
        # already in a transaction (we're between db.add(audit_row) and
        # db.commit() so session IS in a txn) — SAVEPOINT semantics keep
        # the dual-write atomic with the SnapshotModel + audit writes.
        # If any dual-write step raises, the outer commit() will fail and
        # NEITHER table is mutated.
        from app.services.feature_flags import is_fact_event_dual_write_enabled

        if is_fact_event_dual_write_enabled():
            from app.services.encryption.encrypted_value_helper import encrypt_value
            from app.services.projector.fact_projector import (
                FactEventInput,
                project_event,
            )

            # field-key -> (profile_data key, presence-rule)
            # Presence rule : `required` means write even if value is None
            # (nullable canary tracks None as a real fact ; lpp_avoirs is
            # Plan 02-02 nullable canary). `optional` means skip when the
            # key is absent from profile_data (the user hasn't provided it).
            dual_write_specs = (
                # name in profile_data,   field_key,                presence
                ("gross_income",          "monthly_gross_income",   "optional"),
                ("pillar_3a_balance",     "pillar_3a_balance",      "optional"),
                ("archetype_tags",        "archetype_tags",         "optional"),
                ("lpp_avoirs_vieillesse", "lpp_avoirs_vieillesse",  "optional"),
                ("coach_extracted_facts", "coach_extracted_facts",  "optional"),
            )
            for profile_key, field_key, presence in dual_write_specs:
                if profile_key not in profile_data and presence == "optional":
                    continue
                value = profile_data.get(profile_key)
                value_enc = encrypt_value(db, user_id, value)
                event = FactEventInput(
                    user_id=user_id,
                    field_key=field_key,
                    value_enc=value_enc,
                    valid_from=now,
                    source="snapshot_dual_write",
                )
                project_event(db, event)

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

    D-17 (Plan 02-02 P1 continuation-4) : when reading from DB, each row's
    `constants_version_hash` is checked against the active regulatory
    registry via `snapshot_cache.is_snapshot_stale()`. Stale rows are
    annotated via the `mint_constants_version_mismatch_total` counter
    (one increment per stale row observed) so observability surfaces
    « how many rows need a recompute ». The rows themselves are NOT
    mutated (D-04 point-in-time immutability) and ARE still returned to
    the caller — the staleness signal is a recompute trigger, not a
    filter. Callers that want only-fresh rows can re-filter via the
    same `is_snapshot_stale()` helper.

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
        # D-17 read-path wiring : observe staleness without mutating rows.
        # Lazy-imports keep module-load lightweight + avoid circular imports.
        try:
            from app.services.cache.snapshot_cache import is_snapshot_stale
            from app.observability.counters import (
                mint_constants_version_mismatch_total,
            )
            for row in rows:
                if is_snapshot_stale(row):
                    mint_constants_version_mismatch_total.inc()
        except Exception:  # pragma: no cover — observability never breaks reads
            # If the staleness check fails (registry mis-init, counter
            # unavailable), fall through silently — D-17 observability is
            # a signal, not a hard dependency on the read path.
            pass
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


# ═══════════════════════════════════════════════════════════════════════════════
# fact_current read-path (feature-flag-gated, Plan 02-02 W1 D-25 canary substrate)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-25 canary parity gate.
#
# When the FF_FACT_CURRENT_READ feature flag is OFF (default), reads of
# `monthly_gross_income` continue to come from SnapshotModel.gross_income
# (the legacy plaintext Float column). When the flag is ON, the read goes
# through `fact_current.value_enc` decrypted via the D-26 EncryptedValue
# helper.
#
# The flag will be flipped ON in Plan 02-03 PR-2 (dual-write phase) once
# the projector is wired into the snapshot-write side. Until then, the
# default-OFF behaviour preserves zero end-user-visible change.
#
# The canary parity test (`test_canary_monthly_gross_income.py`) writes the
# SAME value via BOTH paths and asserts the two reads return IDENTICAL
# results — the W1 → W2 gate per D-25.

def read_monthly_gross_income(user_id: str, db) -> Optional[float]:
    """Read the current `monthly_gross_income` for a user.

    When FF_FACT_CURRENT_READ is OFF (default), returns the latest
    SnapshotModel.gross_income value for the user (legacy plaintext path).
    When FF_FACT_CURRENT_READ is ON, decrypts fact_current.value_enc via
    the D-26 helper.

    Returns None if the user has no snapshot / no fact_current row.

    Note : SnapshotModel.gross_income is a YEARLY float ; the canary
    parity-test writes the same numeric value via BOTH paths and asserts
    they read back identically. Whether the field semantically represents
    monthly vs annual is the caller's contract — this helper is a transport
    layer, not a unit converter.
    """
    import os

    use_fact_current = os.environ.get("FF_FACT_CURRENT_READ", "").lower() in (
        "1", "true", "yes",
    )

    if use_fact_current:
        from app.models.fact_current import FactCurrent
        from app.services.encryption.encrypted_value_helper import decrypt_value

        row = (
            db.query(FactCurrent)
            .filter(
                FactCurrent.user_id == user_id,
                FactCurrent.field_key == "monthly_gross_income",
            )
            .one_or_none()
        )
        if row is None:
            return None
        return decrypt_value(db, user_id, row.value_enc)

    # Legacy path : latest SnapshotModel.gross_income
    from app.models.snapshot import SnapshotModel
    row = (
        db.query(SnapshotModel)
        .filter(SnapshotModel.user_id == user_id)
        .order_by(SnapshotModel.created_at.desc())
        .first()
    )
    if row is None:
        return None
    return row.gross_income
