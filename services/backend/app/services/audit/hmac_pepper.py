"""Canonical entry for audit-PII HMAC-SHA256-pepper hashing.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-07 / D-14 / D-15 / D-24.

Real implementation (replaces the Plan 02-01 W0 stub that raised
`NotImplementedError`). All audit-PII writes (`audit_events.user_id_hash`,
`audit_events.actor_email_hash`, `audit_events.ip_address_hash`,
`audit_events.user_agent_hash`, `projection_audit_records.user_id_hash`)
MUST go through this single entry. `tools/checks/hmac_pepper_audit.py`
HARD lefthook (Plan 02-01 D-24) rejects bare `hashlib.sha256(user_id|
actor_email|ip_address|user_agent)` outside this allowlisted module.

Why HMAC-with-pepper instead of bare SHA-256
============================================
The audit table is a rainbow-table target. An attacker with a DB dump
+ knowledge of common email shapes / user-id formats can pre-compute
`sha256(email)` for millions of plausible inputs and reverse the hash
column. Adding a server-only secret pepper to the hash makes pre-computation
infeasible — an attacker needs (a) the dump AND (b) the pepper bytes from
Railway's secret store, which is a substantially stronger threat model.

Why fail-closed instead of fail-open on missing pepper
======================================================
Per D-07 + D-14, a production deploy without `MINT_AUDIT_HASH_PEPPER` set
would silently degrade to either bare-SHA-256 (rainbow-vulnerable) or
plaintext (PII residency violation). Both are worse than refusing to boot.
The `PepperNotConfigured` exception forces the deploy to fail loudly.

TESTING=1 escape hatch
======================
The test suite cannot require operators to set a real pepper in every CI
job. When `TESTING=1` AND `MINT_AUDIT_HASH_PEPPER` is unset, this module
falls back to a fixed test-pepper. The test-pepper is NOT a real secret
and MUST NOT be relied upon in production. The Railway production +
staging envs ALWAYS have `MINT_AUDIT_HASH_PEPPER` set to a
`secrets.token_urlsafe(48)` value (verified Julien Plan 02-02 Task 1
checkpoint procedure 2026-05-18).
"""
from __future__ import annotations

import hmac
import os
from functools import lru_cache
from hashlib import sha256
from typing import Optional


class PepperNotConfigured(RuntimeError):
    """Raised when `MINT_AUDIT_HASH_PEPPER` is missing or too short.

    Production deploys MUST set this env var to a ≥32-char value
    (recommend `secrets.token_urlsafe(48)` which yields ~64 chars).
    Outside `TESTING=1`, refusing to boot is the correct behaviour.
    """


_MIN_PEPPER_LEN = 32
# Test-pepper used ONLY when TESTING=1 AND MINT_AUDIT_HASH_PEPPER is unset.
# This is a fixed-string constant — NOT a secret — so the test suite produces
# deterministic hashes across runs. It is intentionally NOT loaded from any
# env var so it cannot accidentally be promoted to prod via env-var typo.
_TEST_PEPPER = (
    "mint-test-pepper-do-not-use-in-prod-32chars-min-padding-padding"
)


@lru_cache(maxsize=1)
def _get_pepper() -> bytes:
    """Resolve the pepper bytes from env (fail-closed) or TESTING fallback.

    `lru_cache` makes the env read a one-shot per process — env-var rotation
    requires a restart (which Railway provides on `railway variables set`).
    Tests that need to flip env vars MUST call `_get_pepper.cache_clear()`
    before and after the monkeypatch block.
    """
    raw = os.environ.get("MINT_AUDIT_HASH_PEPPER", "").strip()
    if raw and len(raw) >= _MIN_PEPPER_LEN:
        return raw.encode("utf-8")
    # Fall back to test-pepper ONLY in TESTING mode
    if os.environ.get("TESTING") == "1":
        return _TEST_PEPPER.encode("utf-8")
    raise PepperNotConfigured(
        f"MINT_AUDIT_HASH_PEPPER is unset or shorter than {_MIN_PEPPER_LEN} chars. "
        "Set it on Railway to a `python3 -c 'import secrets; "
        "print(secrets.token_urlsafe(48))'` value, or set TESTING=1 for the test suite."
    )


def hmac_pii(value: Optional[str]) -> Optional[str]:
    """Canonical HMAC-SHA256-pepper hash for any audit-PII string.

    Returns 64-char lowercase hex digest. None input → None output (caller
    passes optional fields like `user.id` which can be NULL on anonymous
    sessions).
    """
    if value is None:
        return None
    return hmac.new(_get_pepper(), value.encode("utf-8"), sha256).hexdigest()


def hmac_user_id(user_id: Optional[str]) -> Optional[str]:
    """Canonical HMAC for `audit_events.user_id_hash` + `projection_audit_records.user_id_hash`.

    D-14: replaces bare `hashlib.sha256(user_id)` from the Hotfix C migration.
    Hashes are domain-uniform (see hmac_pii docstring) so cross-table joins
    by hash still work for LSFin compliance reports.
    """
    return hmac_pii(user_id)


def hmac_actor_email(actor_email: Optional[str]) -> Optional[str]:
    """Canonical HMAC for `audit_events.actor_email_hash` (D-15)."""
    return hmac_pii(actor_email)


__all__ = [
    "PepperNotConfigured",
    "hmac_pii",
    "hmac_user_id",
    "hmac_actor_email",
]
