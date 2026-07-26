"""Parametrized contract tests for the 4 Priority-2 sev-3 canton-required
endpoints grounded via `_resolve_defaults` + `CoachToolIncomplete`.

Plan: mint-calc-engine-v1-03 — W1 Priority-2 sev-3 endpoint grounding.

W0 audit rows covered (per W0-AUDIT-MATRIX.md § Recommended Fix Priority Order
line 229-233) :
  - row 24 sev-3 : `wealth_tax_service` (POST /api/v1/fiscal/wealth-tax/estimate)
  - row 26 sev-3 : `succession_simulator` (POST /api/v1/life-events/succession/simulate)
  - row 23 sev-3 : `concubinage_service` succession variant
                   (POST /api/v1/family/concubinage/succession)
  - row 3  sev-2 : `location_vs_propriete` (POST /api/v1/arbitrage/location-vs-propriete)

Each endpoint × 3 cases :
  - Test A : blank profile + body missing canton → 422 with CoachToolIncomplete envelope
  - Test B : profile.canton=GE + canton-less body → 200, canton=GE used
  - Test C (sev-3 regression guard) : body explicit `{"canton": None}` + blank profile
            → 422 (NOT a silent wrong-tax fallback nor a 500 KeyError)

5 endpoints × 3 tests would be 15 ; plan acceptance criterion says ≥12, so we
cover all 4 endpoints × 3 cases = 12 ; the 5th (location_vs_propriete row 3
sev-2) gets the same 3-case treatment for symmetry — final total 12 contract
tests.

LSFin (CLAUDE.md §1) : hint_fr assertions use « pourrait / envisager / partager »
vocabulary only. No banned terms.

Threat-model coverage :
  - T-mint-calc-03-01 (DoS via null canton → silent wrong tax / KeyError)
  - T-mint-calc-03-02 (Tampering : body explicit-None precedence over profile)
  - T-mint-calc-03-03 (LSFin : hint_fr French vocabulary)
"""
from __future__ import annotations

import importlib
from typing import Any
from uuid import uuid4

import pytest

from app.models.profile_model import ProfileModel
from tests.conftest import TestingSessionLocal


# Reload the resolver in strict mode for the entire module — every contract
# test below asserts the strict-mode 422 path. The non-strict graceful
# fallback is covered by `test_profile_resolver.py::test_non_strict_mode_*`.
@pytest.fixture(autouse=True)
def _strict_mode(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "true")
    from app.core import profile_resolver as pr
    importlib.reload(pr)
    # Re-import each touched endpoint module so its
    # `from app.core.profile_resolver import ...` picks up the reloaded constants.
    from app.api.v1.endpoints import wealth_tax as wt_ep
    from app.api.v1.endpoints import life_events as le_ep
    from app.api.v1.endpoints import family as fam_ep
    from app.api.v1.endpoints import arbitrage as arb_ep
    importlib.reload(wt_ep)
    importlib.reload(le_ep)
    importlib.reload(fam_ep)
    importlib.reload(arb_ep)
    yield
    # Restore the resolver to default (false) for downstream tests.
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "false")
    importlib.reload(pr)
    importlib.reload(wt_ep)
    importlib.reload(le_ep)
    importlib.reload(fam_ep)
    importlib.reload(arb_ep)


def _seed_profile(data: dict) -> None:
    """Insert a ProfileModel row tied to the conftest `_fake_user` (test-user-id)."""
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
# Endpoint matrix                                                             #
# --------------------------------------------------------------------------- #
#
# Each entry :
#   path                — REST path
#   body_no_canton      — minimal request body WITHOUT canton (the rest of the
#                         required fields supplied so Pydantic validation
#                         passes the canton-grounding-missing case)
#   canton_check_field  — JSON field on the response body whose VALUE contains
#                         the canton echo (used to assert that the profile
#                         canton drove the compute, not a hardcoded default)
#   canton_in_response  — `extract_fn(resp_json) -> str` used in Test B to
#                         pull the canton echo from the response (helpers
#                         differ per endpoint shape).
#
# Endpoint shapes are heterogeneous (camelCase aliases on some, snake_case
# on others, response shapes vary), so the matrix carries an extractor lambda.
# --------------------------------------------------------------------------- #


def _wealth_tax_canton(resp_json: dict) -> str:
    return resp_json["canton"]


def _succession_simulate_canton(resp_json: dict) -> str:
    # SuccessionSimulationResponse.fiscalite is a dict containing canton in some
    # heir rows + premier_eclairage in repartition. The simplest stable check :
    # the disclaimer / checklist mentions canton text. Fall back to scanning the
    # full JSON for the canton code.
    blob = str(resp_json)
    return blob


def _concubinage_succession_canton(resp_json: dict) -> str:
    return resp_json["canton"]


def _location_vs_propriete_canton(resp_json: dict) -> str:
    return " ".join(resp_json.get("hypotheses", []))


