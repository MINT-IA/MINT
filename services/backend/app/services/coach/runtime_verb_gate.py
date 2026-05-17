"""Phase mint-calc-engine-v1 W4 — D-CE-16(c) runtime banned-verb gate.

Triple-defense layer (c). Sister to Phase 94 citation gate, runs UPSTREAM of
it (see Q5 resolution = BEFORE) on the narrator's raw output. Fail-closed :
any match on the banned-term vocabulary returns the LSFin-safe templated
fallback ; no narrator output ever reaches the user with a ranking verb.

Defense layers active in parallel :
    (a) D-CE-15 schema-impossibility — typed Pydantic discriminated payloads
        REJECT `recommended_option` etc. fields at `model_validate` time.
        Shipped in Plan 04 (`app.models.lucidity`).
    (b) D-CE-16(b) lint-time — `tools/checks/banned_terms_python.py` flags
        the 11 paraphrase verbs in pre-commit and CI on `bundles/*.py`.
    (c) D-CE-16(c) THIS MODULE — runtime regex gate on NFKC-normalised +
        zero-width-stripped narrator output.

Why all three :
    - Lexical guardrails alone : 40-80 % false-negative on paraphrase
      (Palo Alto Unit 42 ; arXiv 2504.11168).
    - 100 % evasion via character injection (arXiv 2512.01353).
    - Schema layer closes the structural ranking-field hole ; lint closes
      committed-source ranking verbs ; THIS gate closes free-text emission
      at narrator runtime — the last barrier before HTTP response.

Determinism contract :
    The fallback template is a verbatim string literal (no f-string, no
    .format()). It is INTENTIONALLY SHORTER than Phase 94's
    `FALLBACK_TEMPLATED_TEXT` so the user can distinguish a verb-gate
    fallback from a citation-gate fallback in QA. Sentry breadcrumb
    `coach.verb_gate.fired` is emitted at the call site (coach_chat.py)
    when this gate returns (False, _FALLBACK_FR).

Threat coverage per Plan-18 STRIDE register :
    - T-mint-calc-18-01 (paraphrase leak) — 11 verbs + word-boundary regex.
    - T-mint-calc-18-02 (regex DoS) — all patterns use `re.escape` ; no
      nested groups, no backtracking traps ; linear time.
    - T-mint-calc-18-03 (NFKC bypass) — NFKC normalisation first.
    - T-mint-calc-18-04 (info disclosure) — gate returns a template, never
      the offending narrator text.
"""
from __future__ import annotations

import importlib.util
import re
import unicodedata
from pathlib import Path

# ---------------------------------------------------------------------------
# Pattern established in Plan 04 SUMMARY decisions — load the banned-term
# vocabulary at runtime via importlib so the backend doesn't depend on
# `tools/` being on `sys.path` (which it isn't when running from
# `services/backend/`). This keeps the lint module the canonical single
# source of truth without forcing a packaging restructure.
# ---------------------------------------------------------------------------
_LINT_PATH = (
    Path(__file__).resolve().parents[5] / "tools" / "checks" / "banned_terms_python.py"
)


def _load_lint_vocabulary() -> tuple[
    tuple[str, ...], tuple[str, ...], tuple[str, ...]
]:
    """Load (_WORD_BOUNDARY_BANNED, _PHRASE_BANNED, BANNED_PARAPHRASE_VERBS).

    Same import-via-importlib pattern as `tests/test_lucidity_payloads.py`
    (Plan 04 decision) — avoids the `tools.checks` ImportError when this
    module is imported from inside `services/backend/`.
    """
    spec = importlib.util.spec_from_file_location(
        "banned_terms_python_runtime", _LINT_PATH
    )
    if spec is None or spec.loader is None:  # pragma: no cover — defensive
        raise ImportError(
            f"D-CE-16(c) runtime gate cannot load banned-term vocabulary "
            f"from {_LINT_PATH}"
        )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return (
        tuple(module._WORD_BOUNDARY_BANNED),
        tuple(module._PHRASE_BANNED),
        tuple(module.BANNED_PARAPHRASE_VERBS),
    )


_WORD_BOUNDARY_BANNED, _PHRASE_BANNED, BANNED_PARAPHRASE_VERBS = (
    _load_lint_vocabulary()
)

