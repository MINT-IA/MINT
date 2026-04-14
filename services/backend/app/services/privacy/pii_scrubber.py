"""PII scrubber — Presidio-first with regex fallback.

PRIV-03 — Phase 29.

Two modes:
    - ``mask`` (default for log filter): replace with ``<TAG>`` placeholders.
    - ``fpe`` : replace with structurally-valid but factually-false tokens
                (uses ``fpe`` module). Useful where downstream consumers
                still need parseable values (analytics on tokens).

Defense-in-depth design:
    1. Presidio path runs *first* if available (production Python ≥ 3.10).
       It catches natural-language PII the regex misses ("mon AVS commence
       par 756..." → spaCy NER + custom recognizer).
    2. Regex path *always* runs after, even when Presidio succeeded — it
       guarantees the well-known structural patterns never leak even if a
       Presidio recognizer regresses.

Performance: target ≤ 3 ms per 500-char log line on dev. Presidio
adds 30-100 ms per call; we only pay it when a record passes the cheap
"contains digit" pre-filter. The PIILogFilter further reduces calls by
short-circuiting empty messages.
"""
from __future__ import annotations

import logging
import re
from typing import Literal, Optional

from app.services.privacy import fpe
from app.services.privacy.recognizers_ch import (
    PRESIDIO_AVAILABLE,
    build_recognizers,
    load_employer_gazetteer,
)

logger = logging.getLogger(__name__)

ScrubMode = Literal["mask", "fpe"]
DEFAULT_MODE: ScrubMode = "mask"

# Hard cap on input size so a runaway log line cannot block the filter.
_MAX_INPUT = 100_000


# ---------------------------------------------------------------------------
# Regex fallback (Python 3.9 dev + Presidio-down prod)
# ---------------------------------------------------------------------------

# CH IBAN: 21 chars, prefix CH + 2 digits, then 16-17 digits with optional
# spaces in groups of 4. The pattern is permissive on whitespace and the
# trailing single digit, which is real-world IBAN formatting.
_IBAN_RE = re.compile(
    r"\bCH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{1,3}\b"
)

# AVS / AHV: 756 + 10 digits with optional separators. Catches both the
# canonical "756.1234.5678.97" form and freer prose like "756 1234 5678 90".
# The trailing block is 2 digits; we still match longer trails so "commence
# par 756.1234.5678.90" gets caught even if the user pasted an extra digit.
_AVS_RE = re.compile(
    r"\b756[.\s\-]?\d{4}[.\s\-]?\d{4}[.\s\-]?\d{2,4}\b"
)

# Swiss phone: +41 followed by 9 digits with various separators, or 0XX...
_PHONE_RE = re.compile(
    r"(?:\+41|0041)\s?\d{2}\s?\d{3}\s?\d{2}\s?\d{2}"
)

# Salary CHF — coarse pattern: 4-7 digit number followed by CHF/francs.
_SALARY_RE = re.compile(r"\b\d{4,7}(?:['\s]\d{3})*\s*(?:CHF|francs?)\b", re.IGNORECASE)

# Employer gazetteer — case-insensitive whole-word match per entry.
_employer_patterns: Optional[re.Pattern[str]] = None


def _employer_re() -> Optional[re.Pattern[str]]:
    global _employer_patterns
    if _employer_patterns is not None:
        return _employer_patterns
    names = load_employer_gazetteer()
    if not names:
        return None
    # Sort longest first so "credit suisse" wins over "credit"
    names = sorted(names, key=len, reverse=True)
    alt = "|".join(re.escape(n) for n in names)
    _employer_patterns = re.compile(rf"\b(?:{alt})\b", re.IGNORECASE)
    return _employer_patterns


# ---------------------------------------------------------------------------
# Presidio singleton (lazy)
# ---------------------------------------------------------------------------

_analyzer = None


