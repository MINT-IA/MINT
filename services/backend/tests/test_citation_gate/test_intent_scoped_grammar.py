"""Phase 94.2 / Phase 97 W7 iter#11 — H1 intent-scoped citation grammar.

Pins the contract of `build_intent_scoped_citation_grammar(intents)` :
the H1 hypothesis from `.planning/phases/94.1-.../94.1-EVAL-DELTA.md`
that narrator gate-correct improves when the citation-key vocabulary
listed in the system prompt is scoped to the user's classified intent
set, instead of the flat 18-bullet list (Phase 94.1 baseline).

Per CONTEXT D-36 7-step methodology (Phase 97 W7), this test file
locks the GRAMMAR contract. The eval JSONs (`/tmp/p001_baseline_*`,
`/tmp/p001_h1_*`) lock the gate-correct rate measurement.

Surgical scope (Karpathy #3) :
- 5 unit tests covering empty / single-intent / multi-intent / unknown /
  full-coverage fallback behavior of the new function
- 1 integration test verifying the legacy narrator path picks up the
  intent-scoped variant when called with the `intents` kwarg

Compliance contract (CLAUDE.md §1) : the intent-scoped fragment text
MUST NOT contain LSFin banned terms and MUST keep accents 100% FR. Tested
indirectly by the fact that the scoped variant is built from the same
header / examples / rules + a subset of `CITATION_REGISTRY.description_fr`
strings, all of which are lint-clean by the existing
`tools/checks/banned_terms_python.py` + `tools/checks/accent_lint_fr.py`
pre-commit gates.
"""
from __future__ import annotations

import pytest

from app.services.coach.citation_grammar import (
    CITATION_GRAMMAR_FRAGMENT,
    _INTENT_TO_CITATION_KEYS,
    build_intent_scoped_citation_grammar,
)
from app.services.coach.citation_registry import CITATION_REGISTRY


# ---------------------------------------------------------------------------
# Helper — flag toggle context (env var + live settings)
# ---------------------------------------------------------------------------


def _flip_gate_flag(monkeypatch: pytest.MonkeyPatch, value: bool) -> None:
    """Set COACH_CITATION_GATE_ENABLED on env + live settings to `value`."""
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "true" if value else "false")
    from app.core.config import settings as _settings
    monkeypatch.setattr(_settings, "COACH_CITATION_GATE_ENABLED", value)


# ---------------------------------------------------------------------------
# Test 1 — empty intent set returns the full 18-key fragment (cold-start
# fallback per H1 spec).
# ---------------------------------------------------------------------------


def test_empty_intent_set_returns_full_fragment():
    """`build_intent_scoped_citation_grammar(set())` MUST return the full
    `CITATION_GRAMMAR_FRAGMENT`. This is the cold-start fallback : when no
    intent has been classified yet, the narrator sees the complete 18-key
    vocabulary (safer than showing nothing).
    """
    out = build_intent_scoped_citation_grammar(set())
    assert out == CITATION_GRAMMAR_FRAGMENT, (
        "empty intent set MUST return the full 18-key fragment "
        f"(got len={len(out)}, expected={len(CITATION_GRAMMAR_FRAGMENT)})"
    )


# ---------------------------------------------------------------------------
# Test 2 — single-intent `{'retirement'}` returns ONLY retirement-related
# keys (3a + LPP + AVS + capital tax).
# ---------------------------------------------------------------------------


def _extract_keys_section(fragment: str) -> str:
    """Slice the « Clés autorisées » bullet list out of a fragment.

    The fixed example block (« Exemples (verbatim, à imiter) »)
    contains a verbatim `{{cite:r3a_plafond_salarie_2026}}` cited
    example — that key MUST be allowed to appear in the fragment even
    when retirement is NOT in the scoped intent set. The scoping
    contract is on the « Clés autorisées » bullet list, not the
    examples section.
    """
    start = fragment.index("### Clés autorisées")
    end = fragment.index("### Exemples")
    return fragment[start:end]


def test_retirement_intent_returns_only_retirement_keys():
    """`build_intent_scoped_citation_grammar({'retirement'})` MUST emit a
    fragment whose « Clés autorisées » bullet list contains EXACTLY the
    8 retirement-bucket keys and NONE of the other 10 (FINMA mortgage
    constants, LHID, family/career-specific keys).
    """
    out = build_intent_scoped_citation_grammar({"retirement"})
    keys_section = _extract_keys_section(out)

    # All retirement keys are present in the keys section
    for key in _INTENT_TO_CITATION_KEYS["retirement"]:
        assert f"{{{{cite:{key}}}}}" in keys_section, (
            f"retirement-scoped fragment missing key {key!r} in « Clés autorisées »"
        )

    # No mortgage / non-retirement keys leak into the keys section
    mortgage_only_keys = {
        "finma_taux_calculatoire",
        "amortissement_taux_2026",
        "finma_lcb_tragbarkeit",
        "ltv_max_residence_principale",
        "ratio_endettement_max_33pct",
    }
    for key in mortgage_only_keys:
        assert f"{{{{cite:{key}}}}}" not in keys_section, (
            f"retirement-scoped fragment leaked mortgage key {key!r} into "
            f"« Clés autorisées » — H1 noise-floor reduction broken"
        )

    # Fragment is strictly shorter than the full 18-key fragment
    assert len(out) < len(CITATION_GRAMMAR_FRAGMENT), (
        f"retirement-scoped fragment ({len(out)} chars) not shorter than "
        f"full fragment ({len(CITATION_GRAMMAR_FRAGMENT)} chars) — H1 noise "
        f"reduction did not fire"
    )


