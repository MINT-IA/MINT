"""
Tests for admin audit trail endpoint (GET /api/v1/admin/audit).

Covers:
    - Returns 403 when feature flag is disabled
    - Returns 403 when user is not admin
    - Returns audit events with correct filters
    - Pagination works correctly
    - Results are ordered by created_at descending

Run: cd services/backend && python3 -m pytest tests/test_admin_audit.py -v
"""

import json
import os
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.audit_event import AuditEventModel
from app.services.audit_service import log_audit_event


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _admin_user():
    """Mock admin user with support_admin role + allowlisted email."""
    user = MagicMock()
    user.id = "admin-id"
    user.email = "admin@mint.ch"
    user.display_name = "Admin"
    user.role = "support_admin"
    user.created_at = datetime(2025, 1, 1)
    return user


def _regular_user():
    """Mock regular user without admin role."""
    user = MagicMock()
    user.id = "user-id"
    user.email = "user@example.com"
    user.display_name = "Regular"
    user.role = "user"
    user.created_at = datetime(2025, 1, 1)
    return user


def _get_test_db():
    """Get a test DB session."""
    from tests.conftest import TestingSessionLocal
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def _seed_audit_events(count: int = 5, event_type: str = "test.event", user_id: str = "user-1"):
    """Seed audit events into the test database."""
    from tests.conftest import TestingSessionLocal
    db = TestingSessionLocal()
    try:
        for i in range(count):
            log_audit_event(
                db,
                event_type=event_type,
                user_id=user_id,
                status="success" if i % 2 == 0 else "failure",
                details={"index": i},
            )
        db.commit()
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestAdminAuditEndpoint:
    """Tests for GET /api/v1/admin/audit."""

    def test_returns_403_when_flag_disabled(self):
        """Should return 403 when enable_admin_screens flag is off."""
        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "false",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit")
                assert resp.status_code == 403
                assert "enable_admin_screens" in resp.json()["detail"]

        app.dependency_overrides.clear()

    def test_returns_403_when_not_admin(self):
        """Should return 403 when user lacks admin role."""
        app.dependency_overrides[require_current_user] = _regular_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "true",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit")
                assert resp.status_code == 403

        app.dependency_overrides.clear()

    def test_returns_audit_events(self):
        """Should return audit events when admin + flag enabled."""
        _seed_audit_events(3)

        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "true",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit")
                assert resp.status_code == 200
                data = resp.json()
                assert data["total"] == 3
                assert len(data["items"]) == 3

        app.dependency_overrides.clear()

    def test_filters_by_event_type(self):
        """Should filter events by event_type query param."""
        _seed_audit_events(2, event_type="auth.login")
        _seed_audit_events(3, event_type="billing.charge")

        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "true",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit?event_type=auth.login")
                assert resp.status_code == 200
                data = resp.json()
                assert data["total"] == 2
                assert all(e["eventType"] == "auth.login" for e in data["items"])

        app.dependency_overrides.clear()

    def test_filters_by_user_id(self):
        """Should filter events by user_id query param."""
        _seed_audit_events(2, user_id="alice")
        _seed_audit_events(4, user_id="bob")

        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "true",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit?user_id=alice")
                assert resp.status_code == 200
                data = resp.json()
                assert data["total"] == 2

        app.dependency_overrides.clear()

    def test_filters_by_status(self):
        """Should filter events by status query param."""
        _seed_audit_events(4)  # alternates success/failure

        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "true",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit?status=failure")
                assert resp.status_code == 200
                data = resp.json()
                assert all(e["status"] == "failure" for e in data["items"])

        app.dependency_overrides.clear()

    def test_pagination(self):
        """Should paginate with limit and offset."""
        _seed_audit_events(10)

        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "true",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit?limit=3&offset=0")
                assert resp.status_code == 200
                data = resp.json()
                assert data["total"] == 10
                assert len(data["items"]) == 3
                assert data["limit"] == 3
                assert data["offset"] == 0

                # Second page
                resp2 = client.get("/api/v1/admin/audit?limit=3&offset=3")
                data2 = resp2.json()
                assert len(data2["items"]) == 3
                # Different items
                ids1 = {e["id"] for e in data["items"]}
                ids2 = {e["id"] for e in data2["items"]}
                assert ids1.isdisjoint(ids2)

        app.dependency_overrides.clear()

    def test_descending_order(self):
        """Events should be returned most recent first."""
        _seed_audit_events(5)

        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "true",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit")
                assert resp.status_code == 200
                data = resp.json()
                timestamps = [e["createdAt"] for e in data["items"]]
                assert timestamps == sorted(timestamps, reverse=True)

        app.dependency_overrides.clear()

    def test_empty_result(self):
        """Should return empty list when no events match."""
        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_ADMIN_SCREENS": "true",
            "AUTH_ADMIN_EMAIL_ALLOWLIST": "admin@mint.ch",
        }):
            with TestClient(app) as client:
                resp = client.get("/api/v1/admin/audit?event_type=nonexistent")
                assert resp.status_code == 200
                data = resp.json()
                assert data["total"] == 0
                assert data["items"] == []

        app.dependency_overrides.clear()

    def test_require_flag_on_open_banking(self):
        """Open banking gated endpoints should 403 when FF is off."""
        app.dependency_overrides[require_current_user] = _admin_user
        app.dependency_overrides[get_db] = _get_test_db

        with patch.dict(os.environ, {
            "FF_ENABLE_BLINK_PRODUCTION": "false",
            "OPEN_BANKING_ENABLED": "true",
        }):
            with TestClient(app) as client:
                resp = client.post("/api/v1/open-banking/consent", json={
                    "bankId": "test",
                    "bankName": "Test",
                    "scopes": ["accounts"],
                })
                assert resp.status_code == 403
                assert "enable_blink_production" in resp.json()["detail"]

        app.dependency_overrides.clear()

    def test_require_flag_passes_when_enabled(self):
        """Feature flag check should pass when flag is enabled."""
        from app.services.feature_flags import FeatureFlags

        with patch.dict(os.environ, {"FF_ENABLE_ADMIN_SCREENS": "true"}):
            # Should not raise
            FeatureFlags.require_flag("enable_admin_screens")

    def test_require_flag_raises_when_disabled(self):
        """Feature flag check should raise 403 when flag is disabled."""
        from fastapi import HTTPException
        from app.services.feature_flags import FeatureFlags

        with patch.dict(os.environ, {"FF_ENABLE_ADMIN_SCREENS": "false"}):
            with pytest.raises(HTTPException) as exc_info:
                FeatureFlags.require_flag("enable_admin_screens")
            assert exc_info.value.status_code == 403
