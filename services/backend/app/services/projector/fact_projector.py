"""FactProjector — atomic single-event projector into (fact_event, fact_current).

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-19 + D-26 + D-27 + D-28.

Single entry point : `project_event(session, event)`. Writes BOTH the
append-only `fact_event` row AND the UPSERT into `fact_current` inside a
single atomic transaction (D-19 — `with session.begin()` rollback on
any failure leaves both tables consistent).

Codebase convention
===================
The project uses sync SQLAlchemy throughout (see snapshot_service.py,
key_vault.py, audit_service.py). The plan describes an `async def
project_event(session: AsyncSession, event)` signature, but the surrounding
codebase has zero AsyncSession usage. Matching the codebase convention here
(Karpathy #1 — surface the assumption) ; an async wrapper can be added in
Plan 02-03 if the audit_mobile endpoint needs it (FastAPI itself accepts
sync DB calls inside async route handlers).

UPSERT semantics (D-19 idempotency + last-writer-wins)
======================================================
On Postgres :
    INSERT INTO fact_current (...)
    ON CONFLICT (user_id, field_key) DO UPDATE
        SET value_enc = EXCLUDED.value_enc,
            confidence = EXCLUDED.confidence,
            valid_from = EXCLUDED.valid_from,
            updated_at = now()
        WHERE EXCLUDED.valid_from > fact_current.valid_from

The guarded WHERE makes the UPSERT idempotent + last-writer-wins by
valid_from. An older event arriving late does NOT clobber newer state
(D-04 point-in-time immutability preserved at the read-side).

On SQLite (test path) :
    INSERT OR IGNORE then UPDATE ... WHERE valid_from > existing.valid_from
    (SQLite has ON CONFLICT but the syntax differs slightly ; we use the
    SQLite-portable ON CONFLICT (user_id, field_key) DO UPDATE form.)

Atomicity guarantee
===================
The fact_event INSERT + fact_current UPSERT happen inside a single
`with session.begin()` block. If either raises, the transaction is rolled
back and NEITHER table is mutated. This is the D-19 atomicity contract :
the read-side (fact_current) is NEVER ahead of the write-side (fact_event).
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.fact_current import FactCurrent
from app.models.fact_event import FactEvent


@dataclass
class FactEventInput:
    """Input payload for project_event — pre-encryption.

    The projector accepts the D-26 EncryptedValue dict directly (the caller
    is responsible for encrypting via encrypt_value() from
    app/services/encryption/encrypted_value_helper.py BEFORE calling the
    projector). This keeps the projector single-responsibility (write
    coordination only ; no crypto inside).
    """

    user_id: str
    field_key: str
    value_enc: Dict[str, Any]  # D-26 EncryptedValue.model_dump() shape
    valid_from: datetime
    source: str
    confidence: Optional[Dict[str, Any]] = None  # D-29 EnhancedConfidence shape, nullable


def project_event(session: Session, event: FactEventInput) -> str:
    """Project a single event into (fact_event, fact_current) atomically.

    Returns the generated event_id (UUID4 string).

    Raises whatever the underlying session raises. The transaction is
    rolled back automatically by `with session.begin()` on any exception ;
    after rollback NEITHER fact_event NOR fact_current has been mutated.
    """
    event_id = str(uuid4())
    now = datetime.now(timezone.utc)

    # D-19 : single atomic transaction. session.begin() commits on
    # successful exit and rolls back on exception. If the session is
    # already inside a transaction (typical for test fixtures), use
    # session.begin_nested() for SAVEPOINT semantics.
    if session.in_transaction():
        ctx = session.begin_nested()
    else:
        ctx = session.begin()

    with ctx:
        # ── 1. Append-only INSERT into fact_event ─────────────────────────
        fe = FactEvent(
            event_id=event_id,
            user_id=event.user_id,
            field_key=event.field_key,
            value_enc=event.value_enc,
            confidence=event.confidence,
            valid_from=event.valid_from,
            recorded_at=now,
            source=event.source,
            event_version=1,
        )
        session.add(fe)
        session.flush()  # surface DB constraint failures inside the txn

        # ── 2. UPSERT fact_current via raw SQL (portable Postgres+SQLite) ─
        # SQLAlchemy ORM has no portable .merge() that emits ON CONFLICT
        # DO UPDATE with a WHERE-guard, so we drop to text() for the
        # idempotent UPSERT. The WHERE guard makes this last-writer-wins
        # by valid_from (older events arriving late don't clobber).
        session.execute(
            text(
                """
                INSERT INTO fact_current
                    (user_id, field_key, value_enc, confidence, valid_from, updated_at)
                VALUES
                    (:user_id, :field_key, :value_enc, :confidence, :valid_from, :updated_at)
                ON CONFLICT (user_id, field_key) DO UPDATE
                    SET value_enc  = excluded.value_enc,
                        confidence = excluded.confidence,
                        valid_from = excluded.valid_from,
                        updated_at = excluded.updated_at
                    WHERE excluded.valid_from > fact_current.valid_from
                """
            ),
            {
                "user_id": event.user_id,
                "field_key": event.field_key,
                # SQLAlchemy's bind layer JSON-serialises dicts into the
                # JSONType column on both Postgres (JSONB) and SQLite (TEXT).
                # We pass the dict directly to keep symmetry with the ORM
                # insert above.
                "value_enc": _json_bind(event.value_enc),
                "confidence": _json_bind(event.confidence),
                "valid_from": event.valid_from,
                "updated_at": now,
            },
        )

        # ── 3. QA sec FLAG-1 (2026-05-19) — post-write divergence assertion ─
        # Defense-in-depth against ContextVar leak bugs that could swap
        # event.user_id between the INSERT into fact_event and the UPSERT
        # into fact_current. Without this guard, a wrong-user_id corruption
        # would silently land cross-user data until the drift sampler caught
        # it (continuous_drift_sampler runs hourly, deferred to Plan 02-04
        # full integration). The cost is one extra SELECT per project_event
        # call ; the benefit is mechanical proof that the UPSERT actually
        # targeted the same (user_id, field_key) tuple we just inserted into
        # fact_event. Failure raises inside the `with ctx:` block so the
        # SAVEPOINT (or outer transaction) rolls back automatically — neither
        # fact_event NOR fact_current is mutated on assertion failure.
        verified_row = session.execute(
            text(
                """
                SELECT 1 FROM fact_current
                 WHERE user_id = :user_id
                   AND field_key = :field_key
                """
            ),
            {"user_id": event.user_id, "field_key": event.field_key},
        ).first()
        if verified_row is None:
            raise RuntimeError(
                f"Phase 02 sec FLAG-1 post-write assertion failed : "
                f"project_event for user_id={event.user_id!r} "
                f"field_key={event.field_key!r} valid_from={event.valid_from!r} "
                f"did not produce a matching fact_current row. Possible "
                f"ContextVar user_id swap, schema invariant violation, or "
                f"UPSERT silent failure. Rolling back transaction."
            )

    return event_id


def _json_bind(value: Optional[Dict[str, Any]]) -> Optional[str]:
    """Serialise a dict to a JSON string for the text() bind layer.

    Necessary because raw text() binds don't auto-serialise dicts to JSONB
    the way the ORM does. Returns None for None input.
    """
    if value is None:
        return None
    import json
    return json.dumps(value, separators=(",", ":"), sort_keys=True, ensure_ascii=False)


__all__ = ["FactEventInput", "project_event"]
