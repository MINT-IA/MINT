"""Phase 96 D-11 — Sentry breadcrumb on cap-hit tests.

Per 96-02-PLAN.md Task 3 <behavior> Test 8. The cap-hit emits a
Sentry breadcrumb with category `coach.chat_overflow.turn_4` and
non-PII data (card_id + turn_count only — NEVER user_message).

The helper is tested in isolation here (without the full endpoint
closure) ; the end-to-end emission path is exercised at W3 G1 Maestro.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.services.coach import turn_cap


@pytest.fixture(autouse=True)
def _reset_counter():
    turn_cap.reset()
    yield
    turn_cap.reset()


def test_emit_overflow_breadcrumb_uses_correct_category_and_payload():
    """The breadcrumb fires with the locked VERB-05 category + non-PII data."""
    mock_sentry = MagicMock()
    with patch.object(turn_cap, "sentry_sdk", mock_sentry):
        turn_cap.emit_overflow_breadcrumb(
            source_card_id="mon_3a_2026",
            turn_count=3,
        )
    assert mock_sentry.add_breadcrumb.call_count == 1
    kwargs = mock_sentry.add_breadcrumb.call_args.kwargs
    assert kwargs["category"] == "coach.chat_overflow.turn_4"
    assert kwargs["level"] == "info"
    data = kwargs["data"]
    assert data["source_card_id"] == "mon_3a_2026"
    assert data["turn_count"] == 3
    # PII gate : NO user_message / profile_context / api_key fields.
    forbidden = ("user_message", "message", "profile_context", "api_key", "user_id")
    for k in forbidden:
        assert k not in data, (
            f"PII leak — breadcrumb data carries forbidden key {k!r} : {data}"
        )


def test_emit_overflow_breadcrumb_is_fail_open():
    """If sentry_sdk.add_breadcrumb raises, the helper swallows silently."""
    mock_sentry = MagicMock()
    mock_sentry.add_breadcrumb.side_effect = RuntimeError("sentry down")
    with patch.object(turn_cap, "sentry_sdk", mock_sentry):
        # Must NOT raise.
        turn_cap.emit_overflow_breadcrumb(
            source_card_id="x",
            turn_count=3,
        )


def test_emit_overflow_breadcrumb_handles_missing_sdk():
    """If sentry_sdk import failed at module load, helper is a no-op."""
    with patch.object(turn_cap, "sentry_sdk", None):
        # Must NOT raise.
        turn_cap.emit_overflow_breadcrumb(
            source_card_id="x",
            turn_count=3,
        )


def test_overflow_breadcrumb_payload_excludes_message_field():
    """T-96-W2-PIISmuggling : breadcrumb data MUST NOT carry user_message.

    Specifically asserts that no field name containing the substring
    'message' (e.g. 'user_message', 'message_text') survives in the
    breadcrumb data dict — the only allowed top-level message is the
    breadcrumb's own 'message' kwarg (a static label, not user content).
    """
    mock_sentry = MagicMock()
    with patch.object(turn_cap, "sentry_sdk", mock_sentry):
        turn_cap.emit_overflow_breadcrumb(
            source_card_id="mon_3a_2026",
            turn_count=3,
        )
    kwargs = mock_sentry.add_breadcrumb.call_args.kwargs
    data = kwargs["data"]
    for key in data.keys():
        assert "message" not in key.lower(), (
            f"PII leak — breadcrumb data carries user-content-shaped key "
            f"{key!r} : {data}"
        )
