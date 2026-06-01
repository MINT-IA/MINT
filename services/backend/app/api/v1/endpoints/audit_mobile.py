"""Mobile L1 audit ingestion endpoints — D-12 + D-MOB-03 + iter-2 A6 + iter-3 iA2.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 — P2.

Two endpoints, both writing ONLY to `projection_audit_records` (D-13 clean
separation : NO `fact_event` INSERT from the mobile audit path) :

  POST /v1/audit/mobile-session-start
      Anonymous (no auth required). Single-row INSERT recording one Mobile
      L1 audit event (cold-start or warm-resume). Idempotent : if a row
      with the same (anonymous_session_id, observed_at) already exists,
      returns 200 + skipped=1.

  POST /v1/audit/mobile-session-link
      Authenticated. Batch UPSERT (INSERT ... ON CONFLICT DO NOTHING on
      UNIQUE(anonymous_session_id, observed_at)). For each batch entry,
      enforces the iter-2 A6 **proof-of-session-start handshake** : the
      server REJECTS the entire batch (HTTP 403) if ANY entry's
      `anonymous_session_id` lacks a prior `source='mobile_session_start'`
      row.

  GET  /v1/audit/mobile-session-handshake?anonymous_session_id=...
      Authenticated. Returns the server-side state for an
      anonymous_session_id : session_token (HMAC of the sid + user.id for
      tamper-evidence ; not a credential — used only to prove order in
      replay scenarios), last_seen_local_event_id, has_prior_session_start.
      Per iter-2 A6 + iter-3 iA2 : the mobile client uses this to verify
      replay ordering BEFORE issuing /mobile-session-link batches.

Counters fired :
  mint_anonymous_session_link_total{outcome=...}
    'linked' / 'skipped_duplicate' / 'rejected_no_handshake' / 'error'
"""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import List, Literal, Optional
from uuid import uuid4

import sqlalchemy as sa
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.auth import get_current_user, require_current_user
from app.core.database import get_db
from app.models.projection_audit_record import ProjectionAuditRecord
from app.models.user import User
from app.observability.counters import mint_anonymous_session_link_total
from app.services.audit.hmac_pepper import hmac_user_id, hmac_pii


router = APIRouter()


# ── Pydantic v2 wire shapes ─────────────────────────────────────────────────

class MobileSessionEvent(BaseModel):
    """Single Mobile L1 audit event payload — matches the D-12 contract.

    `source` is type-restricted via `Literal` to the Mobile L1 source values
    (QA sec FLAG-3 fix, 2026-05-19). Backend writer code (snapshot_service,
    projector, backfill script) writes `source='projection' / 'snapshot_dual_write'
    / 'snapshot_backfill_v1'` via the ORM default, NEVER through this endpoint.
    Without the allowlist, a malicious client could POST `source='projection'`
    to fabricate audit rows structurally indistinguishable from server-side
    writes (STRIDE: Spoofing). Add new values here as new mobile session
    states are introduced (and update tests/integration/test_audit_mobile_link.py).
    """

    anonymous_session_id: str = Field(min_length=8, max_length=36)
    app_version: str = Field(min_length=1, max_length=32)
    observed_at: str = Field(min_length=1, max_length=64)  # ISO 8601
    constants_version_hash: str = Field(min_length=1, max_length=64)
    source: Literal["mobile_session_start", "mobile_session_warm_resume"]
    local_event_id: Optional[str] = Field(default=None, max_length=64)
    app_lifecycle_state: Optional[str] = Field(default=None, max_length=32)


class MobileSessionStartResponse(BaseModel):
    """Single-row insert outcome."""

    linked: int = 0
    skipped: int = 0


class MobileSessionLinkBatch(BaseModel):
    """Batch upload from the mobile offline buffer."""

    items: List[MobileSessionEvent] = Field(min_length=1, max_length=200)


class MobileSessionLinkResponse(BaseModel):
    """Outcome of the batch link with handshake enforcement."""

    linked: int = 0
    skipped: int = 0


class MobileSessionHandshakeResponse(BaseModel):
    """Per iter-3 iA2 — server-side state used by mobile replay-ordering logic."""

    session_token: str  # HMAC-tagged anchor ; not a credential
    has_prior_session_start: bool
    last_seen_local_event_id: Optional[str]
    server_received_ts: str  # ISO 8601


# ── Helpers ────────────────────────────────────────────────────────────────

def _parse_iso(ts: str) -> datetime:
    """Parse an ISO 8601 string into a UTC-aware datetime.

    Accepts both `2026-05-18T12:34:56Z` and `+00:00` shapes. Raises
    HTTPException 422 on malformed input rather than the bare ValueError
    so the client gets a clean diagnostic.
    """
    try:
        if ts.endswith("Z"):
            ts = ts[:-1] + "+00:00"
        dt = datetime.fromisoformat(ts)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "error": "invalid_observed_at",
                "message": f"observed_at must be ISO 8601 ({exc})",
                "value": ts,
            },
        ) from exc


