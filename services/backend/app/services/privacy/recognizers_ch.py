"""Custom Presidio recognizers for Swiss PII.

PRIV-03 — Phase 29.

Defines:
    - ``CH_AHV_Recognizer``    — AVS/AHV with EAN-13 check-digit validation
    - ``IBAN_CH_Recognizer``   — narrows Presidio's built-in IBAN to CH
    - ``EMPLOYER_CH_Recognizer`` — gazetteer of the top 30 CH employers

All recognizers are *optional*. They are registered into a Presidio
``AnalyzerEngine`` only if Presidio itself is importable (Python ≥ 3.10
in production). The regex fallback in ``pii_scrubber.scrub()`` covers the
same ground for unit tests on Python 3.9 dev environments.
"""
from __future__ import annotations

import os
import re
from pathlib import Path
from typing import List, Optional

# Presidio is optional. Tests on Python 3.9 cannot install it because
# spaCy/thinc require ≥3.10. Production runs ≥3.10 and resolves the import.
try:  # pragma: no cover — exercised in prod
    from presidio_analyzer import (  # type: ignore
        AnalysisExplanation,
        Pattern,
        PatternRecognizer,
        RecognizerResult,
    )
    PRESIDIO_AVAILABLE = True
except Exception:  # pragma: no cover
    PRESIDIO_AVAILABLE = False
    Pattern = object  # type: ignore
    PatternRecognizer = object  # type: ignore
    RecognizerResult = object  # type: ignore
    AnalysisExplanation = object  # type: ignore


_GAZETTEER_PATH = Path(__file__).parent / "data" / "employer_ch_gazetteer.txt"


def load_employer_gazetteer() -> List[str]:
    """Return the lower-cased non-comment lines of the employer gazetteer."""
    if not _GAZETTEER_PATH.exists():
        return []
    out: List[str] = []
    for line in _GAZETTEER_PATH.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        out.append(s.lower())
    return out


# EAN-13 check-digit (re-implemented here to avoid importing fpe and creating a cycle)
def _ean13_check(body12: str) -> int:
    s = 0
    for i, ch in enumerate(body12):
        d = int(ch)
        s += d if i % 2 == 0 else d * 3
    return (10 - (s % 10)) % 10


def avs_check_digit_valid(avs_text: str) -> bool:
    digits = "".join(c for c in avs_text if c.isdigit())
    if len(digits) != 13 or not digits.startswith("756"):
        return False
    return int(digits[-1]) == _ean13_check(digits[:-1])


# IBAN mod-97 check
def iban_check_valid(iban_text: str) -> bool:
    cleaned = "".join(iban_text.split()).upper()
    if len(cleaned) != 21 or not cleaned.startswith("CH"):
        return False
    rearranged = cleaned[4:] + cleaned[:4]
    if not all(c.isalnum() for c in rearranged):
        return False
    numeric = "".join(
        str(ord(c) - 55) if c.isalpha() else c for c in rearranged
    )
    try:
        return int(numeric) % 97 == 1
    except ValueError:
        return False


# ---------------------------------------------------------------------------
# Presidio-conditional recognizer factory
# ---------------------------------------------------------------------------

def build_recognizers() -> list:
    """Return the list of custom recognizers; empty if Presidio missing."""
    if not PRESIDIO_AVAILABLE:
        return []

    # CH_AHV: 756.XXXX.XXXX.XX (with optional . or space separators)
    ahv_pattern = Pattern(
        name="ch_ahv_format",
        regex=r"\b756[.\s\-]?\d{4}[.\s\-]?\d{4}[.\s\-]?\d{2}\b",
        score=0.6,  # base score; check-digit validation bumps to 0.95
    )

    class _CHAHVRecognizer(PatternRecognizer):  # type: ignore
        def __init__(self):
            super().__init__(
                supported_entity="CH_AHV",
                patterns=[ahv_pattern],
                supported_language="fr",
            )

        def validate_result(self, pattern_text):  # noqa: D401
            return avs_check_digit_valid(pattern_text)

    # IBAN_CH: narrow Presidio IBAN to CH (21 chars, mod-97 valid)
    iban_pattern = Pattern(
        name="iban_ch",
        regex=r"\bCH\d{2}(?:\s?\d{4}){4}\s?\d{1}\b",
        score=0.7,
    )

    class _IBANCHRecognizer(PatternRecognizer):  # type: ignore
        def __init__(self):
            super().__init__(
                supported_entity="IBAN_CH",
                patterns=[iban_pattern],
                supported_language="fr",
            )

        def validate_result(self, pattern_text):
            return iban_check_valid(pattern_text)

    # EMPLOYER_CH: gazetteer-based recognizer (deny-list)
    employers = load_employer_gazetteer()
    employer_patterns = [
        Pattern(
            name=f"employer_{i}",
            regex=r"\b" + re.escape(name) + r"\b",
            score=0.85,
        )
        for i, name in enumerate(employers)
    ]

    class _EmployerCHRecognizer(PatternRecognizer):  # type: ignore
        def __init__(self):
            super().__init__(
                supported_entity="EMPLOYER_CH",
                patterns=employer_patterns,
                supported_language="fr",
            )

    return [_CHAHVRecognizer(), _IBANCHRecognizer(), _EmployerCHRecognizer()]


__all__ = [
    "PRESIDIO_AVAILABLE",
    "avs_check_digit_valid",
    "build_recognizers",
    "iban_check_valid",
    "load_employer_gazetteer",
]
