"""Multi-shape canary #4 — lpp_avoirs_vieillesse nullable parity.

iter-2 A11 + D-34 PROPOSED. Phase mint-data-architecture-v1-02 Plan 02-02
W1 continuation-4 — P4.

A user without an LPP plan : the field is None. Encrypting JSON `null`
produces a valid D-26 envelope ; decrypting returns Python None. Parity
contract : the comparator equals the decrypted value (None == None).
"""
from __future__ import annotations

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
from tests.fixtures.canary_fixtures import build_nullable_canary


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


def test_lpp_avoirs_nullable_roundtrip_preserves_none(db, user_id):
    """A11 : None survives JSON-null encryption + projection + decryption."""
    inp, expected = build_nullable_canary(user_id)
    assert expected is None
    inp.value_enc = encrypt_value(db, user_id, expected)
    project_event(db, inp)

    row = (
        db.query(FactCurrent)
        .filter(
            FactCurrent.user_id == user_id,
            FactCurrent.field_key == "lpp_avoirs_vieillesse",
        )
        .one()
    )
    decoded = decrypt_value(db, user_id, row.value_enc)
    assert decoded is None, f"expected None, got {decoded!r}"
