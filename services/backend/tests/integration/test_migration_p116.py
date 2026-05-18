"""p116_snapshot_constants_invalidation — D-17 tombstone validation.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 — P1.

p116 is a TOMBSTONE migration : no schema change. The D-17 cache-key
contract is enforced by `app/services/cache/snapshot_cache.py`. This
test asserts :

1. The migration upgrades cleanly with NO schema changes vs p115.
2. The downgrade is a no-op (alembic_version row decrements without
   errors).
3. The cache-key contract function `cache_key_for_snapshot` exists +
   includes `constants_version_hash` in its output (the runtime-side
   half of the D-17 contract).
4. The staleness function `is_snapshot_stale` exists + returns a bool.

Combined : alembic chain pinned to p116 + application contract live.
"""
from __future__ import annotations

import importlib
from pathlib import Path

import sqlalchemy as sa
from alembic import command
from alembic.config import Config


def _make_config(tmp_path, monkeypatch):
    db_url = f"sqlite:///{tmp_path}/test.db"
    monkeypatch.setenv("DATABASE_URL", db_url)
    monkeypatch.setenv("TESTING", "1")
    from app.core import config as _cfg_mod
    importlib.reload(_cfg_mod)
    backend_root = Path(__file__).parent.parent.parent
    cfg = Config(str(backend_root / "alembic.ini"))
    cfg.set_main_option("script_location", str(backend_root / "alembic"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    return cfg, db_url


def test_p116_is_noop_schema_change(tmp_path, monkeypatch):
    """SQLite : verify p116 upgrade does NOT change schema vs p115."""
    cfg, db_url = _make_config(tmp_path, monkeypatch)

    command.upgrade(cfg, "p115_hmac_pepper_pii")

    engine = sa.create_engine(db_url)
    inspector_pre = sa.inspect(engine)
    schema_pre = {
        tbl: {c["name"] for c in inspector_pre.get_columns(tbl)}
        for tbl in inspector_pre.get_table_names()
    }

    command.upgrade(cfg, "p116_snapshot_invalidation")

    inspector_post = sa.inspect(engine)
    schema_post = {
        tbl: {c["name"] for c in inspector_post.get_columns(tbl)}
        for tbl in inspector_post.get_table_names()
    }

    assert schema_pre == schema_post, (
        f"p116 must be a tombstone (no schema change) ; got delta : "
        f"added={set(schema_post) - set(schema_pre)}, "
        f"removed={set(schema_pre) - set(schema_post)}"
    )


def test_p116_downgrade_is_noop_and_clean(tmp_path, monkeypatch):
    """Downgrade from p116 → p115 leaves the schema identical."""
    cfg, db_url = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "p116_snapshot_invalidation")

    engine = sa.create_engine(db_url)
    inspector_at_p116 = sa.inspect(engine)
    schema_at_p116 = {
        tbl: {c["name"] for c in inspector_at_p116.get_columns(tbl)}
        for tbl in inspector_at_p116.get_table_names()
    }

    command.downgrade(cfg, "p115_hmac_pepper_pii")

    inspector_at_p115 = sa.inspect(engine)
    schema_at_p115 = {
        tbl: {c["name"] for c in inspector_at_p115.get_columns(tbl)}
        for tbl in inspector_at_p115.get_table_names()
    }

    assert schema_at_p116 == schema_at_p115


def test_d17_application_contract_live():
    """The D-17 cache-key contract MUST exist in the application layer."""
    from app.services.cache.snapshot_cache import (
        cache_key_for_snapshot,
        is_snapshot_stale,
    )

    key = cache_key_for_snapshot(
        user_id="user-d17",
        inputs_hash="abc123",
        constants_version_hash="ph01-fixture-hash",
    )
    assert "ph01-fixture-hash" in key
    assert "user-d17" in key
    assert "abc123" in key

    class _FakeRow:
        constants_version_hash = None

    assert is_snapshot_stale(_FakeRow()) is False
