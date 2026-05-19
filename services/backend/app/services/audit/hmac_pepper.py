"""Canonical entry for audit-PII HMAC-SHA256-pepper hashing.

Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-24) — STUB ONLY.

This module exists as the self-exempt allowlist for
`tools/checks/hmac_pepper_audit.py`. The real implementation lands in
Plan 02-02 W1 (D-Q7 HMAC-pepper migration : `MINT_AUDIT_HMAC_PEPPER` env-var
load + `hmac.new(pepper, user_id.encode(), 'sha256').hexdigest()` + alembic
backfill p112-style).

Until Plan 02-02 W1 ships, calling `hmac_user_id()` from production code
raises `NotImplementedError` — fail-closed beats silently-degraded-PII.

Threat T-02-10 (Information Disclosure) : the stub never holds pepper bytes;
the lint allowlists this path so Plan 02-02 W1 can ship the real impl atomically.
"""
from __future__ import annotations


def hmac_user_id(user_id: str) -> str:
    """Canonical HMAC-SHA256-pepper hash for a user_id (audit PII).

    Returns : 64-char hex digest of HMAC-SHA256(pepper, user_id.encode()).

    Raises : NotImplementedError until Plan 02-02 W1 (D-Q7) lands the
    pepper-load implementation. The signature is locked here so callers can
    be migrated piecewise without import-path drift.
    """
    raise NotImplementedError(
        "hmac_user_id() is a Plan 02-01 W0 stub. Real implementation "
        "(MINT_AUDIT_HMAC_PEPPER env load + HMAC-SHA256 + alembic backfill) "
        "lands in Plan 02-02 W1 (D-Q7). Until then, prefer direct migration "
        "of the call site OR keep using hashlib.sha256 with a baseline entry."
    )


def hmac_actor_email(actor_email: str) -> str:
    """Canonical HMAC-SHA256-pepper hash for an actor email (audit PII).

    Same stub contract as `hmac_user_id`. Real implementation in Plan 02-02 W1.
    """
    raise NotImplementedError(
        "hmac_actor_email() is a Plan 02-01 W0 stub — see hmac_user_id()."
    )
