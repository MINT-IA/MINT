"""Granular consent endpoints (ISO/IEC 29184:2020).

v2.7 Phase 29 / PRIV-01.

Routes (prefix `/api/v1/consents` mounted by router.py):

    GET  /                      — list user's receipts + chain integrity
    POST /grant                 — grant a purpose at the current policy version
    POST /{receipt_id}/revoke   — revoke a receipt (cascade shred if persistence_365d)
    GET  /{receipt_id}/receipt  — return the signed ISO 29184 JSON blob
    GET  /verify-chain          — walk the merkle chain and report integrity

Auth: JWT-gated, user_id derived from session never from body (T-29-10).
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.consent import ConsentModel
from app.models.user import User
from app.schemas.consent_receipt import (
    ConsentGrantRequest,
    ConsentListResponse,
    ConsentPurpose,
    ConsentReceiptOut,
    ConsentRevokeResponse,
)
from app.services.consent.consent_service import (
    CASCADE_GRACE_DAYS,
    ConsentNotFoundError,
    consent_service,
)

router = APIRouter()


def _to_out(row: ConsentModel) -> ConsentReceiptOut:
    return ConsentReceiptOut(
        receipt_id=row.receipt_id,
        purpose=ConsentPurpose(row.purpose_category),
        policy_version=row.policy_version,
        policy_hash=row.policy_hash,
        consent_timestamp=row.consent_timestamp,
        revoked_at=row.revoked_at,
        prev_hash=row.prev_hash,
        signature=row.signature or "",
        receipt_json=row.receipt_json or {},
    )


@router.get("", response_model=ConsentListResponse)
def list_consents(
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> ConsentListResponse:
    rows = [
        r for r in consent_service.list_for_user(db, _user.id)
        if r.receipt_id is not None and r.signature is not None
    ]
    valid, break_at = consent_service.verify_chain(db, _user.id)
    return ConsentListResponse(
        consents=[_to_out(r) for r in rows],
        chain_valid=valid,
        chain_break_receipt_id=break_at,
    )


@router.post("/grant", response_model=ConsentReceiptOut)
def grant_consent(
    request: ConsentGrantRequest,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> ConsentReceiptOut:
    row = consent_service.grant(
        db,
        user_id=_user.id,
        purpose=request.purpose.value,
        policy_version=request.policy_version,
    )
    return _to_out(row)


@router.post("/{receipt_id}/revoke", response_model=ConsentRevokeResponse)
def revoke_consent(
    receipt_id: str,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> ConsentRevokeResponse:
    try:
        row, cascade = consent_service.revoke(
            db, user_id=_user.id, receipt_id=receipt_id
        )
    except ConsentNotFoundError:
        raise HTTPException(status_code=404, detail="Receipt not found for current user")

    message = (
        "Consentement révoqué. Suppression cryptographique des documents "
        f"programmée sous {CASCADE_GRACE_DAYS} jours."
        if cascade
        else "Consentement révoqué."
    )
    return ConsentRevokeResponse(
        receipt_id=row.receipt_id,
        purpose=ConsentPurpose(row.purpose_category),
        revoked_at=row.revoked_at,
        cascade_scheduled=cascade,
        cascade_eta_days=CASCADE_GRACE_DAYS if cascade else 0,
        message=message,
    )


@router.get("/{receipt_id}/receipt")
def get_receipt_json(
    receipt_id: str,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> dict:
    row: ConsentModel = (
        db.query(ConsentModel)
        .filter(
            ConsentModel.user_id == _user.id,
            ConsentModel.receipt_id == receipt_id,
        )
        .one_or_none()
    )
    if row is None or row.receipt_json is None:
        raise HTTPException(status_code=404, detail="Receipt not found")
    return {
        "receipt": row.receipt_json,
        "signature": row.signature,
        "revokedAt": row.revoked_at.isoformat() if row.revoked_at else None,
    }


@router.get("/verify-chain")
def verify_chain(
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> dict:
    valid, break_at = consent_service.verify_chain(db, _user.id)
    return {"valid": valid, "breakAtReceiptId": break_at}
