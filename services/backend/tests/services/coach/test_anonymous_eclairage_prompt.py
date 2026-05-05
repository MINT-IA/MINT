"""
Tests — anonymous_eclairage_prompt module (Phase 57 PR-C).

Covers:
    1. FR base prompt is free of LSFin banned terms (outside instruction
       quotes that LIST them).
    2. EN base prompt is free of LSFin banned terms.
    3. build_anonymous_system_prompt(intent=...) injects the curated
       contextual line for known intents.
    4. build_anonymous_system_prompt() with no intent returns the base prompt.
    5. Invalid / unknown locale falls back to French (default app locale).
    6. Prompt does NOT request KYC PII (AVS, IBAN, fiscal numbers, ZIP, employer)
       — it must explicitly forbid these.

Run:
    cd services/backend && python3 -m pytest tests/services/coach/test_anonymous_eclairage_prompt.py -v
"""

from __future__ import annotations

import re

import pytest

from app.services.coach.anonymous_eclairage_prompt import (
    ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_EN,
    ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_FR,
    ECLAIRAGE_MARKER_EN,
    ECLAIRAGE_MARKER_FR,
    build_anonymous_system_prompt,
)


# ---------------------------------------------------------------------------
# Banned-term scan helpers — banned tokens are LISTED inside the prompt as an
# instruction (e.g. « pas de "garanti" »). Those listings are legitimate. We
# only want to flag uses OUTSIDE quoted contexts.
# ---------------------------------------------------------------------------

# Banned word stems (FR + EN). Matches with or without inflection.
_BANNED_STEMS_FR = [
    r"garanti(?:e|s|es)?",
    r"optimal(?:e|s|es|aux)?",
    r"meilleur(?:e|s|es)?",
    r"parfait(?:e|s|es)?",
    r"id[eé]al(?:e|s|es|aux)?",
    r"sans risque",
]
_BANNED_STEMS_EN = [
    r"guarantee[ds]?",
    r"guaranteed",
    r"optimal",
    r"best",
    r"perfect",
    r"ideal",
    r"risk[- ]free",
]

_BANNED_RE_FR = re.compile(
    r"(?<![A-Za-zÀ-ÿ])(?:" + "|".join(_BANNED_STEMS_FR) + r")(?![A-Za-zÀ-ÿ])",
    re.IGNORECASE,
)
_BANNED_RE_EN = re.compile(
    r"(?<![A-Za-z])(?:" + "|".join(_BANNED_STEMS_EN) + r")(?![A-Za-z])",
    re.IGNORECASE,
)


def _hits_outside_quotes(text: str, regex: re.Pattern) -> list[tuple[str, str]]:
    """Find banned-term hits NOT inside « », “ ”, or " " pair contexts.

    A hit is "inside quotes" if before its position there is an odd count of
    opening French guillemet « (vs closing ») OR an odd count of straight
    double-quote ".
    """
    out: list[tuple[str, str]] = []
    for m in regex.finditer(text):
        before = text[: m.start()]
        if before.count("«") > before.count("»"):
            continue
        if before.count('"') % 2 == 1:
            continue
        snippet = text[max(0, m.start() - 30) : m.end() + 30]
        out.append((m.group(), snippet))
    return out


# ---------------------------------------------------------------------------
# Test 1 — FR prompt: no banned terms outside instruction quotes
# ---------------------------------------------------------------------------


def test_fr_prompt_contains_no_banned_terms() -> None:
    """The FR base prompt must not USE banned terms (LSFin), only LIST them."""
    hits = _hits_outside_quotes(ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_FR, _BANNED_RE_FR)
    assert hits == [], (
        f"FR prompt uses banned terms outside instruction quotes: {hits}"
    )
    # Marker must be present
    assert ECLAIRAGE_MARKER_FR in ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_FR


# ---------------------------------------------------------------------------
# Test 2 — EN prompt: no banned terms outside instruction quotes
# ---------------------------------------------------------------------------


