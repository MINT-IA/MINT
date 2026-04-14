"""Third-party detection — silent flag, nLPD gate is phase 29.

v2.7 Phase 28 / DOC-01.

Heuristic only (regex on capitalized bigrams in source_text). Avoids a
heavy NER dependency (spaCy/stanza ~150MB) for v1 — most CH financial
docs surface the holder name in a recognisable header line.

Returns (False, None) if any name detected matches the user's profile
or partner. Returns (True, name) if a stranger name is found.
"""
from __future__ import annotations

import logging
import os
import re
import unicodedata
from functools import lru_cache
from typing import List, Optional, Tuple

import yaml

from app.schemas.document_understanding import DocumentUnderstandingResult

logger = logging.getLogger(__name__)

# Capitalised bigram: "Marc Dupont", "Lauren Battaglia", "François-Xavier Roux"
# Allows hyphen + Swiss diacritics inside tokens.
_NAME_BIGRAM_RE = re.compile(
    r"\b([A-ZÀ-Ý][a-zà-ÿ\-']{1,}(?:\s+[A-ZÀ-Ý][a-zà-ÿ\-']{1,}))\b",
    re.UNICODE,
)

# Tokens that look like proper nouns but are not person names. Defensive
# allowlist to keep precision high (recall is acceptable to lose).
_NON_PERSON_BIGRAMS = {
    "Caisse Pensions",
    "Plan Maxi",
    "Plan Standard",
    "Säule 3a",
    "Banque Cantonale",
    "Compte Individuel",
    "Année Revenu",
    "Bonification Vieillesse",
    "Salaire Assuré",
    "Avoir Vieillesse",
    "Rachat Maximum",
    "Taux Conversion",
}


def _normalize(s: Optional[str]) -> str:
    if not s:
        return ""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower().strip()


def detect_third_party(
    result: DocumentUnderstandingResult,
    profile_first_name: Optional[str],
    profile_last_name: Optional[str],
    partner_first_name: Optional[str],
) -> Tuple[bool, Optional[str]]:
    """Scan source_text of every extracted field for capitalised name bigrams.

    If a detected name matches profile or partner → (False, None).
    If a detected name is a stranger → (True, "first last").
    If no person-like name detected → (False, None).
    """
    user_tokens = {
        _normalize(profile_first_name),
        _normalize(profile_last_name),
        _normalize(partner_first_name),
    }
    user_tokens.discard("")

    candidates: List[str] = []
    seen: set[str] = set()
    for f in result.extracted_fields:
        text = f.source_text or ""
        for match in _NAME_BIGRAM_RE.findall(text):
            if match in _NON_PERSON_BIGRAMS:
                continue
            if match in seen:
                continue
            seen.add(match)
            candidates.append(match)

    if not candidates:
        return (False, None)

    for name in candidates:
        toks = {_normalize(t) for t in name.split()}
        # If ANY token of the candidate matches a user/partner token →
        # treat as self/partner attribution (zero-effort match).
        if toks & user_tokens:
            return (False, None)

    # First stranger candidate wins
    return (True, candidates[0])


# ── Signatures fixture loader ──────────────────────────────────────────────

_SIGNATURES_PATH = os.path.join(
    os.path.dirname(__file__), "document_signatures.yaml",
)


@lru_cache(maxsize=1)
def load_issuer_signatures() -> dict:
    """Load and cache the issuer signature catalogue.

    Returns: {"issuers": [{name, keywords, document_classes}, ...]}.
    Returns an empty catalogue if the file is missing or malformed (the
    fused Vision call still works without few-shots, just less accurate).
    """
    try:
        with open(_SIGNATURES_PATH, "r", encoding="utf-8") as fh:
            data = yaml.safe_load(fh) or {}
        if not isinstance(data, dict) or "issuers" not in data:
            logger.warning("document_signatures.yaml: malformed")
            return {"issuers": []}
        return data
    except FileNotFoundError:
        logger.warning("document_signatures.yaml: not found at %s", _SIGNATURES_PATH)
        return {"issuers": []}
    except Exception as exc:  # pragma: no cover — defensive
        logger.warning("document_signatures.yaml: load failed err=%s", exc)
        return {"issuers": []}


__all__ = ["detect_third_party", "load_issuer_signatures"]
