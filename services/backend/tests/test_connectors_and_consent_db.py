"""
Tests for P7 infrastructure: CircuitBreaker, ApiConnectorBase, ConsentManager DB mode.

Covers:
    - CircuitBreaker state transitions and thread safety
    - ApiConnectorBase retry logic and circuit integration
    - ConsentManager with actual DB session (not in-memory fallback)
"""

import time
import threading
from typing import Any, Dict, Optional
from unittest.mock import MagicMock

import pytest

from app.services.connectors.base import (
    CircuitBreaker,
    CircuitOpen,
    ApiConnectorBase,
)
from app.services.open_banking.consent_manager import ConsentManager
from app.models.banking_consent import BankingConsentModel
from tests.conftest import TestingSessionLocal


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class FakeConnector(ApiConnectorBase):
    """Concrete connector for testing. Delegates to a mock."""

    source_name = "fake"

    def __init__(self, mock_fn=None, **kwargs):
        super().__init__(base_url="https://fake.api", **kwargs)
        self._mock_fn = mock_fn or MagicMock(return_value={"ok": True})

    def _do_request(
        self,
        method: str,
        path: str,
        headers: Optional[Dict[str, str]] = None,
        params: Optional[Dict[str, Any]] = None,
        json_body: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        return self._mock_fn(method, path)


@pytest.fixture
def db_session():
    """Provide a clean DB session for tests."""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


# ===========================================================================
# CircuitBreaker Tests
# ===========================================================================

class TestCircuitBreaker:
    """Test circuit breaker state transitions."""

    def test_starts_closed(self):
        cb = CircuitBreaker()
        assert cb.state == "closed"
        assert cb.allow_request() is True

    def test_stays_closed_on_success(self):
        cb = CircuitBreaker(threshold=3)
        cb.record_failure()
        cb.record_failure()
        cb.record_success()
        assert cb.state == "closed"
        assert cb.allow_request() is True

    def test_opens_after_threshold_failures(self):
        cb = CircuitBreaker(threshold=3)
        cb.record_failure()
        cb.record_failure()
        cb.record_failure()
        assert cb.state == "open"
        assert cb.allow_request() is False

    def test_rejects_when_open(self):
        cb = CircuitBreaker(threshold=2, recovery_seconds=60)
        cb.record_failure()
        cb.record_failure()
        assert cb.allow_request() is False

    def test_half_open_after_recovery(self):
        cb = CircuitBreaker(threshold=1, recovery_seconds=0)
        cb.record_failure()
        assert cb.state == "open"
        # recovery_seconds=0 → immediately eligible
        time.sleep(0.01)
        assert cb.allow_request() is True
        assert cb.state == "half_open"

    def test_resets_to_closed_on_success_in_half_open(self):
        cb = CircuitBreaker(threshold=1, recovery_seconds=0)
        cb.record_failure()
        time.sleep(0.01)
        cb.allow_request()  # transitions to half_open
        cb.record_success()
        assert cb.state == "closed"

    def test_reopens_on_failure_in_half_open(self):
        cb = CircuitBreaker(threshold=1, recovery_seconds=0)
        cb.record_failure()
        time.sleep(0.01)
        cb.allow_request()  # half_open
        cb.record_failure()
        assert cb.state == "open"

    def test_thread_safety_concurrent_failures(self):
        """Concurrent failures should not corrupt state."""
        cb = CircuitBreaker(threshold=50, recovery_seconds=60)
        errors = []

        def fail_many():
            try:
                for _ in range(100):
                    cb.record_failure()
            except Exception as e:
                errors.append(e)

        threads = [threading.Thread(target=fail_many) for _ in range(4)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert len(errors) == 0
        assert cb.state == "open"


# ===========================================================================
# ApiConnectorBase Tests
# ===========================================================================

class TestApiConnectorBase:
    """Test retry and circuit breaker integration."""

    def test_successful_get(self):
        connector = FakeConnector()
        result = connector.get("/health")
        assert result == {"ok": True}

    def test_retries_on_connection_error(self):
        mock = MagicMock(side_effect=ConnectionError("timeout"))
        connector = FakeConnector(mock_fn=mock, max_retries=3)
        with pytest.raises(ConnectionError):
            connector.get("/fail")
        assert mock.call_count == 3

    def test_no_retry_on_value_error(self):
        mock = MagicMock(side_effect=ValueError("bad request"))
        connector = FakeConnector(mock_fn=mock, max_retries=3)
        with pytest.raises(ValueError):
            connector.get("/bad")
        assert mock.call_count == 1

    def test_circuit_opens_after_threshold(self):
        mock = MagicMock(side_effect=ConnectionError("down"))
        connector = FakeConnector(
            mock_fn=mock, max_retries=1, circuit_threshold=2, circuit_recovery=60
        )
        # First failure → circuit records 1
        with pytest.raises(ConnectionError):
            connector.get("/fail")
        # Second failure → circuit opens
        with pytest.raises(ConnectionError):
            connector.get("/fail")
        # Third call → CircuitOpen (no HTTP call)
        with pytest.raises(CircuitOpen):
            connector.get("/fail")

    def test_max_retries_parameter_respected(self):
        """Verify max_retries is actually used (was WARN-1)."""
        mock = MagicMock(side_effect=ConnectionError("timeout"))
        connector = FakeConnector(mock_fn=mock, max_retries=5)
        with pytest.raises(ConnectionError):
            connector.get("/fail")
        assert mock.call_count == 5

    def test_post_delegates_to_request(self):
        mock = MagicMock(return_value={"created": True})
        connector = FakeConnector(mock_fn=mock)
        result = connector.post("/create")
        assert result == {"created": True}
        mock.assert_called_with("POST", "/create")


# ===========================================================================
# ConsentManager DB Tests
# ===========================================================================

class TestConsentManagerDb:
    """Test ConsentManager with actual DB session."""

    def test_create_consent_persists(self, db_session):
        # Ensure a user exists for FK
        from app.models import User
        user = User(
            id="test-consent-user",
            email="consent@test.ch",
            hashed_password="x",
            email_verified=False,
        )
        db_session.add(user)
        db_session.commit()

        manager = ConsentManager()
        consent = manager.create_consent(
            user_id="test-consent-user",
            bank_id="ubs",
            bank_name="UBS",
            scopes=["accounts", "balances"],
            db=db_session,
        )

        # Verify persisted
        model = db_session.query(BankingConsentModel).filter_by(
            id=consent.consent_id
        ).first()
        assert model is not None
        assert model.user_id == "test-consent-user"
        assert model.bank_id == "ubs"
        assert model.status == "active"

    def test_get_active_consents(self, db_session):
        from app.models import User
        db_session.add(User(
            id="test-active-user", email="active@test.ch",
            hashed_password="x", email_verified=False,
        ))
        db_session.commit()

        manager = ConsentManager()
        manager.create_consent(
            user_id="test-active-user", bank_id="ubs",
            bank_name="UBS", scopes=["accounts"], db=db_session,
        )

        active = manager.get_active_consents("test-active-user", db=db_session)
        assert len(active) == 1
        assert active[0].bank_id == "ubs"

    def test_revoke_consent(self, db_session):
        from app.models import User
        db_session.add(User(
            id="test-revoke-user", email="revoke@test.ch",
            hashed_password="x", email_verified=False,
        ))
        db_session.commit()

        manager = ConsentManager()
        consent = manager.create_consent(
            user_id="test-revoke-user", bank_id="postfinance",
            bank_name="PostFinance", scopes=["transactions"], db=db_session,
        )

        result = manager.revoke_consent(consent.consent_id, db=db_session)
        assert result is True

        # Verify revoked in DB
        model = db_session.query(BankingConsentModel).filter_by(
            id=consent.consent_id
        ).first()
        assert model.status == "revoked"
        assert model.revoked_at is not None

    def test_is_consent_valid_false_after_revoke(self, db_session):
        from app.models import User
        db_session.add(User(
            id="test-valid-user", email="valid@test.ch",
            hashed_password="x", email_verified=False,
        ))
        db_session.commit()

        manager = ConsentManager()
        consent = manager.create_consent(
            user_id="test-valid-user", bank_id="ubs",
            bank_name="UBS", scopes=["accounts"], db=db_session,
        )
        assert manager.is_consent_valid(consent.consent_id, db=db_session) is True

        manager.revoke_consent(consent.consent_id, db=db_session)
        assert manager.is_consent_valid(consent.consent_id, db=db_session) is False

    def test_get_consent_returns_none_for_unknown(self, db_session):
        manager = ConsentManager()
        assert manager.get_consent("nonexistent-id", db=db_session) is None

    def test_revoke_returns_false_for_unknown(self, db_session):
        manager = ConsentManager()
        assert manager.revoke_consent("nonexistent-id", db=db_session) is False

    def test_audit_log_persists_on_create_and_revoke(self, db_session):
        """WARN-6 fix: audit log entries are written to audit_events table."""
        from app.models import User
        from app.models.audit_event import AuditEventModel

        db_session.add(User(
            id="test-audit-user", email="audit@test.ch",
            hashed_password="x", email_verified=False,
        ))
        db_session.commit()

        manager = ConsentManager()
        consent = manager.create_consent(
            user_id="test-audit-user", bank_id="ubs",
            bank_name="UBS", scopes=["accounts"], db=db_session,
        )

        # Check create audit entry
        entries = (
            db_session.query(AuditEventModel)
            .filter_by(user_id="test-audit-user", source="open_banking")
            .all()
        )
        assert len(entries) == 1
        assert entries[0].event_type == "consent_created"

        # Revoke and check second audit entry
        manager.revoke_consent(consent.consent_id, db=db_session)
        entries = (
            db_session.query(AuditEventModel)
            .filter_by(user_id="test-audit-user", source="open_banking")
            .all()
        )
        assert len(entries) == 2
        actions = {e.event_type for e in entries}
        assert actions == {"consent_created", "consent_revoked"}

    def test_get_consent_audit_log_from_db(self, db_session):
        """get_consent_audit_log queries audit_events when db is provided."""
        from app.models import User

        db_session.add(User(
            id="test-auditlog-user", email="auditlog@test.ch",
            hashed_password="x", email_verified=False,
        ))
        db_session.commit()

        manager = ConsentManager()
        manager.create_consent(
            user_id="test-auditlog-user", bank_id="ubs",
            bank_name="UBS", scopes=["accounts"], db=db_session,
        )

        log = manager.get_consent_audit_log("test-auditlog-user", db=db_session)
        assert len(log) == 1
        assert log[0]["action"] == "consent_created"
        assert "timestamp" in log[0]
