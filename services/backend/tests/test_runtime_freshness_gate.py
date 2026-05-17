"""Tests for runtime_freshness_gate (Fix C / obs #157).

Covers : stale-value detection across thousand-separator formats, NFKC
normalisation, zero-width injection, user-echo exemption, current-value
pass-through, empty input pass-through, and the registry-derived
stale_set computation.
"""
from __future__ import annotations

import pytest

from app.services.coach.runtime_freshness_gate import (
    _FALLBACK_FR,
    _build_stale_value_set,
    _normalise_number_token,
    gate,
)


# ── stale_set derivation ──────────────────────────────────────────────


def test_stale_set_contains_known_stale_3a_values():
    """4 known 3a historical limits (2017-2023) must be in stale set."""
    stale = _build_stale_value_set()
    # These four are the 3a historical limits where the value is NOT
    # also present in any current canonical key (verified by
    # _build_stale_value_set algorithm at module load).
    assert 7056 in stale, "2024 plafond 3a salarie-LPP must be stale"
    assert 6883 in stale, "2023 plafond 3a must be stale"
    assert 6826 in stale, "2018-2022 plafond 3a must be stale"
    assert 6768 in stale, "2016-2017 plafond 3a must be stale"


def test_stale_set_excludes_current_value():
    """7'258 = current 2025+2026 plafond 3a + canonical key — NOT stale."""
    stale = _build_stale_value_set()
    assert 7258 not in stale, (
        "7'258 is the current 3a max (canonical key + 2025/2026 historical), "
        "must NOT be flagged stale"
    )


def test_stale_set_is_frozen():
    """lru_cache returns a frozenset for immutability."""
    stale = _build_stale_value_set()
    assert isinstance(stale, frozenset)


# ── number-token normalisation ────────────────────────────────────────


@pytest.mark.parametrize("raw,expected", [
    ("7056", 7056),
    ("7'056", 7056),
    ("7 056", 7056),     # regular space
    ("7 056", 7056),  # narrow no-break space
    ("7 056", 7056),  # NBSP
    ("1,234,567", 1234567),  # anglo comma 3-digit groups
    ("36'288", 36288),
    # Invalid : decimal-style comma rejected
    ("7,5", None),
    ("not a number", None),
    ("", None),
])
def test_normalise_number_token(raw, expected):
    """Thousand-separator variants normalise to the same int."""
    assert _normalise_number_token(raw) == expected


# ── gate behaviour ────────────────────────────────────────────────────


def test_gate_blocks_7056_swiss_apostrophe():
    """The exact LSFin defect from obs #157."""
    result, output = gate("Le plafond 3a est de 7'056 CHF cette année.")
    assert result is False
    assert output == _FALLBACK_FR


def test_gate_blocks_7056_no_separator():
    """LLM may emit `7056` without thousand separator."""
    result, output = gate("Le plafond 3a est de 7056 CHF.")
    assert result is False
    assert output == _FALLBACK_FR


def test_gate_blocks_7056_french_space():
    """LLM may emit `7 056` with regular space."""
    result, output = gate("Le plafond 3a est de 7 056 CHF.")
    assert result is False
    assert output == _FALLBACK_FR


def test_gate_blocks_7056_nbsp():
    """LLM may emit `7 056` with NBSP (proper FR typography)."""
    result, output = gate("Le plafond 3a est de 7 056 CHF.")
    assert result is False
    assert output == _FALLBACK_FR


def test_gate_passes_7258_current_value():
    """7'258 = current 2026 value, MUST NOT be blocked."""
    text = "Le plafond 3a est de 7'258 CHF en 2026."
    result, output = gate(text)
    assert result is True
    assert output == text


def test_gate_passes_empty():
    """Empty input passes through — Phase 94 owns the empty fallback."""
    result, output = gate("")
    assert result is True
    assert output == ""


def test_gate_passes_whitespace_only():
    """Whitespace-only input passes through."""
    result, output = gate("   \n\t  ")
    assert result is True


def test_gate_user_echo_exempted():
    """If user echoes a stale value, narrator may echo it back."""
    user_msg = "J'ai versé 7'056 CHF l'an dernier dans mon 3a."
    narrator = "Tu as versé 7'056 CHF l'an dernier — c'était le plafond 2024."
    result, _ = gate(narrator, user_message=user_msg)
    assert result is True, (
        "User-echo exemption must let through stale values present in user msg"
    )


def test_gate_user_echo_partial_does_not_exempt_other_stale_values():
    """User echoes 7'056 ; narrator emits 7'056 AND 6'883 — 6'883 still blocks."""
    user_msg = "J'ai versé 7'056 CHF en 2024."
    narrator = "En 2023 c'était 6'883 CHF, en 2024 c'était 7'056 CHF."
    result, output = gate(narrator, user_message=user_msg)
    assert result is False, (
        "6'883 not in user msg → still stale → still blocks"
    )
    assert output == _FALLBACK_FR


def test_gate_zero_width_bypass_caught():
    """Character-injection bypass `7'0​56` is neutralised by NFKC + ZWS strip."""
    # U+200B = ZERO WIDTH SPACE inserted to evade naive regex
    sneaky = "Le plafond 3a est de 7'0​56 CHF."
    result, output = gate(sneaky)
    assert result is False
    assert output == _FALLBACK_FR


def test_gate_NFKC_normalisation():
    """Decomposed accent does not affect number matching."""
    # e + combining acute accent = "é" via NFD; NFKC normalises
    text = "Le plafond 3a cette année est de 7'056 CHF."
    result, output = gate(text)
    assert result is False
    assert output == _FALLBACK_FR


def test_gate_preserves_text_on_pass():
    """When passing, the original text is returned unchanged."""
    text = "Bonjour ! Voici une projection sans chiffre régulatoire."
    result, output = gate(text)
    assert result is True
    assert output == text


def test_gate_ignores_small_numbers():
    """Ages, percent, durations < 100 are not regulatory thresholds."""
    text = "Tu as 35 ans, ton taux marginal est 25%, durée 10 ans."
    result, output = gate(text)
    assert result is True


def test_gate_multiple_stale_short_circuits_first():
    """Multiple stale values still produce a single fallback."""
    text = "2017 = 6'768, 2018 = 6'826, 2023 = 6'883, 2024 = 7'056."
    result, output = gate(text)
    assert result is False
    assert output == _FALLBACK_FR


# ── threat coverage ──────────────────────────────────────────────────


def test_gate_threat_t_3a_stale_with_citation():
    """T-3a-stale : LLM emits stale value + valid citation key.

    The cited key is mechanically valid (citation gate accepts), but
    the value is stale 2024. Without this freshness gate, the value
    ships to user under a 2026 citation chip — exactly obs #157.
    """
    text = "Le plafond 3a 2026 est 7'056 CHF {{cite:r3a_plafond_salarie_2026}}."
    result, output = gate(text)
    assert result is False, (
        "Freshness gate must catch even citation-decorated stale values"
    )
    assert output == _FALLBACK_FR


def test_fallback_is_short_and_deterministic():
    """The fallback string is a verbatim short literal — no f-string surprise."""
    assert _FALLBACK_FR == "Je n'ai pas cette donnée à jour pour l'instant."
    # Verify it's distinguishable from Phase 94 citation-gate fallback
    # (which is much longer) and from runtime_verb_gate (« Je n'ai pas
    # cette donnée pour l'instant. » — no « à jour »).
    assert "à jour" in _FALLBACK_FR
