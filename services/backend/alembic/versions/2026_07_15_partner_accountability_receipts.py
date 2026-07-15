"""Create the isolated G1 BND-02A partner-accountability receipt store.

Revision ID: g1_bnd02a_receipts
Revises: 29_05_magic_link_tokens
"""

from alembic import op
import sqlalchemy as sa


revision = "g1_bnd02a_receipts"
down_revision = "29_05_magic_link_tokens"

_TABLE = "partner_accountability_receipts"


def upgrade() -> None:
    bind = op.get_bind()
    if _TABLE in sa.inspect(bind).get_table_names():
        return
    op.create_table(
        _TABLE,
        sa.Column("receipt_id", sa.String(length=36), primary_key=True),
        sa.Column("acting_principal_pseudonym", sa.String(length=64), nullable=True),
        sa.Column("subject_owner_pseudonym", sa.String(length=64), nullable=True),
        sa.Column("subject_kind", sa.String(length=32), nullable=True),
        sa.Column("accountability_kind", sa.String(length=64), nullable=True),
        sa.Column("purpose", sa.String(length=64), nullable=True),
        sa.Column("notice_version", sa.String(length=128), nullable=True),
        sa.Column("policy_version", sa.String(length=128), nullable=True),
        sa.Column("hmac_key_id", sa.String(length=32), nullable=True),
        sa.Column("declared_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("erased_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_partner_accountability_receipts_acting_principal_pseudonym",
        _TABLE,
        ["acting_principal_pseudonym"],
    )
    op.create_index(
        "ix_partner_accountability_actor_erased",
        _TABLE,
        ["acting_principal_pseudonym", "erased_at"],
    )


def downgrade() -> None:
    bind = op.get_bind()
    if _TABLE not in sa.inspect(bind).get_table_names():
        return
    op.drop_index("ix_partner_accountability_actor_erased", table_name=_TABLE)
    op.drop_index(
        "ix_partner_accountability_receipts_acting_principal_pseudonym",
        table_name=_TABLE,
    )
    op.drop_table(_TABLE)
