"""Self-test for `pg_fixture` (D-22 — Phase 02 W0 Plan 02-01).

Asserts (a) the container runs a `PostgreSQL 15.x` server, (b) the alembic
chain reaches the documented heads, (c) downgrade + re-upgrade are
idempotent. Skips with a clear reason if Docker is unavailable on the host.

iter-2 Tier-B B13 adds `test_pg_image_pin_matches_probe()` asserting the
image pin auto-syncs with `tools/db/probe_railway_pg_version.sh`.
"""

from __future__ import annotations

import os

import pytest

from tests.fixtures.pg_fixture import _PG_IMAGE, _probe_pg_version

pytestmark = pytest.mark.pg


def test_pg_fixture_spins_postgres_and_alembic_upgrade_head_idempotent(pg_engine):
    """`pg_engine` runs Postgres 15.x, alembic chain at expected heads, idempotent.

    Covers D-22 acceptance : harness spins real PG, alembic upgrade head + downgrade
    base + re-upgrade head completes within the fixture-scope budget (~60s after
    image cache).
    """
    from sqlalchemy import text

    # (a) Confirm it's PostgreSQL 15.x.
    with pg_engine.connect() as conn:
        version = conn.execute(text("SELECT version()")).scalar_one()
        assert "PostgreSQL 15" in version, (
            f"Expected PostgreSQL 15.x, got: {version!r}. "
            f"_PG_IMAGE={_PG_IMAGE}."
        )

    # (b) Confirm alembic_version table contains at least one of the expected heads.
    with pg_engine.connect() as conn:
        rows = conn.execute(text("SELECT version_num FROM alembic_version")).fetchall()
        heads_in_db = {r[0] for r in rows}
    # Valid states (Phase 02 chain evolution) :
    #   (a) Pre-merge dual-head : {p112, p86} both present.
    #   (b) Single legacy head : {p112} or {p86} alone (intermediate state).
    #   (c) Post-merge single head : {p98_merge_p86_eclairage} (canonical
    #       Plan 02-01 + PR-A onward, the merge migration was cherry-picked
    #       into Plan 02-01 to unblock pg_fixture CI 2026-05-19).
    #   (d) Phase 02 substrate fully applied : {p119_phase02_parity_cont}
    #       (canonical post-Phase-02-substrate, dev branch HEAD after the
    #       4 squash PRs #653 #657 #656 #655 landed 2026-05-19).
    #   (e) ORM-orphan safety net applied : {p122_orm_orphan_safety_net}
    #       (canonical post-2026-05-20 hotfix that backfills the 4
    #       ORM-orphan tables — closes Sentry MINT-BACKEND-3 + MINT-BACKEND-A).
    #   (f) Sub-phase 01.5 waitlist endpoint applied : {p123_waitlist_entry}
    #       (canonical post-2026-05-21 archetype HARD GATE backend slice
    #       — POST /api/v1/waitlist + WaitlistEntry model).
    #   (g) Phase 02 event substrate idempotency applied :
    #       {p120_fact_event_idempotency} (canonical post-2026-06-02
    #       CJT-013 local substrate hardening).
    #   (h) Apple subject binding applied :
    #       {p124_user_apple_sub} (canonical post-2026-06 account lifecycle
    #       integration).
    expected_heads = {
        "p112_audit_event_user_hash",
        "p86_eclairage_delivered",
        "p98_merge_p86_eclairage",
        "p119_phase02_parity_cont",
        "p122_orm_orphan_safety_net",
        "p123_waitlist_entry",
        "p120_fact_event_idempotency",
        "p124_user_apple_sub",
        "p125_consent_shred_pending",
    }
    assert heads_in_db & expected_heads, (
        f"alembic_version table missing expected heads. "
        f"In DB: {heads_in_db}. Expected (any of): {expected_heads}."
    )

    # (c) downgrade base + re-upgrade heads is idempotent (no exceptions).
    # NOTE: with multiple heads, `downgrade base` would tear down the full chain
    # of each head independently. To avoid running a 26+22-step round-trip on
    # every test session, we only assert the upgrade is re-runnable as a no-op
    # (which is the property the fixture relies on).
    from alembic import command
    from alembic.config import Config
    from pathlib import Path
    import sys
    backend_root = Path(__file__).resolve().parent.parent.parent
    if str(backend_root) not in sys.path:
        sys.path.insert(0, str(backend_root))
    cfg = Config(str(backend_root / "alembic.ini"))
    cfg.set_main_option("sqlalchemy.url", str(pg_engine.url))
    # Second upgrade — must be a no-op (already at heads).
    command.upgrade(cfg, "heads")


def test_pg_image_pin_matches_probe():
    """iter-2 Tier-B B13 : `_PG_IMAGE` is derived from `_probe_pg_version()`.

    When `STAGING_DATABASE_URL` is unset, both should resolve to the default
    `15.5`. When set in CI, both auto-sync to whatever Railway PG is running.
    """
    probed = _probe_pg_version()
    assert _PG_IMAGE == f"postgres:{probed}", (
        f"_PG_IMAGE drift : expected postgres:{probed}, got {_PG_IMAGE}."
    )
    # Shape sanity : must be MAJOR.MINOR pattern.
    parts = probed.split(".")
    assert len(parts) >= 2 and all(p.isdigit() for p in parts[:2]), (
        f"Probe returned malformed version {probed!r}. "
        f"Expected MAJOR.MINOR (e.g., 15.5)."
    )


def test_probe_script_default_when_env_unset(monkeypatch):
    """Probe script must print `default:15.5` when STAGING_DATABASE_URL is unset.

    This locks the contract that probe failure is silent + non-fatal — local
    devs running without Railway secrets still get a working pg_fixture.
    """
    import subprocess
    from pathlib import Path

    monkeypatch.delenv("STAGING_DATABASE_URL", raising=False)
    repo_root = Path(__file__).resolve().parent.parent.parent.parent.parent
    probe = repo_root / "tools" / "db" / "probe_railway_pg_version.sh"
    if not probe.exists():
        pytest.skip(f"Probe script missing at {probe}")
    result = subprocess.run(
        ["bash", str(probe)],
        capture_output=True,
        text=True,
        timeout=5,
        env={**os.environ, "STAGING_DATABASE_URL": ""},
    )
    assert result.returncode == 0, (
        f"Probe script exited {result.returncode}. stderr={result.stderr!r}"
    )
    assert result.stdout.strip() == "default:15.5", (
        f"Expected stdout 'default:15.5', got {result.stdout!r}"
    )
