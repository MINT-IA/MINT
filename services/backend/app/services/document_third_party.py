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


# ── v2.7 Phase 29 / PRIV-02 — opposable declaration gate ────────────────────
#
# When DocumentUnderstandingResult.third_party_detected is True, persistence
# of the understanding is blocked until the user signs a nominative
# declaration (ConsentPurpose.THIRD_PARTY_ATTESTATION) bound to this exact
# document hash. Atomic third-party values (salary, avoir, AVS number) are
# never persisted to profile_facts; only aggregated results
# (household_ratio) flow through the normal persistence path.
#
# Design notes:
#   - TTL is 24h per doc_hash — a fresh declaration per upload event.
#   - doc_hash binding prevents "I accepted once, so all future uploads are
#     covered" abuse (T-29-24).
#   - Raw IP never stored: hash_ip() in receipt_builder produces a 16-byte
#     HMAC-SHA256 digest.

DECLARATION_TTL_HOURS = 24


class ThirdPartyDeclarationRequired(Exception):
    """Raised by `require_declaration_or_block` when the gate fails.

    FastAPI handler translates this to HTTP 428 Precondition Required with
    a JSON payload carrying `subject_names`, `doc_hash`, and the
    `declaration_endpoint` the client should hit to grant the receipt.
    """

    def __init__(self, subject_names: List[str], doc_hash: str) -> None:
        self.subject_names = list(subject_names)
        self.doc_hash = doc_hash
        super().__init__(
            f"third-party declaration required for {subject_names} on doc {doc_hash[:12]}"
        )


def _matching_declaration(db, *, user_id: str, doc_hash: str):
    """Return the latest fresh, non-revoked THIRD_PARTY_ATTESTATION row for
    this (user, doc_hash) within the TTL window, else None.

    Local import of ConsentModel keeps this service import-cycle-free.
    """
    from datetime import datetime, timedelta, timezone
    from app.models.consent import ConsentModel

    cutoff = datetime.now(timezone.utc) - timedelta(hours=DECLARATION_TTL_HOURS)
    rows = (
        db.query(ConsentModel)
        .filter(
            ConsentModel.user_id == user_id,
            ConsentModel.purpose_category == "third_party_attestation",
            ConsentModel.revoked_at.is_(None),
            ConsentModel.consent_timestamp >= cutoff,
        )
        .all()
    )
    for row in rows:
        rj = row.receipt_json or {}
        if rj.get("declaredDocHash") == doc_hash:
            return row
    return None


def require_declaration_or_block(
    db,
    *,
    user_id: str,
    understanding,  # DocumentUnderstandingResult
    doc_hash: str,
) -> None:
    """Raise ThirdPartyDeclarationRequired if the gate fails.

    Passes silently (no-op) when:
      - third_party_detected is False; OR
      - a fresh, non-revoked declaration receipt exists for this (user,
        doc_hash) within the TTL window.

    Called from the upload finalization step after understand_document()
    returns, BEFORE any persistence (profile_facts, evidence_text, etc.).
    """
    if not getattr(understanding, "third_party_detected", False):
        return
    if _matching_declaration(db, user_id=user_id, doc_hash=doc_hash) is not None:
        return
    name = getattr(understanding, "third_party_name", None)
    subjects = [name] if name else ["une personne détectée"]
    raise ThirdPartyDeclarationRequired(subjects, doc_hash)


__all__ = [
    "detect_third_party",
    "load_issuer_signatures",
    "DECLARATION_TTL_HOURS",
    "ThirdPartyDeclarationRequired",
    "require_declaration_or_block",
]
