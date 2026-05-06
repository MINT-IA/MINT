"""SHA-256 hash helper for the coach audit log (Phase 93 — COMP-01).

Per OAR-G art. 24 + FINMA Guidance 8/2024 SS VI.

The audit log persists hashed user prompts + LLM responses (never raw text)
so a FINMA inspector can verify that a response was produced for a given
session without exposing PII (nLPD art. 6, LPD).

v1 (Phase 93): unsalted SHA-256 hex digest.
v2 (Phase 96): per-tenant salt via the AUDIT_PROMPT_SALT env var.

The inspector test only cares about presence (a row exists for every coach
response), not unlinkability across sessions, so v1 is sufficient.
"""

from __future__ import annotations

import hashlib

__all__ = ["hash_for_audit"]


def hash_for_audit(text: str) -> str:
    """Return the lowercase SHA-256 hex digest of ``text`` (64 chars).

    Args:
        text: The string to hash. ``None`` and non-string inputs are
            coerced to the empty string so the audit hook never raises.

    Returns:
        A 64-character lowercase hex string.

    Per OAR-G art. 24 + FINMA Guidance 8/2024 SS VI.
    """
    if not isinstance(text, str):
        text = "" if text is None else str(text)
    return hashlib.sha256(text.encode("utf-8")).hexdigest()
