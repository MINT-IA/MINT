"""Canary fixture builders for D-25 + D-34 PROPOSED multi-shape parity gates.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 — P4 iter-2 A11.

Five canary shapes covering the value classes that PR-3 dual-write must
handle without parity drift :

  1. scalar float           — `monthly_gross_income` (the D-25 baseline)
  2. decimal-precision      — `pillar_3a_balance` (exact 2-decimal Decimal)
  3. nested JSONB           — `archetype_tags` (list[str] + nested confidence)
  4. nullable optional      — `lpp_avoirs_vieillesse` (None for users w/o LPP)
  5. multi-KB TOAST blob    — `coach_extracted_facts` (synthetic ≥4KB payload)

Each builder returns a `FactEventInput` ready for `project_event()` plus
a comparator value that the round-trip decryption MUST equal.

Per the actual fact_event schema landed in continuation-3 (user_id /
field_key / value_enc / valid_from), NOT the plan's nominal
subject_type/subject_id/fact_type sketch.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Tuple

from app.services.projector.fact_projector import FactEventInput


# ── Shape 1 : scalar float ───────────────────────────────────────────────

def build_scalar_canary(
    user_id: str,
    *,
    value: float = 8500.0,
    valid_from: datetime | None = None,
) -> Tuple[FactEventInput, float]:
    """Scalar float canary — D-25 baseline."""
    return (
        FactEventInput(
            user_id=user_id,
            field_key="monthly_gross_income",
            value_enc={},  # placeholder ; caller wraps via encrypt_value
            valid_from=valid_from or datetime.now(timezone.utc),
            source="canary_scalar",
        ),
        value,
    )


# ── Shape 2 : decimal-precision ──────────────────────────────────────────

def build_decimal_canary(
    user_id: str,
    *,
    valid_from: datetime | None = None,
) -> Tuple[FactEventInput, str]:
    """Decimal-precision canary — pillar_3a_balance Decimal(12345.67).

    Returned as the canonical-string form so round-trip-via-JSON does
    NOT silently coerce to float64 (TOAST'd Decimal precision loss risk).
    Caller responsible for `Decimal()`-comparing the decrypted plaintext.
    """
    decimal_str = "12345.67"
    return (
        FactEventInput(
            user_id=user_id,
            field_key="pillar_3a_balance",
            value_enc={},
            valid_from=valid_from or datetime.now(timezone.utc),
            source="canary_decimal",
        ),
        decimal_str,
    )


# ── Shape 3 : nested JSONB ───────────────────────────────────────────────

def build_jsonb_canary(
    user_id: str,
    *,
    valid_from: datetime | None = None,
) -> Tuple[FactEventInput, dict]:
    """Nested JSONB canary — archetype_tags list + nested confidence map."""
    payload = {
        "tags": ["expat_eu", "frontalier"],
        "confidence_per_tag": {
            "expat_eu": {"c": 0.8, "a": 0.9, "f": 1.0, "u": 0.7, "score": 0.85},
            "frontalier": {"c": 0.7, "a": 0.85, "f": 0.95, "u": 0.6, "score": 0.78},
        },
    }
    return (
        FactEventInput(
            user_id=user_id,
            field_key="archetype_tags",
            value_enc={},
            valid_from=valid_from or datetime.now(timezone.utc),
            source="canary_jsonb",
        ),
        payload,
    )


# ── Shape 4 : nullable ───────────────────────────────────────────────────

def build_nullable_canary(
    user_id: str,
    *,
    valid_from: datetime | None = None,
) -> Tuple[FactEventInput, Any]:
    """Nullable canary — lpp_avoirs_vieillesse encodes None as JSON null.

    The comparator IS `None` ; the encrypted envelope wraps the literal
    JSON `null` so decryption returns Python `None`. Parity check : the
    decrypted value MUST equal the comparator (None == None → True).
    """
    return (
        FactEventInput(
            user_id=user_id,
            field_key="lpp_avoirs_vieillesse",
            value_enc={},
            valid_from=valid_from or datetime.now(timezone.utc),
            source="canary_nullable",
        ),
        None,
    )


# ── Shape 5 : multi-KB TOAST blob ─────────────────────────────────────────

def build_toast_canary(
    user_id: str,
    *,
    blob_size_bytes: int = 4096,
    valid_from: datetime | None = None,
) -> Tuple[FactEventInput, dict]:
    """TOAST-eligible blob canary — synthetic coach_extracted_facts ≥4KB.

    Postgres TOAST threshold is ~2KB ; a 4KB payload pushes value_enc
    into the TOAST table and exercises the inline-vs-out-of-line storage
    path. SQLite has no TOAST analogue ; the test still passes (the
    parity contract is dialect-independent at the application layer).
    """
    long_string = "x" * blob_size_bytes
    payload = {
        "facts": [long_string],
        "_blob_size_bytes": blob_size_bytes,
    }
    return (
        FactEventInput(
            user_id=user_id,
            field_key="coach_extracted_facts",
            value_enc={},
            valid_from=valid_from or datetime.now(timezone.utc),
            source="canary_toast",
        ),
        payload,
    )


__all__ = [
    "build_scalar_canary",
    "build_decimal_canary",
    "build_jsonb_canary",
    "build_nullable_canary",
    "build_toast_canary",
]
