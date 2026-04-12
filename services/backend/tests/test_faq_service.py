"""
Tests for FaqService — RAG v2.

Validates FAQ count, structure, search, and category filtering.
"""

from __future__ import annotations

import re as _re

import pytest

from app.services.rag.faq_service import FaqEntry, FaqService
from app.services.rag.knowledge_catalog import KnowledgeCategory


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def all_faqs() -> list[FaqEntry]:
    return FaqService.all_faqs()


# ---------------------------------------------------------------------------
# Basic count and structure
# ---------------------------------------------------------------------------


def test_at_least_50_faqs(all_faqs):
    """There must be at least 50 FAQs."""
    assert len(all_faqs) >= 50, f"Expected >= 50 FAQs, got {len(all_faqs)}"


def test_all_faqs_have_id(all_faqs):
    """Every FAQ must have a non-empty id."""
    for faq in all_faqs:
        assert faq.id and faq.id.strip(), f"FAQ has empty id: {faq}"


def test_all_faqs_have_question(all_faqs):
    """Every FAQ must have a non-empty question."""
    for faq in all_faqs:
        assert faq.question and faq.question.strip(), (
            f"FAQ {faq.id} has empty question"
        )


def test_all_faqs_have_answer(all_faqs):
    """Every FAQ must have a non-empty answer."""
    for faq in all_faqs:
        assert faq.answer and faq.answer.strip(), (
            f"FAQ {faq.id} has empty answer"
        )


def test_all_faqs_have_category(all_faqs):
    """Every FAQ must have a valid KnowledgeCategory."""
    valid_cats = set(KnowledgeCategory)
    for faq in all_faqs:
        assert faq.category in valid_cats, (
            f"FAQ {faq.id} has invalid category: {faq.category}"
        )


def test_no_duplicate_faq_ids(all_faqs):
    """All FAQ IDs must be unique."""
    ids = [f.id for f in all_faqs]
    unique_ids = set(ids)
    assert len(ids) == len(unique_ids), (
        f"Duplicate FAQ IDs: {[x for x in ids if ids.count(x) > 1]}"
    )


def test_faq_entries_are_faq_entry_instances(all_faqs):
    """all_faqs() returns FaqEntry instances."""
    for faq in all_faqs:
        assert isinstance(faq, FaqEntry)


# ---------------------------------------------------------------------------
# Compliance checks — no banned terms
# ---------------------------------------------------------------------------

# Banned as absolute promises — checked as whole words to avoid false positives
# (e.g. "certain" banned but not "certaines/certains" as adjectives)
_BANNED_TERMS_WHOLE_WORD = [
    "garanti", "garantis", "garantie", "garanties",
    "sans risque",
    "optimal", "optimaux",
    "parfait", "parfaite",
]
# These must not appear at all (even as substrings)
_BANNED_TERMS_SUBSTRING = ["risk-free"]


def test_no_banned_terms_in_answers(all_faqs):
    """FAQ answers must not contain banned terms (whole-word or absolute)."""
    for faq in all_faqs:
        lower_answer = faq.answer.lower()
        for term in _BANNED_TERMS_WHOLE_WORD:
            pattern = rf"\b{_re.escape(term)}\b"
            assert not _re.search(pattern, lower_answer), (
                f"FAQ {faq.id} contains banned term '{term}' in answer"
            )
        for term in _BANNED_TERMS_SUBSTRING:
            assert term not in lower_answer, (
                f"FAQ {faq.id} contains banned substring '{term}' in answer"
            )


# ---------------------------------------------------------------------------
# Category filtering
# ---------------------------------------------------------------------------


def test_by_category_avs():
    """AVS category returns relevant FAQs."""
    avs_faqs = FaqService.by_category(KnowledgeCategory.AVS)
    assert len(avs_faqs) >= 3, f"Expected >= 3 AVS FAQs, got {len(avs_faqs)}"


def test_by_category_lpp():
    """LPP category returns relevant FAQs."""
    lpp_faqs = FaqService.by_category(KnowledgeCategory.LPP)
    assert len(lpp_faqs) >= 3, f"Expected >= 3 LPP FAQs, got {len(lpp_faqs)}"


def test_by_category_pillar_3a():
    """PILLAR_3A category returns relevant FAQs."""
    faqs = FaqService.by_category(KnowledgeCategory.PILLAR_3A)
    assert len(faqs) >= 3, f"Expected >= 3 3A FAQs, got {len(faqs)}"


def test_by_category_fiscal():
    """FISCAL category returns relevant FAQs."""
    faqs = FaqService.by_category(KnowledgeCategory.FISCAL)
    assert len(faqs) >= 3


def test_by_category_returns_only_that_category():
    """by_category returns only FAQs of the requested category."""
    for cat in KnowledgeCategory:
        faqs = FaqService.by_category(cat)
        for faq in faqs:
            assert faq.category == cat, (
                f"FAQ {faq.id} has category {faq.category}, expected {cat}"
            )


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------


def test_search_avs_returns_results():
    """Search for 'avs rente' returns relevant results."""
    results = FaqService.search("avs rente")
    assert len(results) > 0


def test_search_lpp_returns_results():
    """Search for 'lpp rachat' returns relevant results."""
    results = FaqService.search("lpp rachat")
    assert len(results) > 0


def test_search_hypotheque_returns_results():
    """Search for 'hypothèque' returns results."""
    results = FaqService.search("hypothèque")
    assert len(results) > 0


def test_search_3a_plafond_returns_results():
    """Search for 'plafond 3a' returns results."""
    results = FaqService.search("plafond 3a")
    assert len(results) > 0


def test_search_empty_string_returns_empty():
    """Empty search returns empty list."""
    result = FaqService.search("")
    assert result == []


def test_search_whitespace_returns_empty():
    """Whitespace-only search returns empty list."""
    result = FaqService.search("   ")
    assert result == []


def test_search_unrelated_term_returns_empty_or_few():
    """Search for completely unrelated term returns no results."""
    result = FaqService.search("xyzabcnonexistent")
    assert result == []


def test_search_returns_faq_entry_instances():
    """Search results are FaqEntry instances."""
    results = FaqService.search("retraite")
    for r in results:
        assert isinstance(r, FaqEntry)


# ---------------------------------------------------------------------------
# by_id
# ---------------------------------------------------------------------------


def test_by_id_returns_correct_faq(all_faqs):
    """by_id returns the correct FAQ for a known ID."""
    first = all_faqs[0]
    result = FaqService.by_id(first.id)
    assert result is not None
    assert result.id == first.id
    assert result.question == first.question


def test_by_id_unknown_returns_none():
    """by_id returns None for unknown ID."""
    result = FaqService.by_id("nonexistent_faq_id_xyz")
    assert result is None


# ---------------------------------------------------------------------------
# Canton-specific
# ---------------------------------------------------------------------------


def test_canton_specific_faq_exists():
    """At least one FAQ must be canton-specific (ZG)."""
    zg_faqs = FaqService.by_canton("ZG")
    assert len(zg_faqs) >= 1, "Expected at least one canton-specific FAQ for ZG"


def test_by_canton_unknown_returns_empty():
    """by_canton for unknown canton returns empty list."""
    result = FaqService.by_canton("XX")
    assert result == []
