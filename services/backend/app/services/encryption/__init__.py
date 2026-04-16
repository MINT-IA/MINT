"""Envelope encryption package for evidence_text/vision_raw at rest.

v2.7 Phase 29 / PRIV-04.

Per-user Data Encryption Key (DEK), wrapped by a Master Key (MK).
MK lives in AWS KMS (prod) or is derived from env `MINT_MASTER_KEY` (dev/CI).

Public surface:
    - KeyVaultService (wrap/unwrap, crypto_shred_user, get_or_create_dek)
    - encrypt_bytes / decrypt_bytes (envelope ops with per-write nonce)
    - EncryptedBytes (SQLAlchemy TypeDecorator for BYTEA columns)
    - current_user_id ContextVar (set by middleware, consumed by EncryptedBytes)
    - DEKRevokedError
"""
from app.services.encryption.key_vault import (
    KeyVaultService,
    DEKRevokedError,
    key_vault,
    current_user_id,
)
from app.services.encryption.envelope import encrypt_bytes, decrypt_bytes
from app.services.encryption.column_type import EncryptedBytes

__all__ = [
    "KeyVaultService",
    "DEKRevokedError",
    "key_vault",
    "current_user_id",
    "encrypt_bytes",
    "decrypt_bytes",
    "EncryptedBytes",
]
