"""Phase 96 D-14 + D-15 — NarrativeSleeve schema tests +
CoachChatRequest/Response additive extension tests.

Per 96-02-PLAN.md Task 2 <behavior> Tests 1-13. Validates :
- NarrativeSleeve 4-field instantiation (Test 1)
- metaphor defaulting + frozen + extra-forbid (Tests 2-4)
- field length bounds (Tests 5-8)
- CoachChatRequest backward-compat + new fields (Tests 9-11)
- CoachChatResponse narrative_sleeve optional (Test 12)
- JSON round-trip preserves new fields (Test 13)
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.schemas.card_context import SerializedCardContext
from app.schemas.coach_chat import CoachChatRequest, CoachChatResponse
from app.schemas.narrative_sleeve import NarrativeSleeve


# ---------------------------------------------------------------------------
# Tests 1-4 — NarrativeSleeve core invariants
# ---------------------------------------------------------------------------


def test_narrative_sleeve_full_instantiation():
    """All 4 fields populated → no validation error."""
    sleeve = NarrativeSleeve(
        hook="Trois choix changent ta marge cette année.",
        caption="Le 3a 2026 a un plafond {{cite:pillar_3a.max_contribution_2026}}.",
        next_step="Ouvre le simulateur 3a.",
        metaphor="Une cave à vin qui s'enrichit chaque année.",
    )
    assert sleeve.hook == "Trois choix changent ta marge cette année."
    assert sleeve.next_step == "Ouvre le simulateur 3a."
    assert sleeve.metaphor.startswith("Une cave")


def test_narrative_sleeve_metaphor_defaults_empty():
    """metaphor defaults to empty string when no archetype/canton/event match."""
    sleeve = NarrativeSleeve(
        hook="x",
        caption="y",
        next_step="z",
    )
    assert sleeve.metaphor == ""


def test_narrative_sleeve_model_copy_update():
    """frozen=True still allows model_copy(update=…) (Pydantic v2 semantics)."""
    sleeve = NarrativeSleeve(hook="x", caption="y", next_step="z")
    updated = sleeve.model_copy(update={"hook": "new"})
    assert updated.hook == "new"
    assert sleeve.hook == "x"  # original untouched


def test_narrative_sleeve_extra_forbidden():
    """Unknown fields raise ValidationError."""
    with pytest.raises(ValidationError):
        NarrativeSleeve(
            hook="x",
            caption="y",
            next_step="z",
            unknown_field="leak",  # type: ignore[call-arg]
        )


# ---------------------------------------------------------------------------
# Tests 5-8 — field length bounds
# ---------------------------------------------------------------------------


def test_narrative_sleeve_hook_max_length():
    """hook accepts up to 200 chars ; 201 raises."""
    NarrativeSleeve(hook="a" * 200, caption="y", next_step="z")  # OK
    with pytest.raises(ValidationError):
        NarrativeSleeve(hook="a" * 201, caption="y", next_step="z")


def test_narrative_sleeve_caption_max_length():
    """caption accepts up to 2000 chars ; 2001 raises."""
    NarrativeSleeve(hook="x", caption="b" * 2000, next_step="z")  # OK
    with pytest.raises(ValidationError):
        NarrativeSleeve(hook="x", caption="b" * 2001, next_step="z")


def test_narrative_sleeve_next_step_max_length():
    """next_step accepts up to 120 chars ; 121 raises."""
    NarrativeSleeve(hook="x", caption="y", next_step="c" * 120)  # OK
    with pytest.raises(ValidationError):
        NarrativeSleeve(hook="x", caption="y", next_step="c" * 121)


def test_narrative_sleeve_metaphor_max_length():
    """metaphor accepts empty + up to 200 chars."""
    NarrativeSleeve(hook="x", caption="y", next_step="z", metaphor="")  # OK
    NarrativeSleeve(hook="x", caption="y", next_step="z", metaphor="d" * 200)  # OK
    with pytest.raises(ValidationError):
        NarrativeSleeve(hook="x", caption="y", next_step="z", metaphor="d" * 201)


# ---------------------------------------------------------------------------
# Tests 9-11 — CoachChatRequest extension (additive backward-compat)
# ---------------------------------------------------------------------------


def test_coach_chat_request_all_phase_96_fields():
    """source_card + turn_count + intent all populated → validates."""
    req = CoachChatRequest(
        message="Explique-moi mon 3a",
        source_card=SerializedCardContext(
            card_id="mon_3a_2026",
            card_type="pillar_3a",
        ),
        turn_count=2,
        intent="explain",
    )
    assert req.source_card is not None
    assert req.source_card.card_id == "mon_3a_2026"
    assert req.turn_count == 2
    assert req.intent == "explain"


def test_coach_chat_request_backward_compat_no_phase_96_fields():
    """Legacy pre-96 clients work — all Phase 96 fields are optional."""
    req = CoachChatRequest(message="hi")
    assert req.source_card is None
    assert req.turn_count == 0
    assert req.intent is None


def test_coach_chat_request_invalid_intent_rejected():
    """Literal['explain', 'reassure'] | None — anything else raises."""
    with pytest.raises(ValidationError):
        CoachChatRequest(message="hi", intent="invalid")  # type: ignore[arg-type]


# ---------------------------------------------------------------------------
# Test 12 — CoachChatResponse narrative_sleeve optional
# ---------------------------------------------------------------------------


def test_coach_chat_response_narrative_sleeve_optional():
    """narrative_sleeve defaults to None ; accepts a NarrativeSleeve instance."""
    resp_legacy = CoachChatResponse(message="ok")
    assert resp_legacy.narrative_sleeve is None

    sleeve = NarrativeSleeve(hook="x", caption="y", next_step="z")
    resp_with_sleeve = CoachChatResponse(message="ok", narrative_sleeve=sleeve)
    assert resp_with_sleeve.narrative_sleeve is not None
    assert resp_with_sleeve.narrative_sleeve.hook == "x"


# ---------------------------------------------------------------------------
# Test 13 — JSON round-trip
# ---------------------------------------------------------------------------


def test_coach_chat_request_json_round_trip():
    """model_dump_json + model_validate_json preserves Phase 96 fields."""
    req = CoachChatRequest(
        message="Explique",
        source_card=SerializedCardContext(
            card_id="x",
            card_type="y",
            life_event="housing",
        ),
        turn_count=1,
        intent="reassure",
    )
    payload = req.model_dump_json(by_alias=True)
    rehydrated = CoachChatRequest.model_validate_json(payload)
    assert rehydrated.source_card is not None
    assert rehydrated.source_card.card_id == "x"
    assert rehydrated.source_card.life_event == "housing"
    assert rehydrated.turn_count == 1
    assert rehydrated.intent == "reassure"


def test_coach_chat_response_json_round_trip():
    """Response narrative_sleeve survives JSON round-trip."""
    sleeve = NarrativeSleeve(
        hook="hook",
        caption="cap",
        next_step="step",
        metaphor="met",
    )
    resp = CoachChatResponse(message="ok", narrative_sleeve=sleeve)
    payload = resp.model_dump_json(by_alias=True)
    rehydrated = CoachChatResponse.model_validate_json(payload)
    assert rehydrated.narrative_sleeve is not None
    assert rehydrated.narrative_sleeve.hook == "hook"
    assert rehydrated.narrative_sleeve.metaphor == "met"
