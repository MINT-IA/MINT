"""Self-test fixture for `tools/checks/alembic_boolean_default_lint.py` (D-20).

Contains the exact forbidden BOOLEAN+server_default patterns so the lint has a
deterministic positive test surface. iter-2 Tier-A A7 (postgres-pro HIGH-1) :
seeds all 5+ documented bypass shapes.

NEVER imported by production code — `_BADn` are private sentinels.
"""
from __future__ import annotations

import sqlalchemy as sa  # noqa: F401  # imported for the Column literals below

# Shape 1 : plain string (no sa.text wrapper)
_BAD1 = sa.Column("flag1", sa.Boolean(), nullable=False, server_default="0")

# Shape 2 : sa.literal_column
_BAD2 = sa.Column(
    "flag2", sa.Boolean(), nullable=False, server_default=sa.literal_column("0")
)

# Shape 3a : sa.text with FALSE / TRUE literals
_BAD3 = sa.Column("flag3", sa.Boolean(), nullable=False, server_default=sa.text("FALSE"))

# Shape 3b : sa.text with '0'::int cast
_BAD4 = sa.Column(
    "flag4", sa.Boolean(), nullable=False, server_default=sa.text("'0'::int")
)

# Shape 4 : sa.BOOLEAN() uppercase + sa.text("0")
_BAD5 = sa.Column("flag5", sa.BOOLEAN(), nullable=False, server_default=sa.text("0"))

# Shape 5 : type_= keyword arg + sa.text("1")
_BAD6 = sa.Column(
    "flag6", type_=sa.Boolean(), nullable=False, server_default=sa.text("1")
)
