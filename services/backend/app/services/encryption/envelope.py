"""AES-256-GCM envelope encryption using per-user DEK.

v2.7 Phase 29 / PRIV-04.

Wire format (opaque to callers):

    | nonce (12 bytes, random per write) | ciphertext | GCM tag (16 bytes, appended) |

`AESGCM.encrypt()` in `cryptography` produces `ciphertext || tag`, so the
blob written to DB is exactly `nonce || AESGCM.encrypt(...)`.

Nonce is 12 random bytes (NIST SP 800-38D). Random 96-bit nonces are safe
for < 2^32 writes per key — far beyond single-user volume. The DEK is
per-user, so nonce reuse risk is strictly bounded by the user's own
write rate.

Never reuse a (DEK, nonce) pair. `secrets.token_bytes(12)` is used every
encrypt call. Test suite asserts uniqueness over 10k writes.
"""
from __future__ import annotations

import secrets
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.services.encryption.key_vault import key_vault, DEKRevokedError

NONCE_SIZE_BYTES = 12  # GCM standard


class EncryptionError(Exception):
    """Raised when encrypt/decrypt fails for non-revocation reasons."""


def encrypt_bytes(db, user_id: str, plaintext: bytes) -> bytes:
    """Encrypt `plaintext` under the user's DEK. Returns nonce||ct||tag.

    Raises DEKRevokedError if the user's DEK has been crypto-shredded.
    """
    if plaintext is None:
        raise ValueError("plaintext cannot be None (use empty bytes for empty payload)")
    if not isinstance(plaintext, (bytes, bytearray)):
        raise TypeError(f"plaintext must be bytes, got {type(plaintext).__name__}")

    dek = key_vault.get_or_create_dek(db, user_id)
    aes = AESGCM(dek)
    nonce = secrets.token_bytes(NONCE_SIZE_BYTES)
    # associated_data binds ciphertext to the user — swapping rows across
    # users fails authentication (threat T-29-02).
    aad = user_id.encode("utf-8")
    ct = aes.encrypt(nonce, bytes(plaintext), aad)
    return nonce + ct


def decrypt_bytes(db, user_id: str, blob: bytes) -> bytes:
    """Decrypt an envelope blob produced by `encrypt_bytes` for the same user.

    Raises DEKRevokedError if the DEK has been shredded.
    Raises EncryptionError on any other failure (blob too short, tag mismatch).
    """
    if blob is None:
        raise ValueError("blob cannot be None")
    if len(blob) < NONCE_SIZE_BYTES + 16:  # nonce + minimum tag
        raise EncryptionError("Ciphertext blob too short")

    # get_dek — do NOT auto-create here; a decrypt against a missing DEK
    # is a logical bug, not a first-write.
    dek = key_vault.get_dek(db, user_id)
    aes = AESGCM(dek)
    nonce = bytes(blob[:NONCE_SIZE_BYTES])
    ct = bytes(blob[NONCE_SIZE_BYTES:])
    aad = user_id.encode("utf-8")
    try:
        return aes.decrypt(nonce, ct, aad)
    except Exception as exc:  # InvalidTag etc.
        raise EncryptionError(f"AES-GCM decrypt failed: {exc}") from exc


def encrypt_text(db, user_id: str, text: Optional[str]) -> Optional[bytes]:
    """Convenience: utf-8 encode + encrypt. Returns None for None input."""
    if text is None:
        return None
    return encrypt_bytes(db, user_id, text.encode("utf-8"))


def decrypt_text(db, user_id: str, blob: Optional[bytes]) -> Optional[str]:
    """Convenience: decrypt + utf-8 decode. Returns None for None input."""
    if blob is None:
        return None
    return decrypt_bytes(db, user_id, bytes(blob)).decode("utf-8")


__all__ = [
    "encrypt_bytes",
    "decrypt_bytes",
    "encrypt_text",
    "decrypt_text",
    "EncryptionError",
    "DEKRevokedError",
    "NONCE_SIZE_BYTES",
]
