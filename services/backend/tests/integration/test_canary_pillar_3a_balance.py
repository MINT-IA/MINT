"""Multi-shape canary #2 — pillar_3a_balance decimal-precision parity.

iter-2 A11 + D-34 PROPOSED. Phase mint-data-architecture-v1-02 Plan 02-02
W1 continuation-4 — P4.

Asserts that encrypt_value() + project_event() + decrypt_value() round-trips
a Decimal('12345.67') value WITHOUT precision loss. The value is stored as
its canonical string form via the JSON serialiser in encrypted_value_helper
(separators=(',',':'), sort_keys=True) so decimal-precision is preserved
through the entire path. Decryption returns the string ; caller wraps in
Decimal() for comparison.
"""
from __future__ import annotations

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
from tests.fixtures.canary_fixtures import build_decimal_canary


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
    db.add(User(id=uid, email=f"{uuid4().hex[:8]}@test.local", hashed_password="x"))
    db.commit()
    return uid


def test_pillar_3a_balance_decimal_precision_roundtrip(db, user_id):
    """A11 : Decimal('12345.67') survives encrypt → project → decrypt round-trip."""
    inp, expected_str = build_decimal_canary(user_id)
    inp.value_enc = encrypt_value(db, user_id, expected_str)
    project_event(db, inp)

    row = (
        db.query(FactCurrent)
        .filter(FactCurrent.user_id == user_id, FactCurrent.field_key == "pillar_3a_balance")
        .one()
    )
    decoded = decrypt_value(db, user_id, row.value_enc)
    # JSON serialisation preserves the decimal string verbatim.
    assert decoded == expected_str
    # Decimal-wrapping returns exact precision.
    assert Decimal(decoded) == Decimal("12345.67")
