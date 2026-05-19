"""Plan 02-03 PR-2 — dual-write ON (staging) test.

Asserts that with FF_FACT_EVENT_DUAL_WRITE=on (the staging-soak posture),
`create_snapshot(...)` writes :
  - 1 SnapshotModel row (legacy path, unchanged)
  - N fact_event rows (one per canary-proven field_key present in profile_data)
  - N fact_current rows (UPSERT-keyed by (user_id, field_key))

AND that decrypting each fact_current.value_enc returns the original Python
value from profile_data. Round-trips via the D-26 EncryptedValue envelope
through encrypt_value / decrypt_value helpers — proves the dual-write
parity contract end-to-end at the application layer (SQLite path).
"""
from __future__ import annotations

from decimal import Decimal
from uuid import uuid4

import pytest

from app.models.fact_current import FactCurrent
from app.models.fact_event import FactEvent
from app.models.snapshot import SnapshotModel
from app.models.user import User
from app.services.encryption.encrypted_value_helper import decrypt_value
from app.services.snapshots.snapshot_service import create_snapshot
from tests.conftest import TestingSessionLocal


@pytest.fixture
def db():
    s = TestingSessionLocal()
    try:
        yield s
    finally:
        s.close()


@pytest.fixture
def user_id(db):
    uid = f"u-{uuid4().hex[:8]}"
    u = User(
        id=uid,
        email=f"{uuid4().hex[:8]}@dualon.test",
        hashed_password="x",
    )
    db.add(u)
    db.commit()
    return uid


@pytest.fixture
def ff_on(monkeypatch):
    """Enable FF_FACT_EVENT_DUAL_WRITE for the duration of the test."""
    monkeypatch.setenv("FF_FACT_EVENT_DUAL_WRITE", "1")
    # Sanity : assert the helper sees the env var (defensive against
    # import-time caching that might break a future refactor).
    from app.services.feature_flags import is_fact_event_dual_write_enabled
    assert is_fact_event_dual_write_enabled() is True


def test_dual_write_on_creates_5_fact_rows_and_decrypts_to_originals(
    ff_on, db, user_id
):
    """FF ON → 5 canary field_keys land in fact_event + fact_current.

    Round-trip via decrypt_value MUST equal the original profile_data value
    for each of the 5 canary shapes (scalar, JSONB nested, nullable, blob).
    """
    profile_data = {
        # legacy SnapshotModel columns (still get persisted that way too)
        "age": 35,
        "gross_income": 8500.0,
        "canton": "VD",
        "archetype": "swiss_native",
        "household_type": "single",
        # 5 canary field_keys for dual-write surface
        "pillar_3a_balance": 12345.67,
        "lpp_avoirs_vieillesse": None,
        "archetype_tags": {
            "tags": ["expat_eu", "frontalier"],
            "confidence_per_tag": {
                "expat_eu": {"score": 0.85},
                "frontalier": {"score": 0.78},
            },
        },
        "coach_extracted_facts": {"facts": ["x" * 4096], "_blob_size_bytes": 4096},
    }
    create_snapshot(
        user_id=user_id,
        trigger="profile_update",
        profile_data=profile_data,
        db=db,
    )

    # ── Assertions ─────────────────────────────────────────────────────
    # 1. Legacy SnapshotModel write is unchanged.
    snap_rows = db.query(SnapshotModel).filter(SnapshotModel.user_id == user_id).all()
    assert len(snap_rows) == 1
    assert snap_rows[0].gross_income == 8500.0

    # 2. fact_event has 5 rows for the 5 canary field_keys.
    fe_rows = db.query(FactEvent).filter(
        FactEvent.user_id == user_id,
        FactEvent.source == "snapshot_dual_write",
    ).all()
    fe_keys = sorted(r.field_key for r in fe_rows)
    expected_keys = sorted([
        "monthly_gross_income",
        "pillar_3a_balance",
        "archetype_tags",
        "lpp_avoirs_vieillesse",
        "coach_extracted_facts",
    ])
    assert fe_keys == expected_keys, (
        f"expected {expected_keys}, got {fe_keys}"
    )

    # 3. fact_current has the same 5 rows, UPSERT-keyed.
    fc_rows = db.query(FactCurrent).filter(FactCurrent.user_id == user_id).all()
    fc_by_key = {r.field_key: r for r in fc_rows}
    assert sorted(fc_by_key.keys()) == expected_keys

    # 4. Round-trip parity : decrypt_value returns the original Python value.
    assert decrypt_value(db, user_id, fc_by_key["monthly_gross_income"].value_enc) == 8500.0
    assert decrypt_value(db, user_id, fc_by_key["pillar_3a_balance"].value_enc) == 12345.67
    assert decrypt_value(db, user_id, fc_by_key["lpp_avoirs_vieillesse"].value_enc) is None
    archetype_decrypted = decrypt_value(db, user_id, fc_by_key["archetype_tags"].value_enc)
    assert archetype_decrypted == profile_data["archetype_tags"]
    coach_decrypted = decrypt_value(db, user_id, fc_by_key["coach_extracted_facts"].value_enc)
    assert coach_decrypted == profile_data["coach_extracted_facts"]


