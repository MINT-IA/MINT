"""Self-test fixture for `tools/checks/hmac_pepper_audit.py` (D-24).

Contains the forbidden bare-`hashlib.sha256(user_id, ...)` pattern verbatim so
the lint has a deterministic positive test. NEVER imported by production code.
"""
from __future__ import annotations

import hashlib


def bad_hash_user_id(user_id: str) -> str:
    """FORBIDDEN: bare sha256 over a PII identifier."""
    return hashlib.sha256(user_id.encode()).hexdigest()


def bad_hash_actor_email(actor_email: str) -> str:
    """FORBIDDEN: bare sha256 over an actor email."""
    return hashlib.sha256(actor_email.encode()).hexdigest()
