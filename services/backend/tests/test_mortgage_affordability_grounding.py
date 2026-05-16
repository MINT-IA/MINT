"""Contract tests for the profile-grounded `/api/v1/mortgage/affordability`
endpoint.

Plan: mint-calc-engine-v1-02 — W1 Priority-1 sev-3 endpoints (Task 2).

Verifies the W0 audit row 7 sev-1 fix for `affordability_service.py` :
  - canton, revenu_brut_annuel, avoir_3a, avoir_lpp are now read from
    `_user.profile` via `_resolve_defaults` (D-CE-07) ;
  - missing required profile field → HTTP 422 with `CoachToolIncomplete`
    envelope when `PROFILE_GROUNDING_STRICT_MODE=true` (D-CE-08) ;
  - the regulatory `HYPOTHEQUE_TAUX_THEORIQUE` constant in
    `affordability_service.py` is NEVER user-overridable (FINMA art. 28) and
    is asserted untouched by this plan ;
  - canton from profile drives the response (no silent hardcoded ZH default).

Plan 02 also adds `Depends(require_current_user)` to this endpoint as a
Rule 2 auto-add (missing auth on a profile-grounded route is a critical
correctness gap — documented in the plan SUMMARY).

LSFin (CLAUDE.md §1) : hint_fr in assertions uses « partager / besoin »
vocabulary only.
"""
from __future__ import annotations

import importlib
import inspect
from pathlib import Path
from uuid import uuid4

import pytest

from app.models.profile_model import ProfileModel
from tests.conftest import TestingSessionLocal


@pytest.fixture(autouse=True)
def _strict_mode(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "true")
    from app.core import profile_resolver as pr
    importlib.reload(pr)
    from app.api.v1.endpoints import mortgage as mortgage_ep
    importlib.reload(mortgage_ep)
    yield
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "false")
    importlib.reload(pr)
    importlib.reload(mortgage_ep)


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
# Test 1 — blank profile → 422 with CoachToolIncomplete envelope               #
# --------------------------------------------------------------------------- #


def test_blank_profile_returns_422_with_envelope(client_with_blank_profile):
    """Without profile data and without all required body fields, the
    endpoint returns 422 carrying the CoachToolIncomplete envelope (camelCase
    aliases), NOT a silent calc against hardcoded ZH + 0 income."""
    resp = client_with_blank_profile.post(
        "/api/v1/mortgage/affordability",
        json={"prixAchat": 800000, "epargneDisponible": 200000},
    )
    assert resp.status_code == 422, (
        f"Expected 422 with CoachToolIncomplete envelope, got "
        f"{resp.status_code}: {resp.text}"
    )
    body = resp.json()
    detail = body.get("detail", {})
    assert isinstance(detail, dict), (
        f"Expected CoachToolIncomplete envelope dict, got list (Pydantic "
        f"validation error): {detail!r}"
    )
    assert detail["status"] == "incomplete"
    assert isinstance(detail["missingFields"], list)
    assert len(detail["missingFields"]) >= 1
    assert len(detail["missingFields"]) <= 3
    assert "hintFr" in detail
    assert any(
        kw in detail["hintFr"].lower()
        for kw in ("besoin", "partager", "préciser", "envisager")
    ), f"hintFr lacks conversational vocabulary: {detail['hintFr']!r}"


# --------------------------------------------------------------------------- #
# Test 2 — full profile → 200, canton from profile drives the response        #
# --------------------------------------------------------------------------- #


def test_full_profile_uses_canton_from_profile(client):
    """Profile.canton=GE, body omits canton → response.canton == GE
    (NOT the schema default ZH)."""
    _seed_profile({
        "canton": "GE",
        "income_gross_yearly": 180000,
        "epargne_3a": 50000,
        "avoir_lpp": 100000,
    })
    resp = client.post(
        "/api/v1/mortgage/affordability",
        json={"prixAchat": 800000, "epargneDisponible": 200000},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["canton"] == "GE", (
        f"Expected canton GE from profile, got: {body.get('canton')!r}"
    )


# --------------------------------------------------------------------------- #
# Test 3 — regulatory constant HYPOTHEQUE_TAUX_THEORIQUE preserved             #
# --------------------------------------------------------------------------- #


def test_regulatory_taux_theorique_constant_untouched():
    """T-mint-calc-02-05 boundary : `HYPOTHEQUE_TAUX_THEORIQUE` is the FINMA
    art. 28 regulatory theoretical rate. It is NOT a user-profile field and
    must remain a module-level constant in the service file. Plan 02 must
    NOT add a `from_profile` marker for it."""
    service_path = Path(inspect.getfile(
        __import__(
            "app.services.mortgage.affordability_service",
            fromlist=["affordability_service"],
        )
    ))
    source = service_path.read_text()
    assert "HYPOTHEQUE_TAUX_THEORIQUE" in source, (
        "Regulatory constant HYPOTHEQUE_TAUX_THEORIQUE missing from "
        "affordability_service.py — should never have been removed."
    )

    # Cross-check: the request schema must NOT carry a from_profile marker
    # pointing at the theoretical rate (it's regulatory, not user-data).
    schema_path = Path(inspect.getfile(
        __import__(
            "app.schemas.mortgage",
            fromlist=["mortgage"],
        )
    ))
    schema_src = schema_path.read_text()
    assert "from_profile" not in schema_src or (
        "taux_theorique" not in schema_src.lower()
    ), (
        "Regulatory taux_theorique should NEVER carry a from_profile marker "
        "(threat T-mint-calc-02-05)."
    )
