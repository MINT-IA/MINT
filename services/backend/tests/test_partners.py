"""
Tests for partners endpoint.
"""

import uuid
import pytest
import httpx


@pytest.mark.asyncio
async def test_list_partners(client: httpx.AsyncClient):
    """Test listing all partners."""
    response = await client.get("/api/v1/partners")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0

    # Check partner structure
    partner = data[0]
    assert "id" in partner
    assert "kind" in partner
    assert "name" in partner
    assert "disclosure" in partner
    assert "url" in partner


@pytest.mark.asyncio
async def test_partner_click(client: httpx.AsyncClient):
    """Test tracking a partner click."""
    payload = {
        "profileId": str(uuid.uuid4()),
        "partnerId": "pillar3a-1",
        "kind": "pillar3a",
    }
    response = await client.post("/api/v1/partners/click", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["ok"] is True
