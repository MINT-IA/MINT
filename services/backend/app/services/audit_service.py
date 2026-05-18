"""
Audit service helpers.

Plan 02-02 W1 (D-14): `hash_user_id` now routes through the canonical
HMAC-SHA256-pepper entry `app.services.audit.hmac_pepper.hmac_user_id`.
Bare `hashlib.sha256` was rainbow-table reversible (security-auditor obs #175);
the pepper-hash makes pre-computation infeasible. p114 backfills existing
rows. Public function name `hash_user_id` is preserved for caller
compatibility (open_banking.consent_manager etc.).
"""

from __future__ import annotations

import json
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models.audit_event import AuditEventModel
from app.services.audit.hmac_pepper import hmac_user_id as _hmac_user_id


def hash_user_id(user_id: Optional[str]) -> Optional[str]:
    """Return HMAC-SHA256-pepper hex digest of `user_id`, or None when None.

    D-14 (Plan 02-02 W1): replaced bare `hashlib.sha256` with HMAC-pepper.
    Single source of truth for the audit-row PII hash. Re-used by any code
    path that writes AuditEventModel directly so the audit table stays
    PII-clean even after nLPD right-of-erasure on the user row AND
    rainbow-table reversal becomes infeasible.
    """
    return _hmac_user_id(user_id)


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
