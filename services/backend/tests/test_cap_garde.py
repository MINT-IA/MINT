"""Wave 1a Plan 06 — _validate_cap_response middleware tests.

Per CONTEXT D-09 / D-17, ``_validate_cap_response`` wraps the output of
``_format_cap_status`` (Flutter-sourced cap text) to ensure that no CHF
token reaches the LLM without an adjacent ``{{cite:<key>}}`` placeholder
within ±80 chars. Un-cited tokens are replaced with the verbatim FR
string ``[montant indisponible]`` and a Sentry breadcrumb is emitted
with a non-PII snippet payload.

Regex source-of-truth: ``app.services.coach.citation_parser._RE_CURRENCY``
(Phase 94, re-exported via ``__all__`` at citation_parser.py:721-734).
"""

from unittest import mock

import sentry_sdk

from app.api.v1.endpoints.coach_chat import _validate_cap_response
from app.core.config import settings
from app.services.coach.citation_parser import _RE_CURRENCY


# ---------------------------------------------------------------------------
# Test 1 — cite present within ±80 chars
# ---------------------------------------------------------------------------
def test_cite_present_within_window_passes_through():
    """Cited CHF token: middleware returns input unchanged, no breadcrumb."""
    rendered = (
        "Impact attendu : économise 1'250 CHF par an "
        "{{cite:r3a_plafond_2026}}"
    )
    with mock.patch.object(sentry_sdk, "add_breadcrumb") as m_bc:
        out = _validate_cap_response(rendered)
    assert out == rendered
    assert m_bc.call_count == 0


# ---------------------------------------------------------------------------
# Test 2 — cite absent → replacement + breadcrumb with non-PII snippet
# ---------------------------------------------------------------------------
def test_cite_absent_replaces_chf_and_emits_breadcrumb():
    """Un-cited CHF token: replaced with verbatim FR + Sentry breadcrumb."""
    rendered = "Impact attendu : économise 1'250 CHF par an"
    with mock.patch.object(sentry_sdk, "add_breadcrumb") as m_bc:
        out = _validate_cap_response(rendered)
    assert out == "Impact attendu : économise [montant indisponible] par an"
    assert m_bc.call_count == 1
    kwargs = m_bc.call_args.kwargs
    assert kwargs["category"] == "coach.cap.cap_chf_uncited"
    assert kwargs["level"] == "warning"
    snippet = kwargs["data"]["snippet"]
    assert isinstance(snippet, str)
    assert len(snippet) <= 120
    # Non-PII surface check — payload keys are exactly {"snippet"}, no
    # user_id / profile_id / email.
    assert set(kwargs["data"].keys()) == {"snippet"}


# ---------------------------------------------------------------------------
# Test 3a — boundary: cite at the LATEST start that fits in the window
# ---------------------------------------------------------------------------
def test_boundary_just_inside_window_passes_through():
    """Cite positioned so ``{{cite:`` ENDS at the window's last index.

    The implementation uses ``window_end = match.end() + 80`` (Python
    slicing — upper bound exclusive). For the 7-char literal ``{{cite:``
    to be FULLY present in ``rendered[ws:we]``, its start position must
    satisfy ``cite_start + 7 <= match.end() + 80`` — i.e. the LATEST
    in-window start is ``match.end() + 73``. This is the « cite at the
    boundary » case per plan-06 Test 3a (the plan's literal « 80 » is an
    approximation that does not account for the 7-char search string).
    """
    prefix = "Impact attendu : économise "
    token = "100 CHF"
    text_until_cite = prefix + token
    match = next(_RE_CURRENCY.finditer(text_until_cite))
    target_cite_start = match.end() + 73  # latest position that still fits
    padding_len = target_cite_start - len(text_until_cite)
    assert padding_len > 0
    rendered = text_until_cite + (" " * padding_len) + "{{cite:k}}"
    # Invariant: cite literal lands exactly where we expect
    assert rendered.find("{{cite:") == target_cite_start
    with mock.patch.object(sentry_sdk, "add_breadcrumb") as m_bc:
        out = _validate_cap_response(rendered)
    assert out == rendered
    assert m_bc.call_count == 0


