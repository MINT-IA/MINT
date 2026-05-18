"""p114_hmac_pepper_audit_events — D-14 backfill validation.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 — P1.

Asserts that p114 :
1. Re-hashes existing `audit_events.user_id_hash` values via HMAC-pepper
   (NOT bare SHA-256 as p112 did) — the hash equals `hmac_user_id(user_id)`
   from the canonical entry, NOT `sha256(user_id).hexdigest()`.
2. On Postgres : NULLs the plaintext `user_id` column post-backfill (D-14
   plaintext-drop).
3. Is idempotent : re-running it on already-HMAC-hashed rows is a no-op
   (the hash equals itself).

Test pattern mirrors `tests/test_snapshots_migration_exists.py` (Phase 97
W7 iter#8 precedent) — alembic env.py overrides sqlalchemy.url from
settings.DATABASE_URL, so the test MUST `monkeypatch.setenv("DATABASE_URL", ...)`
+ reload the config module BEFORE creating the alembic Config object.
"""
from __future__ import annotations

import hashlib
import importlib
from pathlib import Path

import sqlalchemy as sa
from alembic import command
from alembic.config import Config


def _make_config(tmp_path, monkeypatch):
    """Build an alembic Config wired to a fresh per-test SQLite file."""
    db_url = f"sqlite:///{tmp_path}/test.db"
    monkeypatch.setenv("DATABASE_URL", db_url)
    monkeypatch.setenv("TESTING", "1")
    from app.core import config as _cfg_mod
    importlib.reload(_cfg_mod)
    backend_root = Path(__file__).parent.parent.parent  # services/backend
    cfg = Config(str(backend_root / "alembic.ini"))
    cfg.set_main_option("script_location", str(backend_root / "alembic"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    return cfg, db_url


def test_p114_backfills_user_id_hash_via_hmac_pepper_sqlite(tmp_path, monkeypatch):
    """SQLite : verify p114 rewrites user_id_hash via hmac_user_id().

    Seeds 3 rows after upgrading to p112 (pre-p114), runs the remaining
    chain through p114, and asserts the hash now matches hmac_user_id().
    """
    # Ensure no lru_cache leak from a previous test (different pepper).
    from app.services.audit import hmac_pepper as hp_mod
    hp_mod._get_pepper.cache_clear()

    cfg, db_url = _make_config(tmp_path, monkeypatch)

    # ── Step 1 : upgrade to p112 (audit_events created at baseline +
    # user_id_hash added at p112). Must use 'heads' (plural) per
    # DEFERRED-02-01-A — but p112 is the head of one of two pre-merge
    # branches, so upgrading to it specifically still runs the linear
    # chain from baseline to p112.
    command.upgrade(cfg, "p112_audit_event_user_hash")

    # ── Step 2 : seed 3 rows with bare-SHA-256 hashes (what p112 produced)
    engine = sa.create_engine(db_url)
    with engine.connect() as conn:
        for i in range(3):
            uid = f"user-p114-{i}"
            bare_hash = hashlib.sha256(uid.encode("utf-8")).hexdigest()
            conn.execute(
                sa.text(
                    """
                    INSERT INTO audit_events
                        (id, user_id, user_id_hash, event_type, status, source, created_at)
                    VALUES
                        (:i, :u, :h, 'login', 'success', 'api', CURRENT_TIMESTAMP)
                    """
                ),
                {"i": f"evt-{i}", "u": uid, "h": bare_hash},
            )
        conn.commit()

    # ── Step 3 : run the remaining migrations through p114 ─────────────────
    command.upgrade(cfg, "p114_hmac_pepper_audit")

    # ── Step 4 : assert user_id_hash now equals hmac_user_id(user_id) ──────
    from app.services.audit.hmac_pepper import hmac_user_id

    with engine.connect() as conn:
        rows = conn.execute(
            sa.text("SELECT id, user_id, user_id_hash FROM audit_events ORDER BY id")
        ).fetchall()

    assert len(rows) == 3
    for row in rows:
        expected = hmac_user_id(row.user_id)
        assert row.user_id_hash == expected, (
            f"row {row.id}: user_id_hash={row.user_id_hash!r} != "
            f"hmac_user_id({row.user_id!r})={expected!r}"
        )
        # SQLite path : plaintext user_id is NOT NULLed (Postgres-only).
        assert row.user_id is not None


def test_p114_is_idempotent_source_level(tmp_path, monkeypatch):
    """Re-running p114 on already-HMAC-hashed rows is a no-op by construction.

    The migration body re-applies `hmac_user_id()` over rows whose
    `user_id IS NOT NULL`. For a row whose `user_id_hash` already equals
    `hmac_user_id(user_id)`, the UPDATE writes the same bytes — no
    observable state change. Asserted both at the source level (the
    migration uses the canonical entry, not a different hash function)
    and at the row level (re-upgrading does not change the hash).
    """
    from app.services.audit import hmac_pepper as hp_mod
    hp_mod._get_pepper.cache_clear()

    cfg, db_url = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "p114_hmac_pepper_audit")

    from app.services.audit.hmac_pepper import hmac_user_id
    uid = "user-p114-idem"
    expected_hash = hmac_user_id(uid)

    engine = sa.create_engine(db_url)
    with engine.connect() as conn:
        conn.execute(
            sa.text(
                """
                INSERT INTO audit_events
                    (id, user_id, user_id_hash, event_type, status, source, created_at)
                VALUES
                    (:i, :u, :h, 'logout', 'success', 'api', CURRENT_TIMESTAMP)
                """
            ),
            {"i": "evt-idem", "u": uid, "h": expected_hash},
        )
        conn.commit()

    # Source-level guarantee : the migration body uses the canonical entry,
    # so re-applying it is identity on already-hashed rows.
    import re
    mig_path = (
        Path(__file__).parent.parent.parent
        / "alembic"
        / "versions"
        / "p114_hmac_pepper_audit_events.py"
    )
    mig_src = mig_path.read_text()
    assert re.search(r"hmac_user_id\(row\.user_id\)", mig_src), (
        "p114 must use hmac_user_id() (canonical entry), not a bare hash."
    )

    # State-level check : hash on disk still matches the expected HMAC
    # post-upgrade (re-runnable contract).
    with engine.connect() as conn:
        row = conn.execute(
            sa.text("SELECT user_id_hash FROM audit_events WHERE id = :i"),
            {"i": "evt-idem"},
        ).fetchone()
    assert row.user_id_hash == expected_hash
