"""TOOL-04 unit tests.

Proves each of the 14 accent PATTERNS fires through the MCP wrapper, the
response schema is stable, empty / None inputs are safe, and the DoS cap at
10 000 chars is enforced while ``text_length`` still reports the original.
"""
from __future__ import annotations

import pytest

from tools.accent import (
    AccentHit,
    AccentResult,
    MAX_TEXT_LEN,
    TOOL_VERSION,
    check_accent_patterns,
)


def test_empty_text_clean() -> None:
    r = check_accent_patterns("")
    assert r.clean is True
    assert r.violations == []
    assert r.text_length == 0
    assert r.version == TOOL_VERSION


def test_none_input_clean() -> None:
    r = check_accent_patterns(None)  # type: ignore[arg-type]
    assert r.clean is True
    assert r.violations == []
    assert r.text_length == 0


def test_clean_accented_fr_returns_no_violations(sample_clean_fr_text: str) -> None:
    r = check_accent_patterns(sample_clean_fr_text)
    assert r.clean is True
    assert r.violations == []
    assert r.text_length == len(sample_clean_fr_text)


def test_single_violation_has_expected_fields() -> None:
    r = check_accent_patterns("creer un plan")
    assert r.clean is False
    assert len(r.violations) == 1
    hit = r.violations[0]
    assert isinstance(hit, AccentHit)
    assert hit.line == 1
    assert hit.snippet == "creer un plan"
    assert "creer" in hit.pattern
    assert hit.suggestion == "créer"


@pytest.mark.parametrize(
    "ascii_word,expected_suggestion",
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
        ("specialiste", "spécialiste(s)"),
        ("gerer", "gérer"),
        ("progres", "progrès"),
    ],
)
def test_each_of_14_patterns_fires(ascii_word: str, expected_suggestion: str) -> None:
    r = check_accent_patterns(f"Il faut {ascii_word} rapidement.")
    assert not r.clean, f"Pattern for {ascii_word!r} did not fire"
    assert any(expected_suggestion in hit.suggestion for hit in r.violations), (
        f"Expected suggestion {expected_suggestion!r} not found for {ascii_word!r}"
    )


def test_multiline_line_numbers_1_indexed() -> None:
    r = check_accent_patterns("ligne 1 ok\ncreer ligne 2\ndecouvrir ligne 3")
    assert not r.clean
    lines = sorted({hit.line for hit in r.violations})
    assert lines == [2, 3]


def test_text_over_cap_truncated_for_scan() -> None:
    """DoS cap: input > MAX_TEXT_LEN is scanned only on the first 10 000 chars,
    but text_length reports the original length."""
    payload = "a" * (MAX_TEXT_LEN + 500)
    r = check_accent_patterns(payload)
    # No accent issues in a stream of 'a' — just verifies the cap behavior.
    assert r.clean is True
    assert r.text_length == MAX_TEXT_LEN + 500


def test_text_over_cap_with_violation_before_cap() -> None:
    """Accent violations in the first MAX_TEXT_LEN chars still fire."""
    payload = "creer un plan\n" + ("x" * (MAX_TEXT_LEN + 100))
    r = check_accent_patterns(payload)
    assert not r.clean
    assert any(hit.suggestion == "créer" for hit in r.violations)
    assert r.text_length == len(payload)


def test_response_schema_is_pydantic_v2() -> None:
    dumped = check_accent_patterns("creer").model_dump()
    assert dumped["version"] == TOOL_VERSION
    assert set(dumped.keys()) == {"version", "clean", "violations", "text_length"}
    assert set(dumped["violations"][0].keys()) == {
        "line",
        "snippet",
        "pattern",
        "suggestion",
    }


def test_statelessness() -> None:
    a = check_accent_patterns("creer un plan").model_dump()
    b = check_accent_patterns("creer un plan").model_dump()
    assert a == b


def test_no_duplicate_pattern_table_in_tool_module() -> None:
    """Regression guard: tool MUST import scan_text from Wave 0 rather than
    redefining the 14 PATTERNS list locally (would drift from source)."""
    from pathlib import Path

    import tools.accent as accent_mod

    src = Path(accent_mod.__file__).read_text(encoding="utf-8")
    # No local PATTERNS = [ ... ] redefinition.
    for line in src.splitlines():
        stripped = line.strip()
        if stripped.startswith(("#", '"', "'")):
            continue
        assert "PATTERNS = [" not in line and "PATTERNS=[" not in line, (
            f"Tool module must not redefine PATTERNS; import scan_text from Wave 0 instead. "
            f"Offending line: {line!r}"
        )
    # The import is the load-bearing signal.
    assert "from tools.checks.accent_lint_fr import" in src