# ---------------------------------------------------------------------------
# Test 3b — boundary: cite ONE char past the threshold → missed
# ---------------------------------------------------------------------------
def test_boundary_just_outside_window_replaces():
    """Cite one char past 3a's threshold: trailing ``:`` falls outside slice."""
    prefix = "Impact attendu : économise "
    token = "100 CHF"
    text_until_cite = prefix + token
    match = next(_RE_CURRENCY.finditer(text_until_cite))
    target_cite_start = match.end() + 74  # one char past — last `:` excluded
    padding_len = target_cite_start - len(text_until_cite)
    rendered = text_until_cite + (" " * padding_len) + "{{cite:k}}"
    with mock.patch.object(sentry_sdk, "add_breadcrumb") as m_bc:
        out = _validate_cap_response(rendered)
    assert "[montant indisponible]" in out
    assert "100 CHF" not in out
    assert m_bc.call_count == 1


# ---------------------------------------------------------------------------
# Test 4 — no CHF tokens → byte-identical passthrough
# ---------------------------------------------------------------------------
def test_no_chf_tokens_passes_through():
    """Cap text with no currency tokens: byte-identical output, no breadcrumb."""
    rendered = (
        "Cap du jour :\n"
        "- Priorité : Optimise ton budget\n"
        "- Action suggérée : Lis ce module"
    )
    with mock.patch.object(sentry_sdk, "add_breadcrumb") as m_bc:
        out = _validate_cap_response(rendered)
    assert out == rendered
    assert m_bc.call_count == 0


# ---------------------------------------------------------------------------
# Test 5 — flag OFF: byte-identical even with un-cited CHF
# ---------------------------------------------------------------------------
def test_flag_off_passes_through(monkeypatch):
    """``COACH_CAP_CHF_GARDE_ENABLED=False``: middleware short-circuits.

    Sequence-dependent flake fix : ``_validate_cap_response`` does an
    in-function ``from app.core.config import settings`` to avoid a
    module-import circular dep (coach_chat.py:3330). ``test_config_guards``
    does ``importlib.reload(config)`` mid-suite which replaces
    ``app.core.config.settings`` with a new instance. The test's
    module-level ``settings`` reference then points to the OLD instance ;
    ``_validate_cap_response`` resolves the NEW instance. Monkeypatching
    via dotted-string forces resolution at patch time using the same
    module-state ``_validate_cap_response`` will see at call time.
    """
    monkeypatch.setattr(
        "app.core.config.settings.COACH_CAP_CHF_GARDE_ENABLED", False
    )
    rendered = "Impact attendu : économise 1'250 CHF par an"
    with mock.patch.object(sentry_sdk, "add_breadcrumb") as m_bc:
        out = _validate_cap_response(rendered)
    assert out == rendered
    assert m_bc.call_count == 0


# ---------------------------------------------------------------------------
# Test 6 — multi-token mixed: offset arithmetic correctness
# ---------------------------------------------------------------------------
def test_multi_token_mixed_offset_correctness():
    """Three CHF tokens; only the last has a cite within window.

    Verifies offset bookkeeping across multiple replacements: tokens 1
    and 2 are replaced (left-to-right) while token 3 is preserved. The
    padding (100 spaces between tokens) ensures each token's ±80-char
    window is disjoint from the others — cite near token 3 does not
    bleed into token 1's or token 2's window.
    """
    rendered = (
        "100 CHF token un sans cite"
        + (" " * 100)
        + "200 CHF token deux sans cite"
        + (" " * 100)
        + "300 CHF token trois avec cite {{cite:k}}"
    )
    with mock.patch.object(sentry_sdk, "add_breadcrumb") as m_bc:
        out = _validate_cap_response(rendered)
    # Tokens 1 and 2 replaced
    assert out.count("[montant indisponible]") == 2
    # Token 3 preserved alongside its cite
    assert "300 CHF token trois avec cite {{cite:k}}" in out
    # Original un-cited tokens are gone
    assert "100 CHF" not in out
    assert "200 CHF" not in out
    # Exactly two breadcrumbs (one per replacement)
    assert m_bc.call_count == 2
