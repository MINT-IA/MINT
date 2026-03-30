"""FIX-109: Persist document metadata in PostgreSQL.

Revision ID: p9_documents_table
Revises: p8_token_blacklist
"""
revision = "p9_documents_table"
down_revision = "p8_token_blacklist"

from alembic import op
import sqlalchemy as sa


def upgrade():
    # Guard: skip if table already exists (idempotent)
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    if "documents" in inspector.get_table_names():
        return

    op.create_table(
        "documents",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), nullable=False, index=True),
        sa.Column("document_type", sa.String(), nullable=False),
        sa.Column("upload_date", sa.DateTime()),
        sa.Column("confidence", sa.Float(), server_default="0.0"),
        sa.Column("fields_found", sa.Integer(), server_default="0"),
        sa.Column("fields_total", sa.Integer(), server_default="0"),
        sa.Column("extracted_fields", sa.JSON(), nullable=True),
        sa.Column("warnings", sa.JSON(), nullable=True),
        sa.Column("extraction_method", sa.String(), server_default="ocr_mlkit"),
        sa.Column("overall_confidence", sa.Float(), server_default="0.0"),
    )


def downgrade():
    op.drop_table("documents")
