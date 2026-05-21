"""Waitlist endpoint — sub-phase 01.5 archetype HARD GATE.

POST /api/v1/waitlist

Public endpoint. No authentication required (the user is, by definition,
not yet supported by MINT — gating them through auth first would
violate nLPD data minimization). Reuses the X-Anonymous-Session header
pattern from `anonymous_chat.py` so the mobile side can dedupe + audit
without surfacing the email back to the device.

Threat mitigations :
- T-13-01 : UUID format validation on X-Anonymous-Session header
- T-13-02 : Pydantic EmailStr + Literal validators + explicit consent guard
- nLPD art. 6 : minimal data (email + archetype + locale + consent), no PII fields
- UCA art. 3(1)(o) : `consentGiven` must be true (validator enforces)

Per memory `project_orm_orphan_pattern` — the SQLAlchemy model
`WaitlistEntry` ships with its alembic migration p123_waitlist_entry
in the same PR as this endpoint.
"""

from __future__ import annotations

import logging
import re
import uuid as uuid_lib
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.waitlist_entry import WaitlistEntry
from app.schemas.waitlist import WaitlistRequest, WaitlistResponse

logger = logging.getLogger(__name__)

router = APIRouter()

# Same UUID regex as anonymous_chat.py:62 — kept local to avoid coupling
# the two endpoints (T-13-06 isolation between anonymous and authenticated
# paths). If we ever extract this to a shared util, both endpoints must
# migrate in the same PR.
_UUID_RE = re.compile(
    r"^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$"
)


@router.post("", response_model=WaitlistResponse, status_code=201)
@limiter.limit("10/minute")
async def submit_waitlist(
    request: Request,
    body: WaitlistRequest,
    db: Session = Depends(get_db),
) -> WaitlistResponse:
    """Capture a waitlist opt-in from the mobile WaitlistScreen.

    Returns 201 on success, 400 on validation failure (handled by
    Pydantic upstream), 401 on missing/malformed X-Anonymous-Session
    header, 409 on dedup (same email + archetype already captured).
    """

    # --- Step 1 : Extract + validate the anonymous session UUID ---
    # The mobile WaitlistService reuses `AnonymousSessionService.getOrCreate()`
    # (apps/mobile/lib/services/anonymous_session_service.dart) so the
    # UUID is already persisted in SharedPreferences before this endpoint
    # is hit. Same convention as anonymous_chat.py:354-366.
    session_id = request.headers.get("X-Anonymous-Session")
    if not session_id:
        raise HTTPException(
            status_code=401,
            detail="Session anonyme requise. Envoie le header X-Anonymous-Session.",
        )

    session_id = session_id.strip().lower()
    if not _UUID_RE.match(session_id):
        raise HTTPException(
            status_code=401,
            detail="Format de session invalide. Un UUID est requis.",
        )

    # --- Step 2 : Dedup check on (email, archetype) ---
    # Same user opting in twice with the same archetype is treated as
    # idempotent success (we return the existing row's id). This makes
    # the mobile client safe to retry on transient network errors
    # without surfacing 409 as an error to the user.
    email_normalized = body.email.strip().lower()
    existing = (
        db.query(WaitlistEntry)
        .filter(
            WaitlistEntry.email == email_normalized,
            WaitlistEntry.archetype == body.archetype,
        )
        .first()
    )
    if existing is not None:
        logger.info(
            "waitlist: idempotent re-submit email=*** archetype=%s id=%s",
            body.archetype,
            existing.id,
        )
        return WaitlistResponse(
            id=existing.id,
            created_at=existing.created_at,
            legal_entity=existing.legal_entity,
            retention_purge_after=existing.retention_purge_after,
        )

    # --- Step 3 : Persist the new row ---
    new_id = str(uuid_lib.uuid4())
    now = datetime.now(timezone.utc)
    purge_after = now + timedelta(days=365)

    entry = WaitlistEntry(
        id=new_id,
        email=email_normalized,
        archetype=body.archetype,
        locale=body.locale,
        source=body.source,
        anonymous_session_id=session_id,
        consent_given=body.consent_given,
        legal_entity="MINT SA",
        created_at=now,
        notified_at=None,
        retention_purge_after=purge_after,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)

    logger.info(
        "waitlist: captured email=*** archetype=%s locale=%s source=%s id=%s",
        body.archetype,
        body.locale,
        body.source,
        new_id,
    )

    return WaitlistResponse(
        id=new_id,
        created_at=now,
        legal_entity="MINT SA",
        retention_purge_after=purge_after,
    )
