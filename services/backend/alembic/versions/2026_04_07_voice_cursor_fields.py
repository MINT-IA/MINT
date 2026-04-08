"""voice_cursor_fields — Phase 02-03 (P0b)

Revision ID: 2026_04_07_voice_cursor_fields
Revises: 5adaafbee2b6
Create Date: 2026-04-07

NOTE — SCAFFOLD ONLY, NOT EXECUTED.

The Profile table (`profiles`) stores its full payload as a JSON
column (`data`) via `JSONEncodedDict` (see app/models/profile_model.py).
This means the 3 new voice cursor fields added by Plan 02-03
(`voiceCursorPreference`, `n5IssuedThisWeek`, `fragileModeEnteredAt`)
require NO DDL change — they live inside the JSON blob and are
naturally read/written by Pydantic round-trips.

This stub exists to:
  1. Document the schema bump for traceability.
  2. Match the Phase 1.5 / 02-03 posture: scaffold migrations even when
     no DDL is required so Alembic history stays linear.
  3. Provide an upgrade()/downgrade() pair that is safe to run later
     should the data column be normalised (v2.3+).

Read-time migration: existing rows without the new keys naturally
return Pydantic defaults ('direct', 0, None) on deserialization.

DO NOT RUN this migration. It is a no-op and exists for documentation only.
"""
from __future__ import annotations

# revision identifiers, used by Alembic.
revision = "2026_04_07_voice_cursor_fields"
down_revision = "5adaafbee2b6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """No-op: voice cursor fields live in profiles.data JSON blob.

    Read-time migration: Pydantic ProfileBase supplies defaults
    (voiceCursorPreference='direct', n5IssuedThisWeek=0,
    fragileModeEnteredAt=None) when deserializing rows that predate
    this schema bump.
    """
    pass


def downgrade() -> None:
    """No-op: nothing to roll back at the SQL layer."""
    pass
