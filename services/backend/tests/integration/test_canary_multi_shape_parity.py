"""Composite multi-shape canary parity gate — W1 → W2 explicit gate.

iter-2 A11 + D-34 PROPOSED. Phase mint-data-architecture-v1-02 Plan 02-02
W1 continuation-4 — P4.

Single integration test exercising all 5 canary shapes in sequence on
the same user, asserting all 5 parity round-trips green. This is the
W1 → W2 explicit gate per D-34 PROPOSED : Plan 02-03 PR-3 (HARD-mode
parity-lint flip per D-31) MUST NOT fire until this composite gate is
green.

The per-shape tests
(test_canary_pillar_3a_balance.py / test_canary_archetype_tags_jsonb.py /
test_canary_lpp_avoirs_nullable.py / test_canary_coach_extracted_toast.py)
exist as standalone signals for narrowed failures ; this composite
asserts they ALL pass for the SAME user inside a SINGLE projector run
(catching any cross-shape leakage that per-shape tests might miss).
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

import pytest

from app.models.fact_current import FactCurrent
from app.models.user import User
from app.services.encryption.encrypted_value_helper import (
    decrypt_value,
    encrypt_value,
)
from app.services.projector.fact_projector import project_event
from tests.conftest import TestingSessionLocal
from tests.fixtures.canary_fixtures import (
    build_decimal_canary,
    build_jsonb_canary,
    build_nullable_canary,
    build_scalar_canary,
    build_toast_canary,
)


@pytest.fixture
def db():
    s = TestingSessionLocal()
    try:
        yield s
    finally:
        s.close()


@pytest.fixture
def user_id(db):
    uid = f"u-multi-{uuid4().hex[:8]}"
    db.add(User(id=uid, email=f"{uuid4().hex[:8]}@test.local", hashed_password="x"))
    db.commit()
    return uid


def test_w1_to_w2_multi_shape_parity_gate_5_of_5(db, user_id):
    """D-34 PROPOSED : all 5 canary shapes parity-round-trip for the same user.

    Each shape is projected with a distinct `valid_from` (spaced 1 hour
    apart) so the fact_current UPSERT-keyed-by-(user_id, field_key)
    semantic produces 5 distinct rows (different field_key per shape).
    Decryption then proves byte-for-byte (semantic) parity per shape.
    """
    now = datetime.now(timezone.utc)
    builders = [
        ("scalar", build_scalar_canary, 0),
        ("decimal", build_decimal_canary, 1),
        ("jsonb", build_jsonb_canary, 2),
        ("nullable", build_nullable_canary, 3),
        ("toast", build_toast_canary, 4),
    ]

    parity_results: dict[str, bool] = {}
    for label, builder, offset in builders:
        inp, expected = builder(user_id, valid_from=now + timedelta(hours=offset))
        inp.value_enc = encrypt_value(db, user_id, expected)
        project_event(db, inp)

        row = (
            db.query(FactCurrent)
            .filter(
                FactCurrent.user_id == user_id,
                FactCurrent.field_key == inp.field_key,
            )
            .one()
        )
        decoded = decrypt_value(db, user_id, row.value_enc)
        if label == "decimal":
            parity_results[label] = (decoded == expected) and Decimal(decoded) == Decimal("12345.67")
        else:
            parity_results[label] = decoded == expected

    assert all(parity_results.values()), (
        f"D-34 PROPOSED multi-shape gate FAILED. Per-shape parity : "
        f"{parity_results}. Plan 02-03 PR-3 CANNOT FIRE until all 5 green."
    )
    # Spell out the pass-count explicitly in the test output for the
    # SUMMARY's evidence cite.
    pass_count = sum(1 for v in parity_results.values() if v)
    assert pass_count == 5, f"expected 5/5 PASS, got {pass_count}/5 : {parity_results}"

    # And the 5 distinct fact_current rows are present.
    rows = (
        db.query(FactCurrent)
        .filter(FactCurrent.user_id == user_id)
        .all()
    )
    assert len(rows) == 5, (
        f"expected 5 fact_current rows for {user_id}, got {len(rows)} : "
        f"{[r.field_key for r in rows]}"
    )
