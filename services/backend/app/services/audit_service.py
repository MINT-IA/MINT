"""
Audit service helpers.
"""

from __future__ import annotations

import json
from typing import Any, Optional
from sqlalchemy.orm import Session

from app.models.audit_event import AuditEventModel


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
            actor_email=actor_email,
            event_type=event_type,
            status=status,
            source=source,
            ip_address=ip_address,
            user_agent=user_agent,
            details_json=json.dumps(details) if details else None,
        )
    )
