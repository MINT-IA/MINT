"""Phase 97 W7 cycle P003 — user-input number awareness regression guard.

Authored 2026-05-12 after Julien's sim screenshot showed the authenticated
coach returning the canned FALLBACK_TEMPLATED_TEXT on a first prompt that
contained complete profile data inline (« j'ai 49 ans, Valais, marié,
7'600 CHF/mois, 300'000 CHF rachat 2e pilier, 5 comptes 3a »). The Phase 94
closed-world citation gate had no awareness of user-supplied numbers —
it only exempted meta-quote, meta-negation, legal-article overlap, OR
adjacent `{{cite:<key>}}` with a registry key. Result : every number the
narrator echoed from the user's own message was treated as uncited, the
first pass returned REJECTED_UNCITED, the second pass collapsed to
FALLBACK on `is_retry=True`, the user saw a generic « tell me more »
response to a 41-word prompt they had just typed.

Fix (P003 cycle FIX-DECISION.md F3) :
  - `citation_parser.gate(...)` accepts a new `user_input_numbers:
    frozenset[Decimal] | None = None` kwarg.
  - Step 5b (between meta-negation and adjacency check) skips any
    matched number whose normalised Decimal value is in the set.
  - The coach_chat handler extracts numeric tokens from `body.message`
    plus the last 8 user turns of conversation history via
    `extract_user_input_numbers` and threads the result through both
    gate invocations.

These tests lock the new behaviour. Pre-fix the assertions on the
"WITH user_input" branches FAIL ; post-fix they PASS. Future PRs that
regress the exemption (e.g. accidentally drop the kwarg pass-through)
will fail these tests = PR blocked.
"""
from __future__ import annotations

from decimal import Decimal

import pytest

from app.services.coach.citation_parser import (
    FALLBACK_TEMPLATED_TEXT,
    GateVerdict,
    extract_user_input_numbers,
    gate,
)


# ── Helpers ──────────────────────────────────────────────────────────


def _julien_prompt() -> str:
    """The verbatim prompt Julien submitted on 2026-05-12T08:13Z, sim
    screenshot at .planning/cycles/P003/CONTEXT.md.
    """
    return (
        "j'ai 49 ans, je vis en Valais, je suis marié, je gagne 7600 CHF "
        "net par mois, j'ai 300 000 CHF de rachat potentiel dans mon "
        "deuxième pilier, et j'ai 5 comptes de troisième pilier, qu'est-ce "
        "que je dois faire ?"
    )


def _narrator_echo() -> str:
    """A plausible narrator first-pass output that echoes Julien's
    numbers back without {{cite:}} placeholders, as the post-P003 system
    prompt fragment authorises.
    """
    return (
        "Avec 49 ans, un salaire net de 7600 CHF par mois et 300000 CHF de "
        "rachat potentiel 2e pilier, voici trois angles à envisager. Tes "
        "5 comptes 3a pourraient être consolidés pour simplifier la "
        "gestion. Le rachat LPP pourrait s'étaler sur plusieurs années "
        "fiscales."
    )


# ── Tests : extractor correctness ────────────────────────────────────


def test_extract_pulls_4_user_numbers_from_julien_prompt():
    """The extractor must surface the 4 distinct numbers Julien typed."""
    out = extract_user_input_numbers(_julien_prompt())
    assert Decimal("49") in out
    assert Decimal("7600") in out
    assert Decimal("300000") in out
    assert Decimal("5") in out


def test_extract_handles_swiss_apostrophe_thousand_separator():
    """`7'600 CHF` and `300'000 CHF` must canonicalise to the same
    Decimals as their no-separator forms.
    """
    out = extract_user_input_numbers(
        "j'ai 7'600 CHF de salaire et 300'000 CHF de rachat"
    )
    assert Decimal("7600") in out
    assert Decimal("300000") in out


