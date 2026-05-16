"""Contract tests for the profile-grounded `/api/v1/lpp-deep/rachat-echelonne`
endpoint.

Plan: mint-calc-engine-v1-02 — W1 Priority-1 sev-3 endpoints (Task 3).

Verifies the W0 audit row 14 SEV-3 fix for `rachat_echelonne_service.py` :
  - canton, age, salary, marital_status are now read from `_user.profile`
    via `_resolve_defaults` (D-CE-07) ;
  - missing required profile field → HTTP 422 with `CoachToolIncomplete`
    envelope (D-CE-08) ;
  - **regression guard (sev-3 incident class)** : profile.canton=null +
    body.canton=null → 422 with envelope, NOT a 500 crash from
    `TAUX_MARGINAUX_PAR_CANTON[None]` KeyError (T-mint-calc-02-03 DoS
    mitigation).

This was the canton-dependent tax-bracket smoking gun for the W0 audit's
12 sev-3 endpoints (~15-30% wrong tax brackets for non-VD users today).

Plan 02 also adds `Depends(require_current_user)` to this endpoint as a
Rule 2 auto-add (missing auth + profile-grounded route).

LSFin (CLAUDE.md §1) : hint_fr in assertions uses « partager / besoin »
vocabulary only.
"""
from __future__ import annotations

import importlib
from uuid import uuid4

import pytest

from app.models.profile_model import ProfileModel
from tests.conftest import TestingSessionLocal


@pytest.fixture(autouse=True)
def _strict_mode(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "true")
    from app.core import profile_resolver as pr
    importlib.reload(pr)
    from app.api.v1.endpoints import lpp_deep as lpp_ep
    importlib.reload(lpp_ep)
    yield
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "false")
    importlib.reload(pr)
    importlib.reload(lpp_ep)


def _seed_profile(data: dict) -> None:
    db = TestingSessionLocal()
    try:
        db.query(ProfileModel).filter(
            ProfileModel.user_id == "test-user-id"
        ).delete()
        db.add(ProfileModel(
            id=str(uuid4()),
            user_id="test-user-id",
            data=data,
        ))
        db.commit()
    finally:
        db.close()


# --------------------------------------------------------------------------- #
# Test 1 — blank profile → 422 (NOT 500 crash, NOT silent VD)                  #
# --------------------------------------------------------------------------- #


def test_blank_profile_returns_422_not_500(client_with_blank_profile):
    """Sev-3 incident reproduction : with blank profile + minimal body, the
    endpoint MUST return 422 with CoachToolIncomplete envelope. Not a 500
    crash, not a silent VD default that ships wrong tax brackets to a GE/JU
    user."""
    resp = client_with_blank_profile.post(
        "/api/v1/lpp-deep/rachat-echelonne",
        json={"avoirActuel": 50000, "rachatMax": 30000},
    )
    assert resp.status_code == 422, (
        f"Expected 422 with CoachToolIncomplete envelope, got "
        f"{resp.status_code}: {resp.text}"
    )
    body = resp.json()
    detail = body.get("detail", {})
    assert isinstance(detail, dict), (
        f"Expected CoachToolIncomplete envelope dict (sev-3 incident class), "
        f"got list/raw Pydantic error: {detail!r}"
    )
    assert detail["status"] == "incomplete"
    assert len(detail["missingFields"]) >= 1
    assert len(detail["missingFields"]) <= 3
    assert "canton" in detail["missingFields"], (
        f"Expected `canton` in missingFields (sev-3 root cause), got: "
        f"{detail['missingFields']}"
    )
    assert "hintFr" in detail


# --------------------------------------------------------------------------- #
# Test 2 — profile.canton=GE drives the response (NOT hardcoded VD)            #
# --------------------------------------------------------------------------- #


def test_full_profile_uses_canton_from_profile(client):
    """Profile.canton=GE + body omits canton → response.canton == GE.
    Closes the « ~15-30% wrong tax brackets for non-VD users » incident."""
    _seed_profile({
        "canton": "GE",
        "revenu_imposable": 120000,
    })
    resp = client.post(
        "/api/v1/lpp-deep/rachat-echelonne",
        json={
            "avoirActuel": 50000,
            "rachatMax": 30000,
            "horizonRachatAnnees": 3,
        },
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["canton"] == "GE", (
        f"Expected canton GE from profile (sev-3 fix), got: "
        f"{body.get('canton')!r}. Wrong tax brackets shipped to non-VD user."
    )


# --------------------------------------------------------------------------- #
# Test 3 — profile lacks revenuImposable → 422 with envelope                   #
# --------------------------------------------------------------------------- #


def test_missing_revenu_imposable_returns_422(client):
    """Profile has canton but lacks revenu_imposable → 422 with envelope
    listing revenu_imposable as missing (NOT silent zero-income calc)."""
    _seed_profile({
        "canton": "GE",
    })
    resp = client.post(
        "/api/v1/lpp-deep/rachat-echelonne",
        json={
            "avoirActuel": 50000,
            "rachatMax": 30000,
            "horizonRachatAnnees": 3,
        },
    )
    assert resp.status_code == 422, resp.text
    detail = resp.json().get("detail", {})
    assert isinstance(detail, dict)
    assert detail["status"] == "incomplete"
    assert "revenu_imposable" in detail["missingFields"], (
        f"Expected `revenu_imposable` in missingFields, got: "
        f"{detail['missingFields']}"
    )


# --------------------------------------------------------------------------- #
# Test 4 — null-canton regression guard (T-mint-calc-02-03 DoS mitigation)     #
# --------------------------------------------------------------------------- #


def test_null_canton_returns_422_not_500(client):
    """REGRESSION GUARD for the sev-3 incident class : profile.canton=None
    + body.canton=None must return 422 BEFORE the service layer attempts
    `TAUX_MARGINAUX_PAR_CANTON[None]` which would raise KeyError → 500.

    Plan 01's `_required_profile_fields_missing` is the gate that catches
    None canton ahead of the service-layer lookup."""
    _seed_profile({
        "canton": None,
        "revenu_imposable": 120000,
    })
    resp = client.post(
        "/api/v1/lpp-deep/rachat-echelonne",
        json={
            "avoirActuel": 50000,
            "rachatMax": 30000,
            "canton": None,
            "horizonRachatAnnees": 3,
        },
    )
    assert resp.status_code == 422, (
        f"Sev-3 regression : expected 422 with envelope, got "
        f"{resp.status_code} (likely a 500 KeyError on CANTON_BRACKETS[None]): "
        f"{resp.text}"
    )
    detail = resp.json().get("detail", {})
    assert isinstance(detail, dict), (
        f"Sev-3 regression : expected CoachToolIncomplete envelope, got: "
        f"{detail!r}"
    )
    assert detail["status"] == "incomplete"
    assert "canton" in detail["missingFields"]