def test_dual_write_on_skips_absent_optional_keys(ff_on, db, user_id):
    """FF ON + minimal profile_data → only the present keys project."""
    profile_data = {
        "age": 25,
        "gross_income": 6500.0,
        # ONLY gross_income present from canary surface ; others absent.
    }
    create_snapshot(
        user_id=user_id,
        trigger="profile_update",
        profile_data=profile_data,
        db=db,
    )

    fc_rows = db.query(FactCurrent).filter(FactCurrent.user_id == user_id).all()
    fc_keys = sorted(r.field_key for r in fc_rows)
    # gross_income is the only canary field_key present, so only 1 fact_current.
    assert fc_keys == ["monthly_gross_income"], (
        f"expected only ['monthly_gross_income'], got {fc_keys}"
    )

    # Round-trip parity for the present key.
    fe = db.query(FactCurrent).filter(
        FactCurrent.user_id == user_id,
        FactCurrent.field_key == "monthly_gross_income",
    ).one()
    assert decrypt_value(db, user_id, fe.value_enc) == 6500.0


def test_dual_write_on_second_call_upserts_fact_current_keeps_fact_event_appended(
    ff_on, db, user_id
):
    """Two snapshots for the same user → fact_event appends (2 rows per key),
    fact_current keeps a single row per (user, key) updated to the latest
    valid_from value (UPSERT last-writer-wins by valid_from)."""
    from datetime import datetime, timedelta, timezone

    # First snapshot
    create_snapshot(
        user_id=user_id,
        trigger="profile_update",
        profile_data={"gross_income": 8500.0},
        db=db,
    )
    # Second snapshot — same user, different gross_income, later valid_from
    # (default valid_from = now, so the second call naturally has a later ts).
    # Add a small sleep-equivalent by burning the SnapshotModel.created_at
    # via datetime.now() ; the projector uses now() for valid_from too so the
    # second call's valid_from > first call's, satisfying the UPSERT WHERE
    # guard.
    import time
    time.sleep(0.01)  # ensure monotonic now() advances past first call
    create_snapshot(
        user_id=user_id,
        trigger="profile_update",
        profile_data={"gross_income": 9000.0},
        db=db,
    )

    # 2 fact_event rows for monthly_gross_income (append-only)
    fe_rows = db.query(FactEvent).filter(
        FactEvent.user_id == user_id,
        FactEvent.field_key == "monthly_gross_income",
    ).order_by(FactEvent.valid_from.asc()).all()
    assert len(fe_rows) == 2, f"expected 2 fact_event rows, got {len(fe_rows)}"

    # 1 fact_current row, latest value = 9000.0
    fc = db.query(FactCurrent).filter(
        FactCurrent.user_id == user_id,
        FactCurrent.field_key == "monthly_gross_income",
    ).one()
    assert decrypt_value(db, user_id, fc.value_enc) == 9000.0
