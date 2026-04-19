"""Wave 0 stub — Plan 01 CTX-02 Task 1 will implement.

Verifies drift.db schema creation is idempotent and matches
30.5-RESEARCH.md §Code Examples Example 2 (5-table schema).
"""
from __future__ import annotations

import pytest


@pytest.mark.skip(
    reason="TODO Wave 1 Plan 01 Task 1: implement dashboard.py init creating drift.db with 5 tables (sessions, commits, violations, context_hits, golden_runs)"
)
def test_schema_creates_5_tables() -> None:
    """Expected 5 tables: sessions, commits, violations, context_hits, golden_runs."""
    pass


@pytest.mark.skip(reason="TODO Wave 1 Plan 01 Task 1: dashboard.py init is idempotent (re-run = no-op)")
def test_schema_init_idempotent() -> None:
    """Running init twice must not fail and must not drop data."""
    pass
