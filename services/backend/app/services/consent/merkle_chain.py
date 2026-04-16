"""Merkle chain over consent receipts — tamper detection.

v2.7 Phase 29 / PRIV-01.

One chain per user. Each row's `prev_hash` = sha256(previous row's signature).
Verify by walking rows in chronological order: if the recomputed prev_hash for
row N does not match the stored prev_hash on row N+1, the chain is broken at
N+1.

Also re-verifies HMAC signature of each row — a DB operator who forges both
signature AND hash still gets caught because the HMAC signing key is not in
the DB.
"""
from __future__ import annotations

import hashlib
from typing import List, Optional, Tuple

from app.models.consent import ConsentModel
from app.services.consent.receipt_builder import verify_signature


def _chronological(rows: List[ConsentModel]) -> List[ConsentModel]:
    return sorted(
        rows,
        key=lambda r: (r.consent_timestamp or r.updated_at, r.receipt_id or ""),
    )


def latest_signature(db, user_id: str) -> Optional[str]:
    """Return the signature of the most recent receipt for this user (any purpose).

    Used by grant() to seed prev_hash on the next receipt.
    """
    rows = (
        db.query(ConsentModel)
        .filter(ConsentModel.user_id == user_id)
        .filter(ConsentModel.signature.isnot(None))
        .all()
    )
    if not rows:
        return None
    rows = _chronological(rows)
    return rows[-1].signature


def append_receipt(
    db,
    *,
    user_id: str,
    purpose: str,
    policy_version: str,
    policy_hash: str,
    receipt_id: str,
    consent_timestamp,
    receipt_json: dict,
    prev_hash: Optional[str],
    signature: str,
) -> ConsentModel:
    """Persist a new ConsentModel row in the user's chain.

    Caller already built + signed the receipt; this function only writes.
    """
    row = ConsentModel(
        user_id=user_id,
        consent_type=purpose,  # legacy column kept in sync
        enabled=True,
        receipt_id=receipt_id,
        purpose_category=purpose,
        policy_version=policy_version,
        policy_hash=policy_hash,
        consent_timestamp=consent_timestamp,
        receipt_json=receipt_json,
        prev_hash=prev_hash,
        signature=signature,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def verify_chain(db, user_id: str) -> Tuple[bool, Optional[str]]:
    """Walk the chain; return (valid, break_at_receipt_id).

    Returns (True, None) on empty chain or fully consistent chain.
    """
    rows = (
        db.query(ConsentModel)
        .filter(ConsentModel.user_id == user_id)
        .filter(ConsentModel.signature.isnot(None))
        .all()
    )
    if not rows:
        return True, None

    rows = _chronological(rows)
    prev_sig: Optional[str] = None
    for row in rows:
        expected_prev = (
            hashlib.sha256(prev_sig.encode("utf-8")).hexdigest() if prev_sig else None
        )
        if row.prev_hash != expected_prev:
            return False, row.receipt_id
        if not verify_signature(row.receipt_json or {}, row.signature or ""):
            return False, row.receipt_id
        prev_sig = row.signature
    return True, None
