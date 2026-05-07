"""Phase 96-03 OBS-03 — happy-path tag emission unit tests.

Validates that the helper sets exactly the 4 Sentry tags required by
ROADMAP success criterion #3:
    eclairage_kind, banned_term_hit, eval_score, archetype

with the exact value contracts documented in
``services/backend/app/utils/sentry_audit_tags.py``.

This is a UNIT test — it monkeypatches ``sentry_sdk.set_tag`` with a
recorder. It does NOT spin up the FastAPI app (that lives in the
integration test in test_audit_log_emit_on_coach_chat.py).
"""
from __future__ import annotations

import sys
import types

import pytest


@pytest.fixture
def fake_sentry(monkeypatch):
    """Inject a fake ``sentry_sdk`` module that records every set_tag call."""
    calls: list[tuple[str, str]] = []

    fake = types.ModuleType("sentry_sdk")

    def _set_tag(name: str, value: str) -> None:
        calls.append((name, value))

    def _add_breadcrumb(**_kwargs):  # pragma: no cover — happy path doesn't use it
        pass

    fake.set_tag = _set_tag
    fake.add_breadcrumb = _add_breadcrumb

    monkeypatch.setitem(sys.modules, "sentry_sdk", fake)
    return calls


def test_happy_path_sets_four_tags_with_expected_values(fake_sentry):
    """Authed /coach/chat normal-path inputs produce the 4 contract tags."""
    from app.utils.sentry_audit_tags import emit_sentry_audit_tags

    emit_sentry_audit_tags(
        eclairage_kind="fiscal_margin_3a",
        banned_term_hit=False,
        eval_score="unavailable",
        archetype="swiss_native",
    )

    assert fake_sentry == [
        ("eclairage_kind", "fiscal_margin_3a"),
        ("banned_term_hit", "false"),
        ("eval_score", "unavailable"),
        ("archetype", "swiss_native"),
    ]


def test_eclairage_kind_none_serialises_to_string_none(fake_sentry):
    """``None`` eclairage_kind becomes the string ``"none"`` (filterable)."""
    from app.utils.sentry_audit_tags import emit_sentry_audit_tags

    emit_sentry_audit_tags(
        eclairage_kind=None,
        banned_term_hit=True,
        eval_score="unavailable",
        archetype=None,
    )

    tags = dict(fake_sentry)
    assert tags["eclairage_kind"] == "none"
    assert tags["banned_term_hit"] == "true"
    assert tags["archetype"] == "unknown"


def test_eval_score_float_caps_to_two_decimals(fake_sentry):
    """A numeric eval_score is formatted to 2 decimals per the tag contract."""
    from app.utils.sentry_audit_tags import emit_sentry_audit_tags

    emit_sentry_audit_tags(
        eclairage_kind="fatca_handoff",
        banned_term_hit=False,
        eval_score=0.9876543,
        archetype="expat_us",
    )

    tags = dict(fake_sentry)
    assert tags["eval_score"] == "0.99"
    assert tags["eclairage_kind"] == "fatca_handoff"
    assert tags["archetype"] == "expat_us"


def test_fatca_handoff_path_tag_shape(fake_sentry):
    """FATCA handoff path values produce the inspector-visible tag shape."""
    from app.utils.sentry_audit_tags import emit_sentry_audit_tags

    emit_sentry_audit_tags(
        eclairage_kind="fatca_handoff",
        banned_term_hit=False,
        eval_score="unavailable",
        archetype="expat_us",
    )

    tags = dict(fake_sentry)
    assert tags == {
        "eclairage_kind": "fatca_handoff",
        "banned_term_hit": "false",
        "eval_score": "unavailable",
        "archetype": "expat_us",
    }


def test_anonymous_path_tag_shape(fake_sentry):
    """Anonymous /anonymous/chat values produce the inspector-visible tag shape."""
    from app.utils.sentry_audit_tags import emit_sentry_audit_tags

    emit_sentry_audit_tags(
        eclairage_kind="fiscal_margin_3a",
        banned_term_hit=False,
        eval_score="unavailable",
        archetype="anonymous",
    )

    tags = dict(fake_sentry)
    assert tags == {
        "eclairage_kind": "fiscal_margin_3a",
        "banned_term_hit": "false",
        "eval_score": "unavailable",
        "archetype": "anonymous",
    }
