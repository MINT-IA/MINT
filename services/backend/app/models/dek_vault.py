"""DEKVault ORM — per-user Data Encryption Key storage (wrapped by MK).

v2.7 Phase 29 / PRIV-04.

One row per user. `wrapped_dek` holds the DEK encrypted by the Master Key
(KMS or Fernet MINT_MASTER_KEY fallback). Destroying `wrapped_dek`
(crypto-shredding) permanently renders every encrypted blob of that user
unreadable — even on Railway WAL backups — without mutating the blobs.

Deliberately in `app/models/` (project convention), not `app/db/models/`.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    LargeBinary,
    String,
)

from app.core.database import Base


class DEKVault(Base):
    """Per-user wrapped Data Encryption Key."""

    __tablename__ = "dek_vault"

    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    # Nullable because crypto_shred_user() sets it to NULL; revoked_at stays
    # as the audit trail of destruction.
    wrapped_dek = Column(LargeBinary, nullable=True)
    kms_key_ref = Column(String(256), nullable=True)
    algo = Column(String(32), nullable=False, default="AES-256-GCM")
    created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    rotated_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)
