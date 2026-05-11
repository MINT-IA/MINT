"""Phase 95 DAG-INVALIDATION — deterministic input-hash computation.

Per CONTEXT D-01 + D-02 and RESEARCH §D-01 verbatim recipe :
- SHA256 hex of RFC 8785 canonical JSON (rfc8785 package, Trail of Bits).
- Floats quantized to Decimal(0.01) BEFORE canonicalisation to dodge
  IEEE 754 artifacts (0.1+0.2 = 0.30000000000000004).
- bool MUST be checked BEFORE int (Python bool subclass of int) — else
  True collapses to 1 in the canonical form.
- numpy.float64 cast via float() then re-quantized (D-02 edge case).
- NaN / inf / -inf raise ValueError — financial inputs MUST NOT be these.

Used by Wave 2 GroundingPack emitter + Wave 1 staleness derivation.
Module export contract :
- compute_inputs_hash(inputs: dict[str, Any]) -> str  (64-char hex)
- _quantize_floats(value: Any) -> Any                 (recursive walker)
"""
from __future__ import annotations

import hashlib
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

import rfc8785  # Trail of Bits, zero deps — preferred over stale jcs==0.2.1


def _quantize_floats(value: Any) -> Any:
    """Recursively quantize floats to Decimal(0.01). NaN/inf raise ValueError.

    Recursion order :
    1. dict -> recurse on values, preserve keys (rfc8785 sorts keys).
    2. list/tuple -> recurse, both serialise to JSON array (tuple -> list).
    3. bool -> return as-is (MUST precede int branch ; bool subset int in Python).
    4. int -> return as-is (no precision loss).
    5. float -> quantize via Decimal(str(v)).quantize(0.01, ROUND_HALF_UP).
    6. numpy.float64 or similar __float__-typed -> cast then recurse.
    7. str / None / fallback -> return as-is.
    """
    if isinstance(value, dict):
        return {k: _quantize_floats(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_quantize_floats(v) for v in value]
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if value != value:  # NaN check (NaN != NaN)
            raise ValueError("NaN not allowed in projection inputs")
        if value in (float("inf"), float("-inf")):
            raise ValueError("inf/-inf not allowed in projection inputs")
        q = Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        return float(q)
    if hasattr(value, "__float__") and not isinstance(value, (str, bytes)):
        return _quantize_floats(float(value))
    return value


def compute_inputs_hash(inputs: dict[str, Any]) -> str:
    """Return SHA256 hex of RFC 8785 canonical JSON of quantized inputs.

    Deterministic across runs and across Python<->Dart runtimes (validated
    by test_hash_parity.py against apps/mobile/tools/hash_parity_harness/).

    Args:
        inputs: dict to hash. Floats are quantized to 2 decimals. Keys
            are sorted lexically by rfc8785.dumps.

    Returns:
        64-char lowercase hex SHA256.

    Raises:
        ValueError: if any float value is NaN, inf, or -inf.
    """
    quantized = _quantize_floats(inputs)
    canonical = rfc8785.dumps(quantized)
    return hashlib.sha256(canonical).hexdigest()


__all__ = ["compute_inputs_hash", "_quantize_floats"]
