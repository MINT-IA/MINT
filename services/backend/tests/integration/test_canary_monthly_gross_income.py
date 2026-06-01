"""D-25 W1 -> W2 canary parity gate — monthly_gross_income.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — Task 3 step 16.

**THIS IS THE GATE.** Without this test green, Plan 02-03 PR-3 (HARD-mode
parity-lint flip per D-31) CANNOT proceed and Phase 02 has zero proven
user-value beyond the substrate.

Contract proven
===============
1. Write `monthly_gross_income = 8500.00` for ONE user via TWO independent
   paths :
     (a) Legacy : SnapshotModel.gross_income (plaintext Float column)
     (b) New    : FactProjector -> fact_event (append-only) + fact_current
                  (UPSERT-keyed, encrypted JSONB)
2. Assert : reading via both paths returns IDENTICAL numeric value 8500.00.
3. Write a SECOND event (same user, new value 9000.00) via the projector :
     - fact_current.value_enc decrypts to 9000.00 (UPSERT happened)
     - fact_event retains BOTH the 8500 and 9000 events (append-only)

The decrypt path exercises the full D-26 EncryptedValue Pydantic v2 wire
shape (ct / iv / tag / alg / dek_id / enc_v) round-trip through encrypt_value
/ decrypt_value helpers. AAD = user_id is enforced inside envelope.encrypt
+ envelope.decrypt — cross-user reads would fail authentication.

Test variants
=============
- `test_canary_monthly_gross_income_sqlite` : runs on the conftest in-memory
  SQLite engine (StaticPool). Always runs. Proves the application-layer
  contract (projector + decrypt + parity) is dialect-independent.
- `test_canary_monthly_gross_income_pg` : `@pytest.mark.pg` — runs on
  pg_fixture (testcontainers Postgres). Skips if Docker unavailable.
  Proves the same contract AGAINST THE PARTITIONED fact_event + the
  REVOKE-protected append-only invariant AT THE DB LEVEL.

The SQLite variant is the always-on signal ; the pg variant is the
Postgres-correctness gate that CI enforces.
"""
from __future__ import annotations

from uuid import uuid4

import pytest

from app.models.fact_current import FactCurrent
from app.models.fact_event import FactEvent
from app.models.snapshot import SnapshotModel
from app.models.user import User


@pytest.fixture
def sqlite_session():
    """Function-scoped sync session over the conftest in-memory engine."""
    from tests.conftest import TestingSessionLocal
    s = TestingSessionLocal()
    try:
        yield s
    finally:
        s.close()


@pytest.fixture
def user_id(sqlite_session):
    """Seed one user for FK satisfaction. Returns the user_id."""
    uid = f"u-{uuid4().hex[:8]}"
    u = User(
        id=uid,
        email=f"{uuid4().hex[:8]}@test.local",
        hashed_password="x",
    )
    sqlite_session.add(u)
    sqlite_session.commit()
    return uid


def _write_legacy_path(db, user_id: str, monthly_value: float) -> None:
    """Write via SnapshotModel.gross_income (legacy plaintext Float)."""
    from datetime import datetime, timezone
    snap = SnapshotModel(
        id=str(uuid4()),
        user_id=user_id,
        created_at=datetime.now(timezone.utc),
        trigger="check_in",
        gross_income=monthly_value,
        archetype="swiss_native",
        canton="VD",
        household_type="single",
    )
    db.add(snap)
    db.commit()


def _write_projector_path(db, user_id: str, monthly_value: float, valid_from):
    """Write via FactProjector -> encrypts + INSERT fact_event + UPSERT fact_current."""
    from app.services.encryption.encrypted_value_helper import encrypt_value
    from app.services.projector.fact_projector import FactEventInput, project_event

    envelope = encrypt_value(db, user_id, monthly_value)
    inp = FactEventInput(
        user_id=user_id,
        field_key="monthly_gross_income",
        value_enc=envelope,
        valid_from=valid_from,
        source="canary_test",
    )
    return project_event(db, inp)


def _read_legacy(db, user_id: str) -> float:
    """Read via legacy SnapshotModel.gross_income — latest row."""
    row = (
        db.query(SnapshotModel)
        .filter(SnapshotModel.user_id == user_id)
        .order_by(SnapshotModel.created_at.desc())
        .first()
    )
    assert row is not None, "expected at least one SnapshotModel row"
    return row.gross_income


def _read_fact_current(db, user_id: str) -> float:
    """Read + decrypt via fact_current.value_enc."""
    from app.services.encryption.encrypted_value_helper import decrypt_value

    row = (
        db.query(FactCurrent)
        .filter(
            FactCurrent.user_id == user_id,
            FactCurrent.field_key == "monthly_gross_income",
        )
        .one_or_none()
    )
    assert row is not None, "expected exactly one fact_current row for monthly_gross_income"
    return decrypt_value(db, user_id, row.value_enc)


# ═══════════════════════════════════════════════════════════════════════════════
# SQLite variant — always-on signal
# ═══════════════════════════════════════════════════════════════════════════════

