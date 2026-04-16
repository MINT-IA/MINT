"""Batch-encrypt document_memory.evidence_text / vision_raw into *_enc columns.

v2.7 Phase 29 / PRIV-04.

Idempotent, resumable, safe to re-run. Logic:

    for each (user_id) with at least one plaintext row in document_memory:
        ensure DEK exists (get_or_create_dek)
        for each plaintext row of that user (batch_size at a time):
            encrypt evidence_text → evidence_text_enc
            encrypt vision_raw    → vision_raw_enc
            verify round-trip (decrypt both and compare to plaintext)
            on verify success → NULL out plaintext columns, commit batch
            on verify failure → roll back batch, log, continue

CLI:
    python scripts/migrate_evidence_text_encrypt.py [--dry-run] [--batch-size N]

Log output is privacy-scrubbed: user counts, row counts, error reasons.
No user_ids, no IBANs, no evidence content.
"""
from __future__ import annotations

import argparse
import logging
import sys
from typing import Iterable, Tuple

from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.document_memory import DocumentMemory
from app.services.encryption.envelope import (
    encrypt_text,
    decrypt_text,
    EncryptionError,
)
from app.services.encryption.key_vault import key_vault, DEKRevokedError

logger = logging.getLogger("migrate_evidence_text_encrypt")


def _users_with_plaintext(db: Session) -> Iterable[str]:
    rows = (
        db.query(DocumentMemory.user_id)
        .filter(
            (DocumentMemory.evidence_text.isnot(None))
            | (DocumentMemory.vision_raw.isnot(None))
        )
        .distinct()
        .all()
    )
    return [r[0] for r in rows]


def _pending_rows_for_user(db: Session, user_id: str, limit: int):
    return (
        db.query(DocumentMemory)
        .filter(
            DocumentMemory.user_id == user_id,
            (DocumentMemory.evidence_text.isnot(None))
            | (DocumentMemory.vision_raw.isnot(None)),
        )
        .limit(limit)
        .all()
    )


def _encrypt_and_verify(
    db: Session,
    user_id: str,
    row: DocumentMemory,
) -> bool:
    pt_e = row.evidence_text
    pt_v = row.vision_raw
    enc_e = encrypt_text(db, user_id, pt_e) if pt_e is not None else None
    enc_v = encrypt_text(db, user_id, pt_v) if pt_v is not None else None
    # Round-trip verification before NULLing plaintext.
    if enc_e is not None and decrypt_text(db, user_id, bytes(enc_e)) != pt_e:
        return False
    if enc_v is not None and decrypt_text(db, user_id, bytes(enc_v)) != pt_v:
        return False
    row.evidence_text_enc = enc_e
    row.vision_raw_enc = enc_v
    row.evidence_text = None
    row.vision_raw = None
    return True


def migrate(dry_run: bool = False, batch_size: int = 500) -> Tuple[int, int, int]:
    """Returns (users_scanned, rows_migrated, rows_failed)."""
    db = SessionLocal()
    users = 0
    rows_migrated = 0
    rows_failed = 0
    try:
        uids = list(_users_with_plaintext(db))
        logger.info("scan: %d user(s) with plaintext rows", len(uids))
        for uid in uids:
            users += 1
            if not dry_run:
                try:
                    key_vault.get_or_create_dek(db, uid)
                except DEKRevokedError:
                    logger.warning("skip user: DEK revoked")
                    continue
            while True:
                rows = _pending_rows_for_user(db, uid, batch_size)
                if not rows:
                    break
                if dry_run:
                    rows_migrated += len(rows)
                    break
                ok_in_batch = 0
                for row in rows:
                    try:
                        if _encrypt_and_verify(db, uid, row):
                            ok_in_batch += 1
                        else:
                            rows_failed += 1
                    except (EncryptionError, DEKRevokedError) as exc:
                        logger.warning("encrypt failed: %s", exc)
                        rows_failed += 1
                try:
                    db.commit()
                    rows_migrated += ok_in_batch
                except Exception as exc:
                    db.rollback()
                    logger.error("batch commit failed: %s", exc)
                    rows_failed += ok_in_batch
                    break
                if len(rows) < batch_size:
                    break
    finally:
        db.close()
    logger.info(
        "done: users=%d rows_migrated=%d rows_failed=%d dry_run=%s",
        users, rows_migrated, rows_failed, dry_run,
    )
    return users, rows_migrated, rows_failed


def _main() -> int:
    parser = argparse.ArgumentParser(
        description="Encrypt document_memory plaintext into *_enc columns (v2.7 PRIV-04)."
    )
    parser.add_argument("--dry-run", action="store_true", help="Count only, do not mutate.")
    parser.add_argument("--batch-size", type=int, default=500)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )

    users, migrated, failed = migrate(dry_run=args.dry_run, batch_size=args.batch_size)
    print(f"users={users} migrated={migrated} failed={failed} dry_run={args.dry_run}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(_main())
