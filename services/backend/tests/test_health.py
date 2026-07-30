"""
Tests for health endpoint.
"""

from datetime import datetime


def test_health_endpoint(client):
    """Test that health endpoint returns ok status."""
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


def test_health_exposes_deploy_marker(client, monkeypatch):
    """Deploy verification: /api/v1/health exposes the running image's commit
    sha (truncated) + a service_time so a post-promotion check can prove which
    image is live instead of trusting an unversioned {"status":"ok"}."""
    monkeypatch.setenv("RAILWAY_GIT_COMMIT_SHA", "abcdef1234567890")
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    # commit is present and truncated to 9 chars.
    assert data["commit"] == "abcdef123"
    # service_time is a parseable ISO-8601 UTC timestamp.
    assert "service_time" in data
    datetime.fromisoformat(data["service_time"])


def test_health_commit_unknown_without_env(client, monkeypatch):
    """Without RAILWAY_GIT_COMMIT_SHA the commit marker degrades to 'unknown'."""
    monkeypatch.delenv("RAILWAY_GIT_COMMIT_SHA", raising=False)
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["commit"] == "unknown"


def test_health_live_unchanged(client, monkeypatch):
    """Liveness probe stays a minimal {"status":"ok"} — the deploy marker is
    scoped to /api/v1/health only (no other surface)."""
    monkeypatch.setenv("RAILWAY_GIT_COMMIT_SHA", "abcdef1234567890")
    response = client.get("/api/v1/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
