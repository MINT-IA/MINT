"""Phase 95 — D-12 LSFin anti-promise annotation lint."""
from __future__ import annotations

import subprocess
import textwrap
from pathlib import Path

# Lint script lives at <repo>/tools/checks/banned_terms_python.py.
# parents[0] = test_dag_invalidation/, [1] = tests/, [2] = backend/,
# [3] = services/, [4] = repo root (MINT.nosync).
LINT = str(Path(__file__).resolve().parents[4] / "tools" / "checks" / "banned_terms_python.py")


def _write_and_lint(tmp_path, content: str) -> tuple:
    src = tmp_path / "sample.py"
    src.write_text(content, encoding="utf-8")
    result = subprocess.run(
        ["python3", LINT, "--lsfin-annotation", str(src)],
        capture_output=True,
        text=True,
    )
    return result.returncode, result.stdout + result.stderr


def test_credible_intervals_without_annotation_fails(tmp_path):
    code = textwrap.dedent("""
        def render():
            entry = {"credible_low": 100, "credible_high": 200}
            return "Tu peux esperer entre 100 et 200 CHF par mois."
    """)
    rc, _ = _write_and_lint(tmp_path, code)
    assert rc != 0


def test_credible_intervals_with_annotation_passes(tmp_path):
    code = textwrap.dedent("""
        def render():
            entry = {"credible_low": 100, "credible_high": 200}
            return "Tu peux envisager entre 100 et 200 CHF par mois (selon le modèle simplifié actuel)."
    """)
    rc, _ = _write_and_lint(tmp_path, code)
    assert rc == 0


def test_no_credible_interval_no_annotation_required(tmp_path):
    code = textwrap.dedent("""
        def render():
            return "Article LIFD art. 33."
    """)
    rc, _ = _write_and_lint(tmp_path, code)
    assert rc == 0


def test_paraphrase_rejected(tmp_path):
    code = textwrap.dedent("""
        def render():
            entry = {"credible_low": 100, "credible_high": 200}
            return "Entre 100 et 200 CHF (selon notre modèle actuel)."
    """)
    rc, _ = _write_and_lint(tmp_path, code)
    assert rc != 0


def test_ascii_e_rejected(tmp_path):
    code = textwrap.dedent("""
        def render():
            entry = {"credible_low": 100, "credible_high": 200}
            return "Entre 100 et 200 (selon le modele simplifie actuel)."
    """)
    rc, _ = _write_and_lint(tmp_path, code)
    assert rc != 0
