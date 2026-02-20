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
    # Import models to ensure they're registered before creating tables
    from app.models import (
        User,
        ProfileModel,
        SessionModel,
        AnalyticsEvent,
        SubscriptionModel,
        EntitlementModel,
        BillingTransactionModel,
        BillingWebhookEventModel,
    )
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
        SubscriptionModel,
        EntitlementModel,
        BillingTransactionModel,
        BillingWebhookEventModel,
    )
    db = TestingSessionLocal()
    try:
        db.query(BillingWebhookEventModel).delete()
        db.query(BillingTransactionModel).delete()
        db.query(EntitlementModel).delete()
        db.query(SubscriptionModel).delete()
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
