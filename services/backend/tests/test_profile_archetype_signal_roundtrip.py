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


def test_pydantic_us_tax_person_int_rejected():
    """Pydantic v2 strict bool: int 1 is not accepted for Optional[bool]."""
    with pytest.raises(ValidationError):
        ProfileUpdate.model_validate({"usTaxPerson": 1})


def test_profile_response_inherits_fields():
    """Profile (response) inherits ProfileBase, so it must carry the fields too."""
    payload = _base_profile_payload()
    payload["nationality"] = "US"
    payload["usTaxPerson"] = True
    p = Profile.model_validate(payload)
    assert p.nationality == "US"
    assert p.usTaxPerson is True
