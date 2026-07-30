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

# ---------------------------------------------------------------------------
# Container-robust banned-term vocabulary source (two belts) — P0 #1118.
#
# Belt 1 — canonical repo lint module `tools/checks/banned_terms_python.py`.
# On a dev-box / CI checkout it is reachable by climbing to the repo-root
# marker. Import its 3 tuples directly (zero drift, no subprocess).
#
# Belt 2 — container fallback. The backend Docker image copies only
# `services/backend/{app,alembic,scripts,...}` (see services/backend/Dockerfile);
# the repo-root `tools/` dir is OUTSIDE the Railway build context, so belt 1 is
# unreachable in production. The previous `parents[5]` hard-coded a dev-box
# depth and raised `IndexError: 5` under Railway `WORKDIR=/app` at IMPORT time,
# 500-ing every /coach/chat resolved-receipt turn (#1118). Belt 2 falls back to
# an app-packaged INLINED copy of the vocabulary (below), shipped inside the
# image. It intentionally does NOT import `app.services.coach.runtime_verb_gate`
# (which holds a sibling inlined copy): this module loads at startup via
# `fact_event -> encrypted_value_helper`, and importing the heavy `coach`
# package here would risk a boot-time import cycle. Drift between this inlined
# copy and the canonical lint module is caught on dev/CI by
# `tests/test_banned_terms_runtime_container.py::
#   TestInlinedVocabDriftGuard::test_inlined_matches_canonical_lint_module`.
# ---------------------------------------------------------------------------
# llm-doctrine-fragment-banned-list
"""
Inlined banned-term vocabulary (belt 2, container fallback) — kept in sync with
`tools/checks/banned_terms_python.py` via TestInlinedVocabDriftGuard. The
strings below are the scanner's own vocabulary, NOT user-facing narrator output.
"""
_INLINED_WORD_BOUNDARY_BANNED: tuple[str, ...] = (
    "garanti",
    "optimal",
    "meilleur",
    "certain",
    "assure",
    "parfait",
)
_INLINED_PHRASE_BANNED: tuple[str, ...] = ("sans risque",)
_INLINED_BANNED_PARAPHRASE_VERBS: tuple[str, ...] = (
    "le choix le plus avisé",
    "le plus pertinent",
    "plus avantageux que",
    "nettement plus",
    "clairement supérieur",
    "à mon avis",
    "je pense que tu",
    "mon conseil serait",
    "tu devrais",
    "il faut",
    "recommandé",
)

_MARKER_RELPATH = Path("tools") / "checks" / "banned_terms_python.py"


def _resolve_repo_root(start: "Path | None" = None) -> "Path | None":
    """First ancestor of `start` containing the lint-module marker, else None.

    Iterating `Path.parents` is bounded by the path's real depth, so a shallow
    container path (Railway `WORKDIR=/app`) yields None instead of the
    `IndexError` that the previous `parents[5]` hard-coded depth raised at import
    time (#1118).
    """
    origin = (start or Path(__file__)).resolve()
    for ancestor in origin.parents:
        if (ancestor / _MARKER_RELPATH).is_file():
            return ancestor
    return None


def _resolve_banned_vocab() -> "tuple[tuple[str, ...], tuple[str, ...], tuple[str, ...]]":
    """Return (word_boundary, phrase, paraphrase) banned-term tuples.

    Belt 1 = canonical repo lint module when reachable ; belt 2 = the
    app-packaged inlined copy above. Never raises: a missing repo root or an
    unimportable lint module falls through to the container-safe vocabulary.
    """
    root = _resolve_repo_root()
    if root is not None:
        tools_checks = str(root / "tools" / "checks")
        if tools_checks not in sys.path:
            sys.path.insert(0, tools_checks)
        try:
            from banned_terms_python import (  # noqa: E402  (path-injected import)
                BANNED_PARAPHRASE_VERBS,
                _PHRASE_BANNED,
                _WORD_BOUNDARY_BANNED,
            )

            return _WORD_BOUNDARY_BANNED, _PHRASE_BANNED, BANNED_PARAPHRASE_VERBS
        except ImportError:  # pragma: no cover — defensive; belt 2 covers it
            pass

    # Belt 2 — app-packaged inlined copy (always shipped in the image).
    return (
        _INLINED_WORD_BOUNDARY_BANNED,
        _INLINED_PHRASE_BANNED,
        _INLINED_BANNED_PARAPHRASE_VERBS,
    )


_WORD_BOUNDARY_BANNED, _PHRASE_BANNED, BANNED_PARAPHRASE_VERBS = _resolve_banned_vocab()


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
