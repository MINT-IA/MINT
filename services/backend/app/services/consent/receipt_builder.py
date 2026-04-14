"""ISO/IEC 29184:2020 consent receipt builder.

v2.7 Phase 29 / PRIV-01.

A receipt is a JSON dict shaped per ISO 29184 §6, wire-level fields:

    {
      "receiptId":         uuid4 str,
      "piiPrincipalId":    sha256(user_id) hex (never raw user_id),
      "piiController":     "MINT Finance SA",
      "purposeCategory":   one of ConsentPurpose,
      "policyUrl":         "https://mint.ch/privacy/v2.3.0",
      "policyVersion":     "v2.3.0",
      "policyHash":        sha256 of policy markdown file content,
      "consentTimestamp":  ISO-8601 UTC,
      "jurisdiction":      "CH",
      "lawfulBasis":       "consent_nLPD_art_6_al_6",
      "revocationEndpoint":"/api/v1/consents/{receipt_id}/revoke",
      "prevHash":          sha256 of previous row's signature (null on genesis)
    }

Signed with HMAC-SHA256 using the MK via envelope fallback (MINT_CONSENT_SIGNING_KEY
env if set, else derived from MINT_MASTER_KEY to avoid operating a third key).
"""
from __future__ import annotations

import hashlib
import hmac
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional
from uuid import uuid4

PII_CONTROLLER = "MINT Finance SA"
JURISDICTION = "CH"
LAWFUL_BASIS = "consent_nLPD_art_6_al_6"
POLICY_URL_TEMPLATE = "https://mint.ch/privacy/{version}"
POLICY_DIR = Path(__file__).resolve().parent.parent.parent.parent / "docs" / "legal"
# also check repo-level docs/legal
_REPO_ROOT = Path(__file__).resolve().parents[5]
_REPO_POLICY_DIR = _REPO_ROOT / "docs" / "legal"


_policy_hash_cache: Dict[str, str] = {}


def piiprincipal_hash(user_id: str) -> str:
    """sha256 hex of user_id — ISO 29184 pseudonymous principal identifier."""
    return hashlib.sha256(user_id.encode("utf-8")).hexdigest()


def compute_policy_hash(version: str) -> str:
    """Compute sha256 of the privacy policy markdown file for a version.

    Looks up `docs/legal/privacy_policy_{version}.md`. Falls back to a
    deterministic synthetic hash (`sha256("missing:{version}")`) when the
    file is absent — acceptable in dev / CI / legacy backfill. Production
    deployments MUST ship the policy file to get a real content hash.
    """
    cached = _policy_hash_cache.get(version)
    if cached:
        return cached

    for candidate in (
        _REPO_POLICY_DIR / f"privacy_policy_{version}.md",
        POLICY_DIR / f"privacy_policy_{version}.md",
    ):
        if candidate.is_file():
            digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
            _policy_hash_cache[version] = digest
            return digest

    digest = hashlib.sha256(f"missing:{version}".encode("utf-8")).hexdigest()
    _policy_hash_cache[version] = digest
    return digest


def _signing_key() -> bytes:
    """Return HMAC key. Prefers `MINT_CONSENT_SIGNING_KEY`, else derives from MK."""
    raw = os.environ.get("MINT_CONSENT_SIGNING_KEY")
    if raw:
        return raw.encode("utf-8")
    mk = os.environ.get("MINT_MASTER_KEY")
    if mk:
        return hashlib.sha256(b"consent:" + mk.encode("utf-8")).digest()
    # Test / dev fallback — deterministic but warned by key_vault layer.
    return hashlib.sha256(b"consent:mint-dev-volatile").digest()


def sign_receipt(receipt_json: Dict[str, Any]) -> str:
    """HMAC-SHA256 hex of canonical JSON-encoded receipt."""
    canonical = json.dumps(receipt_json, sort_keys=True, separators=(",", ":"))
    return hmac.new(_signing_key(), canonical.encode("utf-8"), hashlib.sha256).hexdigest()


def verify_signature(receipt_json: Dict[str, Any], signature: str) -> bool:
    expected = sign_receipt(receipt_json)
    return hmac.compare_digest(expected, signature)


def build_receipt(
    *,
    user_id: str,
    purpose: str,
    policy_version: str,
    prev_signature: Optional[str],
    receipt_id: Optional[str] = None,
    now: Optional[datetime] = None,
) -> Dict[str, Any]:
    """Return a fully-formed ISO 29184 receipt dict, unsigned.

    Caller signs via `sign_receipt` and persists `signature` alongside
    `receipt_json` + `prev_hash`.
    """
    rid = receipt_id or str(uuid4())
    ts = (now or datetime.now(timezone.utc)).replace(microsecond=0)
    prev_hash = (
        hashlib.sha256(prev_signature.encode("utf-8")).hexdigest()
        if prev_signature
        else None
    )
    return {
        "receiptId": rid,
        "piiPrincipalId": piiprincipal_hash(user_id),
        "piiController": PII_CONTROLLER,
        "purposeCategory": purpose,
        "policyUrl": POLICY_URL_TEMPLATE.format(version=policy_version),
        "policyVersion": policy_version,
        "policyHash": compute_policy_hash(policy_version),
        "consentTimestamp": ts.isoformat().replace("+00:00", "Z"),
        "jurisdiction": JURISDICTION,
        "lawfulBasis": LAWFUL_BASIS,
        "revocationEndpoint": f"/api/v1/consents/{rid}/revoke",
        "prevHash": prev_hash,
    }