ENDPOINT_MATRIX = [
    pytest.param(
        "/api/v1/fiscal/wealth-tax/estimate",
        {"fortune_nette": 500000},
        _wealth_tax_canton,
        id="wealth_tax_estimate",
    ),
    pytest.param(
        "/api/v1/life-events/succession/simulate",
        {
            "fortuneTotale": 500000,
            "etatCivil": "celibataire",
            "aConjoint": False,
            "nombreEnfants": 1,
            "aParentsVivants": False,
            "aFratrie": False,
            "aConcubin": False,
            "aTestament": False,
        },
        _succession_simulate_canton,
        id="life_events_succession_simulate",
    ),
    pytest.param(
        "/api/v1/family/concubinage/succession",
        {},
        _concubinage_succession_canton,
        id="family_concubinage_succession",
    ),
    pytest.param(
        "/api/v1/arbitrage/location-vs-propriete",
        {
            "capitalDisponible": 200000,
            "loyerMensuelActuel": 2500,
            "prixBien": 800000,
        },
        _location_vs_propriete_canton,
        id="arbitrage_location_vs_propriete",
    ),
]


# --------------------------------------------------------------------------- #
# Test A — blank profile + canton-less body → 422 with CoachToolIncomplete    #
# --------------------------------------------------------------------------- #


@pytest.mark.parametrize("path,body_no_canton,_extract", ENDPOINT_MATRIX)
def test_blank_profile_returns_422_with_envelope(
    client_with_blank_profile, path, body_no_canton, _extract
):
    """W0 sev-3 fix : with no profile fields, endpoint returns 422 with
    `CoachToolIncomplete` envelope (camelCase aliases) — NOT a silent
    wrong-tax fallback nor a 500 KeyError on `CANTON_*_TAX[None]`."""
    resp = client_with_blank_profile.post(path, json=body_no_canton)
    assert resp.status_code == 422, (
        f"Expected 422 with CoachToolIncomplete envelope on {path}, got "
        f"{resp.status_code}: {resp.text}"
    )
    body = resp.json()
    detail = body.get("detail", {})
    assert isinstance(detail, dict), (
        f"Expected CoachToolIncomplete envelope dict on {path}, got list "
        f"(Pydantic stock validation error): {detail!r}"
    )
    assert detail["status"] == "incomplete"
    assert "missingFields" in detail
    assert isinstance(detail["missingFields"], list)
    assert "canton" in detail["missingFields"], (
        f"Expected 'canton' in missingFields on {path}, got: "
        f"{detail['missingFields']!r}"
    )
    # Cap=3 inherited from Plan 01 envelope — never exceed.
    assert len(detail["missingFields"]) <= 3
    assert "hintFr" in detail
    # LSFin sanity : hint_fr must contain conversational ask vocabulary.
    assert any(
        kw in detail["hintFr"].lower()
        for kw in ("besoin", "partager", "préciser", "envisager", "pourrait")
    ), f"hintFr lacks conversational ask vocabulary on {path}: {detail['hintFr']!r}"


# --------------------------------------------------------------------------- #
# Test B — profile.canton=GE drives the compute (no hardcoded default leak)   #
# --------------------------------------------------------------------------- #


@pytest.mark.parametrize("path,body_no_canton,extract", ENDPOINT_MATRIX)
def test_profile_canton_drives_compute(client, path, body_no_canton, extract):
    """When profile has canton=GE and body omits canton, the response echoes
    GE — NOT the legacy hardcoded VD/ZH/GE-default that ignored profile."""
    _seed_profile({"canton": "GE"})
    resp = client.post(path, json=body_no_canton)
    assert resp.status_code == 200, (
        f"Expected 200 with profile canton=GE on {path}, got "
        f"{resp.status_code}: {resp.text}"
    )
    canton_echo = extract(resp.json())
    assert "GE" in canton_echo, (
        f"Expected canton GE echoed on {path}, got: {canton_echo!r}"
    )


# --------------------------------------------------------------------------- #
# Test C — body explicit None → 422 (sev-3 regression guard, NOT 500/silent)  #
# --------------------------------------------------------------------------- #


@pytest.mark.parametrize("path,body_no_canton,_extract", ENDPOINT_MATRIX)
def test_explicit_null_canton_returns_422_not_500(
    client_with_blank_profile, path, body_no_canton, _extract
):
    """T-mint-calc-03-01 sev-3 regression guard : body explicit `canton: None`
    must return 422 with CoachToolIncomplete — NOT 500 from `CANTON_*_TAX[None]`
    nor a silent fallback to the wrong default canton.

    This is the structural fix that closes the sev-3 null-canton crash class
    for the 4 endpoints in this plan (W0 audit rows 3, 23, 24, 26).
    """
    body_with_null_canton: dict[str, Any] = {**body_no_canton, "canton": None}
    resp = client_with_blank_profile.post(path, json=body_with_null_canton)
    assert resp.status_code == 422, (
        f"sev-3 regression on {path}: expected 422 with CoachToolIncomplete "
        f"envelope, got {resp.status_code}: {resp.text}"
    )
    detail = resp.json().get("detail", {})
    assert isinstance(detail, dict), (
        f"Expected CoachToolIncomplete envelope on {path}, got: {detail!r}"
    )
    assert detail["status"] == "incomplete"
    assert "canton" in detail["missingFields"]
