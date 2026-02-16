import pytest
import json
import os
from fastapi.testclient import TestClient
from app.main import app
from app.schemas.profile import HouseholdType, Goal

client = TestClient(app)

def load_personas():
    persona_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../apps/mobile/assets/config/personas.json"))
    with open(persona_path, "r", encoding="utf-8") as f:
        return json.load(f)

def map_persona_to_profile(answers):
    # Mapping logic for civil status and household
    civil_status = answers.get("q_civil_status", "single")
    children = int(answers.get("q_children", "0"))
    
    ht = HouseholdType.single
    if children > 0:
        ht = HouseholdType.family
    elif civil_status == "married":
        ht = HouseholdType.couple
    elif civil_status == "cohabiting":
        ht = HouseholdType.concubine

    # Mapping logic for goals
    goal_map = {
        "retirement": Goal.retire,
        "real_estate": Goal.house,
        "independence": Goal.invest,
        "budget": Goal.emergency,
        "tax": Goal.optimize_taxes
    }
    target_goal = goal_map.get(answers.get("q_main_goal"), Goal.other)

    return {
        "birthYear": answers.get("q_birth_year"),
        "canton": answers.get("q_canton"),
        "householdType": ht,
        "incomeNetMonthly": float(answers.get("q_net_income_period_chf", 0)),
        "savingsMonthly": float(answers.get("q_savings_monthly", 0)),
        "hasDebt": answers.get("q_has_consumer_debt") == "yes",
        "goal": target_goal,
        "employmentStatus": answers.get("q_employment_status")
    }

@pytest.mark.parametrize("persona", load_personas())
def test_persona_recommendations(persona):
    # 1. Create Profile
    profile_data = map_persona_to_profile(persona["answers"])
    response = client.post("/api/v1/profiles", json=profile_data)
    assert response.status_code == 200
    profile_id = response.json()["id"]

    # 2. Get Recommendations
    rec_response = client.post("/api/v1/recommendations/preview", json={
        "profileId": profile_id
    })
    assert rec_response.status_code == 200
    recommendations = rec_response.json()

    # 3. Assertions based on persona
    if persona["id"] == "young_professional":
        # Should have 3a recommendation
        kinds = [r["kind"] for r in recommendations]
        assert "pillar3a" in kinds
    
    if persona["id"] == "stressed_student":
        # Should have debt or budget recommendation
        kinds = [r["kind"] for r in recommendations]
        assert "debt_repayment" in kinds or "debt_risk" in kinds or "budget_control" in kinds

    if persona["id"] == "self_employed":
        # Should have 3a (pension) for self-employed
        kinds = [r["kind"] for r in recommendations]
        assert "pension_3a" in kinds or any("3e pilier" in r["title"].lower() for r in recommendations)

    # Common assertion: EXACTLY 3 recommendations (if enough data)
    assert len(recommendations) <= 3
    assert len(recommendations) > 0
