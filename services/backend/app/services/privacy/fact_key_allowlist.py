"""Allowlist of fact_keys persisted to ``profile_facts``.

PRIV-06 — Phase 29.

Only the 8 keys listed below may be persisted. Any other key encountered
by ``document_memory_service.persist_fact`` is dropped with a hashed-key
log line. This enforces the data-minimisation principle of nLPD art. 6
al. 2 ("collection limited to the purpose").

Each key is mapped to:
    - a ``Purpose`` enum (projection / arbitrage / premier_eclairage)
      → cross-checked against the user's granular consents (PRIV-01).
    - a ``ttl_days`` integer or ``None`` (None = account-lifetime).
"""
from __future__ import annotations

from enum import Enum
from typing import Dict, Optional, TypedDict


class Purpose(str, Enum):
    """Purpose enum — must stay aligned with the consent purposes table."""
    PROJECTION = "projection"
    ARBITRAGE = "arbitrage"
    PREMIER_ECLAIRAGE = "premier_eclairage"
    LEGACY = "legacy"  # transition only; pre-29-03 rows during backfill


class FactKeyMeta(TypedDict):
    purpose: Purpose
    ttl_days: Optional[int]


# The 8 allowlisted keys. Source of truth — D-PRIV-06.
ALLOWED_FACT_KEYS: Dict[str, FactKeyMeta] = {
    "avoir_lpp":              {"purpose": Purpose.PROJECTION, "ttl_days": None},
    "salaire_assure":         {"purpose": Purpose.PROJECTION, "ttl_days": None},
    "taux_conversion_caisse": {"purpose": Purpose.ARBITRAGE,  "ttl_days": None},
    "avoir_3a":               {"purpose": Purpose.PROJECTION, "ttl_days": None},
    "rente_avs_projetee":     {"purpose": Purpose.PROJECTION, "ttl_days": None},
    "date_naissance":         {"purpose": Purpose.PROJECTION, "ttl_days": None},
    "canton_residence":       {"purpose": Purpose.PROJECTION, "ttl_days": None},
    "archetype":              {"purpose": Purpose.PREMIER_ECLAIRAGE, "ttl_days": None},
}


def is_allowed(fact_key: str) -> bool:
    """Return True iff ``fact_key`` may be persisted."""
    return fact_key in ALLOWED_FACT_KEYS


def purpose_of(fact_key: str) -> Optional[Purpose]:
    """Return the Purpose for a key, or None if not allowlisted."""
    meta = ALLOWED_FACT_KEYS.get(fact_key)
    return meta["purpose"] if meta else None


def ttl_days_of(fact_key: str) -> Optional[int]:
    """Return TTL (days) for a key, or None for account-lifetime/unknown."""
    meta = ALLOWED_FACT_KEYS.get(fact_key)
    return meta["ttl_days"] if meta else None


__all__ = [
    "ALLOWED_FACT_KEYS",
    "FactKeyMeta",
    "Purpose",
    "is_allowed",
    "purpose_of",
    "ttl_days_of",
]
