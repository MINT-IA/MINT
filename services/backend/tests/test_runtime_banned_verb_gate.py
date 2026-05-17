"""Phase mint-calc-engine-v1 Plan 18 / W4 — D-CE-16(c) runtime banned-verb gate.

Triple-defense layer (c) — fail-closed runtime regex gate on NFKC-normalised +
zero-width-stripped narrator output, sibling to Phase 94 citation gate.

Tests :
  1. Clean LSFin-compliant text passes unchanged.
  2-3. Banned root + paraphrase verb trigger fallback.
  4. NFKC normalisation : decomposed-accent variant is detected.
  5. Zero-width-char injection (« opti<ZWS>mal ») is detected.
  6. Case-insensitive match : « OPTIMAL » triggers fallback.
  7. Fallback template is EXACTLY « Je n'ai pas cette donnée pour l'instant. »
  8. Multiple paraphrase verbs in one text → still single fallback (no double-strike).
  9. Empty / whitespace input → passes unchanged (defensive ; Phase 94 owns the
     empty-input FALLBACK path).
 10. Each of the 11 paraphrase verbs fires the gate (parametrized).
"""
from __future__ import annotations

import pytest

from app.services.coach.runtime_verb_gate import (
    _FALLBACK_FR,
    _ZERO_WIDTH_CHARS,
    gate,
)


_EXPECTED_FALLBACK = "Je n'ai pas cette donnée pour l'instant."

_ELEVEN_PARAPHRASE_VERBS = [
    "le choix le plus avisé",
    "le plus pertinent",
    "plus avantageux que",
    "nettement plus",
    "clairement supérieur",
    "à mon avis",
    "je pense que tu",
    "mon conseil serait",
    "tu devrais",
    "il faut",
    "recommandé",
]


def test_fallback_template_string_is_exact():
    """_FALLBACK_FR is the verbatim Plan-18 template (proper FR accent)."""
    assert _FALLBACK_FR == _EXPECTED_FALLBACK
    # Accent verification — « donnée » must be properly accented, not « donnee ».
    assert "donnée" in _FALLBACK_FR
    assert "donnee" not in _FALLBACK_FR


def test_clean_lsfin_compliant_text_passes_unchanged():
    """Compliant FR (« pourrait », « envisager », « adapté ») returns (True, text)."""
    clean = "Tu pourrais envisager 7000 CHF sur ton 3a. C'est une piste adaptée."
    passed, out = gate(clean)
    assert passed is True
    assert out == clean


def test_base_banned_root_triggers_fallback():
    """A base banned root (« optimal ») fires the gate."""
    text = "Le scénario optimal est A."
    passed, out = gate(text)
    assert passed is False
    assert out == _EXPECTED_FALLBACK


def test_paraphrase_verb_triggers_fallback():
    """A D-CE-16(b) paraphrase verb fires the gate."""
    text = "Tu devrais investir 7000 CHF sur ton 3a."
    passed, out = gate(text)
    assert passed is False
    assert out == _EXPECTED_FALLBACK


def test_nfkc_decomposed_accent_evasion_still_caught():
    """Decomposed-accent « recommandé » (e + U+0301) is NFKC-normalised first."""
    decomposed = "Je recommandé cette piste."  # e + combining acute
    passed, out = gate(decomposed)
    assert passed is False, (
        "NFKC normalisation must compose « e + U+0301 » → « é » before regex"
    )
    assert out == _EXPECTED_FALLBACK


def test_zero_width_char_injection_still_caught():
    """Zero-width space (U+200B) inside « optimal » is stripped before match."""
    # « opti<ZWS>mal » — character-injection evasion vector per arXiv 2512.01353
    injected = "Le scénario opti​mal est A."
    passed, out = gate(injected)
    assert passed is False, (
        "Zero-width-char strip must remove U+200B before regex matches "
        "« optimal »"
    )
    assert out == _EXPECTED_FALLBACK


def test_case_insensitive_match():
    """« OPTIMAL » uppercase still triggers the gate."""
    passed, out = gate("Le scénario OPTIMAL est A.")
    assert passed is False
    assert out == _EXPECTED_FALLBACK


def test_empty_string_passes_through():
    """Empty / whitespace input is NOT the gate's responsibility — pass through.

    Phase 94 citation gate owns the empty-input FALLBACK ; this gate runs
    UPSTREAM and must not preempt that fallback by emitting its own template.
    """
    passed, out = gate("")
    assert passed is True
    assert out == ""


def test_whitespace_only_input_passes_through():
    """Same as empty — pass-through for whitespace."""
    passed, out = gate("   \n\t  ")
    assert passed is True
    assert out == "   \n\t  "


