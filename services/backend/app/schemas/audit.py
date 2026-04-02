"""
Audit event schemas for the admin audit trail endpoint.
"""

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class AuditEventResponse(BaseModel):
    """Single audit event returned by the admin endpoint."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        from_attributes=True,
    )

    id: str
    user_id: Optional[str] = None
    actor_email: Optional[str] = None
    event_type: str
    status: str
    source: str
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    details_json: Optional[str] = None
    created_at: datetime


class PaginatedAuditResponse(BaseModel):
    """Paginated list of audit events."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    items: List[AuditEventResponse]
    total: int
    limit: int
    offset: int
