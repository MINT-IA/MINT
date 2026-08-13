"""
Lego C1 — endpoint twin-read « Éclairer ma marge 3a » (beats c4/c5/c8/c9).

POST /api/v1/coach/twin-read/3a-margin

Enveloppe FERMÉE (422 sur tout extra, à tout niveau), consentement validé
en présence + forme, outil read-only forcé, claim-checker avant sortie,
quota anonyme décrémenté par CLÉ D'OPÉRATION idempotente : le rejeu d'une
clé déjà servie retourne la réponse stockée SANS re-consommer.
"""

from __future__ import annotations

import hashlib
import json
import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.anonymous_session import AnonymousSession
from app.models.twin_read_operation import TwinReadOperation
from app.schemas.coach_twin_read import (
    TwinRead3aMarginRequest,
    TwinRead3aMarginResponse,
    TwinReadClaim,
)
from app.services.coach.twin_read_service import (
    TwinReadRejectedError,
    TwinReadToolNotInvokedError,
    generate_eclairage,
)

logger = logging.getLogger(__name__)

router = APIRouter()

MAX_ANONYMOUS_MESSAGES = 3


def expected_operation_key(payload: TwinRead3aMarginRequest) -> str:
    """La clé d'opération est DÉRIVÉE de l'attestation — recalculée ici :
    une clé qui ne colle pas à l'attestation soumise est un mensonge."""
    material = (
        payload.attestation.inputs_hash
        + payload.attestation.registry_hash
        + str(payload.attestation.tax_year)
    )
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


@router.post("/twin-read/3a-margin", response_model=TwinRead3aMarginResponse)
@limiter.limit("10/minute")
async def twin_read_3a_margin(
    request: Request,
    payload: TwinRead3aMarginRequest,
    db: Session = Depends(get_db),
) -> TwinRead3aMarginResponse:
    # ── La clé d'opération doit être la dérivation EXACTE de
    # l'attestation soumise — sinon rejeu incohérent ou clé volée. ──
    if payload.operation_key != expected_operation_key(payload):
        raise HTTPException(
            status_code=422,
            detail={"code": "operation_key_mismatch"},
        )

    # ── Rejeu idempotent : une clé déjà servie ressert la MÊME réponse
    # validée, sans re-consommer — mais UNIQUEMENT à la session qui l'a
    # créée (jamais de fuite inter-session). ──
    existing = db.get(TwinReadOperation, payload.operation_key)
    if existing is not None and existing.session_id != payload.session_id:
        raise HTTPException(status_code=404, detail="operation not found")
    if existing is not None:
        session = db.get(AnonymousSession, payload.session_id)
        remaining = MAX_ANONYMOUS_MESSAGES - (
            session.message_count if session else 0
        )
        return TwinRead3aMarginResponse(
            contract_version=1,
            answer=existing.answer,
            claims=[
                TwinReadClaim(**c) for c in json.loads(existing.claims_json)
            ],
            tool_invoked="read_attested_3a_margin",
            quota_consumed=False,
            messages_remaining=max(0, remaining),
            replayed=True,
        )

    # ── Quota anonyme : même source de vérité que le chat anonyme. ──
    session = db.get(AnonymousSession, payload.session_id)
    if session is None:
        session = AnonymousSession(
            session_id=payload.session_id, message_count=0
        )
        db.add(session)
    if session.message_count >= MAX_ANONYMOUS_MESSAGES:
        raise HTTPException(status_code=429, detail="anonymous quota reached")

    # ── Génération : outil forcé + claim-check (le service lève sinon). ──
    try:
        answer, claims = await generate_eclairage(
            payload.question, payload.attestation
        )
    except TwinReadRejectedError as exc:
        # Rejet DÉTERMINISTE : rien n'est consommé, le mobile rend la
        # copie de secours sans chiffre.
        logger.info("twin-read deterministic rejection: %s", exc.reasons)
        raise HTTPException(
            status_code=422,
            detail={"code": "claim_check_rejected", "reasons": exc.reasons},
        ) from exc
    except TwinReadToolNotInvokedError as exc:
        raise HTTPException(
            status_code=422,
            detail={"code": "tool_not_invoked"},
        ) from exc

    return _finalize_operation(db, payload, session, answer, claims)


def _replayed_response(
    db: Session, payload: TwinRead3aMarginRequest, existing: TwinReadOperation
) -> TwinRead3aMarginResponse:
    session = db.get(AnonymousSession, payload.session_id)
    remaining = MAX_ANONYMOUS_MESSAGES - (
        session.message_count if session else 0
    )
    return TwinRead3aMarginResponse(
        contract_version=1,
        answer=existing.answer,
        claims=[TwinReadClaim(**c) for c in json.loads(existing.claims_json)],
        tool_invoked="read_attested_3a_margin",
        quota_consumed=False,
        messages_remaining=max(0, remaining),
        replayed=True,
    )


def _finalize_operation(
    db: Session,
    payload: TwinRead3aMarginRequest,
    session: AnonymousSession,
    answer: str,
    claims: list[TwinReadClaim],
) -> TwinRead3aMarginResponse:
    """Consommation atomique réponse+quota — CONVERGENTE sous concurrence :
    le perdant d'une course sur la même clé ressert la réponse gagnante
    (replayed), jamais un 500 IntegrityError."""
    db.add(
        TwinReadOperation(
            operation_key=payload.operation_key,
            session_id=payload.session_id,
            answer=answer,
            claims_json=json.dumps(
                [c.model_dump(by_alias=False) for c in claims],
                ensure_ascii=False,
            ),
            quota_consumed=True,
        )
    )
    session.message_count += 1
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.get(TwinReadOperation, payload.operation_key)
        if existing is None or existing.session_id != payload.session_id:
            raise HTTPException(
                status_code=409, detail="operation conflict"
            ) from None
        return _replayed_response(db, payload, existing)

    return TwinRead3aMarginResponse(
        contract_version=1,
        answer=answer,
        claims=claims,
        tool_invoked="read_attested_3a_margin",
        quota_consumed=True,
        messages_remaining=max(
            0, MAX_ANONYMOUS_MESSAGES - session.message_count
        ),
    )
