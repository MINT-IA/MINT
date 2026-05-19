"""Pydantic-typed JSONB helpers around envelope.encrypt_bytes / decrypt_bytes.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-02 + D-26 + iter-2 B6.

`encrypt_value(db, user_id, value, *, source_type=None) -> dict` wraps
`envelope.encrypt_bytes` with:
  1. JSON canonical-form serialization (separators=(',',':'), sort_keys=True)
     so identical Python values produce identical byte arrays before encryption.
  2. (iter-2 B6) When source_type in {'coach_inference', 'user_input'},
     plaintext is scanned for LSFin banned terms; BannedTermsViolation raised
     before encryption (fail-closed at write time).
  3. base64 encoding of the (nonce || ciphertext || tag) blob into a
     D-26-shaped EncryptedValue dict (model_dump).

`decrypt_value(db, user_id, envelope) -> Any` is the inverse: validates the
envelope against the D-26 EncryptedValue model, base64-decodes, calls
envelope.decrypt_bytes (which checks AAD = user_id), JSON-decodes.

Why this wrapper exists (not just call encrypt_bytes directly)
==============================================================
- D-26 wire shape compliance: every `fact_event.value_enc` row MUST match
  the EncryptedValue Pydantic v2 schema. The wrapper guarantees that.
- Canonical JSON: two `encrypt_value(db, u, {"a":1,"b":2})` and
  `encrypt_value(db, u, {"b":2,"a":1})` calls produce ciphertexts that
  decrypt to the same Python dict. Bit-identical envelope bytes are NOT
  promised (nonces are random per write); recovered plaintexts ARE.
- DEK envelope reuse: NEVER call AESGCM() directly here (Karpathy #2 — reuse
  existing primitives). All crypto goes through `envelope.encrypt_bytes`
  which already enforces the AAD = user_id binding.
"""
from __future__ import annotations

import base64
import json
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models.encryption.encrypted_value import EncryptedValue
from app.services.encryption.banned_terms_runtime import (
    BannedTermsViolation,
    scan_value_for_banned_terms,
)
from app.services.encryption.envelope import (
    NONCE_SIZE_BYTES,
    decrypt_bytes,
    encrypt_bytes,
)

# Logical DEK id (D-02). Audit anchor; never the wrapping-key material itself.
LOGICAL_DEK_ID = "mint-master-v1"

# Source types that trigger iter-2 B6 runtime banned-terms scan.
_BANNED_TERMS_SCAN_SOURCES = frozenset({"coach_inference", "user_input"})


def encrypt_value(
    db: Session,
    user_id: str,
    value: Any,
    *,
    source_type: Optional[str] = None,
) -> dict:
    """Encrypt `value` (JSON-serializable) for `user_id`; return D-26 envelope dict.

    iter-2 B6: when source_type in {'coach_inference', 'user_input'}, the
    plaintext is scanned for LSFin banned terms via banned_terms_runtime
    BEFORE encryption. Raises BannedTermsViolation if any hit.
    """
    # iter-2 B6 — write-time gate (fail-closed for coach-narrator paths)
    if source_type in _BANNED_TERMS_SCAN_SOURCES:
        scan_value_for_banned_terms(value)

    # QA code-reviewer polish FLAG-3 (2026-05-19) : json.dumps without
    # default= crashes with bare TypeError when callers pass Decimal
    # (e.g. financial calculations). default=str coerces Decimal /
    # datetime / UUID to ISO string deterministically. The string-canonical
    # form is what the canary fixture (build_decimal_canary) already
    # serializes, so this matches the cross-tooling parity contract used
    # by tools/parity/projection_diff.py.
    plaintext_bytes = json.dumps(
        value, separators=(",", ":"), sort_keys=True, ensure_ascii=False,
        default=str,
    ).encode("utf-8")
    blob = encrypt_bytes(db, user_id, plaintext_bytes)
    # envelope.encrypt_bytes returns nonce(12) || ciphertext || tag(16)
    iv = blob[:NONCE_SIZE_BYTES]
    ct = blob[NONCE_SIZE_BYTES:]
    envelope = EncryptedValue(
        ct=base64.b64encode(ct).decode("ascii"),
        iv=base64.b64encode(iv).decode("ascii"),
        dek_id=LOGICAL_DEK_ID,
    )
    return envelope.model_dump()


def decrypt_value(db: Session, user_id: str, envelope: dict) -> Any:
    """Decrypt a D-26 envelope dict for `user_id`; return JSON-decoded value.

    Validates the envelope shape against EncryptedValue before decoding so
    a malformed JSONB row surfaces as a Pydantic ValidationError, NOT a
    binascii.Error mid-base64. AAD = user_id is enforced inside
    envelope.decrypt_bytes — cross-user decrypts fail authentication.
    """
    parsed = EncryptedValue.model_validate(envelope)
    iv = base64.b64decode(parsed.iv.encode("ascii"))
    ct = base64.b64decode(parsed.ct.encode("ascii"))
    plaintext = decrypt_bytes(db, user_id, iv + ct)
    return json.loads(plaintext.decode("utf-8"))


__all__ = [
    "encrypt_value",
    "decrypt_value",
    "LOGICAL_DEK_ID",
    "BannedTermsViolation",
]
