from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app
from app.services.feature_flags import FeatureFlags


def test_mvp_wedge_onboarding_flag_defaults_off(monkeypatch):
    monkeypatch.delenv("FF_ENABLE_MVP_WEDGE_ONBOARDING", raising=False)

    flags = FeatureFlags.get_flags()

    assert flags["enable_mvp_wedge_onboarding"] is False


def test_mvp_wedge_onboarding_flag_reads_env(monkeypatch):
    monkeypatch.setenv("FF_ENABLE_MVP_WEDGE_ONBOARDING", "true")

    flags = FeatureFlags.get_flags()

    assert flags["enable_mvp_wedge_onboarding"] is True


def test_feature_flags_endpoint_exposes_mvp_wedge_onboarding(
    client,
    monkeypatch,
):
    monkeypatch.setenv("FF_ENABLE_MVP_WEDGE_ONBOARDING", "true")

    resp = client.get("/api/v1/config/feature-flags")

    assert resp.status_code == 200
    assert resp.json()["enableMvpWedgeOnboarding"] is True


def test_feature_flags_endpoint_defaults_mvp_wedge_onboarding_off(
    client,
    monkeypatch,
):
    monkeypatch.delenv("FF_ENABLE_MVP_WEDGE_ONBOARDING", raising=False)

    resp = client.get("/api/v1/config/feature-flags")

    assert resp.status_code == 200
    assert resp.json()["enableMvpWedgeOnboarding"] is False


def test_feature_flags_endpoint_is_available_before_login(monkeypatch):
    monkeypatch.setenv("FF_ENABLE_MVP_WEDGE_ONBOARDING", "true")
    original_overrides = app.dependency_overrides.copy()

    try:
        app.dependency_overrides.pop(require_current_user, None)
        app.dependency_overrides.pop(get_current_user, None)

        with TestClient(app) as anonymous_client:
            resp = anonymous_client.get("/api/v1/config/feature-flags")
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(original_overrides)

    assert resp.status_code == 200
    assert resp.json()["enableMvpWedgeOnboarding"] is True