def test_multi_violation_returns_single_fallback():
    """Text with multiple banned terms still returns ONE fallback (no concatenation)."""
    text = "Tu devrais investir dans le scénario optimal."
    passed, out = gate(text)
    assert passed is False
    assert out == _EXPECTED_FALLBACK  # NOT concatenated, NOT modified


@pytest.mark.parametrize("verb", _ELEVEN_PARAPHRASE_VERBS)
def test_each_of_eleven_paraphrase_verbs_fires_gate(verb):
    """All 11 D-CE-16(b) paraphrase verbs trigger fallback."""
    text = f"Selon mon analyse, {verb} pour ton profil."
    passed, out = gate(text)
    assert passed is False, f"Verb {verb!r} should fire the gate"
    assert out == _EXPECTED_FALLBACK


def test_zero_width_chars_constant_present():
    """_ZERO_WIDTH_CHARS includes U+200B/200C/200D/FEFF/2060 (5 entries)."""
    assert "​" in _ZERO_WIDTH_CHARS  # ZERO WIDTH SPACE
    assert "‌" in _ZERO_WIDTH_CHARS  # ZERO WIDTH NON-JOINER
    assert "‍" in _ZERO_WIDTH_CHARS  # ZERO WIDTH JOINER
    assert "﻿" in _ZERO_WIDTH_CHARS  # ZERO WIDTH NO-BREAK SPACE
    assert "⁠" in _ZERO_WIDTH_CHARS  # WORD JOINER
    assert len(_ZERO_WIDTH_CHARS) >= 5


# ---------------------------------------------------------------------------
# Stage 0-followup (2026-05-17, post mint-calc-engine-v1) — drift guard.
# Runtime gate inlines its banned-term vocabulary so the Railway container
# (where `tools/checks/banned_terms_python.py` is NOT shipped) can boot.
# This test asserts the 3 inlined tuples match the canonical lint exactly.
# Runs in CI + local — both files are present here. Drift = test fails.
# ---------------------------------------------------------------------------
def test_runtime_lint_drift_guard():
    """Runtime gate's 3 banned-term tuples MUST match the lint canonical.

    Inlined values live in `runtime_verb_gate.py` (so Railway container can
    boot without `tools/` on Python path). Source-of-truth values live in
    `tools/checks/banned_terms_python.py`. Any drift between the two would
    create a Layer-(b) ↔ Layer-(c) defense gap : the lint flags a verb at
    commit-time but the runtime gate doesn't catch it at narrator output
    (or vice versa).

    Test uses importlib (not regular import) because `tools/` is not on
    Python path from `services/backend/tests/`. Test SKIPS cleanly if the
    canonical lint file cannot be found — that's the expected state on
    Railway container ; the test is a dev-box / CI gate, not a runtime gate.
    """
    import importlib.util
    from pathlib import Path

    from app.services.coach.runtime_verb_gate import (
        BANNED_PARAPHRASE_VERBS as runtime_paraphrase,
        _PHRASE_BANNED as runtime_phrase,
        _WORD_BOUNDARY_BANNED as runtime_word,
    )

    # Walk up from `services/backend/tests/test_runtime_banned_verb_gate.py`
    # to the repo root (parents[3] = repo root) then into `tools/checks/`.
    lint_path = (
        Path(__file__).resolve().parents[3]
        / "tools"
        / "checks"
        / "banned_terms_python.py"
    )

    if not lint_path.is_file():
        pytest.skip(
            f"Canonical lint not found at {lint_path} — skipping drift guard. "
            f"Expected state on Railway container (build context excludes "
            f"repo-root tools/). On dev-box / CI this should resolve."
        )

    spec = importlib.util.spec_from_file_location(
        "banned_terms_python_drift_guard", lint_path
    )
    assert spec is not None and spec.loader is not None
    lint_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(lint_module)

    assert runtime_word == tuple(lint_module._WORD_BOUNDARY_BANNED), (
        f"_WORD_BOUNDARY_BANNED drift — runtime={runtime_word!r} vs "
        f"lint={tuple(lint_module._WORD_BOUNDARY_BANNED)!r}. Sync "
        f"runtime_verb_gate.py with tools/checks/banned_terms_python.py."
    )
    assert runtime_phrase == tuple(lint_module._PHRASE_BANNED), (
        f"_PHRASE_BANNED drift — runtime={runtime_phrase!r} vs "
        f"lint={tuple(lint_module._PHRASE_BANNED)!r}"
    )
    assert runtime_paraphrase == tuple(lint_module.BANNED_PARAPHRASE_VERBS), (
        f"BANNED_PARAPHRASE_VERBS drift — runtime={runtime_paraphrase!r} vs "
        f"lint={tuple(lint_module.BANNED_PARAPHRASE_VERBS)!r}"
    )
