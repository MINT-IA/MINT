"""
Tests — CoachContext.has_debt field wiring.

Covers:
- build_coach_context(has_debt=True) → ctx.has_debt is True
- build_coach_context() default → ctx.has_debt is False
- build_coach_context(has_debt=None) → ctx.has_debt is False (defensive bool coercion)
- CoachContext() direct default → has_debt is False
- Truthy non-bool values are coerced to bool (string "true", int 1)
"""

import pytest

from app.services.coach.coach_context_builder import build_coach_context
from app.services.coach.coach_models import CoachContext


def test_has_debt_true_passed_through():
    ctx = build_coach_context(has_debt=True)
    assert ctx.has_debt is True


def test_has_debt_false_default():
    ctx = build_coach_context()
    assert ctx.has_debt is False


def test_has_debt_explicit_false():
    ctx = build_coach_context(has_debt=False)
    assert ctx.has_debt is False


def test_has_debt_none_coerced_to_false():
    # bool(None) == False — defensive coercion in builder
    ctx = build_coach_context(has_debt=None)
    assert ctx.has_debt is False


def test_has_debt_int_1_coerced_to_true():
    # bool(1) == True
    ctx = build_coach_context(has_debt=1)
    assert ctx.has_debt is True


def test_has_debt_int_0_coerced_to_false():
    ctx = build_coach_context(has_debt=0)
    assert ctx.has_debt is False


def test_coach_context_dataclass_default():
    ctx = CoachContext()
    assert ctx.has_debt is False


def test_coach_context_dataclass_explicit_true():
    ctx = CoachContext(has_debt=True)
    assert ctx.has_debt is True


def test_has_debt_does_not_affect_other_fields():
    ctx = build_coach_context(has_debt=True, age=42, canton="VS")
    assert ctx.age == 42
    assert ctx.canton == "VS"
    assert ctx.has_debt is True
