"""p11_recent_gravity_events — Phase 11 (VOICE-09/10)

Revision ID: p11_recent_gravity_events
Revises: 2026_04_07_voice_cursor_fields
Create Date: 2026-04-07

NOTE — SCAFFOLD ONLY, NOT EXECUTED.

The Profile table (`profiles`) stores its full payload as a JSON column
(`data`) via `JSONEncodedDict` (see app/models/profile_model.py). The new
`recentGravityEvents` field added by Plan 11-03 lives inside that JSON
blob; no DDL change is required.

This stub exists to:
  1. Document the schema bump for traceability (VOICE-09/10).
  2. Match the Phase 1.5 / 02-03 / 11 posture: scaffold migrations even
     when no DDL is required so Alembic history stays linear.
  3. Provide an upgrade()/downgrade() pair that is safe to run later
     should the data column be normalised (v2.3+).

Read-time migration: existing rows without the `recentGravityEvents`
key naturally return `[]` (Pydantic default_factory) on deserialization.

DO NOT RUN this migration. It is a no-op and exists for documentation only.
"""
from __future__ import annotations

# revision identifiers, used by Alembic.
revision = "p11_recent_gravity_events"
down_revision = "2026_04_07_voice_cursor_fields"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """No-op: recentGravityEvents lives in profiles.data JSON blob.

    Read-time migration: Pydantic ProfileBase supplies the default
    (`recentGravityEvents=[]`) when deserializing rows that predate
    this schema bump.
    """
    pass


def downgrade() -> None:
    """No-op: nothing to roll back at the SQL layer."""
    pass
