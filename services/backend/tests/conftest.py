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


# ---------------------------------------------------------------------------
# Settings singleton reload contamination guard (autouse)
# ---------------------------------------------------------------------------
#
# Several backend tests call `importlib.reload(app.core.config)` to test
# env-var pickup at Settings init. This swaps `app.core.config.settings`
# for a NEW Settings instance. Every other module in the codebase that did
# `from app.core.config import settings` at module load time still holds
# a NAME binding to the ORIGINAL instance. Downstream tests then
# `monkeypatch.setattr(settings, "X", v)` to patch the ORIGINAL, but
# production code paths that re-import (in-function) or live in modules
# loaded AFTER the contaminating reload see the NEW instance — the patches
# are ignored.
#
# This autouse fixture snapshots the original singleton at session start
# and restores it after every test. Cost : a single attribute write per
# test (~µs). Benefit : no test ever sees a contaminated singleton.
@pytest.fixture(autouse=True)
def _restore_settings_singleton():
    """Snapshot + restore `app.core.config.settings` per test.

    Prevents `importlib.reload(app.core.config)` in any test from
    contaminating downstream tests' module-level `settings` references.
    """
    from app.core import config as _cfg_mod
    original_settings = _cfg_mod.settings
    yield
    _cfg_mod.settings = original_settings


def pytest_configure(config):
    """Register markers for Phase 02 real-Postgres tests.

    - `pg` (D-22) : continuation-2/3 baseline marker.
    - `requires_pg` (iter-3 iA1) : explicit « skip with visible reason when
      Docker unavailable » marker. Applied to projector tests so SQLite-only
      runs do NOT silently pass on the SQLite emulation path. Per
      Claude-Opus post-iter-2 review HIGH-A1 + CLAUDE.md §9.2 « tests passing
      != feature working ». The projector's atomic UPSERT semantics are
      Postgres-only ; the SQLite emulation is test-fixture-only and does
      NOT enforce lost-update protection under concurrent writers.
    """
    config.addinivalue_line(
        "markers",
        "pg: real-Postgres integration test (uses pg_fixture testcontainers, "
        "skips if Docker unavailable). Phase mint-data-architecture-v1-02 D-22.",
    )
    config.addinivalue_line(
        "markers",
        "requires_pg: test requires real Postgres (iter-3 iA1 — projector "
        "SQLite-path divergence trap). Skips with explicit message when "
        "Docker unavailable. Use this INSTEAD of `pg` when the test asserts "
        "Postgres-only guarantees (PARTITION BY HASH routing, REVOKE "
        "enforcement, atomic UPSERT under concurrency, INCLUDE covering "
        "index). Per Claude-Opus HIGH-A1 (REVIEWS.md §7.3).",
    )


def pytest_collection_modifyitems(config, items):
    """iter-3 iA1: auto-skip `requires_pg` tests when Docker unavailable.

    The `pg_session` fixture itself self-skips on Docker unavailable, but
    that produces a silent SKIPPED without a clear « projector requires
    Postgres » reason. This hook surfaces the « requires_pg » semantic
    explicitly in collection output.
    """
    # Lazy detection : only probe Docker if at least one `requires_pg` test
    # exists in this collection. Avoids a 1-2s Docker probe on every pytest
    # invocation (including pure unit suites that don't need pg).
    has_requires_pg = any(
        item.get_closest_marker("requires_pg") is not None for item in items
    )
    if not has_requires_pg:
        return

    import shutil
    docker_available = shutil.which("docker") is not None
    if docker_available:
        # Docker binary present ; trust pg_fixture to do the real probe (it
        # tries to start a container and skips on failure). We don't skip
        # here.
        return

    import pytest as _pytest
    skip_marker = _pytest.mark.skip(
        reason="requires Postgres (iter-3 iA1) — Docker binary not found on host"
    )
    for item in items:
        if item.get_closest_marker("requires_pg") is not None:
            item.add_marker(skip_marker)


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


def seed_transfer_consent(user_id: str = "test-user-id") -> None:
    """Seed the TRANSFER_US_ANTHROPIC grant for the fixture user.

    beads MINT_nosync-tcr : CONSENT_GATE_ENFORCEMENT_MODE est hard_block par
    défaut — le coach 403 sans grant. Les fixtures modélisent l'utilisateur
    POST-consentement (le mobile obtient le grant à son premier message via
    la ConsentSheet). Les tests du chemin SANS grant suppriment les receipts
    (voir test_consent_gate_default_hard_block.py).
    """
    from app.services.consent.consent_service import (
        consent_service as _consent_svc,
    )

    db = TestingSessionLocal()
    try:
        _consent_svc.grant(
            db,
            user_id=user_id,
            purpose="transfer_us_anthropic",
            policy_version="v2.4.0",
        )
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
    seed_transfer_consent()

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
    seed_transfer_consent()

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
