#!/usr/bin/env python3
"""Railway pre-deploy migration bootstrap.

Why this exists:
- Some production databases were initialized before Alembic tracking.
- In that state, running `alembic upgrade head` fails on baseline tables
  (e.g. DuplicateTable for audit_events).

Behavior:
1. If `alembic_version` is missing but baseline tables already exist, stamp
   the baseline revision.
2. Run `alembic upgrade head`.
"""

from __future__ import annotations

import os
import subprocess
import sys

from sqlalchemy import create_engine, inspect, text


BASELINE_REVISION = "d73dcc3968c9"
ALEMBIC_TABLE = "alembic_version"
BASELINE_SENTINEL_TABLES = ("users", "audit_events", "profiles")


def _database_url() -> str:
    return os.getenv("DATABASE_URL", "sqlite:///./mint.db")


def _bootstrap_alembic_if_needed(database_url: str) -> None:
    engine = create_engine(database_url)
    with engine.begin() as conn:
        inspector = inspect(conn)
        has_alembic_table = inspector.has_table(ALEMBIC_TABLE)
        has_baseline_tables = any(
            inspector.has_table(table_name) for table_name in BASELINE_SENTINEL_TABLES
        )

        if has_alembic_table or not has_baseline_tables:
            print(
                f"[migrate] bootstrap not required: "
                f"has_alembic_table={has_alembic_table}, "
                f"has_baseline_tables={has_baseline_tables}"
            )
            return

        print(
            "[migrate] detected existing schema without Alembic tracking; "
            f"stamping baseline revision {BASELINE_REVISION}"
        )

        conn.execute(
            text(
                f"CREATE TABLE IF NOT EXISTS {ALEMBIC_TABLE} "
                "(version_num VARCHAR(32) NOT NULL)"
            )
        )
        conn.execute(text(f"DELETE FROM {ALEMBIC_TABLE}"))
        conn.execute(
            text(f"INSERT INTO {ALEMBIC_TABLE} (version_num) VALUES (:version_num)"),
            {"version_num": BASELINE_REVISION},
        )


def _run_alembic_upgrade_head() -> None:
    print("[migrate] running: alembic upgrade head")
    subprocess.run(["alembic", "upgrade", "head"], check=True)


def main() -> int:
    database_url = _database_url()
    print(f"[migrate] using DATABASE_URL={database_url.split('@')[0]}...")

    try:
        _bootstrap_alembic_if_needed(database_url)
        _run_alembic_upgrade_head()
    except Exception as exc:  # pragma: no cover - startup path
        print(f"[migrate] failed: {exc}", file=sys.stderr)
        return 1

    print("[migrate] success")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
