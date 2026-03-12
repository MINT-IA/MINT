"""
Rate limiting configuration for MINT API.

Uses slowapi with in-memory backend by default.
If REDIS_URL is set, uses Redis as the storage backend for distributed rate limiting.
Set TESTING=1 to disable rate limiting in test environments.
"""

import logging
import os

from slowapi import Limiter
from starlette.requests import Request

logger = logging.getLogger(__name__)


def _get_real_client_ip(request: Request) -> str:
    """Return the real client IP for rate limiting.

    Behind Railway's reverse proxy, request.client.host is the proxy IP —
    useless for per-client rate limiting. The real client IP is in
    X-Forwarded-For, appended by each trusted proxy in order.

    We take the RIGHTMOST IP, which is the one appended by our trusted proxy
    (Railway). Client-supplied IPs appear leftmost and are ignored, preventing
    X-Forwarded-For spoofing.

    Falls back to request.client.host when the header is absent (local dev).
    """
    forwarded_for = request.headers.get("X-Forwarded-For", "")
    if forwarded_for:
        ips = [ip.strip() for ip in forwarded_for.split(",") if ip.strip()]
        if ips:
            return ips[-1]  # rightmost = added by Railway proxy, not spoofable
    if request.client:
        return request.client.host or "127.0.0.1"
    return "127.0.0.1"


_redis_url = os.getenv("REDIS_URL", "")
_storage_uri = None

if _redis_url:
    _storage_uri = _redis_url
    logger.info("Rate limiting: using Redis backend at %s", _redis_url)
else:
    logger.info("Rate limiting: using in-memory backend")

limiter = Limiter(
    key_func=_get_real_client_ip,
    enabled=os.getenv("TESTING", "") != "1",
    storage_uri=_storage_uri,
)
