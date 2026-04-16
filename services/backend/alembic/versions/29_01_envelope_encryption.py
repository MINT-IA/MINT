"""Envelope encryption — dek_vault table + encrypted columns on document_memory.

v2.7 Phase 29 / PRIV-04.

Creates:
    - dek_vault (user_id PK FK users.id, wrapped_dek BYTEA NULL, kms_key_ref,
      algo, created_at, rotated_at NULL, revoked_at NULL)
    - document_memory.evidence_text      TEXT NULL    (plaintext, legacy read)
    - document_memory.evidence_text_enc  BYTEA NULL   (AES-256-GCM envelope)
    - document_memory.vision_raw         TEXT NULL    (plaintext, legacy read)
    - document_memory.vision_raw_enc     BYTEA NULL   (AES-256-GCM envelope)

Plaintext columns stay nullable for the backward-compat window. A later
migration will drop them once the batch encryption script has migrated
every row.

Revision ID: 29_01_envelope_encryption
Revises: p28_document_memory
"""

revision = "29_01_envelope_encryption"
down_revision = "p28_document_memory"

from alembic import op
import sqlalchemy as sa


def upgrade():
    # 1) dek_vault
    op.create_table(
        "dek_vault",
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
            nullable=False,
        ),
        sa.Column("wrapped_dek", sa.LargeBinary(), nullable=True),
        sa.Column("kms_key_ref", sa.String(length=256), nullable=True),
        sa.Column(
            "algo",
            sa.String(length=32),
            nullable=False,
            server_default="AES-256-GCM",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("rotated_at", sa.DateTime(), nullable=True),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
    )

    # 2) document_memory plaintext + encrypted columns (all nullable)
    with op.batch_alter_table("document_memory") as batch:
        batch.add_column(sa.Column("evidence_text", sa.Text(), nullable=True))
        batch.add_column(sa.Column("evidence_text_enc", sa.LargeBinary(), nullable=True))
        batch.add_column(sa.Column("vision_raw", sa.Text(), nullable=True))
        batch.add_column(sa.Column("vision_raw_enc", sa.LargeBinary(), nullable=True))


def downgrade():
    with op.batch_alter_table("document_memory") as batch:
        batch.drop_column("vision_raw_enc")
        batch.drop_column("vision_raw")
        batch.drop_column("evidence_text_enc")
        batch.drop_column("evidence_text")
    op.drop_table("dek_vault")
