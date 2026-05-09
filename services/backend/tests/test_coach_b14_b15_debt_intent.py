"""B14 + B15 regression tests — debt-context coach gating.

B14: detect user intent (debt / housing / family / ...) from message and
augment system prompt + suggest_actions chips so an « j'ai des dettes »
query does NOT surface mortgage-amortissement education content as the
top response framing.

B15: skip generic profile-gap chips on suggest_actions when the user
already volunteered concrete facts in the same turn (numbers, CHF
amounts, percentages, dates) AND a save_fact ran for the same turn.

Device finding 2026-05-08 by Julien (TestFlight v2.12.2+4).
Perimeter STUB: .planning/decisions/2026-05-09-perimeter-b14-b15-debt-context-rag/STUB.md
"""

from __future__ import annotations

from unittest.mock import MagicMock

from app.api.v1.endpoints.coach_chat import (
    _classify_user_intent,
    _compute_suggested_actions,
    _has_concrete_facts,
)


# ---------------------------------------------------------------------------
# B14 — intent classifier
# ---------------------------------------------------------------------------


def test_b14_classify_debt_intent_on_bare_dette():
    """« j'ai des dettes » → {debt}. The bare debt declaration is the
    exact device-reported case from 2026-05-08 (TestFlight v2.12.2+4).
    """
    intents = _classify_user_intent("j'ai des dettes")
    assert "debt" in intents
    assert "housing" not in intents


def test_b14_classify_diacritics_robust():
    """The classifier strips diacritics so « endetté » matches « endette ».
    Without diacritic normalization, half the French keywords would miss.
    """
    intents = _classify_user_intent("je suis très endetté depuis 2024")
    assert "debt" in intents


def test_b14_classify_multi_intent_debt_and_housing():
    """« j'ai des dettes mais je veux acheter » → {debt, housing}.
    Multi-intent detection prevents starving the LLM of legitimate
    cross-topic context (e.g. user asking whether to amortize mortgage
    faster to reduce overall debt load).
    """
    intents = _classify_user_intent("j'ai des dettes mais je veux acheter une maison")
    assert "debt" in intents
    assert "housing" in intents


def test_b14_classify_empty_message_returns_empty_set():
    """Edge case: None / empty string → empty set, not crash."""
    assert _classify_user_intent(None) == set()
    assert _classify_user_intent("") == set()
    assert _classify_user_intent("   ") == set()


def test_b14_classify_no_keyword_returns_empty():
    """Vague messages don't fire any intent. Keeps the prompt augmentation
    additive — when intent is unclear, the LLM gets no extra guidance.
    """
    intents = _classify_user_intent("salut, comment ça va")
    assert intents == set()


# ---------------------------------------------------------------------------
# B15 — concrete-fact detection
# ---------------------------------------------------------------------------


def test_b15_concrete_facts_amount_and_percent():
    """« 50000 CHF à 8% » contains 2 concrete-fact signals (amount + %)."""
    assert _has_concrete_facts("j'ai 50000 CHF de dettes à 8%") is True


def test_b15_concrete_facts_below_threshold():
    """Single signal (just an amount, no % or year) is NOT enough — the
    threshold is 2+ signals so a vague « 50k » alone doesn't trigger.
    """
    assert _has_concrete_facts("j'ai 50 CHF") is False


def test_b15_concrete_facts_bare_message():
    """« j'ai des dettes » bare → no concrete facts → False.
    This is the case where generic profile-gap chips SHOULD still fire.
    """
    assert _has_concrete_facts("j'ai des dettes") is False


def test_b15_concrete_facts_amount_and_year():
    """Year + amount combined → True. « depuis 2024 » with « 50k » counts."""
    assert _has_concrete_facts("j'ai 50000 CHF de dettes depuis 2024") is True


# ---------------------------------------------------------------------------
# B14 + B15 integration via _compute_suggested_actions
# ---------------------------------------------------------------------------


def _profile_mock(profile_data: dict) -> MagicMock:
    fake_profile = MagicMock()
    fake_profile.data = profile_data
    fake_db = MagicMock()
    fake_db.query.return_value.filter.return_value.order_by.return_value.first.return_value = (
        fake_profile
    )
    return fake_db


def test_b14_debt_intent_emits_debt_chips_first():
    """When detected_intents={debt} and user has no totalDebt yet, the
    first chip asks for the debt amount — NOT generic « D'où vient ton
    argent ».
    """
    db = _profile_mock({"birthYear": 1990, "canton": "VD"})
    actions = _compute_suggested_actions(
        user_id="u1",
        db=db,
        last_user_message="j'ai des dettes",
        detected_intents={"debt"},
        fact_keys_saved_this_turn=[],
    )
    labels = [a["label"] for a in actions]
    assert any("dettes" in label.lower() for label in labels), (
        f"Expected debt-related chip in {labels!r}"
    )


def test_b15_skip_generic_chips_when_facts_dense():
    """User said « j'ai 50000 CHF de dettes à 8% » + save_fact ran for
    totalDebt + intent=debt. The chips must NOT include generic « D'où
    vient ton argent » even though incomeNetMonthly is still missing.
    """
    db = _profile_mock(
        {
            "birthYear": 1990,
            "canton": "VD",
            "hasDebt": True,
            "totalDebt": 50000,
            # incomeNetMonthly intentionally MISSING — the legacy chip
            # would fire here if the B15 gate is broken.
        }
    )
    actions = _compute_suggested_actions(
        user_id="u1",
        db=db,
        last_user_message="j'ai 50000 CHF de dettes à 8%",
        detected_intents={"debt"},
        fact_keys_saved_this_turn=["totalDebt"],
    )
    labels = [a["label"] for a in actions]
    money_chip = any("D'où vient ton argent" in label for label in labels)
    assert not money_chip, (
        f"B15 broken — generic income chip fired even though user gave "
        f"concrete debt facts. Actions: {labels!r}"
    )


def test_b15_keep_generic_chips_when_no_facts_given():
    """Backward-compat: when user message has no concrete facts AND no
    save_fact ran, the legacy generic chips (B2 « D'où vient ton argent »)
    still fire as before. B15 must not regress the bare-onboarding flow.
    """
    db = _profile_mock({})  # empty profile — early-onboarding state
    actions = _compute_suggested_actions(
        user_id="u1",
        db=db,
        last_user_message="bonjour",
        detected_intents=set(),
        fact_keys_saved_this_turn=[],
    )
    labels = [a["label"] for a in actions]
    # birthYear + canton missing → those chips fire first (3-chip cap)
    age_chip = any("âge" in label.lower() or "age" in label.lower() for label in labels)
    canton_chip = any("canton" in label.lower() for label in labels)
    assert age_chip, f"Age chip missing in {labels!r}"
    assert canton_chip, f"Canton chip missing in {labels!r}"


def test_b14_no_intent_no_kwargs_backward_compat():
    """Calling _compute_suggested_actions with no kwargs (legacy contract)
    must still work. The function gained optional params in B14+B15 — they
    must default to safe values and preserve pre-B14 behavior.
    """
    db = _profile_mock({"birthYear": 1990})
    actions = _compute_suggested_actions(user_id="u1", db=db)
    assert isinstance(actions, list)
    assert all("label" in a and "type" in a for a in actions)