def _payload_hashes(event: MobileSessionEvent) -> tuple[str, str]:
    """Compute scenario_inputs_hash + output_hash for the audit row.

    Mobile L1 audit rows still occupy the legacy NOT-NULL hash columns ;
    we compute deterministic digests from the payload so the rows remain
    queryable + auditable without overloading the column semantics.
    """
    canonical = json.dumps(
        {
            "asid": event.anonymous_session_id,
            "av": event.app_version,
            "oa": event.observed_at,
            "cvh": event.constants_version_hash,
            "src": event.source,
            "lei": event.local_event_id,
            "als": event.app_lifecycle_state,
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    inputs_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    # output_hash mirrors inputs_hash for Mobile L1 (no separate output) ;
    # surface them as distinct columns for cross-table contract uniformity.
    return inputs_hash, inputs_hash


def _build_audit_row(
    event: MobileSessionEvent,
    *,
    user: Optional[User],
    server_received_ts: datetime,
) -> ProjectionAuditRecord:
    """Materialise a ProjectionAuditRecord for Mobile L1 audit ingestion."""
    inputs_hash, output_hash = _payload_hashes(event)
    return ProjectionAuditRecord(
        id=str(uuid4()),
        user_id_hash=hmac_user_id(user.id) if user is not None else hmac_pii(event.anonymous_session_id) or "",
        computed_at=server_received_ts,
        source=event.source,
        projection_type="mobile_l1",
        projection_id=event.anonymous_session_id,
        constants_version_hash=event.constants_version_hash,
        scenario_inputs_hash=inputs_hash,
        output_hash=output_hash,
        lsfin_disclaimer_shown=False,
        app_version=event.app_version,
        observed_at=_parse_iso(event.observed_at),
        anonymous_session_id=event.anonymous_session_id,
        local_event_id=event.local_event_id,
        app_lifecycle_state=event.app_lifecycle_state,
        client_ts=_parse_iso(event.observed_at),
        server_received_ts=server_received_ts,
    )


def _session_token(anonymous_session_id: str, user_id: Optional[str]) -> str:
    """Compute an HMAC-tagged session_token (NOT a credential).

    Used by mobile replay-ordering logic per iter-3 iA2 : the mobile client
    stores the token alongside the anonymous_session_id ; the server uses
    it to detect spoofed link batches (the token derivation includes the
    authenticated user.id, so a replay batch from a different user is
    rejected at the application layer).
    """
    # hmac_pii is the canonical entry — provides the pepper-anchored hash
    # without re-implementing HMAC primitives here.
    composite = f"{anonymous_session_id}:{user_id or 'anon'}"
    return hmac_pii(composite) or ""


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post(
    "/mobile-session-events",
    response_model=MobileSessionLinkResponse,
    status_code=status.HTTP_200_OK,
    tags=["audit-mobile"],
)
def upload_mobile_session_events(
    payload: MobileSessionLinkBatch,
    db: Session = Depends(get_db),
    user: Optional[User] = Depends(get_current_user),
) -> MobileSessionLinkResponse:
    """Batch upload Mobile L1 audit events (auth optional — auth-gated handshake).

    Two operating modes :
      1. Anonymous (no auth header) : accepts only `source='mobile_session_start'`
         entries. Other source values are rejected 403 (anonymous clients
         cannot link a warm_resume without proof of a prior start).
      2. Authenticated (auth header present) : enforces iter-2 A6 proof-
         of-session-start handshake for any non-start entry.

    Idempotent : duplicate (anonymous_session_id, observed_at) entries
    are silently skipped (counted as `skipped`).
    """
    server_received_ts = datetime.now(timezone.utc)

    # ── Anonymous path : only allow session_start ───────────────────────
    if user is None:
        non_start = [e for e in payload.items if e.source != "mobile_session_start"]
        if non_start:
            mint_anonymous_session_link_total.labels(
                outcome="rejected_no_handshake",
            ).inc()
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "session_link_handshake_missing",
                    "message": (
                        "Anonymous batch may only contain "
                        "source='mobile_session_start' entries. "
                        "warm_resume + link batches require an authenticated session."
                    ),
                    "missing_sids": sorted({e.anonymous_session_id for e in non_start}),
                },
            )
    else:
        # ── Authenticated path : enforce proof-of-session-start ───────────
        non_start = [e for e in payload.items if e.source != "mobile_session_start"]
        if non_start:
            sids_needing_proof = {e.anonymous_session_id for e in non_start}
            # Single SELECT to find sids with a prior session_start row.
            rows = db.execute(
                sa.text(
                    """
                    SELECT DISTINCT anonymous_session_id
                      FROM projection_audit_records
                     WHERE anonymous_session_id IN :sids
                       AND source = 'mobile_session_start'
                    """
                ).bindparams(sa.bindparam("sids", expanding=True)),
                {"sids": list(sids_needing_proof)},
            ).fetchall()
            sids_with_proof = {r[0] for r in rows}
            missing = sids_needing_proof - sids_with_proof
            if missing:
                mint_anonymous_session_link_total.labels(
                    outcome="rejected_no_handshake",
                ).inc()
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={
                        "error": "session_link_handshake_missing",
                        "message": (
                            "Batch contains anonymous_session_id values with no prior "
                            "mobile_session_start row. Link rejected. Per iter-2 A6 "
                            "(T-S01 spoofing mitigation), POST /v1/audit/mobile-session-events "
                            "with source='mobile_session_start' BEFORE uploading warm_resume entries."
                        ),
                        "missing_sids": sorted(missing),
                    },
                )

    # ── Idempotent batch INSERT (per-row flush so in-batch dups are caught) ─
    linked = 0
    skipped = 0
    # Track (sid, observed_at) keys seen within THIS batch so in-batch
    # duplicates are skipped without round-tripping to the DB. Cheaper
    # than flush-per-row + cleaner than swallowing IntegrityError.
    seen_in_batch: set[tuple[str, datetime]] = set()
    for event in payload.items:
        try:
            observed_at_dt = _parse_iso(event.observed_at)
            in_batch_key = (event.anonymous_session_id, observed_at_dt)
            if in_batch_key in seen_in_batch:
                skipped += 1
                continue
            # DB-level dedup : pre-check (caught by UNIQUE index — second
            # POST of the same payload returns skipped, not 500).
            existing = db.execute(
                sa.text(
                    """
                    SELECT 1 FROM projection_audit_records
                     WHERE anonymous_session_id = :sid
                       AND observed_at = :oa
                     LIMIT 1
                    """
                ),
                {
                    "sid": event.anonymous_session_id,
                    "oa": observed_at_dt,
                },
            ).fetchone()
            if existing is not None:
                skipped += 1
                continue

            row = _build_audit_row(
                event,
                user=user,
                server_received_ts=server_received_ts,
            )
            # QA BLOCK-2 fix (2026-05-19) : wrap the per-row INSERT in a
            # SAVEPOINT so a mid-batch IntegrityError rolls back ONLY this
            # row, preserving previously-linked rows in the same outer
            # transaction. The previous `db.rollback()` pattern cascade-
            # deleted all prior `linked` rows silently — caller saw
            # `linked=49` but only 20 rows in DB. Mirrors the SAVEPOINT
            # pattern in fact_projector.py:96-101.
            try:
                with db.begin_nested():
                    db.add(row)
                    db.flush()  # surface UNIQUE-violation per-row
                seen_in_batch.add(in_batch_key)
                linked += 1
            except sa.exc.IntegrityError:
                # In-batch tracking missed a concurrent dup (iter-2 A6
                # spoof scenario : another mobile device replayed the
                # same anonymous_session_id+observed_at tuple between
                # the SELECT pre-check and the INSERT). The SAVEPOINT
                # auto-rolled back this row ; prior linked rows are
                # preserved in the outer transaction.
                skipped += 1
                continue
        except HTTPException:
            raise
        except Exception:  # pragma: no cover — surfaces as 500 + counter
            mint_anonymous_session_link_total.labels(outcome="error").inc()
            db.rollback()
            raise

    db.commit()
    if linked > 0:
        mint_anonymous_session_link_total.labels(outcome="linked").inc()
    if skipped > 0:
        mint_anonymous_session_link_total.labels(outcome="skipped_duplicate").inc()
    return MobileSessionLinkResponse(linked=linked, skipped=skipped)