# ---------------------------------------------------------------------------
# Test 3 — single-intent `{'mortgage'}` returns ONLY FINMA / Tragbarkeit /
# LTV keys (mortgage alias for housing).
# ---------------------------------------------------------------------------


def test_mortgage_intent_returns_only_finma_keys():
    """`build_intent_scoped_citation_grammar({'mortgage'})` MUST emit a
    fragment whose bullet list contains the 5 FINMA / mortgage keys and
    NONE of the retirement / 3a / LPP keys. `mortgage` is a fixture-level
    alias for the canonical `housing` intent.
    """
    out = build_intent_scoped_citation_grammar({"mortgage"})
    keys_section = _extract_keys_section(out)

    for key in _INTENT_TO_CITATION_KEYS["mortgage"]:
        assert f"{{{{cite:{key}}}}}" in keys_section, (
            f"mortgage-scoped fragment missing key {key!r} in « Clés autorisées »"
        )

    # No retirement / 3a / LPP keys leak into the keys section
    retirement_only_keys = {
        "r3a_plafond_salarie_2026",
        "r3a_plafond_independant_2026",
        "lpp_taux_conv_obligatoire_2026",
        "opp2_coordination_2026",
        "lpp_rente_survivant_pct",
    }
    for key in retirement_only_keys:
        assert f"{{{{cite:{key}}}}}" not in keys_section, (
            f"mortgage-scoped fragment leaked retirement key {key!r} into "
            f"« Clés autorisées »"
        )


# ---------------------------------------------------------------------------
# Test 4 — multi-intent `{'retirement', 'tax'}` returns the UNION of both
# buckets.
# ---------------------------------------------------------------------------


def test_multi_intent_returns_union_of_buckets():
    """`build_intent_scoped_citation_grammar({'retirement', 'tax'})` MUST
    emit a fragment whose bullet list contains the UNION of both buckets
    (retirement: 8 keys ; tax alias: 7 keys ; union = 11 distinct keys
    because of overlap on lifd_art_22_rentes + lifd_art_38_capital_taux).
    """
    out = build_intent_scoped_citation_grammar({"retirement", "tax"})

    expected_union = (
        _INTENT_TO_CITATION_KEYS["retirement"]
        | _INTENT_TO_CITATION_KEYS["tax"]
    )
    for key in expected_union:
        assert f"{{{{cite:{key}}}}}" in out, (
            f"multi-intent scoped fragment missing key {key!r}"
        )

    # Sanity : union covers more keys than the single-intent retirement case
    out_retirement_only = build_intent_scoped_citation_grammar({"retirement"})
    assert len(out) > len(out_retirement_only), (
        f"multi-intent fragment ({len(out)} chars) not longer than "
        f"retirement-only fragment ({len(out_retirement_only)} chars)"
    )


# ---------------------------------------------------------------------------
# Test 5 — unknown intent label falls back to the full fragment
# (defensive default per H1 spec).
# ---------------------------------------------------------------------------


def test_unknown_intent_falls_back_to_full_fragment():
    """`build_intent_scoped_citation_grammar({'unknown_label_xyz'})` MUST
    return the full 18-key fragment. Defensive default : an unknown intent
    SHOULD NOT cause the narrator to see an empty key list (which would
    force the closed-world fallback on every chiffre).
    """
    out = build_intent_scoped_citation_grammar({"unknown_label_xyz"})
    assert out == CITATION_GRAMMAR_FRAGMENT, (
        "unknown intent MUST fall back to the full fragment "
        f"(got len={len(out)}, expected={len(CITATION_GRAMMAR_FRAGMENT)})"
    )

    # Mix of known + unknown : the known one drives the scoping, unknown
    # is silently dropped.
    out_mixed = build_intent_scoped_citation_grammar({"retirement", "unknown_label_xyz"})
    out_known_only = build_intent_scoped_citation_grammar({"retirement"})
    assert out_mixed == out_known_only, (
        "mixed known/unknown intent set MUST be equivalent to known-only "
        "(unknown silently dropped)"
    )