# Verbatim FR fallback. INTENTIONALLY shorter than Phase 94's
# `FALLBACK_TEMPLATED_TEXT` — distinguishes a verb-gate fallback from a
# citation-gate fallback at QA time. Accent on « donnée » is mandatory
# (CLAUDE.md §2 ; ASCII « donnee » would be a lint violation).
_FALLBACK_FR: str = "Je n'ai pas cette donnée pour l'instant."

# Zero-width / invisible chars. Stripped BEFORE regex match so character-
# injection evasion (« opti<ZWS>mal ») cannot bypass the gate.
# Set covers U+200B, U+200C, U+200D, U+FEFF, U+2060.
_ZERO_WIDTH_CHARS: frozenset[str] = frozenset({
    "​",  # ZERO WIDTH SPACE
    "‌",  # ZERO WIDTH NON-JOINER
    "‍",  # ZERO WIDTH JOINER
    "﻿",  # ZERO WIDTH NO-BREAK SPACE (BOM)
    "⁠",  # WORD JOINER
})

# Pre-compiled regexes. Word-boundary for single-token roots (the 7 base
# banned terms) ; substring (no \b) for multi-word phrases and paraphrase
# verbs (e.g. « le plus pertinent » spans 3 tokens, word-boundary would
# false-negative on common surrounding context). All case-insensitive.
_WORD_BOUNDARY_REGEXES: tuple[re.Pattern[str], ...] = tuple(
    re.compile(r"\b" + re.escape(term) + r"\b", re.IGNORECASE)
    for term in _WORD_BOUNDARY_BANNED
)
_PHRASE_REGEXES: tuple[re.Pattern[str], ...] = tuple(
    re.compile(re.escape(phrase), re.IGNORECASE) for phrase in _PHRASE_BANNED
)
_PARAPHRASE_REGEXES: tuple[re.Pattern[str], ...] = tuple(
    re.compile(re.escape(verb), re.IGNORECASE) for verb in BANNED_PARAPHRASE_VERBS
)


def _strip_zero_width(s: str) -> str:
    """Remove all zero-width / invisible chars from `s`."""
    if not s:
        return s
    # Fast-path : no zero-width char present (the common case for clean LLM
    # output). Skip the per-char filter to keep the gate's overhead at
    # micro-second scale on the happy path.
    if not any(c in _ZERO_WIDTH_CHARS for c in s):
        return s
    return "".join(c for c in s if c not in _ZERO_WIDTH_CHARS)


def gate(text: str) -> tuple[bool, str]:
    """D-CE-16(c) runtime fail-closed banned-verb gate.

    Args:
        text: Narrator output (post-LLM, pre-Phase-94 citation-gate).

    Returns:
        (passed, output) :
            - (True, text) — text contains no banned vocabulary ; original
              string returned unchanged.
            - (False, _FALLBACK_FR) — at least one banned root / phrase /
              paraphrase verb detected (after NFKC + zero-width strip) ;
              the verbatim FR template is returned, the narrator's text is
              NEVER leaked.

    The empty-string / whitespace-only case is pass-through (True, text).
    Phase 94 citation gate owns the empty-input FALLBACK ; this gate runs
    UPSTREAM and must not preempt it. CONTEXT D-08 / D-10 contract.
    """
    if not text or not text.strip():
        return (True, text)

    # 1. NFKC normalise : decomposed accents (e + U+0301 → é), fullwidth
    #    chars, ligatures, etc. are reduced to their canonical compatible
    #    form before any regex sees them.
    normalised = unicodedata.normalize("NFKC", text)

    # 2. Strip zero-width / invisible chars (U+200B etc.) so character-
    #    injection evasion (« opti<ZWS>mal ») is neutralised.
    cleaned = _strip_zero_width(normalised)

    # 3. Word-boundary single-token scan (7 base banned roots).
    for pattern in _WORD_BOUNDARY_REGEXES:
        if pattern.search(cleaned):
            return (False, _FALLBACK_FR)

    # 4. Multi-word phrase scan (« sans risque »).
    for pattern in _PHRASE_REGEXES:
        if pattern.search(cleaned):
            return (False, _FALLBACK_FR)

    # 5. D-CE-16(b) paraphrase-verb scan (11 verbs).
    for pattern in _PARAPHRASE_REGEXES:
        if pattern.search(cleaned):
            return (False, _FALLBACK_FR)

    return (True, text)


__all__ = ["gate", "_FALLBACK_FR", "_ZERO_WIDTH_CHARS"]
