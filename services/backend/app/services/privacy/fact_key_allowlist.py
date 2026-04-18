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
    "SAFE_LOG_FACT_KEYS",
    "is_safe_to_log",
]


# ---------------------------------------------------------------------------
# Save_fact log redaction allowlist (deny-by-default)
#
# Scope: the save_fact coach tool writes 40+ typed facts into ProfileModel.data.
# Logging raw values of financial facts leaks PII (CLAUDE.md §6.7, nLPD art. 4).
# Any fact_key NOT in this set is redacted to "[REDACTED]" in log lines AND in
# the tool return string forwarded back to the LLM.
#
# Rationale for inclusion: only structural/categorical or non-identifying
# markers. Numeric amounts (salary, balances, debt), contribution counts that
# reveal wealth, and household-linked amounts are excluded.
#
# Sources of keys: coach_tools.COACH_TOOLS['save_fact'].input_schema.enum.
# Adversarial panel 2026-04-18 (agent a39aa3c1db57f30a0) mandated deny-by-default
# to prevent silent leaks when new enum values are introduced.
# ---------------------------------------------------------------------------
SAFE_LOG_FACT_KEYS: frozenset[str] = frozenset({
    # Categorical low-entropy identifiers (no re-identification risk alone)
    "canton",              # 26 values
    "householdType",       # 3-4 values (single/couple/concubinage/famille)
    "employmentStatus",    # 3-4 values (salarie/independant/chomeur/retraite)
    "gender",              # 2-3 values
    "goal",                # small enum
    # Booleans (binary, no PII)
    "has2ndPillar",
    "hasVoluntaryLpp",
    "hasDebt",
    "hasAvsGaps",
    # Ratios / small-range integers (low entropy, no re-identification)
    "employmentRate",      # 0-100 percentage
    "targetRetirementAge", # 58-70 range
    # NOTE: birthYear, dateOfBirth, commune, avsContributionYears,
    # spouseBirthYear, spouseAvsContributionYears are NOT in this set —
    # they are quasi-identifiers under nLPD art. 4 (combined with canton
    # they approach uniqueness). All numeric financial amounts (salary,
    # avoirLpp, pillar3aBalance, totalDebt, savingsMonthly, etc.) are
    # excluded by default.
})


def is_safe_to_log(fact_key: str) -> bool:
    """Return True iff the raw value of ``fact_key`` may appear in logs or
    tool-return strings. Deny-by-default: unknown keys return False.

    Used by save_fact handler to decide whether to redact the value before
    logging or before echoing it back to the LLM in the tool result.
    """
    return fact_key in SAFE_LOG_FACT_KEYS
