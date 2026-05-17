"""
Audit service helpers.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any, Optional
from sqlalchemy.orm import Session

from app.models.audit_event import AuditEventModel


def hash_user_id(user_id: Optional[str]) -> Optional[str]:
    """Return sha256(user_id) hex digest, or None when user_id is None.

    Hotfix C 2026-05-17 — single source of truth for the audit-row PII
    hash. Re-used by any code path that writes AuditEventModel directly
    (e.g. open_banking.consent_manager._log_audit) so the audit table
    stays PII-clean even after nLPD right-of-erasure on the user row.
    """
    if user_id is None:
        return None
    return hashlib.sha256(user_id.encode("utf-8")).hexdigest()


def log_audit_event(
    db: Session,
    *,
    event_type: str,
    status: str = "success",
    source: str = "api",
    user_id: Optional[str] = None,
    actor_email: Optional[str] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
    details: Optional[dict[str, Any]] = None,
) -> None:
    """
    Add an audit event row to the current transaction.
    """
    db.add(
        AuditEventModel(
            user_id=user_id,
            user_id_hash=hash_user_id(user_id),
            actor_email=actor_email,
            event_type=event_type,
            status=status,
            source=source,
            ip_address=ip_address,
            user_agent=user_agent,
            details_json=json.dumps(details) if details else None,
        )
    )