def test_en_prompt_contains_no_banned_terms() -> None:
    """The EN base prompt must not USE banned terms, only LIST them."""
    hits = _hits_outside_quotes(ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_EN, _BANNED_RE_EN)
    assert hits == [], (
        f"EN prompt uses banned terms outside instruction quotes: {hits}"
    )
    assert ECLAIRAGE_MARKER_EN in ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_EN


# ---------------------------------------------------------------------------
# Test 3 — build with intent inserts the curated context line
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "intent,expected_keywords",
    [
        ("rente_vs_capital", ["rente", "capital"]),
        ("rachat_lpp", ["LPP"]),
        ("mariage", ["mariage"]),
        ("premier_emploi", ["professionnelle"]),
        ("expat", ["expatri"]),
        ("independant", ["indépendant"]),
    ],
)
def test_build_with_intent_inserts_context(
    intent: str, expected_keywords: list[str]
) -> None:
    """Known intents inject their curated contextual line into the FR prompt."""
    prompt = build_anonymous_system_prompt(intent=intent, locale="fr")
    assert ECLAIRAGE_MARKER_FR in prompt, "marker must remain after injection"
    assert "Contexte intent" in prompt, "expected curated-context block label"
    for kw in expected_keywords:
        assert kw.lower() in prompt.lower(), (
            f"expected keyword {kw!r} in prompt for intent={intent!r}"
        )


def test_build_with_free_text_intent_appends_sentiment() -> None:
    """Free-text felt-state intents (e.g. 'Je me sens perdu') are appended verbatim."""
    prompt = build_anonymous_system_prompt(
        intent="Je me sens perdu", locale="fr"
    )
    assert "Je me sens perdu" in prompt
    # And the curated-context label is NOT used for unknown intents.
    assert "Contexte intent" not in prompt


# ---------------------------------------------------------------------------
# Test 4 — build without intent returns the base prompt
# ---------------------------------------------------------------------------


def test_build_without_intent_returns_base() -> None:
    """No intent + locale=fr → return the base FR prompt unchanged."""
    prompt = build_anonymous_system_prompt(intent=None, locale="fr")
    assert prompt == ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_FR

    # Empty string should also return base (defensive).
    prompt_empty = build_anonymous_system_prompt(intent="   ", locale="fr")
    assert prompt_empty == ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_FR

    # EN variant — same contract.
    prompt_en = build_anonymous_system_prompt(intent=None, locale="en")
    assert prompt_en == ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_EN


# ---------------------------------------------------------------------------
# Test 5 — invalid locale falls back to French
# ---------------------------------------------------------------------------


def test_invalid_locale_falls_back_to_fr() -> None:
    """Unknown / unsupported locales (de/it/es/pt/zz/'') return the FR prompt."""
    for bad_locale in ["de", "it", "es", "pt", "zz", "", "  "]:
        prompt = build_anonymous_system_prompt(intent=None, locale=bad_locale)
        assert ECLAIRAGE_MARKER_FR in prompt, (
            f"locale={bad_locale!r} should fall back to FR"
        )
        # And the EN marker must NOT leak into the FR fallback.
        assert ECLAIRAGE_MARKER_EN not in prompt


# ---------------------------------------------------------------------------
# Test 6 — prompt explicitly forbids KYC-level PII collection
# ---------------------------------------------------------------------------


def test_prompt_does_not_request_pii() -> None:
    """The anonymous prompt must explicitly tell the LLM NOT to ask for AVS,
    IBAN, fiscal numbers, ZIP, employer, last name. Anonymous tier != KYC.
    """
    fr = ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_FR.lower()
    # Each forbidden-PII token must be mentioned in a forbidding context.
    for pii_token in ["avs", "iban", "fiscal", "npa", "employeur"]:
        assert pii_token in fr, (
            f"FR prompt must explicitly mention forbidding {pii_token!r}"
        )
    # The forbidding instruction must use a negative ("jamais" / "ne ... pas").
    assert "jamais" in fr or "ne demande pas" in fr

    en = ANONYMOUS_ECLAIRAGE_SYSTEM_PROMPT_EN.lower()
    for pii_token in ["avs", "iban", "tax", "zip", "employer"]:
        assert pii_token in en, (
            f"EN prompt must explicitly mention forbidding {pii_token!r}"
        )
    assert "never" in en