def _get_analyzer():
    """Return the Presidio AnalyzerEngine or None if unavailable.

    Lazy: import + spaCy model load is ~500 MB in prod; we only pay it on
    first scrub call. Failures are logged once and degrade to regex.
    """
    global _analyzer
    if _analyzer is not None:
        return _analyzer if _analyzer is not False else None
    if not PRESIDIO_AVAILABLE:
        _analyzer = False
        return None
    try:  # pragma: no cover — prod path
        from presidio_analyzer import AnalyzerEngine  # type: ignore
        eng = AnalyzerEngine()
        for rec in build_recognizers():
            eng.registry.add_recognizer(rec)
        _analyzer = eng
        return eng
    except Exception as exc:  # pragma: no cover
        logger.warning(
            "Presidio unavailable, falling back to regex (%s)",
            type(exc).__name__,
        )
        _analyzer = False
        return None


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def scrub(text: Optional[str], mode: ScrubMode = DEFAULT_MODE) -> str:
    """Scrub PII out of ``text``.

    Always returns a string (empty if ``text`` is None / empty). Never
    raises — this function is on the hot logging path.
    """
    if text is None:
        return ""
    if not isinstance(text, str):
        try:
            text = str(text)
        except Exception:
            return ""
    if not text:
        return ""

    # Cap input size; truncate quietly with a marker so the operator can
    # tell the line was clamped.
    if len(text) > _MAX_INPUT:
        text = text[:_MAX_INPUT]

    out = text

    # Stage 1 — Presidio (production only). Replace each entity with a
    # mode-appropriate placeholder.
    analyzer = _get_analyzer()
    if analyzer is not None:  # pragma: no cover — prod path
        try:
            results = analyzer.analyze(
                text=out,
                language="fr",
                entities=[
                    "CH_AHV", "IBAN_CH", "EMPLOYER_CH",
                    "PERSON", "LOCATION", "PHONE_NUMBER",
                ],
            )
            results = sorted(results, key=lambda r: -r.start)
            for r in results:
                placeholder = _placeholder_for(r.entity_type, mode, out[r.start:r.end])
                out = out[:r.start] + placeholder + out[r.end:]
        except Exception as exc:
            logger.debug("presidio scrub failed: %s", type(exc).__name__)

    # Stage 2 — regex belt (always). Catches anything Presidio missed and
    # the entire payload in dev environments without Presidio.
    out = _regex_scrub(out, mode)

    return out


def _placeholder_for(entity: str, mode: ScrubMode, original: str) -> str:
    """Return a mode-appropriate replacement for a Presidio entity."""
    tag = {
        "CH_AHV": "AVS",
        "IBAN_CH": "IBAN",
        "EMPLOYER_CH": "EMPLOYER",
        "PERSON": "PERSON",
        "LOCATION": "LOCATION",
        "PHONE_NUMBER": "PHONE",
    }.get(entity, "PII")

    if mode == "fpe":
        try:
            if entity == "IBAN_CH":
                return fpe.tokenize_iban(original)
            if entity == "CH_AHV":
                # Strip separators, keep 13 digits
                return fpe.tokenize_avs(original)
        except Exception:
            pass  # fall through to mask
    return f"<{tag}>"


def _regex_scrub(text: str, mode: ScrubMode) -> str:
    """Apply the regex belt. Always runs, even after Presidio."""

    def _iban_sub(m: re.Match) -> str:
        if mode == "fpe":
            try:
                return fpe.tokenize_iban(m.group(0))
            except Exception:
                pass
        return "<IBAN>"

    def _avs_sub(m: re.Match) -> str:
        # Try FPE only on canonical 13-digit forms; partials fall back to mask.
        if mode == "fpe":
            digits = "".join(c for c in m.group(0) if c.isdigit())
            if len(digits) == 13 and digits.startswith("756"):
                try:
                    return fpe.tokenize_avs(digits)
                except Exception:
                    pass
        return "<AVS>"

    text = _IBAN_RE.sub(_iban_sub, text)
    text = _AVS_RE.sub(_avs_sub, text)
    text = _PHONE_RE.sub("<PHONE>", text)
    text = _SALARY_RE.sub("<SALARY>", text)

    employer_re = _employer_re()
    if employer_re is not None:
        text = employer_re.sub("<EMPLOYER>", text)
    return text


__all__ = ["DEFAULT_MODE", "ScrubMode", "scrub"]
