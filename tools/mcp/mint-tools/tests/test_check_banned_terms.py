"""TOOL-02 unit tests. Proves detection on LSFin strings, empty-safe, DoS
capped, and sanitized_text parity with ComplianceGuard canonical.
"""
from __future__ import annotations

import pytest

from tools.banned_terms import (
    MAX_TEXT_LEN,
    TOOL_VERSION,
    BannedTermsResult,
    check_banned_terms,
)


def test_clean_text_returns_banned_empty_and_clean_true() -> None:
    result = check_banned_terms("bonjour tout va bien")
    assert isinstance(result, BannedTermsResult)
    assert result.clean is True
    assert result.banned_found == []
    assert result.sanitized_text == "bonjour tout va bien"
    assert result.text_length == 20
    assert result.version == TOOL_VERSION


def test_empty_text_is_safe() -> None:
    result = check_banned_terms("")
    assert result.clean is True
    assert result.banned_found == []
    assert result.sanitized_text == ""
    assert result.text_length == 0


def test_none_text_is_safe() -> None:
    """Non-string input must not crash the tool."""
    result = check_banned_terms(None)  # type: ignore[arg-type]
    assert result.clean is True
    assert result.banned_found == []
    assert result.text_length == 0


def test_detects_garanti() -> None:
    """'garanti' is the canonical LSFin banned term from TERM_REPLACEMENTS."""
    result = check_banned_terms("ce produit est garanti")
    assert result.clean is False
    assert len(result.banned_found) >= 1
    terms = {h.term.lower() for h in result.banned_found}
    assert "garanti" in terms
    # Sanitized text must differ from input
    assert result.sanitized_text != "ce produit est garanti"


def test_detects_multiple_banned_terms() -> None:
    """Multi-term input surfaces all hits."""
    result = check_banned_terms("rendement garanti, meilleur choix sans risque")
    assert result.clean is False
    terms = {h.term.lower() for h in result.banned_found}
    # At least two of the canonical terms must be flagged
    assert len(terms & {"garanti", "meilleur", "sans risque"}) >= 2


def test_hit_has_suggestion_from_term_replacements() -> None:
    """Each hit carries a replacement string from ComplianceGuard.TERM_REPLACEMENTS."""
    result = check_banned_terms("c'est garanti")
    assert len(result.banned_found) >= 1
    garanti_hits = [h for h in result.banned_found if h.term.lower() == "garanti"]
    assert len(garanti_hits) == 1
    # Suggestion is non-empty and matches the canonical replacement
    assert garanti_hits[0].suggestion
    assert "garanti" not in garanti_hits[0].suggestion.lower()


def test_text_over_cap_is_truncated_for_scanning_but_length_reported() -> None:
    """DoS mitigation: inputs >MAX_TEXT_LEN scanned up to cap, original length reported."""
    payload = "a" * (MAX_TEXT_LEN + 500)
    result = check_banned_terms(payload)
    assert result.text_length == MAX_TEXT_LEN + 500
    # Sanitization ran on the MAX_TEXT_LEN-char prefix only
    assert len(result.sanitized_text) <= MAX_TEXT_LEN


def test_statelessness() -> None:
    a = check_banned_terms("test garanti").model_dump()
    b = check_banned_terms("test garanti").model_dump()
    assert a == b


def test_sanitization_parity_with_guard() -> None:
    """sanitized_text MUST equal ComplianceGuard._sanitize_banned_terms output for
    the scanned prefix — this is the contract with backend ground truth."""
    from app.services.coach.compliance_guard import ComplianceGuard

    guard = ComplianceGuard()
    src = "rendement garanti"
    expected = guard._sanitize_banned_terms(src)
    result = check_banned_terms(src)
    assert result.sanitized_text == expected


def test_response_schema_is_pydantic_v2() -> None:
    dumped = check_banned_terms("ok").model_dump()
    assert set(dumped.keys()) == {
        "version",
        "clean",
        "banned_found",
        "sanitized_text",
        "text_length",
    }


def test_module_scope_guard_singleton() -> None:
    """The guard must be instantiated at most once per process (Pitfall 4:
    HallucinationDetector cold-start is expensive)."""
    from tools import banned_terms as mod

    # First call populates _GUARD
    check_banned_terms("ping")
    guard_a = mod._GUARD
    # Second call must not re-instantiate
    check_banned_terms("pong")
    guard_b = mod._GUARD
    assert guard_a is not None
    assert guard_a is guard_b
