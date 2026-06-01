"""Phase 97.5 W2-T6 — backfill migration tests.

Covers `tools/migrations/grant_default_consents_existing_users.py` :
    1. Idempotent re-run: second invocation grants zero new rows.
    2. --dry-run: prints WOULD GRANT lines, does NOT touch the DB.
    3. --confirm guard: non-dry-run without `--confirm staging` returns
       exit-code 2 (refuses to run).

The migration uses `email_verified=True` as the v2.9 cohort proxy (per
julien-go 2026-05-12 + W2-CONSENT-RECEIPT §Data-gaps).

Run :
    cd services/backend && python3 -m pytest tests/test_grant_default_consents_migration.py -v
"""
from __future__ import annotations

import importlib.util
import uuid
from pathlib import Path

import pytest

from app.models.consent import ConsentModel
from app.models.user import User
from app.schemas.consent_receipt import ConsentPurpose
from tests.conftest import TestingSessionLocal


_REPO_ROOT = Path(__file__).resolve().parents[3]
_MIGRATION_PATH = (
    _REPO_ROOT / "tools" / "migrations" / "grant_default_consents_existing_users.py"
)


def _load_migration_module():
    """Import the migration script as a module (it lives outside `app.*`)."""
    spec = importlib.util.spec_from_file_location(
        "_mint_consent_backfill_migration", _MIGRATION_PATH
    )
    assert spec and spec.loader, f"failed to spec the migration at {_MIGRATION_PATH}"
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


@pytest.fixture
def migration():
    return _load_migration_module()


@pytest.fixture
def session_local_patch(monkeypatch, migration):
    """Point the migration's SessionLocal at the test in-memory DB.

    The migration imports `SessionLocal` from `app.core.database` at module
    load time. We patch the attribute on the loaded module so calls inside
    `run_backfill()` use the test DB instead of the dev mint.db file.
    """
    monkeypatch.setattr(migration, "SessionLocal", TestingSessionLocal)
    yield


def _seed_users(*, n_verified: int, n_unverified: int) -> list[str]:
    """Create N verified + M unverified users. Returns the verified user IDs."""
    db = TestingSessionLocal()
    verified_ids: list[str] = []
    try:
        for i in range(n_verified):
            uid = f"verified-{i}-{uuid.uuid4().hex[:8]}"
            db.add(User(
                id=uid,
                email=f"v{i}@mint.ch",
                hashed_password="x",
                email_verified=True,
            ))
            verified_ids.append(uid)
        for i in range(n_unverified):
            db.add(User(
                id=f"unverified-{i}-{uuid.uuid4().hex[:8]}",
                email=f"u{i}@mint.ch",
                hashed_password="x",
                email_verified=False,
            ))
        db.commit()
    finally:
        db.close()
    return verified_ids


def _count_backfill_rows() -> int:
    """Count rows produced by the backfill — identified by basis field."""
    db = TestingSessionLocal()
    try:
        count = 0
        for row in db.query(ConsentModel).filter(
            ConsentModel.purpose_category.in_([
                ConsentPurpose.TRANSFER_US_ANTHROPIC.value,
                ConsentPurpose.PERSISTENCE_365D.value,
            ])
        ).all():
            rj = row.receipt_json or {}
            if rj.get("basis") == "legal-continuity-pre-granular-T&C":
                count += 1
        return count
    finally:
        db.close()


# ---------------------------------------------------------------------------
# 1. Idempotent re-run
# ---------------------------------------------------------------------------


def test_backfill_is_idempotent(migration, session_local_patch):
    """First live run grants N×2 rows ; second live run grants 0."""
    _seed_users(n_verified=3, n_unverified=2)

    granted_first, _ = migration.run_backfill(dry_run=False)
    assert granted_first == 3 * 2, (
        f"expected 6 grants (3 verified users × 2 purposes), got {granted_first}"
    )
    assert _count_backfill_rows() == 6

    # Second run — every (user, purpose) already has an active grant.
    granted_second, skipped_second = migration.run_backfill(dry_run=False)
    assert granted_second == 0, (
        f"idempotency violated: re-run granted {granted_second} rows"
    )
    assert skipped_second == 6
    # No new rows on disk.
    assert _count_backfill_rows() == 6


def test_backfill_skips_unverified_users(migration, session_local_patch):
    """Users with email_verified=False are not in the backfill cohort."""
    _seed_users(n_verified=2, n_unverified=5)

    granted, _ = migration.run_backfill(dry_run=False)
    assert granted == 2 * 2, (
        f"only verified users should be backfilled ; got {granted}"
    )


# ---------------------------------------------------------------------------
# 2. Dry-run does NOT write to the DB
# ---------------------------------------------------------------------------


def test_dry_run_does_not_write(migration, session_local_patch, capsys):
    """--dry-run prints WOULD GRANT lines but inserts zero rows."""
    _seed_users(n_verified=2, n_unverified=0)

    granted, _ = migration.run_backfill(dry_run=True)
    assert granted == 4  # 2 users × 2 purposes — counted, not written

    # No physical backfill rows in DB.
    assert _count_backfill_rows() == 0

    # Output contains WOULD GRANT lines (2 users × 2 purposes = 4 lines).
    out = capsys.readouterr().out
    would_grant_lines = [ln for ln in out.splitlines() if ln.startswith("WOULD GRANT")]
    assert len(would_grant_lines) == 4, (
        f"expected 4 WOULD GRANT lines, got {len(would_grant_lines)} : {out!r}"
    )


# ---------------------------------------------------------------------------
# 3. --confirm guard
# ---------------------------------------------------------------------------


def test_live_run_without_confirm_returns_exit_2(migration, session_local_patch):
    """`main([])` (no --dry-run, no --confirm) refuses with exit 2."""
    exit_code = migration.main([])
    assert exit_code == 2, f"expected exit 2 ; got {exit_code}"


def test_live_run_with_wrong_confirm_returns_exit_2(migration, session_local_patch):
    """`--confirm production` (not 'staging') still refuses with exit 2."""
    exit_code = migration.main(["--confirm", "production"])
    assert exit_code == 2


def test_live_run_with_confirm_staging_executes(migration, session_local_patch):
    """`--confirm staging` actually runs and returns 0."""
    _seed_users(n_verified=1, n_unverified=0)
    exit_code = migration.main(["--confirm", "staging"])
    assert exit_code == 0
    assert _count_backfill_rows() == 2  # 1 user × 2 purposes


def test_dry_run_via_main_returns_exit_0_without_confirm(migration, session_local_patch):
    """`--dry-run` does NOT require --confirm."""
    _seed_users(n_verified=1, n_unverified=0)
    exit_code = migration.main(["--dry-run"])
    assert exit_code == 0
    assert _count_backfill_rows() == 0