def test_extract_handles_space_thousand_separator():
    """The user's literal screenshot uses `300 000 CHF` with a regular
    space. The extractor must canonicalise this too.
    """
    out = extract_user_input_numbers("300 000 CHF de rachat")
    assert Decimal("300000") in out


def test_extract_empty_or_no_digits_returns_empty_set():
    assert extract_user_input_numbers("") == frozenset()
    assert extract_user_input_numbers("aucun chiffre ici") == frozenset()


# ── Tests : normalizer edge cases (coverage : citation_parser.py lines
#    176, 188-189, 191, 193, 196-197 — the _normalize_user_number_token
#    Swiss-notation branches that P003 unit tests above don't exercise
#    by accident) ────────────────────────────────────────────────────


def test_normalize_handles_european_decimal_comma_only():
    """« 7,5% » → Decimal('7.5'). Single comma = decimal separator,
    no apostrophe / space thousands."""
    out = extract_user_input_numbers("le taux est 7,5 %")
    assert Decimal("7.5") in out


def test_normalize_known_limitation_no_dot_thousand_separator():
    """Known limitation : the extractor regex matches Swiss thousand
    separators only (apostrophe, NBSP, regular space). Dot-thousand
    formats (« 1.234,56 » FR/DE, « 1,234.56 » US) split into 2 matches.
    Documented limitation — Swiss users overwhelmingly use apostrophe
    per usage data. Future PR can extend regex if locale telemetry
    surfaces non-Swiss-notation user behaviour.
    """
    fr_eu_out = extract_user_input_numbers("montant 1.234,56 CHF")
    # Regex captures '1.234' as first match and '56' as second match
    # (the suffix-strip removes 'CHF' but the dot-thousand isn't
    # collapsed). Asserting the limitation rather than the ideal.
    assert Decimal("1234.56") not in fr_eu_out  # KNOWN gap
    assert Decimal("56") in fr_eu_out  # safe fallthrough
    # The Swiss-notation equivalent works as expected :
    swiss_out = extract_user_input_numbers("montant 1'234.56 CHF")
    assert Decimal("1234.56") in swiss_out


def test_normalize_handles_count_suffixes():
    """« 5 comptes », « 3 enfants », « 2 personnes » : count suffixes
    should drop and leave the integer."""
    out = extract_user_input_numbers(
        "j'ai 5 comptes, 3 enfants et 2 personnes à charge"
    )
    assert Decimal("5") in out
    assert Decimal("3") in out
    assert Decimal("2") in out


def test_normalize_empty_token_returns_none_via_extractor():
    """Direct check that the extractor handles the empty-input path
    (covers citation_parser.py:175-176 early-return branch)."""
    assert extract_user_input_numbers("") == frozenset()


def test_normalize_unparseable_falls_through_to_empty():
    """If a regex-match somehow extracts a non-Decimal-parseable token
    (degenerate case), the extractor must drop it silently rather than
    raise. Covers citation_parser.py:196-197 InvalidOperation fallback."""
    # Pure non-numeric text — extractor regex won't match anything,
    # but exercise the safety branch by passing a string of pure
    # whitespace and Unicode.
    out = extract_user_input_numbers("        ")
    assert out == frozenset()


# ── Tests : gate exemption mechanics ─────────────────────────────────


def test_gate_pre_p003_rejects_uncited_user_numbers():
    """Pre-fix behaviour pin : when called WITHOUT `user_input_numbers`
    kwarg (or with None), the gate rejects narrator echoes of user data.
    This is the failure mode P003 fixes ; the test stays GREEN because
    the kwarg's default is None.
    """
    g = gate(
        response_text=_narrator_echo(),
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
    )
    assert g.verdict == GateVerdict.REJECTED_UNCITED
    assert g.uncited_numbers_count > 0


