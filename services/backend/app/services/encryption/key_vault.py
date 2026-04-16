"""KeyVaultService — Master Key wrap/unwrap + per-user DEK lifecycle.

v2.7 Phase 29 / PRIV-04.

Two MK backends, selected automatically:
    1. AWS KMS — used when `MINT_KMS_KEY_ID` env var is set (Railway prod path).
       boto3 is imported lazily so dev/CI can skip the dependency.
    2. Fernet self-managed — fallback when `MINT_KMS_KEY_ID` is absent.
       Uses `MINT_MASTER_KEY` env var (urlsafe base64 32-byte key). If unset,
       a volatile process-local key is generated on import (tests / local dev
       only — production MUST provide the env var or KMS will be selected).

Operations:
    - wrap_dek(plaintext_dek) -> bytes        : MK-encrypted blob
    - unwrap_dek(wrapped) -> bytes            : recovers plaintext DEK
    - get_or_create_dek(db, user_id) -> bytes : idempotent, inserts dek_vault row
    - revoke_dek(db, user_id) / crypto_shred_user(db, user_id) : destroy DEK

Every decryption path checks `dek_vault.revoked_at` first. If non-null or
`wrapped_dek IS NULL` → raises `DEKRevokedError`. The ciphertext blobs in
other tables remain untouched (still present on backups) but are now
cryptographically irrecoverable — that is the crypto-shredding guarantee
validated by PFPDT (Infomaniak 2024 opinion).
"""
from __future__ import annotations

import base64
import contextvars
import logging
import os
import secrets
from datetime import datetime, timezone
from typing import Optional

from cryptography.fernet import Fernet, InvalidToken

logger = logging.getLogger(__name__)


# ContextVar set per-request by encryption middleware, consumed by
# EncryptedBytes TypeDecorator. Background jobs MUST set it explicitly.
current_user_id: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar(
    "mint_current_user_id",
    default=None,
)


class DEKRevokedError(Exception):
    """Raised when a user's DEK has been crypto-shredded or is missing."""


class KeyVaultServiceError(Exception):
    """Generic key vault failure (MK unavailable, wrap/unwrap mismatch)."""


# ---------------------------------------------------------------------------
# Master Key backends
# ---------------------------------------------------------------------------

def _fernet_from_env() -> Fernet:
    """Build a Fernet instance from MINT_MASTER_KEY env, or generate volatile.

    MINT_MASTER_KEY must be urlsafe base64 (44 chars, 32 decoded bytes).
    Missing-env path is DEV ONLY — logs a WARNING on first use.
    """
    raw = os.environ.get("MINT_MASTER_KEY")
    if raw:
        try:
            # Validate: Fernet requires exactly 32 decoded bytes.
            decoded = base64.urlsafe_b64decode(raw.encode("ascii"))
            if len(decoded) != 32:
                raise ValueError("MINT_MASTER_KEY must decode to 32 bytes")
            return Fernet(raw.encode("ascii"))
        except (ValueError, TypeError, InvalidToken) as exc:
            logger.error("key_vault: MINT_MASTER_KEY invalid (%s) — refusing", exc)
            raise KeyVaultServiceError("MINT_MASTER_KEY invalid") from exc

    # Volatile process-local key — acceptable only when TESTING=1 or no prod.
    if os.environ.get("TESTING") != "1" and os.environ.get("MINT_ALLOW_VOLATILE_MK") != "1":
        logger.warning(
            "key_vault: MINT_MASTER_KEY not set and TESTING!=1 — refusing "
            "to generate a volatile key in production."
        )
        raise KeyVaultServiceError(
            "No MK configured: set MINT_MASTER_KEY or MINT_KMS_KEY_ID"
        )
    generated = Fernet.generate_key()
    logger.warning(
        "key_vault: using volatile Fernet key (TESTING mode) — DO NOT USE IN PROD"
    )
    return Fernet(generated)


class _FernetBackend:
    """Self-managed Fernet MK. Wraps/unwraps are symmetric (AES-128-CBC+HMAC)."""

    def __init__(self) -> None:
        self._fernet = _fernet_from_env()
        self.key_ref = "fernet:env:MINT_MASTER_KEY"

    def wrap(self, dek: bytes) -> bytes:
        return self._fernet.encrypt(dek)

    def unwrap(self, wrapped: bytes) -> bytes:
        try:
            return self._fernet.decrypt(wrapped)
        except InvalidToken as exc:
            raise KeyVaultServiceError("DEK unwrap failed: invalid token") from exc


class _KMSBackend:
    """AWS KMS MK (imported lazily so boto3 is optional locally)."""

    def __init__(self, key_id: str, region: Optional[str] = None) -> None:
        try:
            import boto3  # type: ignore
        except ImportError as exc:  # pragma: no cover
            raise KeyVaultServiceError(
                "MINT_KMS_KEY_ID set but boto3 is not installed"
            ) from exc
        self._client = boto3.client("kms", region_name=region or os.environ.get("AWS_REGION"))
        self._key_id = key_id
        self.key_ref = f"kms:{key_id}"

    def wrap(self, dek: bytes) -> bytes:  # pragma: no cover (requires AWS)
        resp = self._client.encrypt(KeyId=self._key_id, Plaintext=dek)
        return resp["CiphertextBlob"]

    def unwrap(self, wrapped: bytes) -> bytes:  # pragma: no cover (requires AWS)
        resp = self._client.decrypt(KeyId=self._key_id, CiphertextBlob=wrapped)
        return resp["Plaintext"]


