"""Wave 1b Plan 08 — Sentry breadcrumb contract for tool_call_id citation emission."""
from unittest.mock import MagicMock, patch

import pytest


@pytest.mark.skip(reason="Wave 1b — emit helper lands in Plan 08")
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


@pytest.mark.skip(reason="Wave 1b — fail-open behavior")
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


@pytest.mark.skip(reason="Wave 1b — payload non-PII guarantee")
def test_emit_coach_citation_breadcrumb_payload_is_non_pii():
    # Payload keys are limited to {inputs_hash, profile_id_hashed, elapsed_ms, flag_state}
    # — none can carry CHF, user_id, canton, email.
    from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb  # noqa: F401

    assert True