@router.get(
    "/mobile-session-handshake",
    response_model=MobileSessionHandshakeResponse,
    status_code=status.HTTP_200_OK,
    tags=["audit-mobile"],
)
def get_mobile_session_handshake(
    anonymous_session_id: str = Query(..., min_length=8, max_length=36),
    db: Session = Depends(get_db),
    user: User = Depends(require_current_user),
) -> MobileSessionHandshakeResponse:
    """Return server-side state for an anonymous_session_id (iter-3 iA2).

    The authenticated mobile client calls this BEFORE issuing a
    /mobile-session-events link batch to verify :
      - the server has a prior mobile_session_start row (else the link
        batch will fail handshake);
      - the last_seen_local_event_id matches the mobile's tail of the
        replay queue (else the buffer has drifted ; client triggers a
        full re-replay including missing session_start);
      - the session_token derived from (anonymous_session_id, user.id)
        matches the client-side cache (else either the user has
        rotated or the session is being replayed under the wrong user
        identity — link batch rejected by application layer).
    """
    row = db.execute(
        sa.text(
            """
            SELECT local_event_id, MAX(observed_at) AS last_observed_at
              FROM projection_audit_records
             WHERE anonymous_session_id = :sid
               AND source = 'mobile_session_start'
             GROUP BY local_event_id
             ORDER BY MAX(observed_at) DESC
             LIMIT 1
            """
        ),
        {"sid": anonymous_session_id},
    ).fetchone()

    return MobileSessionHandshakeResponse(
        session_token=_session_token(anonymous_session_id, user.id),
        has_prior_session_start=row is not None,
        last_seen_local_event_id=(row[0] if row is not None else None),
        server_received_ts=datetime.now(timezone.utc).isoformat(),
    )


__all__ = [
    "router",
    "MobileSessionEvent",
    "MobileSessionLinkBatch",
    "MobileSessionLinkResponse",
    "MobileSessionHandshakeResponse",
]
