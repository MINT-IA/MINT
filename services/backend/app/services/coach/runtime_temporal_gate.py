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

_FALLBACK_BY_LANGUAGE: dict[str, str] = {
    "fr": _FALLBACK_FR,
    "de": "Ich habe diese Information im Moment nicht aktuell genug.",
    "en": "I do not have up-to-date data for this right now.",
    "it": "Non ho questa informazione aggiornata per il momento.",
    "es": "No tengo este dato actualizado por el momento.",
    "pt": "Não tenho este dado atualizado neste momento.",
}

_ZERO_WIDTH_CHARS: frozenset[str] = frozenset({
    "​",  # ZERO WIDTH SPACE
    "‌",  # ZERO WIDTH NON-JOINER
    "‍",  # ZERO WIDTH JOINER
    "﻿",  # ZERO WIDTH NO-BREAK SPACE (BOM)
    "⁠",  # WORD JOINER
})

_CURRENT_YEAR_ANCHOR_RE: re.Pattern[str] = re.compile(
    r"\b(?:cette\s+ann[ée]e|this\s+year|ann[ée]e\s+en\s+cours|"
    r"ann[ée]e\s+fiscale\s+courante|dieses\s+jahr|quest['’]?anno|"
    r"este\s+a[nñ]o|este\s+ano)\b",
    re.IGNORECASE,
)

_THREE_A_CEILING_QUESTION_RE: re.Pattern[str] = re.compile(
    r"\b(?:3a|troisi[eè]me\s+pilier|pilier\s+3a)\b.*"
    r"\b(?:combien|mettre|verser|plafond|encore|reste|d[ée]ductible|"
    r"wie\s+viel|einzahlen|s[äa]ule|quanto|versare|pilastro|"
    r"cu[aá]nto|aportar|pilar|depositar)\b|"
    r"\b(?:combien|mettre|verser|plafond|encore|reste|d[ée]ductible|"
    r"wie\s+viel|einzahlen|s[äa]ule|quanto|versare|pilastro|"
    r"cu[aá]nto|aportar|pilar|depositar)\b.*"
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


def fallback_for_language(language: str | None) -> str:
    code = (language or "fr").strip().lower().split("-", maxsplit=1)[0]
    return _FALLBACK_BY_LANGUAGE.get(code, _FALLBACK_FR)


def _is_current_year_question(user_message: str, current_year: int) -> bool:
    cleaned = _clean(user_message)
    return bool(_CURRENT_YEAR_ANCHOR_RE.search(cleaned)) or str(current_year) in {
        m.group(0) for m in _YEAR_RE.finditer(cleaned)
    }


def _years_mentioned(text: str) -> set[int]:
    return {int(m.group(0)) for m in _YEAR_RE.finditer(_clean(text))}


def _is_allowed_historical_year_anchor(text: str, match: re.Match[str]) -> bool:
    """Allow historical rule context, not stale current-year anchoring."""
    before = text[max(0, match.start() - 48):match.start()]
    after = text[match.end():min(len(text), match.end() + 48)]
    return bool(
        re.search(
            r"(?:\bdepuis\s+|\b[aà]\s+partir\s+de\s+|"
            r"\bpar\s+rapport\s+[aà]\s+|\bcomme\s+en\s+)$",
            before,
            re.IGNORECASE,
        )
        or re.search(
            r"^\s*(?:[;,.]\s*)?(?:[ée]tait\s+)?(?:identique|inchang[ée])\b",
            after,
            re.IGNORECASE,
        )
    )


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
    fallback_text: str = _FALLBACK_FR,
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
        return (False, fallback_text)

    is_current_3a_ceiling_question = _is_current_3a_ceiling_question(
        user_message, effective_year
    )
    if is_current_3a_ceiling_question:
        for match in _YEAR_RE.finditer(cleaned):
            year = int(match.group(0))
            if (
                year < effective_year
                and year not in user_years
                and not _is_allowed_historical_year_anchor(cleaned, match)
            ):
                return (False, fallback_text)

    for match in _MONTH_YEAR_RE.finditer(cleaned):
        year = int(match.group("year"))
        if year < effective_year and year not in user_years:
            return (False, fallback_text)

    return (True, text)


__all__ = ["gate", "fallback_for_language", "_FALLBACK_FR"]
