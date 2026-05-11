"""Phase 93.5 Wave 4 — meta-quote / negation aware banned-term scorer tests.

The Plan 93.5-04 live eval flagged narrator outputs like
« Aucun 3a n'est garanti » and « Pas de "meilleur" universel » as
banned-term failures. Those are the LUCID compliance behavior MINT wants —
the narrator is REFUTING the user's banned claim, not asserting it.

This test file pins the new scorer behavior so a future refactor cannot
silently re-introduce the false-positive that hid the real bundle-vs-legacy
quality signal in `93.5-04-EVAL-RESULTS.md`.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


# Load `tools/eval_narrator.py` (not part of the app package) by file path.
def _load_eval_module():
    project_root = Path(__file__).resolve().parents[1]
    module_path = project_root / "tools" / "eval_narrator.py"
    spec = importlib.util.spec_from_file_location("eval_narrator_wave4", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules["eval_narrator_wave4"] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def eval_module():
    return _load_eval_module()


# ---------------------------------------------------------------------------
# Negation patterns (the bulk of the false-positives in 93.5-04 eval)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "response,banned,reason",
    [
        # Real fix-01 excerpt — narrator REFUTES "garanti" with "aucun"
        (
            "**Aucun 3a n'est garanti** (sauf le compte bancaire classique).",
            ["garanti"],
            "aucun + n'est + banned-term — meta-negation",
        ),
        # Real fix-03 excerpt
        (
            "**Aucun placement financier n'est sans risque** (LSFin).",
            ["sans risque"],
            "aucun + n'est + banned-term — meta-negation",
        ),
        # Pas de + banned-term
        (
            "Pas de meilleur universel.",
            ["meilleur"],
            "pas de + banned-term",
        ),
        # n'existe pas
        (
            "Le rendement garanti n'existe pas dans les marchés actions.",
            ["garanti"],
            "n'existe pas — meta-negation",
        ),
        # Il n'y a pas de
        (
            "Il n'y a pas de placement parfait.",
            ["parfait"],
            "il n'y a pas de — meta-negation",
        ),
        # Jamais
        (
            "On ne peut jamais dire qu'un placement est sans risque.",
            ["sans risque"],
            "jamais — meta-negation",
        ),
    ],
)
def test_meta_negation_excused(eval_module, response, banned, reason):
    passed, found, excused = eval_module._score_banned_terms(response, banned)
    assert passed is True, (
        f"Expected meta-negation to be excused ({reason}); "
        f"got found={found}, excused={excused}"
    )
    assert len(excused) >= 1, f"Expected ≥1 excused entry; got {excused}"
    assert all(e["term"] in banned for e in excused)


# ---------------------------------------------------------------------------
# Quoted patterns (meta-quote refutation)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "response,banned,reason",
    [
        # Real fix-02 excerpt — meta-quote
        (
            'Pas de "meilleur" universel.',
            ["meilleur"],
            'meta-quoted with " + negation',
        ),
        # French guillemets
        (
            "Le concept de « garanti » n'existe que pour la garantie des dépôts FINMA.",
            ["garanti"],
            "« » — meta-quoted",
        ),
        # Curly quotes
        (
            "L'idée d'un placement “sans risque” n'a pas de sens en marchés.",
            ["sans risque"],
            "curly quotes — meta-quoted",
        ),
    ],
)
def test_meta_quoted_excused(eval_module, response, banned, reason):
    passed, found, excused = eval_module._score_banned_terms(response, banned)
    assert passed is True, (
        f"Expected meta-quote to be excused ({reason}); "
        f"got found={found}, excused={excused}"
    )
    assert len(excused) >= 1


# ---------------------------------------------------------------------------
# True positives — the scorer MUST still flag actual narrator-asserted bans
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "response,banned,reason",
    [
        # Plain assertion — narrator USES the banned term as a positive claim
        (
            "Ton 3a est garanti à 4% par an, c'est le meilleur rendement.",
            ["garanti", "meilleur"],
            "plain assertion of banned terms",
        ),
        # Sentence-level isolation — negation in PRIOR sentence does NOT excuse
        # the banned term in the NEXT sentence.
        (
            "Aucun 3a n'est risqué. Mais le LPP est garanti à vie.",
            ["garanti"],
            "negation in prior sentence does not cross sentence boundary",
        ),
        # Banned term in a FACTUAL claim about a regulator
        # (Phase 94 will excuse via citation parser ; Wave 4 keeps the flag)
        (
            "Le compte bancaire classique est garanti jusqu'à 100'000 CHF par FINMA.",
            ["garanti"],
            "factual citation — Phase 94 will excuse, Wave 4 still flags",
        ),
    ],
)
def test_true_positives_still_flagged(eval_module, response, banned, reason):
    passed, found, excused = eval_module._score_banned_terms(response, banned)
    assert passed is False, (
        f"Expected scorer to flag the assertion ({reason}); "
        f"got passed=True, found={found}, excused={excused}"
    )
    assert len(found) >= 1


# ---------------------------------------------------------------------------
# Mixed: narrator refutes + later asserts — must flag the assertion
# ---------------------------------------------------------------------------

def test_mixed_meta_then_real_use_flags_real_use(eval_module):
    """If the narrator refutes a term then ALSO uses it as a positive claim,
    the scorer must surface the positive claim as a fail."""
    response = (
        "Aucun placement n'est garanti.\n\n"
        "Mais ton 3a Swisscanto rapporte un 4% garanti à vie."
    )
    passed, found, excused = eval_module._score_banned_terms(response, ["garanti"])
    assert passed is False
    assert "garanti" in found
    assert len(excused) >= 1  # the first (refuting) use is excused


# ---------------------------------------------------------------------------
# Empty / edge cases
# ---------------------------------------------------------------------------

def test_empty_response(eval_module):
    passed, found, excused = eval_module._score_banned_terms(
        "", ["garanti", "meilleur"]
    )
    assert passed is True
    assert found == []
    assert excused == []


def test_empty_banned_list(eval_module):
    passed, found, excused = eval_module._score_banned_terms(
        "Le rendement garanti et meilleur universel.", []
    )
    assert passed is True
    assert found == []
    assert excused == []
