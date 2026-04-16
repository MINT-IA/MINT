"""EncryptedBytes — SQLAlchemy TypeDecorator for transparent encryption.

v2.7 Phase 29 / PRIV-04.

Stores AES-256-GCM envelope ciphertext in a LargeBinary / BYTEA column.
`process_bind_param` encrypts on write; `process_result_value` decrypts on
read. Both need (user_id, db_session) from the current request — surfaced
via two ContextVars set by `app.middleware.encryption_context.EncryptionContextMiddleware`.

    current_user_id  → str   (required for any bind/result value)
    current_db_session → Session (required to unwrap the DEK)

If either ContextVar is unset (e.g. raw SQLAlchemy script or worker without
setup), the decorator raises `EncryptionContextMissing` on bind/result —
loudly by design: silently storing plaintext would break the at-rest
guarantee.

Callers who want to set the columns explicitly (e.g. migration batch)
can bypass the TypeDecorator by writing the raw bytes produced by
`envelope.encrypt_bytes(db, user_id, plaintext)` directly — the column
happily accepts pre-encrypted bytes because the TypeDecorator short-circuits
on bytes that already look like envelope blobs? No: the decorator always
encrypts on bind. For raw-byte writes the caller should use a separate
column or set the ContextVars. Simpler alternative: service code calls
encrypt_bytes / decrypt_bytes explicitly and stores into a plain
LargeBinary column — which is what `document_memory_service` does in
this plan.

We still ship EncryptedBytes for future adopters + for tests that prove
the contract works end-to-end.
"""
from __future__ import annotations

import contextvars
from typing import Any, Optional

from sqlalchemy import LargeBinary
from sqlalchemy.types import TypeDecorator

# Second ContextVar (paired with current_user_id in key_vault) holding the
# active DB session for the request.
current_db_session: contextvars.ContextVar[Optional[Any]] = contextvars.ContextVar(
    "mint_current_db_session",
    default=None,
)


class EncryptionContextMissing(RuntimeError):
    """Raised when EncryptedBytes is used outside an encryption context."""


class EncryptedBytes(TypeDecorator):
    """BYTEA column with transparent AES-256-GCM envelope encryption."""

    impl = LargeBinary
    cache_ok = True

    def process_bind_param(self, value: Optional[bytes], dialect) -> Optional[bytes]:
        if value is None:
            return None
        if not isinstance(value, (bytes, bytearray)):
            raise TypeError(
                f"EncryptedBytes expects bytes, got {type(value).__name__}"
            )
        from app.services.encryption.envelope import encrypt_bytes
        from app.services.encryption.key_vault import current_user_id

        uid = current_user_id.get()
        db = current_db_session.get()
        if uid is None or db is None:
            raise EncryptionContextMissing(
                "EncryptedBytes bind requires current_user_id + current_db_session "
                "ContextVars to be set (see app.middleware.encryption_context)"
            )
        return encrypt_bytes(db, uid, bytes(value))

    def process_result_value(self, value: Optional[bytes], dialect) -> Optional[bytes]:
        if value is None:
            return None
        from app.services.encryption.envelope import decrypt_bytes
        from app.services.encryption.key_vault import current_user_id

        uid = current_user_id.get()
        db = current_db_session.get()
        if uid is None or db is None:
            raise EncryptionContextMissing(
                "EncryptedBytes result requires current_user_id + current_db_session "
                "ContextVars to be set"
            )
        return decrypt_bytes(db, uid, bytes(value))


__all__ = ["EncryptedBytes", "current_db_session", "EncryptionContextMissing"]
