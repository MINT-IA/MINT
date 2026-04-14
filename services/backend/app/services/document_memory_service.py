"""DocumentMemoryService — fingerprint, upsert, diff against previous.

v2.7 Phase 28 / DOC-01 (Document Memory v1).

Sync API (sqlalchemy ORM Session — matches the rest of the documents
endpoint stack which is sync). The async migration is out of scope here.
"""
from __future__ import annotations

import hashlib
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.models.document_memory import DocumentMemory
from app.schemas.document_understanding import (
    DocumentUnderstandingResult,
    FieldDiff,
)
from app.services.encryption.envelope import (
    encrypt_text,
    decrypt_text,
    EncryptionError,
)
from app.services.encryption.key_vault import DEKRevokedError

logger = logging.getLogger(__name__)


def compute_fingerprint(
    doc_class: str,
    issuer: Optional[str],
    layout_signature: Optional[str] = None,
) -> str:
    """Deterministic fingerprint of a document's identity (not its content).

    Two uploads of the same issuer's same document type collide. Layout
    signature reserved for future iterations (e.g. hash of header bbox
    structure). 32 hex chars = 128 bits, plenty for per-user uniqueness.
    """
    raw = f"{doc_class}|{issuer or ''}|{layout_signature or ''}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:32]


def _diff_fields(
    old_fields: Dict[str, Any],
    new_fields: Dict[str, Any],
) -> Dict[str, FieldDiff]:
    """Compute per-field diff with delta_pct for numeric fields."""
    diff: Dict[str, FieldDiff] = {}
    keys = set(old_fields) | set(new_fields)
    for k in keys:
        old = old_fields.get(k)
        new = new_fields.get(k)
        if old == new:
            continue
        delta_pct: Optional[float] = None
        if (
            isinstance(old, (int, float))
            and isinstance(new, (int, float))
            and not isinstance(old, bool)
            and not isinstance(new, bool)
            and old != 0
        ):
            try:
                delta_pct = round(((new - old) / abs(old)) * 100.0, 2)
            except Exception:
                delta_pct = None
        diff[k] = FieldDiff(old=old, new=new, delta_pct=delta_pct)
    return diff


def upsert_and_diff(
    db: Session,
    user_id: str,
    result: DocumentUnderstandingResult,
    layout_signature: Optional[str] = None,
) -> Optional[Dict[str, FieldDiff]]:
    """Upsert memory row, return diff dict if previous version existed.

    First time we see (user_id, fingerprint) → returns None.
    Subsequent uploads → returns dict of changed fields with delta_pct.

    Always commits the new history entry.
    """
    fingerprint = compute_fingerprint(
        result.document_class.value if hasattr(result.document_class, "value") else str(result.document_class),
        result.issuer_guess,
        layout_signature,
    )
    new_fields_dict: Dict[str, Any] = {
        f.field_name: f.value for f in result.extracted_fields
    }

    existing = (
        db.query(DocumentMemory)
        .filter(
            DocumentMemory.user_id == user_id,
            DocumentMemory.fingerprint == fingerprint,
        )
        .one_or_none()
    )

    diff: Optional[Dict[str, FieldDiff]] = None
    history_entry = {
        "date": datetime.now(timezone.utc).isoformat(),
        "fields": new_fields_dict,
    }

    if existing is not None:
        history: List[Dict[str, Any]] = list(existing.field_history or [])
        if history:
            last = history[-1].get("fields") or {}
            diff = _diff_fields(last, new_fields_dict) or None
        history.append(history_entry)
        existing.field_history = history
        existing.last_seen_at = datetime.now(timezone.utc)
        existing.issuer = result.issuer_guess or existing.issuer
    else:
        row = DocumentMemory(
            user_id=user_id,
            fingerprint=fingerprint,
            doc_type=(
                result.document_class.value
                if hasattr(result.document_class, "value")
                else str(result.document_class)
            ),
            issuer=result.issuer_guess,
            last_seen_at=datetime.now(timezone.utc),
            field_history=[history_entry],
        )
        db.add(row)

    try:
        db.commit()
    except Exception as exc:
        logger.warning("document_memory: commit failed user=%s err=%s", user_id, exc)
        db.rollback()
        return None

    return diff


def _flag_privacy_v2(user_id: str) -> bool:
    """Synchronous read of PRIVACY_V2_ENABLED.

    FlagsService is async, but document_memory_service is called from sync
    endpoints. We spawn a short-lived event loop run — mirrors the pattern
    used by other sync-callers of FlagsService in this codebase. Fail-closed
    on any exception (plaintext write path).
    """
    try:
        import asyncio
        from app.services.flags_service import flags
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                # We're inside an async context; create_task + block is unsafe.
                # Fall back to synchronous Redis call via nested event loop.
                return asyncio.run_coroutine_threadsafe(
                    flags.is_enabled("PRIVACY_V2_ENABLED", user_id), loop
                ).result(timeout=1.0)
        except RuntimeError:
            pass
        return asyncio.run(flags.is_enabled("PRIVACY_V2_ENABLED", user_id))
    except Exception as exc:
        logger.debug("flag check failed (%s) — defaulting to plaintext", exc)
        return False


