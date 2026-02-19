"""
Rate limiting configuration for MINT API.

Uses slowapi with in-memory backend by default.
If REDIS_URL is set, uses Redis as the storage backend for distributed rate limiting.
Set TESTING=1 to disable rate limiting in test environments.
"""

import logging
import os

from slowapi import Limiter
from slowapi.util import get_remote_address

logger = logging.getLogger(__name__)

_redis_url = os.getenv("REDIS_URL", "")
_storage_uri = None

if _redis_url:
    _storage_uri = _redis_url
    logger.info("Rate limiting: using Redis backend at %s", _redis_url)
else:
    logger.info("Rate limiting: using in-memory backend")

limiter = Limiter(
    key_func=get_remote_address,
    enabled=os.getenv("TESTING", "") != "1",
    storage_uri=_storage_uri,
)
