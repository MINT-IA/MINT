"""Pre-flight zero-user gate test — Plan 02-03 Task 0 (iter-2 B1).

Asserts the contract of `scripts/preflight_zero_user_gate.py` :
- exit 0 when `users` table is empty.
- exit 1 when `users` table has any row.
- exit 0 with WARN line when no DB URL configured.

The script under test is invoked as a subprocess (it has a `__main__`
guard) so we exercise the actual exit code surface CI would observe.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from uuid import uuid4

import pytest

from app.models.user import User


# Repo root resolved relative to this test file (5 levels up from
# tests/integration/test_*.py -> integration -> tests -> backend -> services -> repo).
_REPO_ROOT = Path(__file__).resolve().parents[4]
_SCRIPT = _REPO_ROOT / "services" / "backend" / "scripts" / "preflight_zero_user_gate.py"
assert _SCRIPT.is_file(), f"preflight script not found at expected path: {_SCRIPT}"


def _run_script(env_overrides: dict) -> subprocess.CompletedProcess:
    """Invoke the preflight script in a clean env subprocess."""
    env = os.environ.copy()
    # Wipe any inherited prod / test DB URLs so the test fully controls.
    env.pop("PROD_DATABASE_URL", None)
    env.pop("PREFLIGHT_TEST_DATABASE_URL", None)
    env.update(env_overrides)
    return subprocess.run(
        [sys.executable, str(_SCRIPT)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
        timeout=30,
    )


def test_no_db_url_warns_and_exits_zero():
    """No PROD_DATABASE_URL configured → WARN + exit 0 (CI path)."""
    result = _run_script({})
    assert result.returncode == 0, (
        f"expected exit 0 with no DB URL, got {result.returncode}\n"
        f"stdout={result.stdout!r}\nstderr={result.stderr!r}"
    )
    assert "WARN" in result.stdout, (
        f"expected WARN message in stdout, got: {result.stdout!r}"
    )


def test_zero_users_exits_zero_ok(tmp_path):
    """Empty users table → OK + exit 0."""
    # Build a tiny SQLite DB with an empty users table matching the
    # production schema's COUNT(*) target.
    from sqlalchemy import create_engine, text

    db_file = tmp_path / "preflight_zero.db"
    url = f"sqlite:///{db_file}"
    engine = create_engine(url)
    with engine.connect() as conn:
        conn.execute(text("CREATE TABLE users (id TEXT PRIMARY KEY)"))
        conn.commit()
    engine.dispose()

    result = _run_script({"PREFLIGHT_TEST_DATABASE_URL": url})
    assert result.returncode == 0, (
        f"expected exit 0 with 0 users, got {result.returncode}\n"
        f"stdout={result.stdout!r}\nstderr={result.stderr!r}"
    )
    assert "OK: prod users=0" in result.stdout, (
        f"expected OK stdout, got: {result.stdout!r}"
    )


def test_nonzero_users_exits_one_blocked(tmp_path):
    """users table with any row → BLOCKED + exit 1."""
    from sqlalchemy import create_engine, text

    db_file = tmp_path / "preflight_nonzero.db"
    url = f"sqlite:///{db_file}"
    engine = create_engine(url)
    with engine.connect() as conn:
        conn.execute(text("CREATE TABLE users (id TEXT PRIMARY KEY)"))
        conn.execute(text("INSERT INTO users (id) VALUES ('u-1')"))
        conn.execute(text("INSERT INTO users (id) VALUES ('u-2')"))
        conn.commit()
    engine.dispose()

    result = _run_script({"PREFLIGHT_TEST_DATABASE_URL": url})
    assert result.returncode == 1, (
        f"expected exit 1 with 2 users, got {result.returncode}\n"
        f"stdout={result.stdout!r}\nstderr={result.stderr!r}"
    )
    assert "BLOCKED" in result.stdout, (
        f"expected BLOCKED stdout, got: {result.stdout!r}"
    )
    assert "2 users" in result.stdout, (
        f"expected user-count in stdout, got: {result.stdout!r}"
    )


@pytest.mark.pg
@pytest.mark.requires_pg
def test_zero_users_against_pg_fixture(pg_session, pg_engine):
    """pg_fixture variant — empty users table on real Postgres → exit 0."""
    # pg_fixture provides a real Postgres URL via the engine config.
    url = str(pg_engine.url)
    result = _run_script({"PREFLIGHT_TEST_DATABASE_URL": url})
    assert result.returncode == 0, (
        f"expected exit 0 against empty pg_fixture, got {result.returncode}\n"
        f"stdout={result.stdout!r}\nstderr={result.stderr!r}"
    )
    assert "OK: prod users=0" in result.stdout


@pytest.mark.pg
@pytest.mark.requires_pg
def test_nonzero_users_against_pg_fixture(pg_session, pg_engine):
    """pg_fixture variant — seeded user on real Postgres → exit 1."""
    user = User(
        id=f"u-{uuid4().hex[:8]}",
        email=f"{uuid4().hex[:8]}@preflight.test",
        hashed_password="x",
    )
    pg_session.add(user)
    pg_session.commit()

    url = str(pg_engine.url)
    result = _run_script({"PREFLIGHT_TEST_DATABASE_URL": url})
    assert result.returncode == 1, (
        f"expected exit 1 against seeded pg_fixture, got {result.returncode}\n"
        f"stdout={result.stdout!r}\nstderr={result.stderr!r}"
    )
    assert "BLOCKED" in result.stdout
