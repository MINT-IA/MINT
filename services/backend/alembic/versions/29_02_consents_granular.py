"""Granular consent receipts (ISO/IEC 29184:2020) — PRIV-01.

v2.7 Phase 29 / Plan 02.

Adds receipt / merkle-chain columns to the legacy `consents` table, adds a
composite index on (user_id, purpose_category, revoked_at), and backfills
legacy rows where `enabled = TRUE AND consent_type IS NOT NULL` into the new
shape using policy_version="v1.0.0-legacy" — triggers re-consent at next
upload because the current policy version will not match.

Revision ID: 29_02_consents_granular
Revises: 29_01_envelope_encryption
"""

revision = "29_02_consents_granular"
down_revision = "29_01_envelope_encryption"

import hashlib
import json
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa


LEGACY_POLICY_VERSION = "v1.0.0-legacy"


def upgrade():
    with op.batch_alter_table("consents") as batch:
        batch.add_column(sa.Column("receipt_id", sa.String(length=36), nullable=True))
        batch.add_column(sa.Column("purpose_category", sa.String(length=64), nullable=True))
        batch.add_column(sa.Column("policy_version", sa.String(length=32), nullable=True))
        batch.add_column(sa.Column("policy_hash", sa.String(length=64), nullable=True))
        batch.add_column(sa.Column("consent_timestamp", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("revoked_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("receipt_json", sa.JSON(), nullable=True))
        batch.add_column(sa.Column("prev_hash", sa.String(length=64), nullable=True))
        batch.add_column(sa.Column("signature", sa.String(length=64), nullable=True))
        # Legacy consent_type was NOT NULL in phase 23; relax so new rows can
        # omit it when written via the granular API only.
        batch.alter_column("consent_type", existing_type=sa.String(), nullable=True)

    # Index — SQLite cannot add an index inside batch_alter_table in our setup,
    # so create it separately (portable to Postgres too).
    op.create_index(
        "ix_consents_user_purpose",
        "consents",
        ["user_id", "purpose_category", "revoked_at"],
    )
    op.create_index(
        "ix_consents_receipt_id",
        "consents",
        ["receipt_id"],
        unique=True,
    )

    # --- Backfill legacy grants into granular shape --------------------------
    # Map legacy consent_type → one or more granular purposes (conservative).
    legacy_map = {
        # byok_data_sharing implied transfer to Anthropic
        "byok_data_sharing": ["transfer_us_anthropic"],
        # snapshot_storage implied persistence of parsed doc data
        "snapshot_storage": ["persistence_365d"],
        # notifications — no granular purpose (skipped)
    }

    conn = op.get_bind()
    # Only attempt backfill on backends that expose the legacy columns with
    # data. On a fresh install this is a no-op.
    rows = conn.execute(
        sa.text(
            "SELECT id, user_id, consent_type, enabled, updated_at "
            "FROM consents WHERE enabled = TRUE"
        )
    ).fetchall()

    policy_hash = hashlib.sha256(b"missing:v1.0.0-legacy").hexdigest()
    ts = datetime.now(timezone.utc).replace(microsecond=0).isoformat()

    for row in rows:
        legacy_id, user_id, consent_type, _enabled, _updated_at = row
        mapped = legacy_map.get((consent_type or "").lower(), [])
        if not mapped:
            continue
        for purpose in mapped:
            # Skip if already present (idempotent re-run guard)
            existing = conn.execute(
                sa.text(
                    "SELECT 1 FROM consents WHERE user_id = :uid "
                    "AND purpose_category = :p AND revoked_at IS NULL"
                ),
                {"uid": user_id, "p": purpose},
            ).first()
            if existing:
                continue
            receipt_id_legacy = f"legacy-{legacy_id}-{purpose}"
            receipt_json = {
                "receiptId": receipt_id_legacy,
                "piiPrincipalId": hashlib.sha256(str(user_id).encode("utf-8")).hexdigest(),
                "piiController": "MINT Finance SA",
                "purposeCategory": purpose,
                "policyUrl": f"https://mint.ch/privacy/{LEGACY_POLICY_VERSION}",
                "policyVersion": LEGACY_POLICY_VERSION,
                "policyHash": policy_hash,
                "consentTimestamp": ts,
                "jurisdiction": "CH",
                "lawfulBasis": "consent_nLPD_art_6_al_6",
                "revocationEndpoint": f"/api/v1/consents/{receipt_id_legacy}/revoke",
                "prevHash": None,
                "backfilled": True,
            }
            conn.execute(
                sa.text(
                    "INSERT INTO consents "
                    "(id, user_id, consent_type, enabled, updated_at, "
                    " receipt_id, purpose_category, policy_version, policy_hash, "
                    " consent_timestamp, receipt_json, prev_hash, signature) "
                    "VALUES (:id, :uid, :ct, 1, :upd, "
                    " :rid, :pc, :pv, :ph, :cts, :rj, NULL, :sig)"
                ),
                {
                    "id": f"{legacy_id}-{purpose}"[:36],
                    "uid": user_id,
                    "ct": consent_type,
                    "upd": ts,
                    "rid": receipt_id_legacy,
                    "pc": purpose,
                    "pv": LEGACY_POLICY_VERSION,
                    "ph": policy_hash,
                    "cts": ts,
                    "rj": json.dumps(receipt_json),
                    # Signature stays NULL for legacy rows → verify_chain
                    # will skip them (filters signature IS NOT NULL).
                    "sig": None,
                },
            )


def downgrade():
    op.drop_index("ix_consents_receipt_id", table_name="consents")
    op.drop_index("ix_consents_user_purpose", table_name="consents")
    with op.batch_alter_table("consents") as batch:
        batch.drop_column("signature")
        batch.drop_column("prev_hash")
        batch.drop_column("receipt_json")
        batch.drop_column("revoked_at")
        batch.drop_column("consent_timestamp")
        batch.drop_column("policy_hash")
        batch.drop_column("policy_version")
        batch.drop_column("purpose_category")
        batch.drop_column("receipt_id")
        batch.alter_column("consent_type", existing_type=sa.String(), nullable=False)
