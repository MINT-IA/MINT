"""R6 roundtrip preservation tests — sub-phase 01.5 archetype HARD GATE.

Guards against the silent FATCA-signal erasure that would occur if Pydantic
stripped usTaxPerson / nationality on response serialization.

Reference: .planning/phases/01.5-archetype-hard-gate-fatca/01.5-REVIEWS.md §R4 + §R6.
"""
from datetime import datetime

import pytest
from pydantic import ValidationError

from app.schemas.profile import Profile, ProfileUpdate


def _base_profile_payload() -> dict:
    return {
        "householdType": "single",
        "id": "test-id",
        "createdAt": datetime.utcnow().isoformat(),
    }


def test_pydantic_roundtrip_preserves_us_tax_person_true():
    update = ProfileUpdate(usTaxPerson=True, nationality="US")
    dumped = update.model_dump()
    assert dumped["usTaxPerson"] is True
    assert dumped["nationality"] == "US"
    re_parsed = ProfileUpdate.model_validate(dumped)
    assert re_parsed.usTaxPerson is True
    assert re_parsed.nationality == "US"


def test_pydantic_roundtrip_preserves_us_tax_person_false():
    update = ProfileUpdate(usTaxPerson=False)
    assert update.usTaxPerson is False
    re_parsed = ProfileUpdate.model_validate(update.model_dump())
    assert re_parsed.usTaxPerson is False  # NOT None, NOT True


def test_pydantic_roundtrip_preserves_us_tax_person_null():
    """R4 tri-state guard: explicit None must survive as None, never coerced to False."""
    update = ProfileUpdate(usTaxPerson=None)
    assert update.usTaxPerson is None
    re_parsed = ProfileUpdate.model_validate(update.model_dump())
    assert re_parsed.usTaxPerson is None  # critical: NOT False


def test_pydantic_default_us_tax_person_is_none():
    update = ProfileUpdate()
    assert update.usTaxPerson is None
    assert update.nationality is None


def test_pydantic_nationality_ch_preserved():
    update = ProfileUpdate(nationality="CH")
    assert update.nationality == "CH"


def test_pydantic_nationality_us_preserved():
    update = ProfileUpdate(nationality="US")
    assert update.nationality == "US"


def test_pydantic_nationality_max_length():
    with pytest.raises(ValidationError):
        ProfileUpdate(nationality="A" * 100)


def test_pydantic_nationality_int_rejected():
    """Plan Task 1 behavior Test 8: non-string nationality is rejected."""
    with pytest.raises(ValidationError):
        ProfileUpdate.model_validate({"nationality": 123})


def test_pydantic_us_tax_person_non_coercible_rejected():
    """A non-bool, non-numeric, non-string-bool input is rejected.

    Note: Pydantic v2 in default (lax) mode intentionally coerces 0/1 and
    'true'/'false' to bool — this is documented Pydantic behavior and is
    NOT a tri-state bug because the coercion still yields True/False, not None.
    The R4 guard is about None vs False — proven by the _null / _false tests above.
    Here we assert that genuinely non-bool inputs (a dict) are rejected.
    """
    with pytest.raises(ValidationError):
        ProfileUpdate.model_validate({"usTaxPerson": {"not": "a bool"}})


def test_profile_response_inherits_fields():
    """Profile (response) inherits ProfileBase, so it must carry the fields too."""
    payload = _base_profile_payload()
    payload["nationality"] = "US"
    payload["usTaxPerson"] = True
    p = Profile.model_validate(payload)
    assert p.nationality == "US"
    assert p.usTaxPerson is True