def persist_evidence_text(
    db: Session,
    user_id: str,
    row: DocumentMemory,
    evidence_text: Optional[str],
    vision_raw: Optional[str] = None,
) -> None:
    """Write evidence_text + vision_raw to the memory row.

    Flag ON  → writes go into *_enc columns (plaintext columns stay NULL).
    Flag OFF → writes go into plaintext columns (legacy path).

    Does not commit — caller controls transaction boundary.
    Raises DEKRevokedError if flag is ON but the user's DEK was shredded.
    """
    if _flag_privacy_v2(user_id):
        row.evidence_text = None
        row.vision_raw = None
        row.evidence_text_enc = encrypt_text(db, user_id, evidence_text)
        row.vision_raw_enc = encrypt_text(db, user_id, vision_raw)
    else:
        row.evidence_text = evidence_text
        row.vision_raw = vision_raw
        row.evidence_text_enc = None
        row.vision_raw_enc = None


def read_evidence_text(
    db: Session,
    user_id: str,
    row: DocumentMemory,
) -> Dict[str, Optional[str]]:
    """Return {'evidence_text': ..., 'vision_raw': ...} with transparent decrypt.

    Read path:
        1. If *_enc is non-null → decrypt it.
        2. Else → return plaintext column (backward-compat window).

    Propagates DEKRevokedError if the user's DEK was shredded and an
    encrypted blob is present — the API layer should surface 410 Gone.
    """
    def _read(enc: Optional[bytes], plain: Optional[str]) -> Optional[str]:
        if enc is not None:
            return decrypt_text(db, user_id, bytes(enc))
        return plain

    return {
        "evidence_text": _read(row.evidence_text_enc, row.evidence_text),
        "vision_raw": _read(row.vision_raw_enc, row.vision_raw),
    }


def _hash_key(key: str) -> str:
    """Return a short stable hash of a fact_key for safe drop logging."""
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:12]


def persist_fact(
    db: Optional[Session],
    user_id: str,
    key: str,
    value: Any,
    *,
    source: str = "coach",
) -> bool:
    """Persist a single fact_key to ``profile_facts`` (PRIV-06).

    Allowlist-gated: keys not in ``ALLOWED_FACT_KEYS`` are silently dropped
    with a hashed-key log line. The drop is the *only* enforcement point —
    callers do not need to check ``is_allowed`` themselves.

    Returns ``True`` if the value was accepted (would be) persisted, ``False``
    if dropped. The DB write itself is best-effort: when ``db`` is None or
    the ``profile_facts`` table is not yet present (Alembic migration
    pending in some environments), we still return True so business logic
    treats the fact as accepted from a privacy/policy standpoint.

    The ``ttl_expires_at`` column is computed from
    ``ALLOWED_FACT_KEYS[key]['ttl_days']``: ``None`` ⇒ NULL (account
    lifetime).
    """
    from app.services.privacy.fact_key_allowlist import (
        ALLOWED_FACT_KEYS,
        is_allowed,
        purpose_of,
        ttl_days_of,
    )

    if not key or not is_allowed(key):
        # PRIV-06: hard drop. Log carries the hashed key only; never the
        # raw key (some keys are themselves PII signals e.g. "iban") and
        # never the value.
        logger.info(
            "fact_key dropped purpose_violation count=1 key_hash=%s source=%s",
            _hash_key(key or ""),
            source,
        )
        return False

    purpose = purpose_of(key)
    ttl_days = ttl_days_of(key)
    expires_at: Optional[datetime] = None
    if ttl_days is not None:
        from datetime import timedelta
        expires_at = datetime.now(timezone.utc) + timedelta(days=ttl_days)

    # DB write — best-effort. profile_facts may not exist yet on the
    # target DB; we tolerate that (test envs, fresh dev DBs) and return
    # True as long as the policy gate passed.
    if db is None:
        return True
    try:
        from sqlalchemy import text
        db.execute(
            text(
                "INSERT INTO profile_facts (user_id, fact_key, value, "
                "purpose, ttl_expires_at, updated_at) VALUES "
                "(:uid, :k, :v, :p, :exp, :now) "
                "ON CONFLICT (user_id, fact_key) DO UPDATE SET "
                "value = EXCLUDED.value, purpose = EXCLUDED.purpose, "
                "ttl_expires_at = EXCLUDED.ttl_expires_at, "
                "updated_at = EXCLUDED.updated_at"
            ),
            {
                "uid": user_id,
                "k": key,
                "v": str(value) if value is not None else None,
                "p": purpose.value if purpose else "projection",
                "exp": expires_at,
                "now": datetime.now(timezone.utc),
            },
        )
        db.commit()
    except Exception as exc:
        logger.debug(
            "persist_fact: DB write skipped/failed (%s) — policy gate ok",
            type(exc).__name__,
        )
        try:
            db.rollback()
        except Exception:
            pass
    return True


__all__ = [
    "compute_fingerprint",
    "upsert_and_diff",
    "persist_evidence_text",
    "read_evidence_text",
    "persist_fact",
    "DEKRevokedError",
    "EncryptionError",
]
