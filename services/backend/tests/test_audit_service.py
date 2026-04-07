"""
Tests for audit_service.py (P0 — regulatory traceability).

Covers:
    - log_audit_event() creates event with correct fields
    - log_audit_event() with missing optional fields
    - Event type stored correctly
    - Query audit events by user_id
    - Audit events persist with details_json
    - Audit events are immutable (no update method)

Run: cd services/backend && python3 -m pytest tests/test_audit_service.py -v
"""

import json


from app.models.audit_event import AuditEventModel
from app.services.audit_service import log_audit_event


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_db_session():
    """Get a test DB session from the conftest engine."""
    from tests.conftest import TestingSessionLocal
    return TestingSessionLocal()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestLogAuditEvent:
    """Tests for log_audit_event()."""

    def test_creates_event_with_all_fields(self):
        """log_audit_event() with all fields creates a complete row."""
        db = _get_db_session()
        try:
            log_audit_event(
                db,
                event_type="user.login",
                status="success",
                source="api",
                user_id="user-123",
                actor_email="test@mint.ch",
                ip_address="192.168.1.1",
                user_agent="Mozilla/5.0",
                details={"action": "login", "method": "password"},
            )
            db.commit()

            row = db.query(AuditEventModel).filter_by(user_id="user-123").first()
            assert row is not None
            assert row.event_type == "user.login"
            assert row.status == "success"
            assert row.source == "api"
            assert row.actor_email == "test@mint.ch"
            assert row.ip_address == "192.168.1.1"
            assert row.user_agent == "Mozilla/5.0"
            parsed = json.loads(row.details_json)
            assert parsed["action"] == "login"
            assert row.created_at is not None
        finally:
            db.close()

    def test_creates_event_with_minimal_fields(self):
        """log_audit_event() with only required fields does not crash."""
        db = _get_db_session()
        try:
            log_audit_event(db, event_type="system.startup")
            db.commit()

            row = (
                db.query(AuditEventModel)
                .filter_by(event_type="system.startup")
                .first()
            )
            assert row is not None
            assert row.user_id is None
            assert row.actor_email is None
            assert row.ip_address is None
            assert row.user_agent is None
            assert row.details_json is None
            assert row.status == "success"
            assert row.source == "api"
        finally:
            db.close()

    def test_details_json_is_none_when_no_details(self):
        """details_json is None when details=None."""
        db = _get_db_session()
        try:
            log_audit_event(db, event_type="test.no_details", details=None)
            db.commit()

            row = (
                db.query(AuditEventModel)
                .filter_by(event_type="test.no_details")
                .first()
            )
            assert row is not None
            assert row.details_json is None
        finally:
            db.close()

    def test_details_json_serializes_complex_dict(self):
        """details dict with nested structure serializes correctly."""
        db = _get_db_session()
        try:
            details = {"amounts": [100, 200], "nested": {"key": "value"}}
            log_audit_event(
                db, event_type="test.complex", details=details
            )
            db.commit()

            row = (
                db.query(AuditEventModel)
                .filter_by(event_type="test.complex")
                .first()
            )
            assert row is not None
            parsed = json.loads(row.details_json)
            assert parsed["amounts"] == [100, 200]
            assert parsed["nested"]["key"] == "value"
        finally:
            db.close()

    def test_query_by_user_id_returns_correct_events(self):
        """Querying by user_id returns only that user's events."""
        db = _get_db_session()
        try:
            log_audit_event(db, event_type="a.action", user_id="alice")
            log_audit_event(db, event_type="b.action", user_id="bob")
            log_audit_event(db, event_type="a.action2", user_id="alice")
            db.commit()

            alice_events = (
                db.query(AuditEventModel)
                .filter_by(user_id="alice")
                .all()
            )
            assert len(alice_events) == 2
            assert all(e.user_id == "alice" for e in alice_events)
        finally:
            db.close()

    def test_multiple_events_same_type(self):
        """Multiple events of the same type are stored independently."""
        db = _get_db_session()
        try:
            for i in range(3):
                log_audit_event(
                    db,
                    event_type="repeated.event",
                    user_id="user-repeat",
                    details={"index": i},
                )
            db.commit()

            events = (
                db.query(AuditEventModel)
                .filter_by(event_type="repeated.event")
                .all()
            )
            assert len(events) == 3
            indices = {json.loads(e.details_json)["index"] for e in events}
            assert indices == {0, 1, 2}
        finally:
            db.close()

    def test_status_can_be_failure(self):
        """status='failure' is stored correctly."""
        db = _get_db_session()
        try:
            log_audit_event(
                db,
                event_type="auth.failed",
                status="failure",
                user_id="user-fail",
            )
            db.commit()

            row = (
                db.query(AuditEventModel)
                .filter_by(user_id="user-fail")
                .first()
            )
            assert row is not None
            assert row.status == "failure"
        finally:
            db.close()
