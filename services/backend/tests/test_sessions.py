import pytest


def test_create_session(client):
    # 1. Create a profile first
    profile_resp = client.post(
        "/api/v1/profiles",
        json={
            "householdType": "single",
            "goal": "invest",
            "canton": "ZH",
            "birthYear": 1995,
        },
    )
    profile_id = profile_resp.json()["id"]

    # 2. Create a session
    resp = client.post(
        "/api/v1/sessions",
        json={
            "profileId": profile_id,
            "answers": {"hasDebt": False},
            "selectedFocusKinds": ["compound_interest", "pillar3a"],
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["profileId"] == profile_id
    assert "id" in data
    assert "recommendedGoalTemplateId" in data


def test_get_session_report(client):
    # 1. Create profile
    profile_resp = client.post(
        "/api/v1/profiles",
        json={
            "householdType": "couple",
            "goal": "optimize_taxes",
            "canton": "GE",
            "birthYear": 1985,
        },
    )
    profile_id = profile_resp.json()["id"]

    # 2. Create session
    session_resp = client.post(
        "/api/v1/sessions",
        json={
            "profileId": profile_id,
            "answers": {"hasDebt": False},
            "selectedFocusKinds": ["pillar3a", "compound_interest"],
        },
    )
    session_id = session_resp.json()["id"]

    # 3. Get report
    resp = client.get(f"/api/v1/sessions/{session_id}/report")
    assert resp.status_code == 200
    report = resp.json()
    assert report["sessionId"] == session_id
    assert "id" in report["recommendedGoalTemplate"]
    assert len(report["topActions"]) == 3

    # Check TopAction structure
    for action in report["topActions"]:
        assert "ifThen" in action
        assert "SI" in action["ifThen"]
        assert "ALORS" in action["ifThen"]

    # Check Overview
    overview = report["overview"]
    assert overview["canton"] == "GE"
    assert overview["householdType"] == "couple"

    # Check MintRoadmap (Previously SoA)
    roadmap = report["mintRoadmap"]
    assert "limitations" in roadmap
    assert "assumptions" in roadmap
    assert roadmap["natureOfService"] == "Coaching / Mentorat Informatif"
    assert len(roadmap["conflictsOfInterest"]) > 0

    # Check Evidence Links
    for reco in report["recommendations"]:
        assert "evidenceLinks" in reco
        if reco["kind"] == "pillar3a":
            assert len(reco["evidenceLinks"]) >= 2
            assert "url" in reco["evidenceLinks"][0]
