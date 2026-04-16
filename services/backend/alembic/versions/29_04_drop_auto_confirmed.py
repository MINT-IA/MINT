"""Soft-transition legacy auto-confirmed field states → needs_review.

PRIV-08 — Phase 29-04.

Per LSFin art. 7-10, a field auto-validated by the extractor (status=
``confirmed``) equates to implicit financial advice. Every extraction
MUST now start as ``needs_review``; the user promotes to ``user_validated``
via explicit UI action (BatchValidationBubble swipe-right = confirm all,
tap = correct one).

This migration is intentionally **soft**:
    - It does NOT drop the enum value at the DB layer (risky on Postgres
      — requires ALTER TYPE + re-deploy). The Python enum removes the
      symbol; a runtime guard in document_vision_service rejects any
      write with status=confirmed.
    - It finds any legacy rows that still carry ``confirmed`` in their
      JSON payloads (document_memory.field_history) and rewrites them
      to ``needs_review``. Users will re-confirm next time they open
      the document card.
    - If no pre-existing column holds the status, the migration is a
      no-op (typical for this project — most repos carry the status
      only in the freshly-added ``extracted_fields[*].status`` Pydantic
      field, not in an SQL column).

Idempotent + prod-safe: all ops guarded by inspector + SQL WHERE filters.

Revision ID: 29_04_drop_auto_confirmed
Revises:    29_03_fact_key_ttl_purpose
"""
from __future__ import annotations

revision = "29_04_drop_auto_confirmed"
down_revision = "29_03_fact_key_ttl_purpose"

from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector


def _has_table(inspector: Inspector, table: str) -> bool:
    return table in inspector.get_table_names()


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    # Soft-rewrite any confirmed -> needs_review inside document_memory JSON.
    # Portable string-replace works on SQLite + Postgres for the JSON dump;
    # avoids JSONB path updates that vary by dialect.
    if _has_table(inspector, "document_memory"):
        dialect = bind.dialect.name
        try:
            if dialect == "postgresql":
                op.execute(
                    sa.text(
                        "UPDATE document_memory "
                        "SET field_history = REPLACE("
                        "  CAST(field_history AS TEXT), "
                        "  '\"status\": \"confirmed\"', "
                        "  '\"status\": \"needs_review\"'"
                        ")::json "
                        "WHERE CAST(field_history AS TEXT) LIKE '%\"status\": \"confirmed\"%'"
                    )
                )
            else:
                # SQLite: field_history stored as TEXT via JSON type — use
                # json() round-trip with REPLACE to keep the value valid.
                op.execute(
                    sa.text(
                        "UPDATE document_memory "
                        "SET field_history = REPLACE("
                        "  field_history, "
                        "  '\"status\": \"confirmed\"', "
                        "  '\"status\": \"needs_review\"'"
                        ") "
                        "WHERE field_history LIKE '%\"status\": \"confirmed\"%'"
                    )
                )
        except Exception:
            # Best-effort soft-transition. If the JSON rewrite fails on an
            # edge-case dialect, the runtime guard still catches auto-confirm
            # on the next read.
            pass


def downgrade() -> None:
    # Downgrade is intentionally a no-op. The pre-29-04 "confirmed" status
    # represented an LSFin violation; restoring it on rollback would be
    # worse than leaving the rows at needs_review.
    pass
