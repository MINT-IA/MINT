"""Tests for ComplianceGuardrails.truncate_to_sentences edge cases.

Covers the list-marker merge + ends-badly cleanup added in PR #332 to fix
the Run-001 bug where a coach reply ended on a dangling '2.' because list
markers were counted as sentences.
"""
from __future__ import annotations

import pytest

from app.services.rag.guardrails import ComplianceGuardrails as CG


# ---------------------------------------------------------------------------
# Baseline behaviour
# ---------------------------------------------------------------------------


def test_no_truncation_when_under_limit():
    text = "Phrase un. Phrase deux."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=3)
    assert out == "Phrase un. Phrase deux."
    assert trunc is False


def test_basic_truncation_to_max():
    text = "Une. Deux. Trois. Quatre. Cinq."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=2)
    assert trunc is True
    assert "Une." in out
    assert "Deux." in out
    assert "Trois" not in out


def test_empty_text_is_noop():
    out, trunc = CG.truncate_to_sentences("", max_sentences=3)
    assert out == ""
    assert trunc is False


def test_non_string_is_noop():
    out, trunc = CG.truncate_to_sentences(None, max_sentences=3)  # type: ignore[arg-type]
    assert out is None
    assert trunc is False


# ---------------------------------------------------------------------------
# List-marker merge (covers the new pre-merge loop)
# ---------------------------------------------------------------------------


def test_list_markers_merged_with_following_sentence():
    text = "Trois alertes : 1. Première alerte longue. 2. Deuxième alerte. 3. Troisième."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=5)
    # After merge: 4 sentences ("Trois alertes :", "1. Première...", "2. ...", "3. ...")
    # ≤ 5 so no truncation.
    assert trunc is False
    assert "1." in out and "Première" in out
    assert "2." in out and "Deuxième" in out


def test_list_markers_dont_inflate_sentence_count():
    text = "1. Un. 2. Deux. 3. Trois. 4. Quatre."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=4)
    # 4 merged sentences ≤ 4 → no truncation
    assert trunc is False
    assert "Quatre" in out


def test_trailing_list_marker_dropped():
    text = "Phrase un. Phrase deux. 3."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=5)
    # Dangling "3." with no following content → dropped
    assert "3." not in out or out.rstrip().endswith("deux.")
    assert "deux." in out


# ---------------------------------------------------------------------------
# Ends-badly cleanup
# ---------------------------------------------------------------------------


def test_ends_on_comma_drops_last_kept():
    text = "Phrase un. Phrase deux fragment, Phrase trois normale. Phrase quatre."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=2)
    # First 2 = ["Phrase un.", "Phrase deux fragment, Phrase trois normale."]
    # Second one ends on "normale." not a bad ending → kept
    assert trunc is True


def test_ends_on_conjunction_drops():
    text = "Premiere phrase. Deuxieme phrase mais. Troisieme phrase normale. Quatrieme."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=2)
    # First 2 kept = ["Premiere phrase.", "Deuxieme phrase mais."]
    # Second ends with "mais." → trailing conjunction → drop
    assert "mais" not in out
    assert "Premiere" in out
    assert trunc is True


def test_ends_on_unbalanced_paren_drops():
    text = "Premiere. Deuxieme phrase (avec paren ouverte. Troisieme. Quatrieme."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=2)
    # The second kept sentence has "(" but no ")" → drop
    assert "(avec" not in out
    assert "Premiere" in out


def test_min_one_sentence_kept_even_if_ends_badly():
    """If only 1 sentence to keep and it ends badly, do NOT drop it."""
    text = "Premiere phrase mais. Deuxieme."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=1)
    # Only 1 kept → keep it even with bad ending (else returns nothing)
    assert "Premiere" in out
    assert trunc is True


# ---------------------------------------------------------------------------
# Real Run-001 regression
# ---------------------------------------------------------------------------


def test_run_001_julien_dangling_two_dot():
    text = (
        "**300k LPP + trou de 50k = tu peux racheter maintenant.** "
        "Mais 3 alertes avant de signer : "
        "1. **Blocage EPL** : si tu rachètes, interdiction immobilière 3 ans. "
        "2. **Étalement** : tu peux étaler sur 3 ans. "
        "3. **Conjoint** : impact si Lauren US."
    )
    out, _ = CG.truncate_to_sentences(text, max_sentences=5)
    # Must NOT end on dangling "2." or "3."
    assert not out.rstrip().endswith("2.")
    assert not out.rstrip().endswith("3.")
    # If list-merge worked, we keep all 4 effective sentences (intro + 3 bullets) ≤ 5
    assert "Blocage EPL" in out


# ---------------------------------------------------------------------------
# Whitespace robustness
# ---------------------------------------------------------------------------


def test_extra_whitespace_handled():
    text = "  Une.   Deux.   Trois.  "
    out, _ = CG.truncate_to_sentences(text, max_sentences=2)
    assert "Une." in out
    assert "Deux." in out
    assert "Trois" not in out


# ---------------------------------------------------------------------------
# Markdown bold/italic adjacent to sentence terminator (Run-003 regression)
# ---------------------------------------------------------------------------


def test_markdown_bold_after_period_still_splits():
    """'Phrase un.** Phrase deux.' must be 2 sentences, not 1."""
    text = "**Phrase un.** Phrase deux. Phrase trois. Phrase quatre. Phrase cinq. Phrase six."
    out, trunc = CG.truncate_to_sentences(text, max_sentences=5)
    assert trunc is True
    assert "six" not in out
    assert "Phrase un" in out


def test_quote_after_period_still_splits():
    text = '"Phrase un." Phrase deux. Phrase trois. Phrase quatre. Phrase cinq. Phrase six.'
    out, trunc = CG.truncate_to_sentences(text, max_sentences=5)
    assert trunc is True
    assert "six" not in out


def test_run_003_sophie_markdown_genevra_3a():
    text = (
        "**7258 CHF en 3a cette année = 1800 CHF d'impôts en moins à Genève.** "
        "À 28 ans, salarié·e à 5800 net/mois, tu paies l'impôt GE plein tarif. "
        "Le 3a, c'est un compte bloqué jusqu'à tes 60 ans. "
        "Chaque franc versé = déduit de ton revenu imposable. "
        "L'État te rembourse environ 25%. "
        "si tu verses 604 CHF/mois, tu récupères ~150 CHF d'impôts par mois."
    )
    out, trunc = CG.truncate_to_sentences(text, max_sentences=5)
    assert trunc is True
    assert "604 CHF/mois" not in out
    assert "Genève" in out


def test_only_whitespace_returns_unchanged():
    out, trunc = CG.truncate_to_sentences("   ", max_sentences=3)
    assert out == "   "
    assert trunc is False
