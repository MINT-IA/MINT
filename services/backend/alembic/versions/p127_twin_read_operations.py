"""twin_read_operations — idempotence du Lego C1 (beat c8/c9).

Une ligne par clé d'opération (dérivée de l'attestation) : le rejeu de la
même clé retourne la réponse validée STOCKÉE sans re-consommer le quota.
La consommation est comptée par clé, jamais par requête — un timeout
post-envoi rejoué converge à exactement une consommation.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "p127_twin_read_operations"
down_revision: Union[str, Sequence[str], None] = "p126_money_truth_receipts"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "twin_read_operations",
        sa.Column("operation_key", sa.String(64), primary_key=True),
        sa.Column("session_id", sa.String(36), nullable=False, index=True),
        sa.Column("answer", sa.Text(), nullable=False),
        sa.Column("claims_json", sa.Text(), nullable=False),
        sa.Column("quota_consumed", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("twin_read_operations")