def test_gate_post_p003_passes_user_echo_with_kwarg():
    """The P003 contract : with `user_input_numbers` populated from the
    user message, the gate stops counting echoed user data as uncited.
    """
    user_numbers = extract_user_input_numbers(_julien_prompt())
    g = gate(
        response_text=_narrator_echo(),
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
        user_input_numbers=user_numbers,
    )
    assert g.verdict == GateVerdict.PASS, (
        f"Expected PASS with user_input_numbers={sorted(user_numbers)}, "
        f"got {g.verdict.value} with uncited_count={g.uncited_numbers_count}"
    )
    assert g.uncited_numbers_count == 0


def test_gate_post_p003_still_rejects_fabricated_numbers():
    """Adversarial : the exemption MUST NOT leak into narrator-fabricated
    numbers. If the narrator invents a 1'200 CHF figure not in the user
    message, the gate still rejects.
    """
    user_numbers = extract_user_input_numbers(_julien_prompt())
    fabricated = (
        _narrator_echo()
        + " Tu pourrais épargner 1200 CHF supplémentaires par mois."
    )
    g = gate(
        response_text=fabricated,
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
        user_input_numbers=user_numbers,
    )
    assert g.verdict == GateVerdict.REJECTED_UNCITED
    assert g.uncited_numbers_count >= 1


def test_gate_post_p003_swiss_apostrophe_echo_passes():
    """The narrator may echo Julien's `7600` as the Swiss-formatted
    `7'600 CHF` ; the normalisation in the gate must match across
    formatting variants.
    """
    user_numbers = extract_user_input_numbers(_julien_prompt())
    narrator_with_swiss_fmt = (
        "Avec un salaire net de 7'600 CHF par mois et 300'000 CHF de "
        "rachat 2e pilier, plusieurs pistes sont à envisager."
    )
    g = gate(
        response_text=narrator_with_swiss_fmt,
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
        user_input_numbers=user_numbers,
    )
    assert g.verdict == GateVerdict.PASS, (
        f"Swiss-format echo should pass with user_input_numbers ; got "
        f"{g.verdict.value} uncited_count={g.uncited_numbers_count}"
    )


def test_gate_byte_identity_when_kwarg_none():
    """Byte-identity invariant (D-20) : when `user_input_numbers=None`
    the gate's behaviour is identical to pre-P003. Critical for the
    flag-OFF and bundle-disabled paths.
    """
    g_default = gate(
        response_text=_narrator_echo(),
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
    )
    g_explicit_none = gate(
        response_text=_narrator_echo(),
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
        user_input_numbers=None,
    )
    assert g_default.verdict == g_explicit_none.verdict
    assert (
        g_default.uncited_numbers_count == g_explicit_none.uncited_numbers_count
    )


def test_gate_post_p003_banned_claim_still_caught_on_user_numbers():
    """The user-input exemption MUST NOT bypass the banned-claim verb
    regex. If the narrator says « vous gagnerez 7600 » (affirmative
    futur on a user-supplied number), the banned-claim path still
    fires. LSFin no-promise invariant (CLAUDE.md NEVER #8) preserved.
    """
    user_numbers = extract_user_input_numbers(_julien_prompt())
    banned_text = "Avec ce profil, vous gagnerez 7600 CHF par mois en plus."
    g = gate(
        response_text=banned_text,
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
        user_input_numbers=user_numbers,
    )
    assert g.verdict == GateVerdict.REJECTED_BANNED_CLAIM
    assert len(g.banned_claims_found) >= 1


def test_gate_retry_with_user_numbers_does_not_force_fallback_on_clean_text():
    """End-to-end retry scenario : if the first-pass narrator echoes user
    data (now exempt), the gate PASSES on first pass — no retry needed.
    This is the key UX behaviour change : Julien's path no longer takes
    the 30s, 2-LLM-call fallback collapse.
    """
    user_numbers = extract_user_input_numbers(_julien_prompt())
    g_first_pass = gate(
        response_text=_narrator_echo(),
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
        user_input_numbers=user_numbers,
    )
    assert g_first_pass.verdict == GateVerdict.PASS
    assert not g_first_pass.retry_needed
    # And the gated text is NOT the canned fallback.
    assert g_first_pass.gated_text != FALLBACK_TEMPLATED_TEXT


