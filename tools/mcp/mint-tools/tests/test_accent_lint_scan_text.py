"""Tests for the additive scan_text(text) helper in tools/checks/accent_lint_fr.py.

Ensures Phase 30.7 TOOL-04 backend is ready before Wave 1 wraps it in an MCP tool.
Also guards against accidental regression in scan_file (which now delegates to scan_text).
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Resolve tools/checks/ on sys.path. conftest.py puts services/backend on path;
# we also need repo root for `tools.checks.*` to resolve as a namespace package.
# test file is at tools/mcp/mint-tools/tests/... so parents[4] == repo root.
_REPO_ROOT = Path(__file__).resolve().parents[4]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from tools.checks.accent_lint_fr import PATTERNS, scan_file, scan_text  # noqa: E402


def test_empty_text_returns_empty_list() -> None:
    assert scan_text("") == []


def test_clean_accented_fr_returns_empty(sample_clean_fr_text: str) -> None:
    assert scan_text(sample_clean_fr_text) == []


def test_single_violation_returns_tuple() -> None:
    out = scan_text("creer un plan")
    assert len(out) == 1
    lineno, snippet, pat = out[0]
    assert lineno == 1
    assert snippet == "creer un plan"
    assert pat == r"\bcreer\b -> créer"


def test_line_numbers_are_1_indexed() -> None:
    out = scan_text("ligne 1 accents ok\ncreer ligne 2\ndecouvrir ligne 3")
    linenos = sorted({lineno for lineno, _, _ in out})
    assert linenos == [2, 3]


@pytest.mark.parametrize(
    "ascii_word,expected_correction",
    [
        ("creer", "créer"),
        ("decouvrir", "découvrir"),
        ("eclairage", "éclairage"),
        ("securite", "sécurité"),
        ("liberer", "libérer"),
        ("preter", "prêter"),
        ("realiser", "réaliser"),
        ("deja", "déjà"),
        ("recu", "reçu"),
        ("elaborer", "élaborer"),
        ("regler", "régler"),
        # Phase 34 Plan 01 D-11 reconciliation — 3 stems added, 3 removed.
        # Canonical 14 now matches CLAUDE.md §2 exactly. See
        # tests/checks/test_accent_lint_fr.py for the cardinality guard.
        ("prevoyance", "prévoyance"),
        ("reperer", "repérer"),
        ("cle", "clé"),
    ],
)
def test_each_pattern_detected(ascii_word: str, expected_correction: str) -> None:
    out = scan_text(f"Il faut {ascii_word} rapidement.")
    assert len(out) >= 1, f"Pattern for '{ascii_word}' did not fire"
    # Correction is present in one of the tuples' third field.
    assert any(expected_correction in triplet[2] for triplet in out)


def test_pattern_count_matches_claude_md_section_2() -> None:
    """CLAUDE.md §2 defines exactly 14 canonical accent patterns. Phase 34
    Plan 01 reconciled this list (D-11) — drift any direction fails here
    AND in tests/checks/test_accent_lint_fr.py::test_pattern_set_matches_canonical.
    """
    assert len(PATTERNS) == 14


def test_scan_file_still_delegates_to_scan_text(tmp_path: Path) -> None:
    """Regression guard: scan_file behavior preserved post-refactor."""
    target = tmp_path / "sample.py"
    target.write_text("# creer\n", encoding="utf-8")
    out = scan_file(target)
    assert len(out) == 1
    assert out[0][0] == 1  # lineno
