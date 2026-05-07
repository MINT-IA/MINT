"""
Test configuration and fixtures.
"""

import os
from unittest.mock import MagicMock

# Disable rate limiting in tests
os.environ["TESTING"] = "1"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.main import app
from app.core.auth import get_current_user, require_current_user
from app.core.database import Base, get_db


def _fake_user():
    """Return a mock user for auth dependency override in tests."""
    from datetime import datetime
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    user.created_at = datetime(2025, 1, 1)
    return user

# Create in-memory SQLite database for tests with StaticPool
# StaticPool ensures all connections use the same in-memory database
SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,  # Use StaticPool to share in-memory database across connections
)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    """Override database dependency for tests."""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


# Create tables once at module level
@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    """Create database tables once for all tests."""
    # Import models to ensure they're registered with SQLAlchemy before create_all
    import app.models.user  # noqa: F401
    import app.models  # noqa: F401
    from app.models.banking_consent import BankingConsentModel  # noqa: F401
    from app.models.external_data_source import ExternalDataSourceModel  # noqa: F401
    from app.models.token_blacklist import TokenBlacklist  # noqa: F401
    from app.models.document import DocumentModel  # noqa: F401

    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function", autouse=True)
def clean_database():
    """Clean all tables before each test."""
    # Delete all data from tables before each test
    from app.models import (
        AnalyticsEvent,
        SessionModel,
        ProfileModel,
        User,
        LoginSecurityStateModel,
        PasswordResetTokenModel,
        EmailVerificationTokenModel,
        SubscriptionModel,
        EntitlementModel,
        BillingTransactionModel,
        BillingWebhookEventModel,
        AuditEventModel,
        HouseholdModel,
        HouseholdMemberModel,
        AdminAuditEventModel,
        SnapshotModel,
        ConsentModel,
    )
    from app.models.banking_consent import BankingConsentModel
    from app.models.external_data_source import ExternalDataSourceModel
    from app.models.token_blacklist import TokenBlacklist
    from app.models.document import DocumentModel  # noqa: F811
    from app.models.scenario import ScenarioModel
    db = TestingSessionLocal()
    try:
        db.query(ScenarioModel).delete()
        db.query(DocumentModel).delete()
        db.query(TokenBlacklist).delete()
        db.query(ExternalDataSourceModel).delete()
        db.query(BankingConsentModel).delete()
        db.query(SnapshotModel).delete()
        db.query(ConsentModel).delete()
        db.query(BillingWebhookEventModel).delete()
        db.query(EmailVerificationTokenModel).delete()
        db.query(PasswordResetTokenModel).delete()
        db.query(LoginSecurityStateModel).delete()
        db.query(AdminAuditEventModel).delete()
        db.query(AuditEventModel).delete()
        db.query(BillingTransactionModel).delete()
        db.query(EntitlementModel).delete()
        db.query(SubscriptionModel).delete()
        db.query(HouseholdMemberModel).delete()
        db.query(HouseholdModel).delete()
        db.query(AnalyticsEvent).delete()
        db.query(SessionModel).delete()
        db.query(ProfileModel).delete()
        db.query(User).delete()
        db.commit()
    finally:
        db.close()


@pytest.fixture
def client():
    """Test client with test database and auth override."""
    # Override the database and auth dependencies
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user

    with TestClient(app) as test_client:
        yield test_client

    # Clean up
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Phase 95 Plan 95-03 / TEST-04 — testcontainers-Postgres opt-in fixtures.
#
# Additive only: nothing above this line is touched. Tests opt in via
#     pytestmark = pytest.mark.postgres
# AND by requesting `pg_engine` / `pg_db` explicitly. Tests that don't ask
# for those fixtures keep using the in-memory SQLite path.
#
# Local dev: needs Docker Desktop running. When Docker is unavailable
# (CI without DinD, local laptop without Docker) the fixture skips with a
# clear reason — never raises (Karpathy 3 / surgical: keep the SQLite
# fast-path green for the 99% of tests that don't need Postgres).
#
# CI: the .github/workflows/ci.yml `alembic-check` job uses a sidecar
# `services: postgres` container instead of testcontainers (managed by
# GH Actions, faster than Docker-from-pytest in the runner). Both code
# paths converge on `DATABASE_URL` / SQLAlchemy create_engine.
# ---------------------------------------------------------------------------


def _external_postgres_url():
    """Return DATABASE_URL if it already points at a Postgres instance.

    Returns ``str`` when an external Postgres URL is configured, ``None``
    otherwise.

    CI runs the `alembic-check` job with a `services: postgres` sidecar
    and exports DATABASE_URL up-front; in that case we reuse the sidecar
    instead of spinning a second container via testcontainers (avoids
    Docker-in-Docker complications + halves the test runtime).
    """
    import os

    url = os.environ.get("DATABASE_URL")
    if url and url.startswith(("postgresql://", "postgresql+psycopg2://", "postgres://")):
        return url
    return None


