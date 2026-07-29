"""p126 — money_truth_receipts store→resolve table (firstJob PR-E, E1).

Crée la table ``money_truth_receipts`` : store append-only du
MoneyTruthReceipt pour le handoff /first-job → coach (SPEC §4.3). Suit le
pattern ``projection_audit_records`` (p111) — modèle Base, scoping propriétaire
par hash HMAC, append-only sur Postgres via REVOKE UPDATE/DELETE — mais comme
un store de résolution à fenêtre bornée (RECEIPT_RESOLVE_TTL, calculé à la
lecture ; la ligne n'est pas supprimée). Distinct du journal LSFin ~10 ans :
le corps du receipt porte la valeur nette + inputs en clair, d'où une table
dédiée plutôt que le journal de conformité hash-only (nLPD D12).

Revision ID : p126_money_truth_receipts   (24 chars — sous le cap Postgres
              alembic_version.version_num VARCHAR(32)).
Revises     : p125_consent_shred_pending
Create Date : 2026-07-29

Dialect branch
==============
Postgres : REVOKE UPDATE, DELETE sur la table depuis PUBLIC et (si le rôle
existe) depuis ``app_role``. SQLite (tests) : INSERT-only par convention.

Downgrade
=========
DROP TABLE retire tous les privilèges automatiquement — pas de GRANT
symétrique nécessaire.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "p126_money_truth_receipts"
down_revision: Union[str, Sequence[str], None] = "p125_consent_shred_pending"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "money_truth_receipts",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("owner_scope_hash", sa.String(length=64), nullable=False),
        sa.Column("owner_kind", sa.String(length=16), nullable=False),
        sa.Column("receipt_id", sa.String(length=64), nullable=False),
        sa.Column("inputs_hash", sa.String(length=64), nullable=False),
        sa.Column("claim_id", sa.String(length=64), nullable=False),
        sa.Column("receipt_body", sa.Text(), nullable=False),
        sa.Column("output_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "source",
            sa.String(length=32),
            nullable=False,
            server_default="mobile_l1_receipt",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        # Idempotence + scoping : un receipt_id est unique PAR propriétaire.
        sa.UniqueConstraint(
            "owner_scope_hash",
            "receipt_id",
            name="uq_money_truth_owner_receipt",
        ),
    )
    op.create_index(
        "ix_money_truth_owner_receipt",
        "money_truth_receipts",
        ["owner_scope_hash", "receipt_id"],
    )

    # ── Postgres append-only enforcement (pattern p111) ─────────────────
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("REVOKE UPDATE, DELETE ON money_truth_receipts FROM PUBLIC")
        op.execute(
            """
            DO $$
            BEGIN
                IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_role') THEN
                    REVOKE UPDATE, DELETE ON money_truth_receipts FROM app_role;
                END IF;
            END
            $$;
            """
        )


def downgrade() -> None:
    op.drop_index(
        "ix_money_truth_owner_receipt",
        table_name="money_truth_receipts",
    )
    op.drop_table("money_truth_receipts")
