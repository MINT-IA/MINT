"""Phase 97 W7 iter#6 — Apple-App-Site-Association endpoint tests.

Guards the /.well-known/apple-app-site-association route added in
app/main.py for iOS Universal Links (S004 + F007 close-out).

Apple is strict on the AASA contract :
- the path must match exactly (no .json suffix)
- the response must be served as application/json
- the payload must contain applinks.details[].appID + applinks.details[].paths

Any future PR that breaks any of those three contracts fails this test
= PR blocked.
"""
import json

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_aasa_endpoint_returns_200():
    """Bare AASA path returns 200 (no .json suffix, no auth)."""
    response = client.get("/.well-known/apple-app-site-association")
    assert response.status_code == 200


def test_aasa_endpoint_content_type_is_application_json():
    """Apple requires Content-Type: application/json (NOT text/json,
    NOT application/octet-stream). Strict per Apple developer docs."""
    response = client.get("/.well-known/apple-app-site-association")
    # FastAPI/Starlette appends charset=utf-8 ; the prefix is the contract.
    assert response.headers["content-type"].startswith("application/json"), (
        f"AASA Content-Type must start with 'application/json', got "
        f"{response.headers['content-type']!r}"
    )


def test_aasa_payload_shape_matches_apple_contract():
    """Payload must contain applinks.apps + applinks.details with at
    least one details entry carrying appID + paths."""
    response = client.get("/.well-known/apple-app-site-association")
    payload = response.json()

    assert "applinks" in payload, "AASA payload missing top-level 'applinks' key"
    applinks = payload["applinks"]
    assert "apps" in applinks, "applinks missing 'apps' field"
    assert isinstance(applinks["apps"], list), "applinks.apps must be a list"
    assert "details" in applinks, "applinks missing 'details' field"
    assert isinstance(applinks["details"], list), "applinks.details must be a list"
    assert len(applinks["details"]) >= 1, "applinks.details must have at least one entry"

    detail = applinks["details"][0]
    assert "appID" in detail, "applinks.details[0] missing appID"
    assert "paths" in detail, "applinks.details[0] missing paths"
    assert isinstance(detail["paths"], list), "applinks.details[0].paths must be a list"
    assert len(detail["paths"]) >= 1, "applinks.details[0].paths must have at least one path"


def test_aasa_appid_uses_team_id_prefix():
    """appID format must be <TEAM_ID>.<BUNDLE_ID> per Apple spec.
    Team ID from Runner.xcodeproj/project.pbxproj :line 682,707
    DEVELOPMENT_TEAM = 7F5UDGYS5H. Bundle ID : ch.mint.app."""
    response = client.get("/.well-known/apple-app-site-association")
    detail = response.json()["applinks"]["details"][0]
    assert detail["appID"] == "7F5UDGYS5H.ch.mint.app", (
        f"appID drifted from canonical TEAM_ID.BUNDLE_ID — got {detail['appID']!r}"
    )


def test_aasa_paths_exclude_debug_routes():
    """Production AASA paths must not associate debug/demo surfaces."""
    response = client.get("/.well-known/apple-app-site-association")
    paths = response.json()["applinks"]["details"][0]["paths"]
    assert "/debug/chat-as-verb" not in paths
    assert all(not path.startswith("/debug") for path in paths)


def test_aasa_paths_match_release_routes():
    """Production AASA paths must point at live app routes, not stale slugs."""
    response = client.get("/.well-known/apple-app-site-association")
    paths = response.json()["applinks"]["details"][0]["paths"]

    assert paths == [
        "/home",
        "/anonymous/chat",
        "/coach/chat",
        "/explore",
        "/explore/*",
    ]
    assert "/aujourd-hui" not in paths
    assert "/explorer/*" not in paths


def test_aasa_payload_is_valid_json():
    """Belt-and-suspenders : response.json() never raises ; the bytes
    are syntactically valid JSON (no trailing commas, no comments)."""
    response = client.get("/.well-known/apple-app-site-association")
    # Will raise ValueError if invalid JSON
    parsed = json.loads(response.content)
    assert isinstance(parsed, dict)
