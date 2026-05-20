"""p122 ORM-orphan tables safety net

Revision ID: p122_orm_orphan_safety_net
Revises: p119_phase02_parity_cont
Create Date: 2026-05-20

Standalone hotfix (not part of any Wave) — closes Sentry MINT-BACKEND-3
(208 events, `relation "document_embeddings" does not exist`) + MINT-BACKEND-A
(20 events, `relation "document_audit_logs" does not exist`) by creating
both missing tables on staging + future-prod. Idempotent : also creates
magic_link_tokens + coach_insights with `IF NOT EXISTS` semantics in case
the historical `create_all()` bypass in `app/main.py:81-82` didn't reach a
given env.

Chains off p119 (current dev head) — leaves p120 / p121 free for the
deferred Wave 0 PR A2 (`p120_fact_event_idempotency`) and Wave 2 PR-5
(`p121_drop_snapshot_legacy`). Those PRs chain off p122 when they ship.

Cross-dialect : the 3 ORM-shaped tables (document_audit_logs,
magic_link_tokens, coach_insights) are created via `op.create_table()` so
SQLAlchemy emits the right DDL on both Postgres (prod / staging / tests
under integration_pg/) and SQLite (CI `alembic upgrade head` check +
local dev). The pgvector-backed `document_embeddings` is Postgres-only
(no SQLite analogue for `vector(1536)` + IVFFlat). On SQLite, that block
is skipped — RAG hybrid_search tests already mock the vector store path.
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "p122_orm_orphan_safety_net"
down_revision = "p119_phase02_parity_cont"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name
    insp = sa.inspect(bind)
    existing = set(insp.get_table_names())

    # ── 1. document_audit_logs (nLPD audit trail, ORM in app/models/document_audit.py) ──
    if "document_audit_logs" not in existing:
        op.create_table(
            "document_audit_logs",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("user_id_hash", sa.String(), nullable=False),
            sa.Column("document_type", sa.String(), nullable=False),
            sa.Column("field_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("overall_confidence", sa.Float(), nullable=False, server_default="0.0"),
            sa.Column(
                "extraction_method",
                sa.String(),
                nullable=False,
                server_default="claude_vision",
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(), nullable=True),
            sa.Column("retained_until", sa.DateTime(), nullable=True),
            sa.Column("classification_result", sa.String(), nullable=True),
            sa.Column("error_message", sa.Text(), nullable=True),
        )
        op.create_index(
            "ix_document_audit_logs_user_id_hash",
            "document_audit_logs",
            ["user_id_hash"],
        )

    # ── 2. magic_link_tokens (passwordless login, ORM in app/models/magic_link_token.py) ──
    if "magic_link_tokens" not in existing:
        op.create_table(
            "magic_link_tokens",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("email", sa.String(), nullable=False),
            sa.Column("token_hash", sa.String(), nullable=False, unique=True),
            sa.Column("expires_at", sa.DateTime(), nullable=False),
            sa.Column("used", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("used_at", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_magic_link_tokens_email", "magic_link_tokens", ["email"])
        # token_hash already has UNIQUE constraint above ; no separate index needed

    # ── 3. coach_insights (cross-session coach memory, ORM in app/models/coach_insight.py) ──
    if "coach_insights" not in existing:
        op.create_table(
            "coach_insights",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column(
                "user_id",
                sa.String(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("topic", sa.String(), nullable=False),
            sa.Column("summary", sa.Text(), nullable=False),
            sa.Column(
                "insight_type", sa.String(), nullable=False, server_default="fact"
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_coach_insights_user_id", "coach_insights", ["user_id"])
        op.create_index(
            "ix_coach_insights_user_topic", "coach_insights", ["user_id", "topic"]
        )

    # ── 4. document_embeddings (Postgres + pgvector only — skip on SQLite) ──
    # Column shape ported verbatim from services/backend/migrations/003_pgvector.sql
    # (legacy DO-NOT-EXECUTE SQL never executed against any deployed Postgres).
    # IVFFlat lists=10 per legacy comment (sqrt of ~100 docs corpus size).
    if dialect == "postgresql" and "document_embeddings" not in existing:
        op.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        op.execute(
            """
            CREATE TABLE document_embeddings (
                id          SERIAL PRIMARY KEY,
                doc_id      VARCHAR(100) NOT NULL UNIQUE,
                doc_type    VARCHAR(20)  NOT NULL
                            CHECK (doc_type IN ('concept','faq','canton','legal','memory')),
                title       VARCHAR(200),
                content     TEXT         NOT NULL,
                embedding   vector(1536),
                metadata    JSONB        DEFAULT '{}'::jsonb,
                created_at  TIMESTAMPTZ  DEFAULT NOW(),
                updated_at  TIMESTAMPTZ  DEFAULT NOW()
            );
            """
        )
        op.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_embeddings_vector
                ON document_embeddings USING ivfflat (embedding vector_cosine_ops)
                WITH (lists = 10);
            """
        )
        op.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_embeddings_doc_type
                ON document_embeddings (doc_type);
            """
        )
        op.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_embeddings_content_fts
                ON document_embeddings USING gin (to_tsvector('french', content));
            """
        )


def downgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name
    insp = sa.inspect(bind)
    existing = set(insp.get_table_names())

    # Reverse order. pgvector extension intentionally NOT dropped (wide blast radius
    # on shared Postgres ; unused extension is harmless).
    if dialect == "postgresql" and "document_embeddings" in existing:
        op.execute("DROP INDEX IF EXISTS idx_embeddings_content_fts;")
        op.execute("DROP INDEX IF EXISTS idx_embeddings_doc_type;")
        op.execute("DROP INDEX IF EXISTS idx_embeddings_vector;")
        op.execute("DROP TABLE IF EXISTS document_embeddings;")

    if "coach_insights" in existing:
        op.drop_index("ix_coach_insights_user_topic", table_name="coach_insights")
        op.drop_index("ix_coach_insights_user_id", table_name="coach_insights")
        op.drop_table("coach_insights")

    if "magic_link_tokens" in existing:
        op.drop_index("ix_magic_link_tokens_email", table_name="magic_link_tokens")
        op.drop_table("magic_link_tokens")

    if "document_audit_logs" in existing:
        op.drop_index(
            "ix_document_audit_logs_user_id_hash", table_name="document_audit_logs"
        )
        op.drop_table("document_audit_logs")
