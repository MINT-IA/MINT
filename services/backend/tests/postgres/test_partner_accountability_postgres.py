"""Real-PostgreSQL activation proofs for G1 BND-02A accountability."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import subprocess
import sys
from threading import Barrier, Event
import time
from uuid import uuid4

from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import sessionmaker
from starlette.requests import Request
import pytest

from app.api.v1.endpoints.auth import delete_account
from app.models.partner_accountability_receipt import PartnerAccountabilityReceipt
from app.models.user import User
from app.schemas.partner_accountability import PartnerAccountabilityReceiptCreate
from app.services.partner_accountability.service import (
    PartnerAccountabilityInactive,
    PartnerAccountabilityService,
)


_BACKEND = Path(__file__).resolve().parents[2]
_POSTGRES_URL_ENV = "MINT_TEST_POSTGRES_URL"
_NOTICE_VERSION = "synthetic-partner-lpp-notice-v1"
_POLICY_VERSION = "synthetic-partner-accountability-policy-v1"
_HMAC_KEY = "synthetic-postgres-key-not-for-production"


def _configured_postgres_url() -> str:
    raw = (os.environ.get(_POSTGRES_URL_ENV) or "").strip()
    if not raw:
        pytest.skip(
            f"real PostgreSQL proof requires explicit {_POSTGRES_URL_ENV}"
        )
    url = make_url(raw)
    if url.get_backend_name() != "postgresql":
        pytest.fail(f"{_POSTGRES_URL_ENV} must be a PostgreSQL URL")
    return raw


def _run_alembic(database_url: str, *args: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.update(
        {
            "DATABASE_URL": database_url,
            "ENVIRONMENT": "development",
            "TESTING": "1",
        }
    )
    return subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=_BACKEND,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )


@pytest.fixture
def postgres_database_url() -> str:
    """Create a disposable database on an explicitly supplied PostgreSQL server."""
    admin_url = make_url(_configured_postgres_url())
    database_name = f"mint_bnd02a_{uuid4().hex}"
    target_url = admin_url.set(database=database_name)
    admin_engine = create_engine(admin_url, isolation_level="AUTOCOMMIT")
    with admin_engine.connect() as connection:
        connection.exec_driver_sql(f'CREATE DATABASE "{database_name}"')
    try:
        yield target_url.render_as_string(hide_password=False)
    finally:
        with admin_engine.connect() as connection:
            connection.execute(
                text(
                    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                    "WHERE datname = :database_name AND pid <> pg_backend_pid()"
                ),
                {"database_name": database_name},
            )
            connection.exec_driver_sql(f'DROP DATABASE "{database_name}"')
        admin_engine.dispose()


@pytest.fixture
def migrated_postgres(postgres_database_url: str):
    _run_alembic(postgres_database_url, "upgrade", "head")
    engine = create_engine(postgres_database_url)
    try:
        yield engine
    finally:
        engine.dispose()


@pytest.fixture
def accountability_contract(monkeypatch):
    monkeypatch.setenv("MINT_PARTNER_ACCOUNTABILITY_HMAC_KEY", _HMAC_KEY)
    monkeypatch.delenv(
        "MINT_PARTNER_ACCOUNTABILITY_PREVIOUS_HMAC_KEYS_JSON",
        raising=False,
    )
    monkeypatch.setenv("PARTNER_LPP_NOTICE_VERSION", _NOTICE_VERSION)
    monkeypatch.setenv("PARTNER_LPP_POLICY_VERSION", _POLICY_VERSION)


def _body(*, receipt_id=None, owner_token=None) -> PartnerAccountabilityReceiptCreate:
    return PartnerAccountabilityReceiptCreate(
        receipt_id=receipt_id or uuid4(),
        subject_owner_token=str(owner_token or uuid4()),
        subject_kind="manualPartner",
        accountability_kind="acting_user_partner_authorization_declaration",
        purpose="one_shot_lpp_extraction",
        notice_version=_NOTICE_VERSION,
        policy_version=_POLICY_VERSION,
    )


def _insert_user(session_factory, *, actor_id: str) -> None:
    with session_factory() as db:
        db.add(
            User(
                id=actor_id,
                email=f"{actor_id}@example.invalid",
                hashed_password="not-a-real-password-hash",
                email_verified=True,
            )
        )
        db.commit()


def test_partner_accountability_alembic_upgrade_downgrade_round_trip(
    postgres_database_url,
):
    """The new revision must really apply and reverse on PostgreSQL."""
    _run_alembic(postgres_database_url, "upgrade", "29_05_magic_link_tokens")
    engine = create_engine(postgres_database_url)
    try:
        assert not inspect(engine).has_table("partner_accountability_receipts")

        _run_alembic(postgres_database_url, "upgrade", "head")
        table = inspect(engine).get_columns("partner_accountability_receipts")
        columns = {column["name"]: column for column in table}
        assert set(columns) == {
            "receipt_id",
            "acting_principal_pseudonym",
            "subject_owner_pseudonym",
            "subject_kind",
            "accountability_kind",
            "purpose",
            "notice_version",
            "policy_version",
            "hmac_key_id",
            "declared_at",
            "expires_at",
            "revoked_at",
            "consumed_at",
            "erased_at",
        }
        assert columns["receipt_id"]["nullable"] is False
        assert columns["declared_at"]["type"].timezone is True
        assert columns["expires_at"]["type"].timezone is True
        assert columns["consumed_at"]["type"].timezone is True
        indexes = {
            index["name"]
            for index in inspect(engine).get_indexes(
                "partner_accountability_receipts"
            )
        }
        assert indexes == {
            "ix_partner_accountability_actor_erased",
            "ix_partner_accountability_receipts_acting_principal_pseudonym",
        }

        _run_alembic(
            postgres_database_url,
            "downgrade",
            "29_05_magic_link_tokens",
        )
        assert not inspect(engine).has_table("partner_accountability_receipts")
        _run_alembic(postgres_database_url, "upgrade", "head")
        assert inspect(engine).has_table("partner_accountability_receipts")
    finally:
        engine.dispose()


def test_one_shot_consumption_serializes_two_postgres_sessions(
    migrated_postgres,
    accountability_contract,
):
    """Exactly one concurrent PostgreSQL session can consume the receipt."""
    session_factory = sessionmaker(bind=migrated_postgres, expire_on_commit=False)
    actor_id = str(uuid4())
    _insert_user(session_factory, actor_id=actor_id)
    body = _body()
    with session_factory() as db:
        row, created = PartnerAccountabilityService(db).create(
            actor_id=actor_id,
            body=body,
        )
        assert created is True
        assert row.consumed_at is None

    statements: list[str] = []

    def capture_for_update(_conn, _cursor, statement, _params, _context, _many):
        if "FOR UPDATE" in statement.upper():
            statements.append(statement)

    event.listen(migrated_postgres, "before_cursor_execute", capture_for_update)
    barrier = Barrier(3)

    def consume() -> str:
        with session_factory() as db:
            barrier.wait(timeout=5)
            try:
                PartnerAccountabilityService(db).consume_for_lpp(
                    actor_id=actor_id,
                    receipt_id=body.receipt_id,
                )
            except PartnerAccountabilityInactive:
                return "inactive"
            return "consumed"

    try:
        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(consume) for _ in range(2)]
            barrier.wait(timeout=5)
            outcomes = [future.result(timeout=10) for future in futures]
    finally:
        event.remove(migrated_postgres, "before_cursor_execute", capture_for_update)

    assert sorted(outcomes) == ["consumed", "inactive"]
    assert sum("partner_accountability_receipts" in item for item in statements) == 2
    with session_factory() as db:
        row = db.get(PartnerAccountabilityReceipt, str(body.receipt_id))
        assert row is not None
        assert row.consumed_at is not None


def test_exact_receipt_create_is_idempotent_across_postgres_sessions(
    migrated_postgres,
    accountability_contract,
):
    """Concurrent exact creates converge to one row and one created response."""
    session_factory = sessionmaker(bind=migrated_postgres, expire_on_commit=False)
    actor_id = str(uuid4())
    _insert_user(session_factory, actor_id=actor_id)
    body = _body()
    barrier = Barrier(3)

    def create() -> bool:
        with session_factory() as db:
            barrier.wait(timeout=5)
            _, created = PartnerAccountabilityService(db).create(
                actor_id=actor_id,
                body=body,
            )
            return created

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(create) for _ in range(2)]
        barrier.wait(timeout=5)
        outcomes = [future.result(timeout=10) for future in futures]

    assert sorted(outcomes) == [False, True]
    with session_factory() as db:
        assert db.query(PartnerAccountabilityReceipt).count() == 1


def test_account_delete_wins_race_without_orphan_receipt(
    migrated_postgres,
    accountability_contract,
    monkeypatch,
):
    """A create begun after delete's scan must block, then fail closed."""
    session_factory = sessionmaker(bind=migrated_postgres, expire_on_commit=False)
    actor_id = str(uuid4())
    _insert_user(session_factory, actor_id=actor_id)
    with migrated_postgres.begin() as connection:
        connection.exec_driver_sql(
            "CREATE TABLE document_embeddings (metadata jsonb NOT NULL DEFAULT '{}'::jsonb)"
        )

    scan_complete = Event()
    release_delete = Event()
    original_erase_all = PartnerAccountabilityService.erase_all_for_actor

    def erase_then_pause(self, *, actor_id):
        erased = original_erase_all(self, actor_id=actor_id)
        scan_complete.set()
        if not release_delete.wait(timeout=10):
            raise TimeoutError("test did not release account deletion")
        return erased

    monkeypatch.setattr(
        PartnerAccountabilityService,
        "erase_all_for_actor",
        erase_then_pause,
    )
    request = Request(
        {
            "type": "http",
            "method": "DELETE",
            "path": "/api/v1/auth/account",
            "headers": [],
            "client": ("127.0.0.1", 12345),
        }
    )
    delete_errors: list[BaseException] = []
    create_outcome: list[str] = []
    body = _body()

    def delete_user() -> None:
        with session_factory() as db:
            user = db.get(User, actor_id)
            assert user is not None
            try:
                delete_account.__wrapped__(
                    request=request,
                    credentials=None,
                    db=db,
                    current_user=user,
                )
            except BaseException as exc:  # surfaced in the test thread
                delete_errors.append(exc)

    def create_receipt() -> None:
        with session_factory() as db:
            db.execute(text("SET application_name = 'mint_bnd02a_race_create'"))
            try:
                PartnerAccountabilityService(db).create(
                    actor_id=actor_id,
                    body=body,
                )
            except Exception as exc:
                create_outcome.append(type(exc).__name__)
            else:
                create_outcome.append("created")

    delete_thread = ThreadPoolExecutor(max_workers=1)
    create_thread = ThreadPoolExecutor(max_workers=1)
    try:
        delete_future = delete_thread.submit(delete_user)
        assert scan_complete.wait(timeout=10)
        create_future = create_thread.submit(create_receipt)

        deadline = time.monotonic() + 5
        wait_event = None
        while time.monotonic() < deadline:
            with migrated_postgres.connect() as connection:
                wait_event = connection.execute(
                    text(
                        "SELECT wait_event_type FROM pg_stat_activity "
                        "WHERE application_name = 'mint_bnd02a_race_create'"
                    )
                ).scalar_one_or_none()
            if wait_event == "Lock":
                break
            if create_future.done():
                break
            time.sleep(0.05)
        assert wait_event == "Lock", (
            "receipt creation did not wait on the deleting actor row; "
            f"outcome={create_outcome}"
        )

        release_delete.set()
        delete_future.result(timeout=10)
        create_future.result(timeout=10)
    finally:
        release_delete.set()
        delete_thread.shutdown(wait=True, cancel_futures=True)
        create_thread.shutdown(wait=True, cancel_futures=True)

    assert not delete_errors
    assert create_outcome == ["PartnerAccountabilityActorUnavailable"]
    with session_factory() as db:
        assert db.get(User, actor_id) is None
        assert db.get(PartnerAccountabilityReceipt, str(body.receipt_id)) is None


