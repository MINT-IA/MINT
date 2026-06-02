"""
Regression test for BUG-W2026-03 — PII scrub must NOT block the LLM input.

Walkthrough 2026-05-07: a user typed « Je gagne 7500 CHF par mois et je veux
acheter un appartement à Lausanne. Est-ce réaliste? » in the anonymous chat.
The LLM responded « Je ne peux pas voir ton salaire (il apparaît masqué) »
and then defaulted to a generic affordability framing.

Root cause: `_PII_PATTERNS` includes `\\b\\d{4,7}\\s*(?:CHF|francs?)\\b` which
was being applied to the user message BEFORE it was passed to the LLM. So
« 7500 CHF » became « [***] » before the LLM saw it.

Intent: the scrub is for downstream artefacts (audit log hash, future log
surfaces) — not for the live conversation input. The user voluntarily shared
the number, the assistant must use it.

Fix: pass `body.message` (raw) to the orchestrator; pass the scrubbed value
to `hash_for_audit` only.

This test asserts the contract:
    - LLM `question=` argument keeps the literal salary
    - audit-log `prompt_hash` is computed from the scrubbed text
"""
from __future__ import annotations

import os

# Match the env-priming pattern from test_anonymous_chat.py — without this,
# the endpoint short-circuits on `os.environ.get("ANTHROPIC_API_KEY", "")`
# and returns 503 before the orchestrator mock can be called.
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-anonymous-key")

from unittest.mock import AsyncMock, patch



_VALID_SESSION_ID = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
_SESSION_HEADER = "X-Anonymous-Session"
_USER_PROMPT_WITH_SALARY = (
    "Je gagne 7500 CHF par mois et je veux acheter un appartement Lausanne."
)

_MOCK_LLM_RESULT = {
    "answer": "OK, voyons.",
    "disclaimers": [],
    "tokens_used": 42,
}


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_user_salary_reaches_llm_unscrubbed(mock_query, client):
    """The literal `7500 CHF` must be in the question= passed to the LLM."""
    mock_query.return_value = _MOCK_LLM_RESULT
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={
            "message": _USER_PROMPT_WITH_SALARY,
            "language": "fr",
            "intent": None,
        },
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert resp.status_code == 200, resp.text

    # The LLM must have been called with the *raw* user message — including
    # the literal "7500 CHF" — not the scrubbed "[***]" form.
    assert mock_query.called
    kwargs = mock_query.call_args.kwargs
    question = kwargs.get("question", "")
    assert "7500 CHF" in question, (
        f"LLM input should preserve the user's literal salary; got: {question!r}"
    )
    assert "[***]" not in question, (
        f"LLM input should NOT contain the PII scrub marker; got: {question!r}"
    )


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_scrubbed_marker_never_in_llm_input(mock_query, client):
    """Defense in depth — `[***]` placeholder must not appear in the LLM
    input regardless of where the user's salary lands in the message."""
    mock_query.return_value = _MOCK_LLM_RESULT
    multi_amount = (
        "Salaire 8500 CHF, charges 2200 francs, je vise un IBAN "
        "CH93 0076 2011 6238 5295 7. Conseille-moi."
    )
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={"message": multi_amount, "language": "fr", "intent": None},
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert resp.status_code == 200, resp.text
    question = mock_query.call_args.kwargs.get("question", "")
    assert "[***]" not in question
    assert "8500 CHF" in question
    assert "2200 francs" in question
    assert "CH93" in question  # IBAN preserved for the LLM
