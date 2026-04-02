"""
Tests for Snapshots DB persistence + Open Banking consent DB via API endpoints.

Verifies that:
1. List snapshots returns DB results (not just in-memory)
2. Delete snapshots clears DB and subsequent GET returns empty
3. Open banking consent creates in DB

Run: cd services/backend && python3 -m pytest tests/test_snapshots_db.py -v
"""

import os
import pytest
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from app.main import app
from app.core.auth import require_current_user, get_current_user
from app.core.database import get_db
from app.services.reengagement.consent_manager import ConsentManager
from app.services.reengagement.reengagement_models import ConsentType
from tests.conftest import TestingSessionLocal, override_get_db


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _fake_user():
    """Mock authenticated user."""
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    return user


def _grant_snapshot_consent():
    """Grant snapshot_storage consent for the test user."""
    db = TestingSessionLocal()
    ConsentManager.update_consent(
        "test-user-id", ConsentType.snapshot_storage, True, db=db
    )
    db.close()


_VALID_SNAPSHOT_BODY = {
    "userId": "test-user-id",
    "trigger": "quarterly",
    "profileData": {
        "age": 49,
        "gross_income": 122207,
        "canton": "VS",
        "archetype": "swiss_native",
        "household_type": "couple",
        "replacement_ratio": 0.655,
        "months_liquidity": 6.0,
        "tax_saving_potential": 7258,
        "confidence_score": 0.72,
        "enrichment_count": 3,
        "fri_total": 68.5,
        "fri_l": 72.0,
        "fri_f": 65.0,
        "fri_r": 70.0,
        "fri_s": 66.0,
    },
}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client():
    """Test client with test DB and auth override."""
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user

    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# ===========================================================================
# 2a. List snapshots uses DB
# ===========================================================================


class TestListSnapshotsDB:
    """Verify GET /snapshots returns data persisted in DB."""

    def test_list_snapshots_empty_initially(self, client):
        """GET /snapshots returns empty list when no snapshots exist."""
        response = client.get("/api/v1/snapshots")
        assert response.status_code == 200
        data = response.json()
        assert data["snapshots"] == []
        assert data["count"] == 0

    def test_list_snapshots_returns_db_results(self, client):
        """Create a snapshot via API, then GET /snapshots returns it."""
        _grant_snapshot_consent()

        # Create snapshot
        create_resp = client.post("/api/v1/snapshots", json=_VALID_SNAPSHOT_BODY)
        assert create_resp.status_code == 200
        created_id = create_resp.json()["id"]

        # List snapshots
        list_resp = client.get("/api/v1/snapshots")
        assert list_resp.status_code == 200
        data = list_resp.json()
        assert data["count"] >= 1
        ids = [s["id"] for s in data["snapshots"]]
        assert created_id in ids

    def test_list_snapshots_returns_multiple(self, client):
        """Multiple snapshots are all returned."""
        _grant_snapshot_consent()

        created_ids = []
        for _ in range(3):
            resp = client.post("/api/v1/snapshots", json=_VALID_SNAPSHOT_BODY)
            assert resp.status_code == 200
            created_ids.append(resp.json()["id"])

        list_resp = client.get("/api/v1/snapshots")
        assert list_resp.status_code == 200
        data = list_resp.json()
        assert data["count"] == 3
        returned_ids = [s["id"] for s in data["snapshots"]]
        for cid in created_ids:
            assert cid in returned_ids

    def test_list_snapshots_respects_limit(self, client):
        """GET /snapshots?limit=2 returns at most 2 snapshots."""
        _grant_snapshot_consent()

        for _ in range(5):
            resp = client.post("/api/v1/snapshots", json=_VALID_SNAPSHOT_BODY)
            assert resp.status_code == 200

        list_resp = client.get("/api/v1/snapshots?limit=2")
        assert list_resp.status_code == 200
        data = list_resp.json()
        assert len(data["snapshots"]) <= 2

    def test_snapshot_fields_persisted(self, client):
        """Snapshot fields are correctly persisted and returned."""
        _grant_snapshot_consent()

        create_resp = client.post("/api/v1/snapshots", json=_VALID_SNAPSHOT_BODY)
        assert create_resp.status_code == 200
        snapshot = create_resp.json()

        assert snapshot["trigger"] == "quarterly"
        assert snapshot["canton"] == "VS"
        assert snapshot["grossIncome"] == 122207
        assert snapshot["archetype"] == "swiss_native"
        assert snapshot["friTotal"] == 68.5


# ===========================================================================
# 2b. Delete snapshots uses DB
# ===========================================================================


