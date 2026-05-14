"""Wave 1a D-15 — hashing helpers for coach observability.

Distinct from `app.services.coach.inputs_hash.compute_inputs_hash` which
hashes a profile SLICE (the minimal fields a tool reads). `hash_profile_id`
hashes the profile_id itself for non-PII Sentry breadcrumb payloads.
"""
from __future__ import annotations

import hashlib


def hash_profile_id(profile_id: str) -> str:
    """First 16 hex chars of SHA-256(profile_id).

    Used as the non-PII profile identifier in coach Sentry breadcrumbs
    (D-15). 16 chars = 64 bits of entropy — collision-safe at MINT scale
    and irreversible (cannot recover profile_id from the prefix).

    Distinct from `app.services.coach.inputs_hash.compute_inputs_hash`,
    which hashes a profile SLICE (the minimal fields a tool reads), not
    the profile_id string.
    """
    return hashlib.sha256(profile_id.encode("utf-8")).hexdigest()[:16]
