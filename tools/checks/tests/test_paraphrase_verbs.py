"""Tests for `tools/checks/banned_terms_python.py` paraphrase-verb extension.

Phase mint-calc-engine-v1 Plan 18 / W4 — D-CE-16 layer (b) lint-time defense.

Scope :
  1. The 11 paraphrase verbs from CONTEXT §D-CE-16 are present in the lint's
     scanned vocabulary (combined word-boundary + phrase scans).
  2. A synthetic Python file containing each paraphrase verb is flagged
     (exit 1 + match reported on file:line).
  3. The pre-existing 7 base banned roots remain flagged (no regression).
  4. A SAFE Python file using LSFin-compliant wording (« pourrait »,
     « envisager », « adapté ») exits 0.
  5. NFKC-equivalent input (degree-sign noise, decomposed accents) is
     reduced to its canonical form before regex match, so banned terms
     cannot be hidden behind unicode-equivalence games.

Tests load `banned_terms_python` via importlib so they are independent of the
package path of the test runner (`tools.checks` is not a real installed
package — it's a flat checks dir).
"""
from __future__ import annotations

import importlib.util
import subprocess
import sys
import unicodedata
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[3]
_LINT_PATH = _REPO_ROOT / "tools" / "checks" / "banned_terms_python.py"


def _load_lint_module():
    spec = importlib.util.spec_from_file_location("banned_terms_python", _LINT_PATH)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# The 11 D-CE-16(b) paraphrase verbs — verbatim from CONTEXT §D-CE-16.
# Listed here as the canonical source so the test file fails LOUD if the
# lint's extension diverges from the doctrine.
# ---------------------------------------------------------------------------
_EXPECTED_PARAPHRASE_VERBS = [
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


def test_lint_module_exposes_paraphrase_verbs_constant():
    """The lint module exports an 11-entry BANNED_PARAPHRASE_VERBS tuple."""
    mod = _load_lint_module()
    assert hasattr(mod, "BANNED_PARAPHRASE_VERBS"), (
        "banned_terms_python.py must export BANNED_PARAPHRASE_VERBS "
        "(D-CE-16(b) extension)"
    )
    paraphrase = tuple(mod.BANNED_PARAPHRASE_VERBS)
    assert len(paraphrase) == 11, (
        f"Expected 11 paraphrase verbs per CONTEXT §D-CE-16(b), "
        f"got {len(paraphrase)}: {paraphrase}"
    )
    for verb in _EXPECTED_PARAPHRASE_VERBS:
        assert verb in paraphrase, f"Missing paraphrase verb: {verb!r}"


def test_all_11_paraphrase_verbs_scanned_by_lint(tmp_path):
    """Each of the 11 paraphrase verbs triggers exit 1 on a fixture file."""
    mod = _load_lint_module()
    for verb in _EXPECTED_PARAPHRASE_VERBS:
        fixture = tmp_path / f"verb_{abs(hash(verb))}.py"
        fixture.write_text(
            f'""""Sample violation fixture."""\n'
            f'narrator_output = "Pour ta situation, {verb} cette piste."\n',
            encoding="utf-8",
        )
        hits = mod.scan_file(fixture)
        assert hits, (
            f"Verb {verb!r} should be flagged by scan_file ; got no hits. "
            f"Lint extension is missing this paraphrase verb."
        )


@pytest.mark.parametrize("verb", _EXPECTED_PARAPHRASE_VERBS)
def test_lint_cli_exit_1_per_paraphrase_verb(tmp_path, verb):
    """`python3 banned_terms_python.py <fixture>` exits 1 per paraphrase verb."""
    fixture = tmp_path / "violation.py"
    fixture.write_text(
        f'sample = "Selon mon analyse, {verb} pour ce profil."\n',
        encoding="utf-8",
    )
    result = subprocess.run(
        [sys.executable, str(_LINT_PATH), str(fixture)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 1, (
        f"Lint should exit 1 on verb {verb!r} ; got returncode "
        f"{result.returncode} ; stderr={result.stderr!r}"
    )
    assert "banned term" in result.stderr.lower(), result.stderr


def test_base_seven_terms_still_flagged(tmp_path):
    """The 7 pre-existing CLAUDE.md §1 base banned roots remain flagged."""
    mod = _load_lint_module()
    base_terms = [
        "garanti",
        "optimal",
        "meilleur",
        "certain",
        "assure",
        "parfait",
        "sans risque",
    ]
    for term in base_terms:
        fixture = tmp_path / f"base_{term.replace(' ', '_')}.py"
        fixture.write_text(
            f'sample = "Le rendement est {term} pour cette piste."\n',
            encoding="utf-8",
        )
        hits = mod.scan_file(fixture)
        assert hits, f"Base term {term!r} regression — not flagged."


def test_safe_lsfin_wording_passes(tmp_path):
    """Compliant FR (« pourrait », « envisager », « adapté ») exits 0."""
    safe_file = tmp_path / "safe.py"
    safe_file.write_text(
        'sample = (\n'
        '    "Tu pourrais envisager d\'allouer 7000 CHF à ton 3a. "\n'
        '    "Cette piste est adaptée à ton profil. "\n'
        '    "Tu peux aussi explorer une alternative."\n'
        ')\n',
        encoding="utf-8",
    )
    result = subprocess.run(
        [sys.executable, str(_LINT_PATH), str(safe_file)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"Safe LSFin wording should pass ; got returncode "
        f"{result.returncode} ; stderr={result.stderr!r}"
    )


def test_nfkc_normalised_input_still_flagged(tmp_path):
    """NFKC-equivalent input (decomposed accents) is reduced before match.

    The scan_file path reads the file as UTF-8 and applies NFKC normalisation
    so a decomposed-accent variant of « recommandé » (the `é` written as
    `e` + U+0301 combining acute) is still flagged.
    """
    mod = _load_lint_module()
    fixture = tmp_path / "decomposed.py"
    # « recommande » + combining acute ⇒ « recommandé » after NFKC.
    decomposed = "recommandé"
    assert unicodedata.normalize("NFKC", decomposed) == "recommandé"
    fixture.write_text(
        f'narrator = "Je {decomposed} cette piste."\n',
        encoding="utf-8",
    )
    hits = mod.scan_file(fixture)
    assert hits, (
        "Decomposed-accent « recommandé » should be flagged after NFKC "
        "normalisation ; got no hits. Lint extension may be missing NFKC."
    )
