"""Wave 1c-A3 (D-A3-05 #1) — for each of the 5 chip-emitters:

- blank profile + tool-eligible question → CoachToolIncomplete payload.
- complete profile → CoachToolOk payload.
- partial profile (1 field missing) → missing_fields == [<the one>].

Path note: lives at tests/test_coach_chat_missing_fields_handshake.py under
the FLAT tests/test_*.py convention (no subdirectory).
"""
import pytest

from app.api.v1.endpoints.coach_chat import (
    _CHIP_EMITTER_REQUIRED_FIELDS,
    _missing_fields_for,
)
from app.models.coach_tools._response import (
    CoachToolIncomplete,
    CoachToolOk,
    CoachToolResponse,
)


_CHIPS = sorted(_CHIP_EMITTER_REQUIRED_FIELDS.keys())


@pytest.mark.parametrize("name", _CHIPS)
def test_blank_profile_yields_incomplete(name: str) -> None:
    missing = _missing_fields_for(name, profile_context={})
    assert missing, f"{name} should report missing fields on blank profile"
    assert len(missing) <= 3, "cap=3 per D-A3-01"


@pytest.mark.parametrize("name", _CHIPS)
def test_complete_profile_yields_ok(name: str) -> None:
    required = _CHIP_EMITTER_REQUIRED_FIELDS[name]
    # Any truthy value satisfies the gate.
    full_ctx = {k: 1 for k in required}
    missing = _missing_fields_for(name, profile_context=full_ctx)
    assert missing == [], (
        f"{name} should have no missing fields on complete profile; got {missing}"
    )


@pytest.mark.parametrize("name", _CHIPS)
def test_partial_profile_one_field_missing(name: str) -> None:
    required = _CHIP_EMITTER_REQUIRED_FIELDS[name]
    if len(required) < 2:
        pytest.skip(f"{name} only has {len(required)} field — partial case n/a")
    # Provide all but the FIRST required field.
    ctx = {k: 1 for k in required[1:]}
    missing = _missing_fields_for(name, profile_context=ctx)
    assert missing == [required[0]], (
        f"{name} expected [{required[0]}], got {missing}"
    )


def test_incomplete_payload_validates_cap_and_min_length() -> None:
    """CoachToolIncomplete enforces cap=3 + min_length on missing_fields + hint_fr."""
    # Happy path
    ok = CoachToolResponse.model_validate({
        "status": "incomplete",
        "missingFields": ["age"],
        "hintFr": "Pour calculer, j'ai besoin de ton âge.",
    })
    assert isinstance(ok.root, CoachToolIncomplete)
    # Cap=3 violation
    with pytest.raises(Exception):
        CoachToolResponse.model_validate({
            "status": "incomplete",
            "missingFields": ["a", "b", "c", "d"],
            "hintFr": "trop de champs aaaaaaaaaa",
        })
    # Empty missing_fields rejected
    with pytest.raises(Exception):
        CoachToolResponse.model_validate({
            "status": "incomplete",
            "missingFields": [],
            "hintFr": "vide aaaaaaaaaa",
        })
