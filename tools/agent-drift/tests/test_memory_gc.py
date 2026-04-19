"""Wave 0 stub — Plan 02 CTX-01 memory GC (30j retention) will implement.

Per D-02: files with mtime older than 30 days are archived to memory/archive/YYYY-MM/.
Files younger than 30 days stay in memory/topics/.
Border case (exactly 30 days) = archive (inclusive boundary).
"""
from __future__ import annotations

import pytest


@pytest.mark.skip(
    reason="TODO Wave 2 Plan 02 Task 3: memory_gate.py --apply archives files with mtime >30d to archive/YYYY-MM/"
)
def test_gc_archives_files_older_than_30_days(fake_memory_topic: dict) -> None:
    """fake_memory_topic['stale'] (40 days old) MUST move to archive/ after GC."""
    pass


@pytest.mark.skip(
    reason="TODO Wave 2 Plan 02 Task 3: memory_gate.py keeps files younger than 30d in place"
)
def test_gc_keeps_files_younger_than_30_days(fake_memory_topic: dict) -> None:
    """fake_memory_topic['fresh'] (1 day old) MUST stay in memory/topics/ after GC."""
    pass


@pytest.mark.skip(
    reason="TODO Wave 2 Plan 02 Task 3: border case exactly 30d → archive (inclusive boundary, D-02)"
)
def test_gc_border_case_exactly_30_days(fake_memory_topic: dict) -> None:
    """fake_memory_topic['border'] (30 days old exactly) MUST archive per D-02 rationale."""
    pass