class TestDeleteSnapshotsDB:
    """Verify DELETE /snapshots clears DB data."""

    def test_delete_snapshots_clears_db(self, client):
        """DELETE /snapshots returns count=1 after creating 1 snapshot."""
        _grant_snapshot_consent()

        # Create one snapshot
        create_resp = client.post("/api/v1/snapshots", json=_VALID_SNAPSHOT_BODY)
        assert create_resp.status_code == 200

        # Delete all
        del_resp = client.delete("/api/v1/snapshots")
        assert del_resp.status_code == 200
        data = del_resp.json()
        assert data["deletedCount"] >= 1

        # Verify empty
        list_resp = client.get("/api/v1/snapshots")
        assert list_resp.status_code == 200
        assert list_resp.json()["count"] == 0
        assert list_resp.json()["snapshots"] == []

    def test_delete_multiple_snapshots(self, client):
        """DELETE /snapshots clears all snapshots for the user."""
        _grant_snapshot_consent()

        for _ in range(3):
            resp = client.post("/api/v1/snapshots", json=_VALID_SNAPSHOT_BODY)
            assert resp.status_code == 200

        del_resp = client.delete("/api/v1/snapshots")
        assert del_resp.status_code == 200
        assert del_resp.json()["deletedCount"] == 3

        list_resp = client.get("/api/v1/snapshots")
        assert list_resp.json()["count"] == 0

    def test_delete_on_empty_returns_zero(self, client):
        """DELETE /snapshots when no snapshots exist returns count=0."""
        del_resp = client.delete("/api/v1/snapshots")
        assert del_resp.status_code == 200
        assert del_resp.json()["deletedCount"] == 0

    def test_create_snapshot_requires_consent(self, client):
        """POST /snapshots returns 403 without snapshot_storage consent."""
        # No consent granted
        response = client.post("/api/v1/snapshots", json=_VALID_SNAPSHOT_BODY)
        assert response.status_code == 403
        assert "snapshot_storage" in response.json()["detail"]


# ===========================================================================
# 4. Open Banking consent creates in DB
# ===========================================================================


class TestOpenBankingConsentDB:
    """Verify POST /open-banking/consent persists in DB."""

    _CONSENT_BODY = {
        "bankId": "ubs",
        "bankName": "UBS",
        "scopes": ["accounts", "balances", "transactions"],
    }

    @pytest.fixture(autouse=True)
    def _enable_open_banking(self):
        """Enable OPEN_BANKING_ENABLED + FF_ENABLE_BLINK_PRODUCTION for these tests."""
        original = os.environ.get("OPEN_BANKING_ENABLED")
        original_ff = os.environ.get("FF_ENABLE_BLINK_PRODUCTION")
        os.environ["OPEN_BANKING_ENABLED"] = "true"
        os.environ["FF_ENABLE_BLINK_PRODUCTION"] = "true"
        yield
        if original is None:
            os.environ.pop("OPEN_BANKING_ENABLED", None)
        else:
            os.environ["OPEN_BANKING_ENABLED"] = original
        if original_ff is None:
            os.environ.pop("FF_ENABLE_BLINK_PRODUCTION", None)
        else:
            os.environ["FF_ENABLE_BLINK_PRODUCTION"] = original_ff

    def test_open_banking_consent_creates_in_db(self, client):
        """POST /open-banking/consent creates a consent and returns it."""
        response = client.post(
            "/api/v1/open-banking/consent", json=self._CONSENT_BODY
        )
        assert response.status_code == 200
        data = response.json()
        assert data["bankId"] == "ubs"
        assert data["bankName"] == "UBS"
        assert "consentId" in data
        assert data["scopes"] == ["accounts", "balances", "transactions"]
        assert "grantedAt" in data
        assert "expiresAt" in data

    def test_open_banking_consent_persists_and_listed(self, client):
        """Created consent appears in GET /open-banking/consents."""
        # Create consent
        create_resp = client.post(
            "/api/v1/open-banking/consent", json=self._CONSENT_BODY
        )
        assert create_resp.status_code == 200
        consent_id = create_resp.json()["consentId"]

        # List consents — returns paginated response with items
        list_resp = client.get("/api/v1/open-banking/consents")
        assert list_resp.status_code == 200
        data = list_resp.json()
        items = data.get("items", data) if isinstance(data, dict) else data
        consent_ids = [c["consentId"] for c in items]
        assert consent_id in consent_ids

    def test_open_banking_consent_revocable(self, client):
        """DELETE /open-banking/consent/{id} revokes the consent."""
        # Create
        create_resp = client.post(
            "/api/v1/open-banking/consent", json=self._CONSENT_BODY
        )
        assert create_resp.status_code == 200
        consent_id = create_resp.json()["consentId"]

        # Revoke
        del_resp = client.delete(f"/api/v1/open-banking/consent/{consent_id}")
        assert del_resp.status_code == 200

    def test_open_banking_blocked_when_disabled(self, client):
        """POST /open-banking/consent returns 503 when feature is disabled."""
        os.environ["OPEN_BANKING_ENABLED"] = "false"
        response = client.post(
            "/api/v1/open-banking/consent", json=self._CONSENT_BODY
        )
        assert response.status_code == 503
