"""Contract tests for `app.core.sentry_scrub.before_send`.

Deterministic ground truth for the Swiss-compliance panel's
non-negotiable: no AVS, IBAN, email, phone, or Claude payload may
leave the backend inside a Sentry event.

Mirror file: `apps/mobile/test/services/observability/sentry_scrub_test.dart`.
"""

from __future__ import annotations

from app.core.sentry_scrub import REDACTED, before_send


def _event(**kwargs) -> dict:
    return dict(kwargs)


def test_avs_redacted_in_message() -> None:
    out = before_send(_event(message="patient AVS 756.1234.5678.97"), {})
    assert REDACTED in out["message"]
    assert "756.1234.5678.97" not in out["message"]


def test_swiss_iban_redacted() -> None:
    out = before_send(_event(message="transfer to CH93 0076 2011 6238 5295 7"), {})
    assert "CH93 0076" not in out["message"]
    assert REDACTED in out["message"]


def test_email_redacted() -> None:
    out = before_send(_event(message="lookup user lauren.doe@expat.example.com"), {})
    assert "lauren.doe@" not in out["message"]


def test_swiss_phone_redacted() -> None:
    out = before_send(_event(message="call +41 79 123 45 67"), {})
    assert "+41 79" not in out["message"]


def test_prompt_key_value_dropped() -> None:
    out = before_send(
        _event(
            extra={
                "prompt": "tu garantis un rendement optimal",
                "safe_metric": 42,
            }
        ),
        {},
    )
    assert out["extra"]["prompt"] == REDACTED
    assert out["extra"]["safe_metric"] == 42


def test_claude_wildcard_keys_dropped() -> None:
    out = before_send(
        _event(
            extra={
                "claude_response": "banned-term-bearing answer",
                "claude_request_id": "msg_01ABCDEF",
                "kept_field": "ok",
            }
        ),
        {},
    )
    assert out["extra"]["claude_response"] == REDACTED
    assert out["extra"]["claude_request_id"] == REDACTED
    assert out["extra"]["kept_field"] == "ok"


def test_partial_substring_key_NOT_dropped() -> None:
    out = before_send(
        _event(
            extra={
                "is_prompt_eligible": True,
                "completion_rate": 0.93,  # starts with 'completion' but not exact
            }
        ),
        {},
    )
    assert out["extra"]["is_prompt_eligible"] is True
    assert out["extra"]["completion_rate"] == 0.93


def test_breadcrumb_data_and_message_scrubbed() -> None:
    out = before_send(
        _event(
            breadcrumbs={
                "values": [
                    {
                        "message": "user 756.9876.5432.10 hit /api/profile",
                        "data": {"prompt": "drop me", "route": "/profile"},
                    }
                ]
            }
        ),
        {},
    )
    crumb = out["breadcrumbs"]["values"][0]
    assert "756.9876" not in crumb["message"]
    assert crumb["data"]["prompt"] == REDACTED
    assert crumb["data"]["route"] == "/profile"


def test_request_data_dropped_wholesale() -> None:
    out = before_send(
        _event(
            request={
                "url": "https://api.mint.app/v1/coach/chat",
                "method": "POST",
                "data": {"messages": [{"role": "user", "content": "IBAN CH93..."}]},
                "headers": {"authorization": "Bearer xxx"},
                "cookies": "session=abc",
                "query_string": "q=salaire+120000",
            }
        ),
        {},
    )
    assert out["request"] == {
        "url": "https://api.mint.app/v1/coach/chat",
        "method": "POST",
    }


def test_nested_pii_in_extras_scrubbed() -> None:
    out = before_send(
        _event(
            extra={
                "context": {
                    "archetype": "expat_us",
                    "note": "AVS 756.1111.2222.33 — FATCA flagged",
                }
            }
        ),
        {},
    )
    nested = out["extra"]["context"]
    assert nested["archetype"] == "expat_us"
    assert "756.1111" not in nested["note"]


def test_exception_value_scrubbed_but_frames_untouched() -> None:
    out = before_send(
        _event(
            exception={
                "values": [
                    {
                        "type": "ValueError",
                        "value": "bad input: AVS 756.3333.4444.55",
                        "stacktrace": {
                            "frames": [
                                {
                                    "filename": "app/services/foo.py",
                                    "function": "process",
                                }
                            ]
                        },
                    }
                ]
            }
        ),
        {},
    )
    assert "756.3333" not in out["exception"]["values"][0]["value"]
    # Stack frame untouched
    assert (
        out["exception"]["values"][0]["stacktrace"]["frames"][0]["filename"]
        == "app/services/foo.py"
    )
