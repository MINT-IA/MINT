"""EncryptionContextMiddleware — populates ContextVars for EncryptedBytes.

v2.7 Phase 29 / PRIV-04.

Reads the JWT from the Authorization header (best-effort, non-blocking),
extracts user_id into `current_user_id` for the lifetime of the request.
Database sessions are created per-dependency via `get_db()` — we do NOT
create one here; instead, callers that want to use `EncryptedBytes` must
either:

    (a) bind `current_db_session` themselves inside the endpoint handler
        (`current_db_session.set(db)` after Depends(get_db)), or
    (b) use the explicit `encrypt_bytes(db, user_id, ...)` / `decrypt_bytes`
        helpers from `app.services.encryption.envelope` — which is what
        document_memory_service does in this plan.

Background workers / cron scripts MUST set both ContextVars manually.
"""
from __future__ import annotations

import logging
from typing import Optional

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from app.services.encryption.key_vault import current_user_id

logger = logging.getLogger(__name__)


def _extract_user_id(request: Request) -> Optional[str]:
    auth = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth or not auth.lower().startswith("bearer "):
        return None
    token = auth.split(None, 1)[1].strip()
    try:
        from app.services.auth_service import decode_token
        payload = decode_token(token)
        if payload is None:
            return None
        return payload.get("user_id")
    except Exception as exc:  # pragma: no cover
        logger.debug("encryption_context: token decode failed: %s", exc)
        return None


class EncryptionContextMiddleware(BaseHTTPMiddleware):
    """Sets current_user_id for the request lifespan."""

    async def dispatch(self, request: Request, call_next):
        uid = _extract_user_id(request)
        token = current_user_id.set(uid)
        try:
            response = await call_next(request)
        finally:
            current_user_id.reset(token)
        return response


__all__ = ["EncryptionContextMiddleware"]
