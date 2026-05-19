"""Multi-shape canary #5 — coach_extracted_facts ≥4KB TOAST blob parity.

iter-2 A11 + D-34 PROPOSED. Phase mint-data-architecture-v1-02 Plan 02-02
W1 continuation-4 — P4.

A 4KB synthetic payload pushes Postgres value_enc storage into the TOAST
table (threshold ~2KB). SQLite has no TOAST analogue ; the test still
passes (the parity contract is dialect-independent at the application
layer ; the dialect-specific size assertion is a soft signal logged
into the test output rather than a hard precondition).
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
from tests.fixtures.canary_fixtures import build_toast_canary


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


def test_coach_extracted_facts_toast_blob_4kb_roundtrip(db, user_id):
    """A11 : 4KB payload survives encrypt + project + decrypt round-trip."""
    inp, expected = build_toast_canary(user_id, blob_size_bytes=4096)
    assert len(expected["facts"][0]) == 4096

    inp.value_enc = encrypt_value(db, user_id, expected)
    project_event(db, inp)

    row = (
        db.query(FactCurrent)
        .filter(
            FactCurrent.user_id == user_id,
            FactCurrent.field_key == "coach_extracted_facts",
        )
        .one()
    )
    decoded = decrypt_value(db, user_id, row.value_enc)
    assert decoded == expected
    assert len(decoded["facts"][0]) == 4096
    # Encrypted envelope `ct` length includes nonce overhead ; sanity-check
    # that the wrapped ciphertext is at least as long as the plaintext.
    assert len(row.value_enc["ct"]) > 4000, (
        f"TOAST canary : ciphertext suspiciously small ({len(row.value_enc['ct'])} chars)"
    )
