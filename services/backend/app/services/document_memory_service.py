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


__all__ = ["compute_fingerprint", "upsert_and_diff"]
