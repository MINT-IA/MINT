"""p115_hmac_pepper_pii_columns — D-15 PII hash columns validation.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 — P1.

Asserts that p115 :
1. Adds 3 *_hash columns to audit_events : actor_email_hash, ip_address_hash,
   user_agent_hash (each VARCHAR(64) nullable + indexed).
2. Backfills each existing row's *_hash columns via `hmac_pii()` from the
   canonical entry.
3. Retains the original plaintext columns (D-15 one-release deprecation cycle).
4. Adds 3 indexes : ix_audit_events_actor_email_hash, _ip_address_hash,
   _user_agent_hash.

Test pattern mirrors `tests/test_snapshots_migration_exists.py` —
alembic env.py overrides sqlalchemy.url from settings.DATABASE_URL,
so the test MUST `monkeypatch.setenv("DATABASE_URL", ...)` + reload
the config module BEFORE creating the alembic Config object.
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


def test_p115_adds_hash_columns_and_backfills_sqlite(tmp_path, monkeypatch):
    """SQLite : verify p115 adds 3 *_hash columns + backfills via hmac_pii()."""
    from app.services.audit import hmac_pepper as hp_mod
    hp_mod._get_pepper.cache_clear()

    cfg, db_url = _make_config(tmp_path, monkeypatch)

    # Upgrade to p114 (pre-p115 state ; audit_events has plaintext columns
    # but no *_hash columns).
    command.upgrade(cfg, "p114_hmac_pepper_audit")

    engine = sa.create_engine(db_url)
    pii_rows = [
        ("evt-1", "user1", "alice@example.ch", "10.0.0.1", "Mozilla/5.0"),
        ("evt-2", "user2", "bob@example.ch",   "10.0.0.2", "curl/7.85"),
        ("evt-3", "user3", None,                None,        "Mint-Mobile/2.12"),
    ]
    with engine.connect() as conn:
        for evt_id, uid, ae, ip, ua in pii_rows:
            conn.execute(
                sa.text(
                    """
                    INSERT INTO audit_events
                        (id, user_id, actor_email, ip_address, user_agent,
                         event_type, status, source, created_at)
                    VALUES
                        (:i, :u, :ae, :ip, :ua, 'login', 'success', 'api',
                         CURRENT_TIMESTAMP)
                    """
                ),
                {"i": evt_id, "u": uid, "ae": ae, "ip": ip, "ua": ua},
            )
        conn.commit()

    # Run p115
    command.upgrade(cfg, "p115_hmac_pepper_pii")

    from app.services.audit.hmac_pepper import hmac_pii

    inspector = sa.inspect(engine)
    cols = {c["name"] for c in inspector.get_columns("audit_events")}
    assert "actor_email_hash" in cols
    assert "ip_address_hash" in cols
    assert "user_agent_hash" in cols
    # Plaintext columns retained for the deprecation cycle.
    assert "actor_email" in cols
    assert "ip_address" in cols
    assert "user_agent" in cols

    indexes = {idx["name"] for idx in inspector.get_indexes("audit_events")}
    assert "ix_audit_events_actor_email_hash" in indexes
    assert "ix_audit_events_ip_address_hash" in indexes
    assert "ix_audit_events_user_agent_hash" in indexes

    with engine.connect() as conn:
        rows = conn.execute(
            sa.text(
                """
                SELECT id, actor_email, ip_address, user_agent,
                       actor_email_hash, ip_address_hash, user_agent_hash
                  FROM audit_events ORDER BY id
                """
            )
        ).fetchall()

    assert len(rows) == 3
    for row in rows:
        assert row.actor_email_hash == hmac_pii(row.actor_email)
        assert row.ip_address_hash == hmac_pii(row.ip_address)
        assert row.user_agent_hash == hmac_pii(row.user_agent)


def test_p115_handles_all_null_pii_row_without_error(tmp_path, monkeypatch):
    """A row with all-NULL PII columns should not be selected for backfill ;
    the migration's WHERE clause excludes it. Asserts no AttributeError on None."""
    from app.services.audit import hmac_pepper as hp_mod
    hp_mod._get_pepper.cache_clear()

    cfg, db_url = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "p114_hmac_pepper_audit")

    engine = sa.create_engine(db_url)
    with engine.connect() as conn:
        conn.execute(
            sa.text(
                """
                INSERT INTO audit_events
                    (id, user_id, actor_email, ip_address, user_agent,
                     event_type, status, source, created_at)
                VALUES
                    ('evt-null', 'user1', NULL, NULL, NULL,
                     'login', 'success', 'api', CURRENT_TIMESTAMP)
                """
            )
        )
        conn.commit()

    # Should not raise.
    command.upgrade(cfg, "p115_hmac_pepper_pii")

    with engine.connect() as conn:
        row = conn.execute(
            sa.text(
                "SELECT actor_email_hash, ip_address_hash, user_agent_hash "
                "FROM audit_events WHERE id = 'evt-null'"
            )
        ).fetchone()
    # All-NULL plaintext row stays all-NULL on the hash side (the WHERE
    # clause excludes it from the UPDATE pass — no rows changed).
    assert row.actor_email_hash is None
    assert row.ip_address_hash is None
    assert row.user_agent_hash is None
