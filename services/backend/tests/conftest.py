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

# Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-22) — real-Postgres pg_fixture.
# Imported at module-import so `pytest --collect-only` discovers `pg_engine`/`pg_session`.
# The fixture itself self-skips if Docker is unavailable on the host (local-dev path).
from tests.fixtures.pg_fixture import pg_engine, pg_session  # noqa: F401


def pytest_configure(config):
    """Register the `pg` marker for Phase 02 real-Postgres tests (D-22)."""
    config.addinivalue_line(
        "markers",
        "pg: real-Postgres integration test (uses pg_fixture testcontainers, "
        "skips if Docker unavailable). Phase mint-data-architecture-v1-02 D-22.",
    )


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


@pytest.fixture
def client_with_blank_profile():
    """Concern D (Karpathy #4 reproduce-the-bug-first) — yields a TestClient
    authenticated as the conftest `_fake_user` whose `profile.data == {}`.

    Use in one contract test per Wave-1-fixed endpoint to assert 422 fires
    when profile fields are missing (D-CE-08 + CoachToolIncomplete envelope).

    Without this fixture, happy-path test bodies that pass all fields
    explicit-set pass the 422 check even though real users with blank profiles
    would hit the bug. The fixture is the cheapest way to reproduce the bug
    that ships to production today.
    """
    from uuid import uuid4
    from app.models.profile_model import ProfileModel

    # Override the same dependencies as the standard `client` fixture.
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user

    # Insert a ProfileModel row with data={} tied to _fake_user.id.
    db = TestingSessionLocal()
    profile = ProfileModel(
        id=str(uuid4()),
        user_id="test-user-id",  # matches _fake_user() above
        data={},
    )
    db.add(profile)
    db.commit()
    db.close()

    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        # Clean up the row (clean_database autouse handles it for next test,
        # but be explicit so the fixture is self-contained).
        cleanup = TestingSessionLocal()
        try:
            cleanup.query(ProfileModel).filter(
                ProfileModel.user_id == "test-user-id"
            ).delete()
            cleanup.commit()
        finally:
            cleanup.close()
        app.dependency_overrides.clear()
