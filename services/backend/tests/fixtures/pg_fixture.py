"""Real-Postgres pg_fixture for Phase 02 W0 (D-22).

Spins a `postgres:<MAJOR.MINOR>` testcontainer (dynamically pinned via
`tools/db/probe_railway_pg_version.sh` per iter-2 Tier-B B13), builds a SQLAlchemy
engine over the container URL, runs `alembic upgrade heads` (plural — handles
the pre-existing dual-head condition documented in
`.planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md`
entry DEFERRED-02-01-A), and yields the engine to tests.

Pytest marker `pg` (registered in `tests/conftest.py`) gates per-test opt-in.
Tests that consume this fixture skip with a CLEAR reason if Docker is
unavailable on the host — local dev without Docker still gets a green run.

Per CONTEXT.md D-22 + RESEARCH § Standard Stack : testcontainers-python is the
per-PR primary, Railway-staging replica is supplementary nightly soak.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

# Lazy imports — these modules are only needed if the fixture actually runs,
# and importing them at module top-level breaks local devs who haven't pip-installed
# testcontainers (since conftest.py auto-imports this module).
_PG_FIXTURE_DIR = Path(__file__).resolve().parent
_BACKEND_ROOT = _PG_FIXTURE_DIR.parent.parent  # services/backend/
_REPO_ROOT = _BACKEND_ROOT.parent.parent  # MINT repo root
_PROBE_SCRIPT = _REPO_ROOT / "tools" / "db" / "probe_railway_pg_version.sh"


def _probe_pg_version() -> str:
    """Returns the major.minor PG version to pin in testcontainers.

    Honors `STAGING_DATABASE_URL` env var if set (queries Railway PG live);
    otherwise returns the default `15.5`. Iter-2 Tier-B B13 (postgres-pro MED).
    Falls back silently to `15.5` if the probe script is missing or errors.
    """
    if not _PROBE_SCRIPT.exists():
        return "15.5"
    try:
        result = subprocess.run(
            ["bash", str(_PROBE_SCRIPT)],
            capture_output=True,
            text=True,
            timeout=5,
        )
        # Output shape: "railway:15.7" or "default:15.5"
        out = result.stdout.strip()
        if ":" in out:
            return out.split(":", 1)[1] or "15.5"
        return "15.5"
    except Exception:
        return "15.5"


_PG_IMAGE = f"postgres:{_probe_pg_version()}"


def _docker_available() -> bool:
    """Returns True if `docker info` succeeds (Docker daemon reachable).

    Used to skip the fixture cleanly on hosts without Docker (local dev without
    Docker Desktop, etc.). CI runners (GH Actions ubuntu-latest) ship Docker
    pre-installed per CONTEXT T-02-09 mitigation.
    """
    if shutil.which("docker") is None:
        return False
    try:
        result = subprocess.run(
            ["docker", "info"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.returncode == 0
    except Exception:
        return False


@pytest.fixture(scope="session")
def pg_engine():
    """Module-scoped real Postgres engine. Skips if Docker unavailable.

    Runs `alembic upgrade heads` (plural) inside the container. See
    `deferred-items.md` DEFERRED-02-01-A for the dual-head condition the
    plural form handles.
    """
    if not _docker_available():
        pytest.skip(
            "Docker unavailable on this host — pg_fixture cannot spin a Postgres "
            "testcontainer (CI runs the suite via GH Actions ubuntu-latest which "
            "ships Docker pre-installed). Per CONTEXT T-02-09 mitigation."
        )

    # Defer heavy imports until we know Docker is available.
    from sqlalchemy import create_engine
    try:
        from testcontainers.postgres import PostgresContainer  # type: ignore[import-not-found]
    except ImportError as exc:
        # CI fix 2026-05-19 : the Backend tests workflow installs the base
        # `dependencies` but not the `[test]` extra where testcontainers is
        # declared. PG integration workflow installs `[test]` and runs this
        # fixture for real. Backend tests path → skip gracefully so the
        # other 7000+ tests can still run.
        pytest.skip(
            f"testcontainers package not installed ({exc}) — pg_fixture "
            "requires `pip install '.[test]'`. PR-A merges testcontainers "
            "via PG integration workflow; Backend tests workflow runs the "
            "rest of the sweep unaffected. Per CONTEXT T-02-09 mitigation."
        )

    with PostgresContainer(_PG_IMAGE) as pg:
        url = pg.get_connection_url()
        engine = create_engine(url, future=True)
        _run_alembic_upgrade_heads(url)
        try:
            yield engine
        finally:
            engine.dispose()


@pytest.fixture(scope="function")
def pg_session(pg_engine):
    """Function-scoped Session over pg_engine. TRUNCATES known tables between tests.

    Truncation list grows as Phase 02 ships new tables (Plan 02-02 adds
    `fact_event` + `fact_current` ; Plan 02-03/04 may add more). For now,
    truncates the baseline-as-of-2026-05-18 tables that exist after alembic
    upgrade heads against the p112_audit_event_user_hash chain. Missing
    tables are tolerated silently (DROP-IF-EXISTS-like semantics via try/except).
    """
    from sqlalchemy.orm import Session

    baseline_tables = [
        "projection_audit_records",
        "audit_events",
        "dek_vault",
        "snapshots",
    ]
    session = Session(pg_engine)
    try:
        yield session
    finally:
        session.rollback()
        # Truncate AFTER the test runs so the next test starts clean.
        try:
            with pg_engine.begin() as conn:
                # Filter to tables that actually exist (the dual-head condition
                # means some baseline tables may live in the p86 branch only).
                from sqlalchemy import inspect

                existing = set(inspect(pg_engine).get_table_names())
                truncate_list = [t for t in baseline_tables if t in existing]
                if truncate_list:
                    sql = (
                        "TRUNCATE TABLE "
                        + ", ".join(truncate_list)
                        + " RESTART IDENTITY CASCADE"
                    )
                    from sqlalchemy import text as _text
                    conn.execute(_text(sql))
        except Exception:
            # Truncate is best-effort cleanup ; never fail a test on cleanup.
            pass
        session.close()


def _run_alembic_upgrade_heads(database_url: str) -> None:
    """Programmatically run `alembic upgrade heads` against `database_url`.

    Uses `heads` (plural) to tolerate the pre-existing dual-head condition
    (`p112_audit_event_user_hash` + `p86_eclairage_delivered`). See
    `deferred-items.md` DEFERRED-02-01-A. A merge migration will collapse
    these into a single head in a follow-up PR before / during Plan 02-02.

    CI fix 2026-05-19 : services/backend/alembic/env.py:38 unconditionally
    overrides `cfg.sqlalchemy.url` with `settings.DATABASE_URL`. Setting the
    URL on the Config object is insufficient — env.py wins. The reliable
    path is to set the `DATABASE_URL` env var AND patch the already-imported
    `settings.DATABASE_URL` BEFORE invoking `command.upgrade()`. Otherwise
    alembic upgrades whatever DB `settings.DATABASE_URL` resolves to (SQLite
    default in test env), while the fixture queries the Postgres
    testcontainer → `relation "alembic_version" does not exist`.
    """
    import os
    from alembic import command
    from alembic.config import Config

    if str(_BACKEND_ROOT) not in sys.path:
        sys.path.insert(0, str(_BACKEND_ROOT))

    # Patch BOTH the env var (for env.py re-loads) and the already-imported
    # settings instance (Pydantic-Settings caches on first import).
    from app.core.config import settings

    original_db_url_env = os.environ.get("DATABASE_URL")
    original_settings_url = settings.DATABASE_URL
    os.environ["DATABASE_URL"] = database_url
    settings.DATABASE_URL = database_url

    try:
        alembic_ini = _BACKEND_ROOT / "alembic.ini"
        cfg = Config(str(alembic_ini))
        cfg.set_main_option("sqlalchemy.url", database_url)
        command.upgrade(cfg, "heads")
    finally:
        # Restore previous env state so subsequent non-pg-fixture tests still
        # see the SQLite default.
        settings.DATABASE_URL = original_settings_url
        if original_db_url_env is None:
            os.environ.pop("DATABASE_URL", None)
        else:
            os.environ["DATABASE_URL"] = original_db_url_env
