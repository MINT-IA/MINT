"""Runtime LSFin banned-terms scanner for `encrypt_value()` write-time gate.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — iter-2 B6.

Reuses the vocabulary tuples from `tools/checks/banned_terms_python.py`
(NOT a subprocess — imports the constants directly). Called from
`encrypt_value()` BEFORE encryption when source_type is in
{'coach_inference', 'user_input'}.

Why fail-closed at write time
=============================
LSFin compliance applies to user-facing narrator output. If a coach LLM
inference path produces a forbidden return-promise phrase and that text
is encrypted into fact_event.value_enc, the disclosure has already
happened: a subsequent decrypt would re-expose the phrase to a user.
Catching it at encrypt time prevents the violation from ever reaching
the database.
"""
from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path
from typing import Any, Iterable

# Import the vocabulary tuples directly from the lint module. The lint
# module is at <repo_root>/tools/checks/banned_terms_python.py — add its
# parent dir to sys.path on import. (Avoids subprocess overhead in the
# hot path encrypt_value will sit on.)
_REPO_ROOT = Path(__file__).resolve().parents[5]
_TOOLS_CHECKS = _REPO_ROOT / "tools" / "checks"
if str(_TOOLS_CHECKS) not in sys.path:
    sys.path.insert(0, str(_TOOLS_CHECKS))

from banned_terms_python import (  # noqa: E402  (path-injected import)
    BANNED_PARAPHRASE_VERBS,
    _PHRASE_BANNED,
    _WORD_BOUNDARY_BANNED,
)


class BannedTermsViolation(ValueError):
    """Raised when plaintext about to be encrypted contains a banned term.

    Carries the offending term + a redacted snippet (no PII echo). Caller
    (`encrypt_value`) lets it propagate — fail-closed at write time per
    iter-2 B6.
    """


# Word-boundary regex per term (NFKC-normalised at scan time).
_WB_RES = [
    re.compile(rf"\b{re.escape(term)}\b", re.IGNORECASE)
    for term in _WORD_BOUNDARY_BANNED
]
_PARAPHRASE_RES = [
    re.compile(re.escape(verb), re.IGNORECASE) for verb in BANNED_PARAPHRASE_VERBS
]


def _iter_strings(value: Any) -> Iterable[str]:
    """Yield every str leaf in a JSON-serializable value (dict / list / scalar)."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from _iter_strings(v)
    elif isinstance(value, (list, tuple)):
        for v in value:
            yield from _iter_strings(v)
    # ints / floats / bool / None → nothing to scan


def _scan_text(text: str) -> tuple[str, str] | None:
    """Return (offending_term, redacted_snippet) on first hit, else None."""
    norm = unicodedata.normalize("NFKC", text).lower()
    for term, regex in zip(_WORD_BOUNDARY_BANNED, _WB_RES):
        if regex.search(norm):
            return term, _redact(text, term)
    for phrase in _PHRASE_BANNED:
        if phrase.lower() in norm:
            return phrase, _redact(text, phrase)
    for verb, regex in zip(BANNED_PARAPHRASE_VERBS, _PARAPHRASE_RES):
        if regex.search(norm):
            return verb, _redact(text, verb)
    return None


def _redact(text: str, term: str) -> str:
    """First ~50 chars of `text` for an error log — no full PII echo."""
    snippet = text[:50]
    return snippet + "..." if len(text) > 50 else snippet


def scan_value_for_banned_terms(value: Any) -> None:
    """Scan all str leaves of `value`; raise BannedTermsViolation on first hit.

    Used by `encrypt_value(... source_type in {'coach_inference', 'user_input'})`
    as a fail-closed write-time gate (iter-2 B6).
    """
    for text in _iter_strings(value):
        hit = _scan_text(text)
        if hit:
            term, snippet = hit
            raise BannedTermsViolation(
                f"LSFin banned term '{term}' detected in plaintext "
                f"about to be encrypted (snippet: {snippet!r}). "
                f"iter-2 B6: encrypt_value(... source_type in "
                f"{{'coach_inference', 'user_input'}}) is fail-closed."
            )


__all__ = ["BannedTermsViolation", "scan_value_for_banned_terms"]
