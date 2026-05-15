"""Wave 1b Plan 08 — Sentry breadcrumb contract for tool_call_id citation emission."""
from unittest.mock import MagicMock, patch


def test_emit_coach_citation_breadcrumb_5_kwarg_payload():
    from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb

    with patch("app.observability.coach_breadcrumbs.sentry_sdk") as mock_sdk:
        mock_sdk.add_breadcrumb = MagicMock()
        emit_coach_citation_breadcrumb(
            tool_name="budget_snapshot",
            inputs_hash="a" * 64,
            profile_id_hashed="b" * 16,
            elapsed_ms=42,
            flag_state="on",
        )
        mock_sdk.add_breadcrumb.assert_called_once()
        call = mock_sdk.add_breadcrumb.call_args
        assert call.kwargs["category"] == "coach.citation.tool_call_id.budget_snapshot"
        assert call.kwargs["data"]["inputs_hash"] == "a" * 64
        assert call.kwargs["data"]["profile_id_hashed"] == "b" * 16
        assert call.kwargs["data"]["elapsed_ms"] == 42
        assert call.kwargs["data"]["flag_state"] == "on"


def test_emit_coach_citation_breadcrumb_fails_open_when_sentry_unavailable():
    from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb

    with patch("app.observability.coach_breadcrumbs.sentry_sdk", None):
        # Must not raise.
        emit_coach_citation_breadcrumb(
            tool_name="x",
            inputs_hash="0" * 64,
            profile_id_hashed="0" * 16,
            elapsed_ms=0,
            flag_state="on",
        )


def test_emit_coach_citation_breadcrumb_payload_is_non_pii():
    # Payload keys are limited to {inputs_hash, profile_id_hashed, elapsed_ms, flag_state}
    # — none can carry CHF, user_id, canton, email. Plus an extra_tags merge
    # guard: extra_tags MUST NOT clobber the core 4 keys.
    from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb

    with patch("app.observability.coach_breadcrumbs.sentry_sdk") as mock_sdk:
        mock_sdk.add_breadcrumb = MagicMock()
        emit_coach_citation_breadcrumb(
            tool_name="budget_snapshot",
            inputs_hash="a" * 64,
            profile_id_hashed="b" * 16,
            elapsed_ms=42,
            flag_state="on",
            extra_tags={"inputs_hash": "EVIL", "extra_clean": "ok"},
        )
        call = mock_sdk.add_breadcrumb.call_args
        data = call.kwargs["data"]
        # extra_tags MUST NOT clobber the core 4 keys.
        assert data["inputs_hash"] == "a" * 64
        assert data["profile_id_hashed"] == "b" * 16
        # Non-clobbering extra_tag passes through.
        assert data.get("extra_clean") == "ok"
        # No PII-shaped keys (e.g. email, ahv, canton).
        assert "email" not in data and "ahv" not in data and "canton" not in data
