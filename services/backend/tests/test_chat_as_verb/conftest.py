"""Phase 96 test fixtures for chat_as_verb test suite.

Per 96-02-PLAN.md Task 1 step 3 — shared fixtures consumed by all 6
test files in this directory.
"""
from __future__ import annotations

from decimal import Decimal

import pytest


@pytest.fixture
def serialized_card_context_full():
    """7-field SerializedCardContext fixture covering the full schema surface."""
    from app.schemas.card_context import SerializedCardContext

    return SerializedCardContext(
        card_id="mon_3a_2026",
        card_type="pillar_3a",
        computed_facts={
            "annual_contribution_chf": Decimal("7056.00"),
            "years_until_retirement": 22,
            "frequency_note": "annual",
        },
        grounding_keys=["pillar_3a.max_contribution_2026"],
        life_event="retirement",
        canton="VD",
        archetype="swiss_native",
    )


@pytest.fixture
def serialized_card_context_minimal():
    """Minimal SerializedCardContext with only required fields populated."""
    from app.schemas.card_context import SerializedCardContext

    return SerializedCardContext(card_id="x", card_type="y")


@pytest.fixture(autouse=False)
def turn_counter_reset():
    """Reset the in-memory TURN_COUNTER between tests that need isolation.

    Opt-in via explicit fixture request (not autouse) so legacy tests that
    do not import the turn_cap module are unaffected.
    """
    from app.services.coach.turn_cap import reset

    reset()
    yield
    reset()
