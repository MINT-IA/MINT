"""Consent service — grant / revoke / list / verify_chain.

v2.7 Phase 29 / PRIV-01.

Wires receipt_builder + merkle_chain into a single façade used by the REST
layer. Revocation of `persistence_365d` cascades to `crypto_shred_user` (a 30d
scheduled shred is the current design; here we expose the immediate shred hook
and let the background job scheduler call it — see Phase 29-01 summary for the
rationale behind the deferred scheduled job).
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Callable, List, Optional

from app.models.consent import ConsentModel
from app.services.consent import merkle_chain
from app.services.consent.receipt_builder import (
    build_receipt,
    compute_policy_hash,
    hash_ip,
    sign_receipt,
)
from app.services.encryption.key_vault import key_vault as _key_vault

logger = logging.getLogger(__name__)

# Grace window before crypto-shred fires on revoking persistence_365d.
CASCADE_GRACE_DAYS = 30


class ConsentError(Exception):
    pass


class ConsentNotFoundError(ConsentError):
    pass


class ConsentService:
    """Façade: backend of /api/v1/consents/*."""

    # Inject-able so tests can stub the shred call without monkey-patching.
    def __init__(self, shred_hook: Optional[Callable[[object, str], bool]] = None) -> None:
        self._shred_hook = shred_hook

    def _shred(self, db, user_id: str) -> bool:
        if self._shred_hook is not None:
            return self._shred_hook(db, user_id)
        try:
            return _key_vault.crypto_shred_user(db, user_id)
        except Exception as exc:  # pragma: no cover — log only
            logger.warning("consent.cascade_shred failed user=%s err=%s", user_id, exc)
            return False

    # -- grant -----------------------------------------------------------------
    def grant(
        self,
        db,
        *,
        user_id: str,
        purpose: str,
        policy_version: str,
    ) -> ConsentModel:
        prev_signature = merkle_chain.latest_signature(db, user_id)
        # Full microsecond precision — two consecutive grants in the same
        # second must order deterministically in verify_chain.
        now = datetime.now(timezone.utc)
        receipt_json = build_receipt(
            user_id=user_id,
            purpose=purpose,
            policy_version=policy_version,
            prev_signature=prev_signature,
            now=now,
        )
        signature = sign_receipt(receipt_json)
        row = merkle_chain.append_receipt(
            db,
            user_id=user_id,
            purpose=purpose,
            policy_version=policy_version,
            policy_hash=receipt_json["policyHash"],
            receipt_id=receipt_json["receiptId"],
            consent_timestamp=now,
            receipt_json=receipt_json,
            prev_hash=receipt_json["prevHash"],
            signature=signature,
        )
        return row

    # -- grant nominative (PRIV-02) -------------------------------------------
    def grant_nominative(
        self,
        db,
        *,
        user_id: str,
        subject_name: str,
        doc_hash: str,
        declared_from_ip: Optional[str],
        policy_version: str = "v2.3.0",
        subject_role: str = "declared_other",
    ) -> ConsentModel:
        """Create a THIRD_PARTY_ATTESTATION receipt bound to (doc_hash, subject_name).

        The receipt is signed + merkle-chained like every other consent row but
        its `receipt_json` carries three extra fields that make it opposable:

            - subjectName      : the detected PERSON string (never hashed —
                                 audit requires the same string the user saw).
            - subjectRole      : "declared_partner" | "declared_other".
            - declaredDocHash  : sha256 of the uploaded file bytes; gate
                                 requires an exact match before proceeding.
            - declaredFromIp   : HMAC-SHA256 of raw IP truncated to 16 bytes;
                                 audit can cluster without PII exposure.

        Per D-PRIV-02: one receipt per (user, doc_hash) — no receipt reuse
        across documents. The gate enforces this via the doc_hash match.
        """
        prev_signature = merkle_chain.latest_signature(db, user_id)
        now = datetime.now(timezone.utc)
        extra = {
            "subjectName": subject_name,
            "subjectRole": subject_role,
            "declaredDocHash": doc_hash,
            "declaredFromIp": hash_ip(declared_from_ip),
        }
        receipt_json = build_receipt(
            user_id=user_id,
            purpose="third_party_attestation",
            policy_version=policy_version,
            prev_signature=prev_signature,
            now=now,
            extra=extra,
        )
        signature = sign_receipt(receipt_json)
        row = merkle_chain.append_receipt(
            db,
            user_id=user_id,
            purpose="third_party_attestation",
            policy_version=policy_version,
            policy_hash=receipt_json["policyHash"],
            receipt_id=receipt_json["receiptId"],
            consent_timestamp=now,
            receipt_json=receipt_json,
            prev_hash=receipt_json["prevHash"],
            signature=signature,
        )
        return row

    # -- revoke ----------------------------------------------------------------
    def revoke(
        self,
        db,
        *,
        user_id: str,
        receipt_id: str,
    ) -> tuple[ConsentModel, bool]:
        """Revoke a receipt. Returns (row, cascade_scheduled).

        If purpose == persistence_365d AND this was the last active grant for
        that purpose, `cascade_scheduled=True` and a shred is initiated.
        """
        row: Optional[ConsentModel] = (
            db.query(ConsentModel)
            .filter(
                ConsentModel.user_id == user_id,
                ConsentModel.receipt_id == receipt_id,
            )
            .one_or_none()
        )
        if row is None:
            raise ConsentNotFoundError(f"receipt {receipt_id} not found for user")
        if row.revoked_at is not None:
            return row, False  # idempotent

        row.revoked_at = datetime.now(timezone.utc)
        row.enabled = False
        db.commit()
        db.refresh(row)

        cascade = False
        if row.purpose_category == "persistence_365d":
            # Any other active persistence_365d grant? If not → schedule shred.
            active = (
                db.query(ConsentModel)
                .filter(
                    ConsentModel.user_id == user_id,
                    ConsentModel.purpose_category == "persistence_365d",
                    ConsentModel.revoked_at.is_(None),
                )
                .count()
            )
            if active == 0:
                # Fire immediate shred hook — the 30-day grace period is an
                # operational policy layered on top (scheduled job deferred
                # per 29-01 summary). Tests stub shred_hook.
                self._shred(db, user_id)
                cascade = True
        return row, cascade

    # -- list ------------------------------------------------------------------
    def list_for_user(self, db, user_id: str) -> List[ConsentModel]:
        return (
            db.query(ConsentModel)
            .filter(
                ConsentModel.user_id == user_id,
                ConsentModel.purpose_category.isnot(None),
            )
            .all()
        )

    # -- verify chain ---------------------------------------------------------
    def verify_chain(self, db, user_id: str):
        return merkle_chain.verify_chain(db, user_id)

    # -- helper: current policy hash ------------------------------------------
    @staticmethod
    def policy_hash(version: str) -> str:
        return compute_policy_hash(version)


# Module-level singleton (stateless)
consent_service = ConsentService()
