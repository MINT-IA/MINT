"""MoneyTruthReceipt store/resolve endpoints (Tranche firstJob PR-E, E1).

Deux endpoints sous ``/lucidity/receipts`` (SPEC §4.3) :

  POST /v1/lucidity/receipts
      Écriture idempotente. Auth optionnelle : propriétaire = user.id
      (authentifié) OU anonymousSessionId (store /first-job pré-auth).
      Ré-émission = no-op (status='duplicate').

  POST /v1/lucidity/receipts/resolve
      Résolution scopée propriétaire. Renvoie 'resolved' (+ receipt complet),
      'pending' (+ inputs, receipt pas encore synchronisé) ou 'not_found'.
      L'accès croisé ne renvoie JAMAIS le receipt d'autrui.

Le mécanisme est aussi câblé côté coach (`coach_chat` accepte receiptId +
inputsHash et appelle ``resolve_receipt_context``) — SPEC §4.3 handoff.

Threats
=======
- Spoofing / accès croisé (T-firstjob-E-01) : ``owner_scope_hash`` HMAC filtre
  toute résolution ; un propriétaire ne voit que ses propres receipts.
- Owner manquant : 400 explicite (jamais de receipt « global » non scopé).
"""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.auth import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.money_truth_receipt_api import (
    ResolveReceiptRequest,
    ResolveReceiptResponse,
    StoreReceiptRequest,
    StoreReceiptResponse,
)
from app.services.lucidity.receipt_store import (
    resolve_receipt,
    store_receipt,
)

router = APIRouter()


@router.post(
    "/receipts",
    response_model=StoreReceiptResponse,
    status_code=status.HTTP_200_OK,
    tags=["lucidity-receipts"],
)
def store_money_truth_receipt(
    payload: StoreReceiptRequest,
    db: Session = Depends(get_db),
    user: Optional[User] = Depends(get_current_user),
) -> StoreReceiptResponse:
    """Persiste un MoneyTruthReceipt de façon idempotente, scopé propriétaire."""
    try:
        result = store_receipt(
            db,
            receipt=payload.receipt,
            user=user,
            anonymous_session_id=payload.anonymous_session_id,
        )
    except ValueError as exc:
        # Owner manquant OU conflit d'idempotence (même receipt_id, inputs_hash
        # divergent).
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT
            if "Conflit" in str(exc)
            else status.HTTP_400_BAD_REQUEST,
            detail={"error": "receipt_store_rejected", "message": str(exc)},
        ) from exc
    return StoreReceiptResponse(
        status=result.status,
        receipt_id=result.receipt_id,
        inputs_hash=result.inputs_hash,
    )


@router.post(
    "/receipts/resolve",
    response_model=ResolveReceiptResponse,
    status_code=status.HTTP_200_OK,
    tags=["lucidity-receipts"],
)
def resolve_money_truth_receipt(
    payload: ResolveReceiptRequest,
    db: Session = Depends(get_db),
    user: Optional[User] = Depends(get_current_user),
) -> ResolveReceiptResponse:
    """Résout un receipt par (receiptId, inputsHash) scopé au propriétaire."""
    result = resolve_receipt(
        db,
        receipt_id=payload.receipt_id,
        inputs_hash=payload.inputs_hash,
        receipt_inputs=payload.receipt_inputs,
        user=user,
        anonymous_session_id=payload.anonymous_session_id,
    )
    return ResolveReceiptResponse(
        status=result.status.value,
        receipt=result.receipt,
        inputs=result.inputs,
    )


__all__ = ["router"]
