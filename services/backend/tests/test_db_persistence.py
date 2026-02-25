"""
Tests for DB persistence — Snapshots + Consent with SQLAlchemy.

Verifies that snapshot_service and consent_manager work correctly
when a DB session is provided (production mode) vs in-memory (fallback).

Sources:
    - LPD art. 6 (droit a l'effacement)
    - nLPD art. 5 let. f (profilage)
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.snapshot import SnapshotModel
from app.models.consent import ConsentModel
from app.services.snapshots.snapshot_service import (
    create_snapshot,
    get_snapshots,
    delete_all_snapshots,
    get_evolution,
)
from app.services.reengagement.consent_manager import ConsentManager
from app.services.reengagement.reengagement_models import ConsentType


# ===================================================================
# Test DB setup (isolated in-memory SQLite)
# ===================================================================

TEST_DB_URL = "sqlite:///:memory:"

_engine = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

_SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_engine)


@pytest.fixture(autouse=True)
def db_session():
    """Create tables, yield a session, then drop tables."""
    Base.metadata.create_all(bind=_engine)
    session = _SessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=_engine)


USER_ID = "test-user-db-001"


# ===================================================================
# 1. Snapshot DB persistence (6 tests)
# ===================================================================


class TestSnapshotDbPersistence:
    """Snapshot CRUD with actual DB session."""

    def test_create_snapshot_persists_to_db(self, db_session):
        """create_snapshot with db writes to the snapshots table."""
        snap = create_snapshot(
            user_id=USER_ID,
            trigger="quarterly",
            profile_data={"age": 35, "fri_total": 72.0},
            db=db_session,
        )
        assert snap.user_id == USER_ID
        assert snap.age == 35
        assert snap.fri_total == 72.0
        # Verify in DB
        count = db_session.query(SnapshotModel).filter_by(user_id=USER_ID).count()
        assert count == 1

    def test_get_snapshots_from_db(self, db_session):
        """get_snapshots with db reads from the snapshots table."""
        create_snapshot(USER_ID, "quarterly", {"fri_total": 60.0}, db=db_session)
        create_snapshot(USER_ID, "life_event", {"fri_total": 65.0}, db=db_session)
        snaps = get_snapshots(USER_ID, db=db_session)
        assert len(snaps) == 2
        # Most recent first
        assert snaps[0].fri_total == 65.0

    def test_get_snapshots_respects_limit(self, db_session):
        """get_snapshots with db respects limit parameter."""
        for i in range(5):
            create_snapshot(USER_ID, "quarterly", {"age": 30 + i}, db=db_session)
        snaps = get_snapshots(USER_ID, limit=3, db=db_session)
        assert len(snaps) == 3

    def test_delete_all_snapshots_from_db(self, db_session):
        """delete_all_snapshots with db removes all user rows."""
        create_snapshot(USER_ID, "quarterly", {}, db=db_session)
        create_snapshot(USER_ID, "life_event", {}, db=db_session)
        count = delete_all_snapshots(USER_ID, db=db_session)
        assert count == 2
        remaining = get_snapshots(USER_ID, db=db_session)
        assert len(remaining) == 0

    def test_delete_snapshots_lpd_right_to_erasure(self, db_session):
        """LPD compliance: delete returns 0 for unknown user."""
        count = delete_all_snapshots("unknown-user", db=db_session)
        assert count == 0

    def test_get_evolution_from_db(self, db_session):
        """get_evolution with db returns chronological time series."""
        create_snapshot(USER_ID, "quarterly", {"replacement_ratio": 0.55}, db=db_session)
        create_snapshot(USER_ID, "quarterly", {"replacement_ratio": 0.60}, db=db_session)
        evo = get_evolution(USER_ID, field="replacement_ratio", db=db_session)
        assert len(evo) == 2
        assert evo[0]["value"] == 0.55
        assert evo[1]["value"] == 0.60


# ===================================================================
# 2. Consent DB persistence (8 tests)
# ===================================================================


class TestConsentDbPersistence:
    """Consent CRUD with actual DB session."""

    def test_consent_off_by_default_in_db(self, db_session):
        """New user has no consent rows — defaults to False."""
        assert ConsentManager.is_consent_given(USER_ID, ConsentType.byok_data_sharing, db=db_session) is False

    def test_enable_consent_persists_to_db(self, db_session):
        """update_consent with db creates a row in the consents table."""
        ConsentManager.update_consent(USER_ID, ConsentType.byok_data_sharing, True, db=db_session)
        assert ConsentManager.is_consent_given(USER_ID, ConsentType.byok_data_sharing, db=db_session) is True
        count = db_session.query(ConsentModel).filter_by(user_id=USER_ID).count()
        assert count == 1

    def test_disable_consent_updates_db(self, db_session):
        """Disabling consent updates existing row rather than creating new."""
        ConsentManager.update_consent(USER_ID, ConsentType.byok_data_sharing, True, db=db_session)
        ConsentManager.update_consent(USER_ID, ConsentType.byok_data_sharing, False, db=db_session)
        assert ConsentManager.is_consent_given(USER_ID, ConsentType.byok_data_sharing, db=db_session) is False
        # Still only 1 row (upsert, not insert)
        count = db_session.query(ConsentModel).filter_by(
            user_id=USER_ID,
            consent_type=ConsentType.byok_data_sharing.value,
        ).count()
        assert count == 1

    def test_consent_independence_in_db(self, db_session):
        """Toggling BYOK in DB does not affect notifications."""
        ConsentManager.update_consent(USER_ID, ConsentType.byok_data_sharing, True, db=db_session)
        assert ConsentManager.is_consent_given(USER_ID, ConsentType.notifications, db=db_session) is False

    def test_revoke_all_in_db(self, db_session):
        """revoke_all sets all consent rows to False in DB."""
        for ct in ConsentType:
            ConsentManager.update_consent(USER_ID, ct, True, db=db_session)
        ConsentManager.revoke_all(USER_ID, db=db_session)
        for ct in ConsentType:
            assert ConsentManager.is_consent_given(USER_ID, ct, db=db_session) is False

    def test_multi_user_isolation_in_db(self, db_session):
        """User A's consent in DB does not affect user B."""
        ConsentManager.update_consent("user-a", ConsentType.notifications, True, db=db_session)
        assert ConsentManager.is_consent_given("user-a", ConsentType.notifications, db=db_session) is True
        assert ConsentManager.is_consent_given("user-b", ConsentType.notifications, db=db_session) is False

    def test_user_dashboard_with_db(self, db_session):
        """get_user_dashboard with db reflects actual DB state."""
        mgr = ConsentManager()
        ConsentManager.update_consent(USER_ID, ConsentType.snapshot_storage, True, db=db_session)
        dash = mgr.get_user_dashboard(USER_ID, db=db_session)
        state_map = {c.consent_type: c.enabled for c in dash.consents}
        assert state_map[ConsentType.snapshot_storage] is True
        assert state_map[ConsentType.byok_data_sharing] is False
        assert state_map[ConsentType.notifications] is False

    def test_re_enable_after_revoke_in_db(self, db_session):
        """User can re-enable consent after revoke_all in DB."""
        for ct in ConsentType:
            ConsentManager.update_consent(USER_ID, ct, True, db=db_session)
        ConsentManager.revoke_all(USER_ID, db=db_session)
        ConsentManager.update_consent(USER_ID, ConsentType.notifications, True, db=db_session)
        assert ConsentManager.is_consent_given(USER_ID, ConsentType.notifications, db=db_session) is True
        assert ConsentManager.is_consent_given(USER_ID, ConsentType.byok_data_sharing, db=db_session) is False