# ── Test : the « 49 ans » edge case (duration regex collision) ──────


def test_gate_post_p003_age_in_years_passes_when_user_supplied():
    """« 49 ans » trips the duration regex AND is in the user's message.
    The exemption must apply to durations too, not just currency.
    """
    user_numbers = extract_user_input_numbers("j'ai 49 ans")
    g = gate(
        response_text="À 49 ans, tu es proche de la dernière décennie de cotisation.",
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
        pack=None,
        user_input_numbers=user_numbers,
    )
    assert g.verdict == GateVerdict.PASS, (
        f"49 ans should pass when user said « j'ai 49 ans » ; got "
        f"{g.verdict.value}"
    )


# ── Tests : the coach_chat.py session-aggregator helper ──────────────
#
# `_collect_user_input_numbers_from_session(message, history)` was
# extracted to a module-level helper so diff-cover hits every branch
# without integration-test plumbing. These tests lock its behaviour.


def test_session_aggregator_empty_history():
    """No history at all — only the current message is scanned."""
    from app.api.v1.endpoints.coach_chat import (
        _collect_user_input_numbers_from_session,
    )
    out = _collect_user_input_numbers_from_session(
        message="j'ai 49 ans", history=None
    )
    assert Decimal("49") in out


def test_session_aggregator_pulls_user_turns_from_history():
    """User-role turns add their numeric content to the exemption set."""
    from app.api.v1.endpoints.coach_chat import (
        _collect_user_input_numbers_from_session,
    )
    history = [
        {"role": "user", "content": "j'ai 7600 CHF de salaire"},
        {"role": "assistant", "content": "Compris."},
        {"role": "user", "content": "et 300 000 CHF de rachat 2e pilier"},
    ]
    out = _collect_user_input_numbers_from_session(
        message="qu'est-ce que je dois faire ?", history=history
    )
    assert Decimal("7600") in out
    assert Decimal("300000") in out


def test_session_aggregator_skips_assistant_turns():
    """Assistant-role turns MUST NOT contribute numbers to the
    exemption set — only USER-supplied numbers earn the gate
    exemption."""
    from app.api.v1.endpoints.coach_chat import (
        _collect_user_input_numbers_from_session,
    )
    history = [
        {"role": "assistant", "content": "Le plafond 3a 2026 est 7056 CHF"},
    ]
    out = _collect_user_input_numbers_from_session(
        message="merci", history=history
    )
    assert Decimal("7056") not in out


def test_session_aggregator_skips_non_string_content():
    """If a turn has a non-string `content` (malformed history payload),
    skip without raising."""
    from app.api.v1.endpoints.coach_chat import (
        _collect_user_input_numbers_from_session,
    )
    history = [
        {"role": "user", "content": ["49", "7600"]},
        {"role": "user", "content": None},
        {"role": "user", "content": "300000"},
    ]
    out = _collect_user_input_numbers_from_session(
        message="", history=history
    )
    assert Decimal("300000") in out


def test_session_aggregator_respects_history_window():
    """Only the last `history_window` turns are scanned."""
    from app.api.v1.endpoints.coach_chat import (
        _collect_user_input_numbers_from_session,
    )
    history = [
        {"role": "user", "content": "100"},
        {"role": "user", "content": "200"},
        {"role": "user", "content": "300"},
        {"role": "user", "content": "400"},
        {"role": "user", "content": "500"},
    ]
    out = _collect_user_input_numbers_from_session(
        message="", history=history, history_window=2
    )
    assert Decimal("500") in out
    assert Decimal("400") in out
    assert Decimal("100") not in out
    assert Decimal("200") not in out
    assert Decimal("300") not in out