def _select_backend():
    kms_key = os.environ.get("MINT_KMS_KEY_ID")
    if kms_key:
        try:
            return _KMSBackend(kms_key)
        except KeyVaultServiceError as exc:
            logger.warning("key_vault: KMS backend unavailable (%s) → fallback Fernet", exc)
    return _FernetBackend()


# ---------------------------------------------------------------------------
# KeyVaultService
# ---------------------------------------------------------------------------

class KeyVaultService:
    """Facade over MK backend + DEKVault ORM row lifecycle.

    In-process DEK cache (plaintext) keyed by user_id. Cache is cleared by
    revoke_dek so shredded users cannot decrypt via stale cache entries.
    """

    DEK_SIZE_BYTES = 32  # AES-256

    def __init__(self) -> None:
        self._backend = None  # lazy — avoids import-time env read failures
        self._dek_cache: dict[str, bytes] = {}

    def _get_backend(self):
        if self._backend is None:
            self._backend = _select_backend()
        return self._backend

    # Reset hook — used by tests that rotate MINT_MASTER_KEY between cases.
    def reset(self) -> None:
        self._backend = None
        self._dek_cache.clear()

    # -- Wrap / unwrap raw bytes --------------------------------------------
    def wrap_dek(self, dek: bytes) -> bytes:
        return self._get_backend().wrap(dek)

    def unwrap_dek(self, wrapped: bytes) -> bytes:
        return self._get_backend().unwrap(wrapped)

    @property
    def key_ref(self) -> str:
        return self._get_backend().key_ref

    # -- DEK lifecycle ------------------------------------------------------
    def _generate_dek(self) -> bytes:
        return secrets.token_bytes(self.DEK_SIZE_BYTES)

    def get_or_create_dek(self, db, user_id: str) -> bytes:
        """Return plaintext DEK for user. Generate + persist if absent.

        Raises DEKRevokedError if a row exists but wrapped_dek is NULL or
        revoked_at is set (crypto-shredded).
        """
        cached = self._dek_cache.get(user_id)
        if cached is not None:
            return cached

        from app.models.dek_vault import DEKVault  # local import to dodge cycles

        row: Optional[DEKVault] = (
            db.query(DEKVault).filter(DEKVault.user_id == user_id).one_or_none()
        )

        if row is not None:
            if row.revoked_at is not None or row.wrapped_dek is None:
                raise DEKRevokedError(
                    f"DEK for user {user_id} was revoked at {row.revoked_at}"
                )
            dek = self.unwrap_dek(bytes(row.wrapped_dek))
            self._dek_cache[user_id] = dek
            return dek

        # Create
        dek = self._generate_dek()
        wrapped = self.wrap_dek(dek)
        row = DEKVault(
            user_id=user_id,
            wrapped_dek=wrapped,
            kms_key_ref=self.key_ref,
            algo="AES-256-GCM",
            created_at=datetime.now(timezone.utc),
        )
        db.add(row)
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise
        self._dek_cache[user_id] = dek
        return dek

    def get_dek(self, db, user_id: str) -> bytes:
        """Read-only: fetch DEK. Raises DEKRevokedError if shredded/missing."""
        cached = self._dek_cache.get(user_id)
        if cached is not None:
            return cached

        from app.models.dek_vault import DEKVault

        row: Optional[DEKVault] = (
            db.query(DEKVault).filter(DEKVault.user_id == user_id).one_or_none()
        )
        if row is None:
            raise DEKRevokedError(f"No DEK exists for user {user_id}")
        if row.revoked_at is not None or row.wrapped_dek is None:
            raise DEKRevokedError(
                f"DEK for user {user_id} was revoked at {row.revoked_at}"
            )
        dek = self.unwrap_dek(bytes(row.wrapped_dek))
        self._dek_cache[user_id] = dek
        return dek

    def revoke_dek(self, db, user_id: str) -> bool:
        """Destroy the user's DEK — crypto-shredding.

        Sets wrapped_dek = NULL and revoked_at = NOW(). Idempotent.
        Clears in-process cache so subsequent reads cannot use stale DEK.
        """
        from app.models.dek_vault import DEKVault

        row: Optional[DEKVault] = (
            db.query(DEKVault).filter(DEKVault.user_id == user_id).one_or_none()
        )
        # Always purge cache first — even if DB write fails we do not want a
        # stale DEK still decrypting in the current process.
        self._dek_cache.pop(user_id, None)
        if row is None:
            return False
        row.wrapped_dek = None
        row.revoked_at = datetime.now(timezone.utc)
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise
        return True

    # Alias for explicit API use
    def crypto_shred_user(self, db, user_id: str) -> bool:
        return self.revoke_dek(db, user_id)


# Process-wide singleton (thread-safe: stateless apart from cache which is
# keyed by user_id and written only under single-threaded request handlers).
key_vault = KeyVaultService()