# ---------------------------------------------------------------------------
# Test 6 — full-coverage union (every intent listed) defers to the full
# fragment to avoid duplicate code paths.
# ---------------------------------------------------------------------------


def test_full_coverage_union_defers_to_full_fragment():
    """When the intent set covers every registry key, defer to
    `CITATION_GRAMMAR_FRAGMENT` (the canonical full path). Prevents two
    fragment strings from claiming to be « the full vocabulary ».
    """
    # Pick intents whose union covers all 18 registry keys.
    full_coverage = {"retirement", "taxes", "housing", "family", "career"}
    union_keys: set[str] = set()
    for intent in full_coverage:
        union_keys |= _INTENT_TO_CITATION_KEYS[intent]

    if union_keys == set(CITATION_REGISTRY.keys()):
        # Only assert when the union really covers everything.
        out = build_intent_scoped_citation_grammar(full_coverage)
        assert out == CITATION_GRAMMAR_FRAGMENT, (
            "full-coverage union MUST return the canonical CITATION_GRAMMAR_FRAGMENT"
        )


# ---------------------------------------------------------------------------
# Integration — legacy narrator path picks up the intent-scoped variant
# when called with the `intents` kwarg + flag ON.
# ---------------------------------------------------------------------------


def test_legacy_path_uses_intent_scoped_grammar_when_intents_provided(
    monkeypatch: pytest.MonkeyPatch,
):
    """`build_narrator_system_prompt(..., intents={'retirement'})` with
    `COACH_CITATION_GATE_ENABLED=true` MUST embed the retirement-scoped
    grammar (8 keys), NOT the full 18-key fragment. This is the H1 wire-up
    contract — without it, the eval harness cannot measure the H1 effect.
    """
    _flip_gate_flag(monkeypatch, True)
    from app.services.coach.claude_coach_service import (
        build_narrator_system_prompt,
    )

    out_full = build_narrator_system_prompt(
        ctx=None, language="fr", cash_level=3, intents=None
    )
    out_scoped = build_narrator_system_prompt(
        ctx=None, language="fr", cash_level=3, intents={"retirement"}
    )

    # Both contain the doctrine header (sanity)
    assert "DOCTRINE — GRAMMAIRE DE CITATION" in out_full
    assert "DOCTRINE — GRAMMAIRE DE CITATION" in out_scoped

    # Intent-scoped prompt is STRICTLY shorter (less noise)
    assert len(out_scoped) < len(out_full), (
        f"intent-scoped prompt ({len(out_scoped)} chars) not shorter than "
        f"full prompt ({len(out_full)} chars) — H1 wire-up broken"
    )

    # Mortgage keys absent from retirement-scoped « Clés autorisées »
    # section. (The « Exemples » section contains a verbatim 3a citation
    # example for the syntax — that's intentional and unrelated to
    # intent-scoping.)
    mortgage_key = "finma_taux_calculatoire"
    full_keys_section = _extract_keys_section(out_full)
    scoped_keys_section = _extract_keys_section(out_scoped)
    assert f"{{{{cite:{mortgage_key}}}}}" in full_keys_section, (
        "full fragment « Clés autorisées » missing mortgage key — sanity check broken"
    )
    assert f"{{{{cite:{mortgage_key}}}}}" not in scoped_keys_section, (
        "retirement-scoped « Clés autorisées » leaked mortgage key — "
        "H1 noise reduction broken"
    )


def test_legacy_path_byte_identity_preserved_when_intents_omitted(
    monkeypatch: pytest.MonkeyPatch,
):
    """Existing callers that DO NOT pass the `intents` kwarg MUST see the
    same prompt as before (full 18-key fragment when flag ON, no fragment
    when flag OFF). Defends the byte-identity invariant pinned by
    `test_byte_identity_flag_off.py`.
    """
    _flip_gate_flag(monkeypatch, True)
    from app.services.coach.claude_coach_service import (
        build_narrator_system_prompt,
    )

    # No intents kwarg — defaults to None
    out_default = build_narrator_system_prompt(
        ctx=None, language="fr", cash_level=3
    )
    # Explicit None
    out_explicit_none = build_narrator_system_prompt(
        ctx=None, language="fr", cash_level=3, intents=None
    )
    # Explicit empty set
    out_empty_set = build_narrator_system_prompt(
        ctx=None, language="fr", cash_level=3, intents=set()
    )

    assert out_default == out_explicit_none == out_empty_set, (
        "intents=None / intents=set() / kwarg-omitted MUST be equivalent "
        "(backward-compat for existing callers)"
    )

    # The default prompt embeds the FULL fragment
    assert CITATION_GRAMMAR_FRAGMENT in out_default, (
        "default prompt missing the full fragment with flag ON — backward-compat broken"
    )
