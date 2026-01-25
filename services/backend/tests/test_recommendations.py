"""
Tests for recommendations endpoint.
"""

import uuid
import pytest
import httpx


@pytest.mark.asyncio
async def test_preview_recommendations(client: httpx.AsyncClient):
    """Test previewing recommendations for a profile."""
    # Create profile
    profile_payload = {
        "householdType": "single",
        "goal": "invest",
        "birthYear": 1995,
        "savingsMonthly": 500,
    }
    profile_resp = await client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    # Get recommendations
    request_payload = {"profileId": profile_id}
    response = await client.post("/api/v1/recommendations/preview", json=request_payload)
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) <= 3  # Max 3 recommendations

    # Check recommendation structure
    if len(data) > 0:
        rec = data[0]
        assert "id" in rec
        assert "kind" in rec
        assert "title" in rec
        assert "summary" in rec
        assert "why" in rec
        assert "assumptions" in rec
        assert "impact" in rec
        assert "risks" in rec
        assert "alternatives" in rec
        assert "nextActions" in rec


@pytest.mark.asyncio
async def test_preview_recommendations_with_focus(client: httpx.AsyncClient):
    """Test previewing recommendations with a focus kind filter."""
    profile_id = str(uuid.uuid4())
    request_payload = {"profileId": profile_id, "focusKind": "compound_interest"}
    response = await client.post("/api/v1/recommendations/preview", json=request_payload)
    assert response.status_code == 200
    data = response.json()
    # All returned should be compound_interest
    for rec in data:
        assert rec["kind"] == "compound_interest"
