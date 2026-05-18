"""Multi-shape canary #3 — archetype_tags nested JSONB parity.

iter-2 A11 + D-34 PROPOSED. Phase mint-data-architecture-v1-02 Plan 02-02
W1 continuation-4 — P4.
"""
from __future__ import annotations

from datetime import datetime, timezone
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
from tests.fixtures.canary_fixtures import build_jsonb_canary


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


def test_archetype_tags_nested_jsonb_deep_equality(db, user_id):
    """A11 : nested dict + list survive deep-equality round-trip."""
    inp, expected = build_jsonb_canary(user_id)
    inp.value_enc = encrypt_value(db, user_id, expected)
    project_event(db, inp)

    row = (
        db.query(FactCurrent)
        .filter(FactCurrent.user_id == user_id, FactCurrent.field_key == "archetype_tags")
        .one()
    )
    decoded = decrypt_value(db, user_id, row.value_enc)
    assert decoded == expected
    # Spot-check deep structure preservation.
    assert decoded["tags"] == ["expat_eu", "frontalier"]
    assert decoded["confidence_per_tag"]["expat_eu"]["score"] == 0.85
    assert decoded["confidence_per_tag"]["frontalier"]["score"] == 0.78
