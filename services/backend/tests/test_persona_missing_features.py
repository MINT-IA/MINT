"""
Tests for "New Mint" missing features: Tax Estimator & Concubinage.
Integration tests verifying specific Personas.
"""
import pytest
import httpx

@pytest.mark.asyncio
async def test_persona_vaud_fiscal(client: httpx.AsyncClient):
    """
    Persona: Vaud Fiscal
    Expectation: Scoreboard shows estimated tax savings range (e.g. ~1100-1400 CHF) instead of hardcoded Potentiel Élevé.
    """
    profile_payload = {
        "householdType": "single",
        "goal": "optimize_taxes",
        "canton": "VD",
        "incomeGrossYearly": 120000,
        "birthYear": 1985,
    }
    profile_resp = await client.post("/api/v1/profiles", json=profile_payload)
    if profile_resp.status_code != 200:
        pytest.fail(f"Profile Create Failed: {profile_resp.text}")
    
    profile_id = profile_resp.json()["id"]

    session_resp = await client.post(
        "/api/v1/sessions",
        json={
            "profileId": profile_id,
            "answers": {"hasDebt": False},
            "selectedFocusKinds": ["pillar3a"],
        },
    )
    assert session_resp.status_code == 200
    session_id = session_resp.json()["id"]

    report_resp = await client.get(f"/api/v1/sessions/{session_id}/report")
    assert report_resp.status_code == 200
    report = report_resp.json()

    scoreboard = report["scoreboard"]
    tax_item = next(item for item in scoreboard if item["label"] == "Épargne/Impôts")
    
    assert "CHF" in tax_item["value"]
    assert "-" in tax_item["value"]
    assert "~" in tax_item["value"]

@pytest.mark.asyncio
async def test_persona_concubins_legal(client: httpx.AsyncClient):
    """
    Persona: Concubins
    Expectation: HouseholdType 'concubine' triggers "Protéger conjoint" recommendation.
    """
    profile_payload = {
        "householdType": "concubine",
        "goal": "house",
        "canton": "GE",
        "birthYear": 1990,
    }
    profile_resp = await client.post("/api/v1/profiles", json=profile_payload)
    
    if profile_resp.status_code != 200:
        pytest.fail(f"Profile Create Failed: {profile_resp.text}")
    
    profile_id = profile_resp.json()["id"]

    session_resp = await client.post(
        "/api/v1/sessions",
        json={
            "profileId": profile_id,
            "answers": {"hasDebt": False},
            "selectedFocusKinds": [],
        },
    )
    assert session_resp.status_code == 200
    session_id = session_resp.json()["id"]

    report_resp = await client.get(f"/api/v1/sessions/{session_id}/report")
    report = report_resp.json()
    
    recos = report["recommendations"]
    has_legal_reco = any(r["kind"] == "legal_protection" for r in recos)
    
    assert has_legal_reco is True, "Missing 'legal_protection' recommendation for concubins"
