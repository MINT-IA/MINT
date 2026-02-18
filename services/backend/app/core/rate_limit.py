"""
Rate limiting configuration for MINT API.

Uses slowapi with in-memory backend.
Production should switch to Redis backend via RATE_LIMIT_STORAGE_URL env var.
Set TESTING=1 to disable rate limiting in test environments.
"""

import os

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(
    key_func=get_remote_address,
    enabled=os.getenv("TESTING", "") != "1",
)