@pytest.fixture(scope="session")
def postgres_container():
    """Spin up a fresh `postgres:15-alpine` container per pytest session.

    Two code paths converge on the same `pg_engine` URL contract:
      1. CI (alembic-check job) — DATABASE_URL already points at the
         GH Actions Postgres sidecar; we yield a tiny shim object so
         pg_engine reads `.get_connection_url()` without spawning a
         second Docker container.
      2. Local dev — testcontainers spawns postgres:15-alpine via
         Docker. Skips with a clear reason if Docker is not reachable
         (no daemon, no socket, permission denied) so non-Postgres
         tests on a Docker-less laptop still run green.
    """
    external_url = _external_postgres_url()
    if external_url is not None:
        # CI sidecar path — no Docker spawn.
        class _ExternalPg:
            def get_connection_url(self) -> str:
                return external_url

        yield _ExternalPg()
        return

    try:
        # Defer import so the dev dep is only required when the fixture
        # is actually requested. Tests that never ask for `pg_*` don't
        # pay the import cost (or the install cost, since the suite
        # tolerates `testcontainers` being absent in minimal envs).
        from testcontainers.postgres import PostgresContainer
    except ImportError as exc:  # pragma: no cover - dev-extras-not-installed branch
        pytest.skip(
            f"testcontainers[postgres] not installed: {exc}. "
            "Install with `pip install -e .[dev]` from services/backend/."
        )

    try:
        import docker  # type: ignore  # transitive dep of testcontainers

        # Cheap probe — raises DockerException if the daemon is unreachable.
        docker.from_env().ping()
    except Exception as exc:  # pragma: no cover - non-Docker dev laptops
        pytest.skip(f"Docker unavailable, skipping Postgres fixture: {exc}")

    pg = PostgresContainer("postgres:15-alpine")
    pg.start()
    try:
        yield pg
    finally:
        # Container teardown: log + rethrow on failure (never silently
        # swallow per CLAUDE.md / no-bare-catches discipline).
        try:
            pg.stop()
        except Exception:
            import logging

            logging.exception(
                "[Phase95/TEST-04] PostgresContainer teardown failed; "
                "container may be left running. Manual cleanup may be needed."
            )
            raise


@pytest.fixture(scope="session")
def pg_engine(postgres_container):
    """Session-scoped SQLAlchemy engine bound to the Postgres container.

    Runs `alembic upgrade head` once per session so the schema is at
    HEAD before any opt-in test executes. Tests that need to walk the
    full ladder (forward/rollback/check) call alembic.command.* directly
    against this engine — see test_alembic_full_chain.py.
    """
    from sqlalchemy import create_engine

    url = postgres_container.get_connection_url()
    eng = create_engine(url, future=True)

    # Run alembic upgrade head once per session, with DATABASE_URL pointing
    # at the testcontainers instance so env.py picks up the right URL.
    import os

    from alembic import command
    from alembic.config import Config

    backend_dir = os.path.abspath(
        os.path.join(os.path.dirname(__file__), os.pardir)
    )
    cfg = Config(os.path.join(backend_dir, "alembic.ini"))
    # alembic.ini lives in services/backend; script_location is relative
    # to %(here)s so it already resolves correctly when we point Config
    # at the absolute path above.
    cfg.set_main_option("sqlalchemy.url", url)

    prev_db_url = os.environ.get("DATABASE_URL")
    os.environ["DATABASE_URL"] = url
    try:
        command.upgrade(cfg, "head")
    finally:
        if prev_db_url is None:
            os.environ.pop("DATABASE_URL", None)
        else:
            os.environ["DATABASE_URL"] = prev_db_url

    try:
        yield eng
    finally:
        eng.dispose()


@pytest.fixture(scope="function")
def pg_db(pg_engine):
    """Per-test session bound to the testcontainers-Postgres engine.

    Wraps the test in an outer transaction + SAVEPOINT and rolls back
    on teardown so each test sees a clean slate without paying for a
    full `drop_all + create_all` cycle (too slow on Postgres).
    """
    from sqlalchemy.orm import sessionmaker

    connection = pg_engine.connect()
    transaction = connection.begin()
    SessionPg = sessionmaker(bind=connection, autocommit=False, autoflush=False)
    session = SessionPg()
    try:
        yield session
    finally:
        session.close()
        try:
            transaction.rollback()
        finally:
            connection.close()