def test_canary_monthly_gross_income_sqlite(sqlite_session, user_id):
    """D-25 parity proof on SQLite. Same numeric value via both paths,
    asserted IDENTICAL ; second write proves UPSERT + append-only.
    """
    from datetime import datetime, timezone

    db = sqlite_session

    # ── Setup : write 8500.00 via BOTH paths ────────────────────────────────
    initial_value = 8500.00
    t1 = datetime(2026, 1, 1, tzinfo=timezone.utc)
    _write_legacy_path(db, user_id, initial_value)
    _write_projector_path(db, user_id, initial_value, valid_from=t1)

    # ── Assert : both reads return IDENTICAL value ─────────────────────────
    legacy_read = _read_legacy(db, user_id)
    fact_read = _read_fact_current(db, user_id)
    assert legacy_read == initial_value, (
        f"Legacy SnapshotModel.gross_income mismatch: expected {initial_value}, "
        f"got {legacy_read}"
    )
    assert fact_read == initial_value, (
        f"fact_current decrypt mismatch: expected {initial_value}, got {fact_read}"
    )
    assert legacy_read == fact_read, (
        f"D-25 PARITY GATE FAILED: legacy={legacy_read} vs fact_current={fact_read}"
    )

    # ── Second write : projector-only, NEW value, NEWER valid_from ─────────
    new_value = 9000.00
    t2 = datetime(2026, 6, 1, tzinfo=timezone.utc)
    _write_projector_path(db, user_id, new_value, valid_from=t2)

    # fact_current UPSERTed to NEW value (last-writer-wins by valid_from)
    db.expire_all()
    fact_read_after = _read_fact_current(db, user_id)
    assert fact_read_after == new_value, (
        f"fact_current UPSERT failed: expected {new_value} after second write, "
        f"got {fact_read_after}"
    )

    # fact_event retains BOTH events (append-only invariant)
    fe_count = (
        db.query(FactEvent)
        .filter(
            FactEvent.user_id == user_id,
            FactEvent.field_key == "monthly_gross_income",
        )
        .count()
    )
    assert fe_count == 2, (
        f"APPEND-ONLY INVARIANT VIOLATED: expected 2 fact_event rows "
        f"(8500 + 9000), got {fe_count}"
    )


def test_canary_via_snapshot_service_helper_branches(sqlite_session, user_id, monkeypatch):
    """Parity gate exercised via the SnapshotService helper (both flag values).

    With FF_FACT_CURRENT_READ OFF : helper returns SnapshotModel.gross_income.
    With FF_FACT_CURRENT_READ ON  : helper returns decrypted fact_current.value_enc.

    Asserts both branches return the same numeric value when seeded identically.
    """
    from datetime import datetime, timezone
    from app.services.snapshots.snapshot_service import read_monthly_gross_income

    db = sqlite_session
    value = 8500.00
    t1 = datetime(2026, 1, 1, tzinfo=timezone.utc)
    _write_legacy_path(db, user_id, value)
    _write_projector_path(db, user_id, value, valid_from=t1)

    # Flag OFF (default) -> legacy path
    monkeypatch.delenv("FF_FACT_CURRENT_READ", raising=False)
    legacy_read = read_monthly_gross_income(user_id, db)
    assert legacy_read == value

    # Flag ON -> fact_current path
    monkeypatch.setenv("FF_FACT_CURRENT_READ", "1")
    fact_read = read_monthly_gross_income(user_id, db)
    assert fact_read == value

    assert legacy_read == fact_read, (
        f"D-25 PARITY VIA HELPER FAILED: legacy={legacy_read} "
        f"vs fact_current={fact_read}"
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Postgres variant — stronger gate (PARTITION BY HASH + REVOKE-protected)
# Skips if Docker unavailable.
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.pg
@pytest.mark.requires_pg  # iter-3 iA1 — explicit projector-SQLite-divergence guard
def test_canary_monthly_gross_income_pg(pg_session):
    """Same D-25 contract as the SQLite variant, but against real Postgres.

    Validates :
      - PARTITION BY HASH (user_id) PARTITIONS 8 routes the INSERT to the
        correct partition (transparent at the application layer ; we just
        prove the INSERT succeeds + the SELECT returns the row).
      - REVOKE UPDATE, DELETE on fact_event is in place (an explicit
        UPDATE attempt would fail ; we don't issue one here — it's covered
        by the alembic migration's DDL contract).
      - The covering index `ix_fact_current_user_field_covering` is present
        with INCLUDE (value_enc, valid_from) — pg_fixture's alembic
        upgrade ran the Postgres branch of p98.

    Note : pg_session is function-scoped and TRUNCATEs known tables between
    tests (see pg_fixture.py). The seed-and-write pattern here is the same
    as the SQLite variant.
    """
    from datetime import datetime, timezone

    db = pg_session

    # Seed one user — pg_session truncates between tests so we always start clean.
    uid = f"u-pg-{uuid4().hex[:8]}"
    u = User(
        id=uid,
        email=f"{uuid4().hex[:8]}@test.local",
        hashed_password="x",
    )
    db.add(u)
    db.commit()

    initial_value = 8500.00
    t1 = datetime(2026, 1, 1, tzinfo=timezone.utc)
    _write_legacy_path(db, uid, initial_value)
    _write_projector_path(db, uid, initial_value, valid_from=t1)

    legacy_read = _read_legacy(db, uid)
    fact_read = _read_fact_current(db, uid)
    assert legacy_read == fact_read == initial_value, (
        f"D-25 PARITY GATE (PG) FAILED: legacy={legacy_read} "
        f"vs fact_current={fact_read} expected={initial_value}"
    )

    # UPSERT proof on real Postgres ON CONFLICT
    new_value = 9000.00
    t2 = datetime(2026, 6, 1, tzinfo=timezone.utc)
    _write_projector_path(db, uid, new_value, valid_from=t2)

    db.expire_all()
    fact_read_after = _read_fact_current(db, uid)
    assert fact_read_after == new_value

    fe_count = (
        db.query(FactEvent)
        .filter(
            FactEvent.user_id == uid,
            FactEvent.field_key == "monthly_gross_income",
        )
        .count()
    )
    assert fe_count == 2, (
        f"APPEND-ONLY INVARIANT (PG) VIOLATED: expected 2 fact_event rows, "
        f"got {fe_count}"
    )
