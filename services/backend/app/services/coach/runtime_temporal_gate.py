"""Runtime temporal-anchor gate for current-year coach questions.

CJT-021: a response can cite the correct 2026 3a ceiling while still using
past-year timing examples ("janvier 2025") for a user asking "cette annee".
This gate is deliberately narrower than the numeric freshness gate: it only
blocks past month/year anchors when the user question is current-year scoped.
"""
from __future__ import annotations

import datetime as _dt
import re
import unicodedata
from typing import Optional


_FALLBACK_FR: str = "Je n'ai pas cette donnée à jour pour l'instant."

_ZERO_WIDTH_CHARS: frozenset[str] = frozenset({
    "​",  # ZERO WIDTH SPACE
    "‌",  # ZERO WIDTH NON-JOINER
    "‍",  # ZERO WIDTH JOINER
    "﻿",  # ZERO WIDTH NO-BREAK SPACE (BOM)
    "⁠",  # WORD JOINER
})

_CURRENT_YEAR_ANCHOR_RE: re.Pattern[str] = re.compile(
    r"\b(?:cette\s+ann[ée]e|this\s+year|ann[ée]e\s+en\s+cours|"
    r"ann[ée]e\s+fiscale\s+courante)\b",
    re.IGNORECASE,
)

_THREE_A_CEILING_QUESTION_RE: re.Pattern[str] = re.compile(
    r"\b(?:3a|troisi[eè]me\s+pilier|pilier\s+3a)\b.*"
    r"\b(?:combien|mettre|verser|plafond|encore|reste|d[ée]ductible)\b|"
    r"\b(?:combien|mettre|verser|plafond|encore|reste|d[ée]ductible)\b.*"
    r"\b(?:3a|troisi[eè]me\s+pilier|pilier\s+3a)\b",
    re.IGNORECASE,
)

_MARKET_REQUEST_RE: re.Pattern[str] = re.compile(
    r"\b(?:rendement|march[ée]|titres?|etf|fonds?|risque|placement|produit|cash)\b",
    re.IGNORECASE,
)

_MARKET_TIMING_RE: re.Pattern[str] = re.compile(
    r"\b(?:rendement\s+potentiel|march[ée]\s+en\s+plus|"
    r"rapport(?:er|era|e|ent)?\s+un\s+an\s+de\s+march[ée])\b",
    re.IGNORECASE,
)

_MONTH_YEAR_RE: re.Pattern[str] = re.compile(
    r"\b(?:janvier|fevrier|février|mars|avril|mai|juin|juillet|aout|août|"
    r"septembre|octobre|novembre|decembre|décembre)\s+"
    r"(?P<year>19\d{2}|20\d{2})\b",
    re.IGNORECASE,
)

_YEAR_RE: re.Pattern[str] = re.compile(r"\b(19\d{2}|20\d{2})\b")


def _strip_zero_width(s: str) -> str:
    if not s:
        return s
    if not any(c in _ZERO_WIDTH_CHARS for c in s):
        return s
    return "".join(c for c in s if c not in _ZERO_WIDTH_CHARS)


def _clean(s: str) -> str:
    return _strip_zero_width(unicodedata.normalize("NFKC", s or ""))


def _is_current_year_question(user_message: str, current_year: int) -> bool:
    cleaned = _clean(user_message)
    return bool(_CURRENT_YEAR_ANCHOR_RE.search(cleaned)) or str(current_year) in {
        m.group(0) for m in _YEAR_RE.finditer(cleaned)
    }


def _years_mentioned(text: str) -> set[int]:
    return {int(m.group(0)) for m in _YEAR_RE.finditer(_clean(text))}


def _is_current_3a_ceiling_question(user_message: str, current_year: int) -> bool:
    cleaned = _clean(user_message)
    if _MARKET_REQUEST_RE.search(cleaned):
        return False
    return _is_current_year_question(cleaned, current_year) and bool(
        _THREE_A_CEILING_QUESTION_RE.search(cleaned)
    )


def gate(
    text: str,
    *,
    user_message: str = "",
    current_year: Optional[int] = None,
) -> tuple[bool, str]:
    """Fail closed on past month/year examples in current-year answers."""
    if not text or not text.strip():
        return (True, text)

    effective_year = current_year or _dt.date.today().year
    if not _is_current_year_question(user_message, effective_year):
        return (True, text)

    user_years = _years_mentioned(user_message)
    cleaned = _clean(text)
    if (
        _is_current_3a_ceiling_question(user_message, effective_year)
        and _MARKET_TIMING_RE.search(cleaned)
    ):
        return (False, _FALLBACK_FR)

    for match in _MONTH_YEAR_RE.finditer(cleaned):
        year = int(match.group("year"))
        if year < effective_year and year not in user_years:
            return (False, _FALLBACK_FR)

    return (True, text)


__all__ = ["gate", "_FALLBACK_FR"]