def test_receipt_create_wins_race_and_account_delete_erases_it(
    migrated_postgres,
    accountability_contract,
    monkeypatch,
):
    """A delete waiting behind creation must see and erase the committed receipt."""
    session_factory = sessionmaker(bind=migrated_postgres, expire_on_commit=False)
    actor_id = str(uuid4())
    _insert_user(session_factory, actor_id=actor_id)
    with migrated_postgres.begin() as connection:
        connection.exec_driver_sql(
            "CREATE TABLE document_embeddings (metadata jsonb NOT NULL DEFAULT '{}'::jsonb)"
        )

    actor_locked = Event()
    release_create = Event()
    original_lock_actor = (
        PartnerAccountabilityService._lock_actor_for_receipt_write
    )

    def lock_then_pause(self, *, actor_id):
        original_lock_actor(self, actor_id=actor_id)
        actor_locked.set()
        if not release_create.wait(timeout=10):
            raise TimeoutError("test did not release receipt creation")

    monkeypatch.setattr(
        PartnerAccountabilityService,
        "_lock_actor_for_receipt_write",
        lock_then_pause,
    )
    request = Request(
        {
            "type": "http",
            "method": "DELETE",
            "path": "/api/v1/auth/account",
            "headers": [],
            "client": ("127.0.0.1", 12345),
        }
    )
    body = _body()
    create_errors: list[BaseException] = []
    delete_errors: list[BaseException] = []

    def create_receipt() -> None:
        with session_factory() as db:
            try:
                _, created = PartnerAccountabilityService(db).create(
                    actor_id=actor_id,
                    body=body,
                )
                assert created is True
            except BaseException as exc:  # surfaced in the test thread
                create_errors.append(exc)

    def delete_user() -> None:
        with session_factory() as db:
            db.execute(text("SET application_name = 'mint_bnd02a_race_delete'"))
            user = db.get(User, actor_id)
            assert user is not None
            try:
                delete_account.__wrapped__(
                    request=request,
                    credentials=None,
                    db=db,
                    current_user=user,
                )
            except BaseException as exc:  # surfaced in the test thread
                delete_errors.append(exc)

    create_thread = ThreadPoolExecutor(max_workers=1)
    delete_thread = ThreadPoolExecutor(max_workers=1)
    try:
        create_future = create_thread.submit(create_receipt)
        assert actor_locked.wait(timeout=10)
        delete_future = delete_thread.submit(delete_user)

        deadline = time.monotonic() + 5
        wait_event = None
        while time.monotonic() < deadline:
            with migrated_postgres.connect() as connection:
                wait_event = connection.execute(
                    text(
                        "SELECT wait_event_type FROM pg_stat_activity "
                        "WHERE application_name = 'mint_bnd02a_race_delete'"
                    )
                ).scalar_one_or_none()
            if wait_event == "Lock":
                break
            if delete_future.done():
                break
            time.sleep(0.05)
        assert wait_event == "Lock", (
            "account deletion did not wait on receipt creation; "
            f"errors={delete_errors}"
        )

        release_create.set()
        create_future.result(timeout=10)
        delete_future.result(timeout=10)
    finally:
        release_create.set()
        create_thread.shutdown(wait=True, cancel_futures=True)
        delete_thread.shutdown(wait=True, cancel_futures=True)

    assert not create_errors
    assert not delete_errors
    with session_factory() as db:
        assert db.get(User, actor_id) is None
        tombstone = db.get(PartnerAccountabilityReceipt, str(body.receipt_id))
        assert tombstone is not None
        assert tombstone.erased_at is not None
        assert tombstone.acting_principal_pseudonym is None
        assert tombstone.subject_owner_pseudonym is None
        assert tombstone.hmac_key_id is None
