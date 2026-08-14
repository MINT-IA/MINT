"""Plan 01 Task 1 — drift.db schema tests.

Verifies `dashboard.py init` creates all 5 tables (sessions, commits,
violations, context_hits, golden_runs) from schema.sql (verbatim per
30.5-RESEARCH.md §Code Examples Example 2) and that the command is idempotent.
"""
from __future__ import annotations

import os
import sqlite3
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
DASHBOARD = REPO_ROOT / "tools" / "agent-drift" / "dashboard.py"
EXPECTED_TABLES = {"sessions", "commits", "violations", "context_hits", "golden_runs"}


def _run(db: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(DASHBOARD), *args],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
        check=True,
        env={**os.environ, "MINT_AGENT_DRIFT_DB": str(db)},
    )


def test_schema_creates_5_tables(tmp_path: Path) -> None:
    """`dashboard.py init` creates drift.db with exactly 5 tables."""
    db = tmp_path / "drift.db"
    _run(db, "init")
    assert db.exists(), f"drift.db was not created at {db}"
    conn = sqlite3.connect(db)
    try:
        rows = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
    finally:
        conn.close()
    tables = {r[0] for r in rows}
    # Allow SQLite internal tables (sqlite_sequence for AUTOINCREMENT) to coexist
    assert EXPECTED_TABLES.issubset(
        tables
    ), f"missing tables: {EXPECTED_TABLES - tables} (got {tables})"


def test_schema_init_idempotent(tmp_path: Path) -> None:
    """Running `init` twice must not fail and must not duplicate schema."""
    db = tmp_path / "drift.db"
    _run(db, "init")
    _run(db, "init")  # second run must not raise
    conn = sqlite3.connect(db)
    try:
        rows = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        ).fetchall()
    finally:
        conn.close()
    tables = {r[0] for r in rows}
    assert tables == EXPECTED_TABLES, f"expected {EXPECTED_TABLES}, got {tables}"
