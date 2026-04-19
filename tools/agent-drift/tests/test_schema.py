"""Plan 01 Task 1 — drift.db schema tests.

Verifies `dashboard.py init` creates all 5 tables (sessions, commits,
violations, context_hits, golden_runs) from schema.sql (verbatim per
30.5-RESEARCH.md §Code Examples Example 2) and that the command is idempotent.
"""
from __future__ import annotations

import sqlite3
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
DASHBOARD = REPO_ROOT / "tools" / "agent-drift" / "dashboard.py"
DB = REPO_ROOT / ".planning" / "agent-drift" / "drift.db"

EXPECTED_TABLES = {"sessions", "commits", "violations", "context_hits", "golden_runs"}


def _run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(DASHBOARD), *args],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
        check=True,
    )


def _reset_db() -> None:
    if DB.exists():
        DB.unlink()
    # Clean sqlite journal / shm / wal siblings if present
    for suffix in ("-journal", "-shm", "-wal"):
        sib = DB.with_name(DB.name + suffix)
        if sib.exists():
            sib.unlink()


def test_schema_creates_5_tables() -> None:
    """`dashboard.py init` creates drift.db with exactly 5 tables."""
    _reset_db()
    _run("init")
    assert DB.exists(), f"drift.db was not created at {DB}"
    conn = sqlite3.connect(DB)
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


def test_schema_init_idempotent() -> None:
    """Running `init` twice must not fail and must not duplicate schema."""
    _reset_db()
    _run("init")
    _run("init")  # second run must not raise
    conn = sqlite3.connect(DB)
    try:
        rows = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        ).fetchall()
    finally:
        conn.close()
    tables = {r[0] for r in rows}
    assert tables == EXPECTED_TABLES, f"expected {EXPECTED_TABLES}, got {tables}"
