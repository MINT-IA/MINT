"""Contract tests for the profile-grounded `/api/v1/arbitrage/allocation-annuelle`
endpoint.

Plan: mint-calc-engine-v1-02 — W1 Priority-1 sev-3 endpoints (Task 1).

Verifies the W0 audit row 1 sev-2 fix for `allocation_annuelle.py` :
  - canton, is_property_owner, taux_hypothecaire, rendement_3a are now read
    from `_user.profile` via `_resolve_defaults` (D-CE-07) ;
  - missing required profile field → HTTP 422 with `CoachToolIncomplete`
    envelope when `PROFILE_GROUNDING_STRICT_MODE=true` (D-CE-08) ;
  - body explicit values WIN over profile (precedence kept from Plan 01) ;
  - body explicit None on a required field → 422 (explicit clear, NOT silent
    fallback to profile).

Threat-model coverage : T-mint-calc-02-01 (body override Tampering),
T-mint-calc-02-04 (LSFin hint_fr French text).

LSFin (CLAUDE.md §1) : hint_fr in the assertion uses « pourrait / envisager /
partager » vocabulary only. No banned terms.
"""
from __future__ import annotations

import importlib
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
    # Re-import the endpoint module so its `from app.core.profile_resolver
    # import ...` picks up the reloaded constants.
    from app.api.v1.endpoints import arbitrage as arb_ep
    importlib.reload(arb_ep)
    yield
    # Restore the resolver to default (false) for downstream tests.
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "false")
    importlib.reload(pr)
    importlib.reload(arb_ep)


def _seed_profile(data: dict) -> None:
    """Insert a ProfileModel row tied to the conftest `_fake_user` (test-user-id)."""
    db = TestingSessionLocal()
    try:
        # Wipe any pre-existing rows so each test starts from a known baseline.
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
    """W0 sev-2 fix : with no profile fields, endpoint returns 422 with
    `CoachToolIncomplete` envelope (camelCase aliases) — NOT a silent
    hardcoded-VD computation."""
    resp = client_with_blank_profile.post(
        "/api/v1/arbitrage/allocation-annuelle",
        json={"montantDisponible": 10000, "tauxMarginal": 0.25},
    )
    assert resp.status_code == 422, (
        f"Expected 422 with CoachToolIncomplete envelope, got "
        f"{resp.status_code}: {resp.text}"
    )
    body = resp.json()
    detail = body.get("detail", {})
    # Pydantic stock validation errors return `detail` as a list — the
    # CoachToolIncomplete envelope returns it as a dict. Differentiate.
    assert isinstance(detail, dict), (
        f"Expected CoachToolIncomplete envelope dict, got list (Pydantic "
        f"validation error): {detail!r}"
    )
    assert detail["status"] == "incomplete"
    assert "missingFields" in detail
    assert isinstance(detail["missingFields"], list)
    assert len(detail["missingFields"]) >= 1
    # Cap=3 inherited from Plan 01 envelope — never exceed.
    assert len(detail["missingFields"]) <= 3
    assert "hintFr" in detail
    # LSFin sanity : hint_fr must contain conversational ask vocabulary.
    assert any(
        kw in detail["hintFr"].lower()
        for kw in ("besoin", "partager", "préciser", "envisager")
    ), f"hintFr lacks conversational ask vocabulary: {detail['hintFr']!r}"


# --------------------------------------------------------------------------- #
# Test 2 — full profile → 200, canton from profile drives the response        #
# --------------------------------------------------------------------------- #


def test_full_profile_uses_canton_from_profile(client):
    """When profile has all required fields, endpoint returns 200 and the
    response.canton echoes the PROFILE canton (GE), not the hardcoded VD."""
    _seed_profile({
        "canton": "GE",
        "is_property_owner": True,
        "taux_hypothecaire": 0.028,
        "rendement_3a": 0.02,
    })
    resp = client.post(
        "/api/v1/arbitrage/allocation-annuelle",
        json={"montantDisponible": 10000, "tauxMarginal": 0.25},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    # The service builds an `hypotheses` list that includes the canton text
    # — assert canton:GE is mentioned, NOT VD.
    hypos_joined = " ".join(body.get("hypotheses", []))
    assert "GE" in hypos_joined, (
        f"Expected canton GE in hypotheses, got: {hypos_joined!r}"
    )
    assert "VD" not in hypos_joined, (
        f"Hardcoded VD leaked despite profile canton=GE : {hypos_joined!r}"
    )


# --------------------------------------------------------------------------- #
# Test 3 — body explicit None → 422 (explicit clear wins over profile)        #
# --------------------------------------------------------------------------- #


def test_body_explicit_null_canton_returns_422(client):
    """T-mint-calc-02-01 mitigation : body explicit None must NOT silently
    fall back to profile. Plan 01 `_resolve_defaults` honors
    `body.model_fields_set` — explicit-None is preserved as a required-missing
    signal."""
    _seed_profile({
        "canton": "GE",
        "is_property_owner": True,
        "taux_hypothecaire": 0.028,
        "rendement_3a": 0.02,
    })
    resp = client.post(
        "/api/v1/arbitrage/allocation-annuelle",
        json={
            "montantDisponible": 10000,
            "tauxMarginal": 0.25,
            "canton": None,  # explicit clear
        },
    )
    assert resp.status_code == 422, resp.text
    detail = resp.json().get("detail", {})
    assert isinstance(detail, dict), (
        f"Expected CoachToolIncomplete envelope, got: {detail!r}"
    )
    assert detail["status"] == "incomplete"
    assert "canton" in detail["missingFields"]


# --------------------------------------------------------------------------- #
# Test 4 — body explicit value WINS over profile                              #
# --------------------------------------------------------------------------- #


def test_body_canton_overrides_profile_canton(client):
    """When body and profile both have canton, body wins (precedence per
    Plan 01 D-CE-07). Profile=GE, body=VD → response uses VD."""
    _seed_profile({
        "canton": "GE",
        "is_property_owner": True,
        "taux_hypothecaire": 0.028,
        "rendement_3a": 0.02,
    })
    resp = client.post(
        "/api/v1/arbitrage/allocation-annuelle",
        json={
            "montantDisponible": 10000,
            "tauxMarginal": 0.25,
            "canton": "VD",  # body wins
        },
    )
    assert resp.status_code == 200, resp.text
    hypos_joined = " ".join(resp.json().get("hypotheses", []))
    assert "VD" in hypos_joined, (
        f"Expected canton VD (body override) in hypotheses, got: {hypos_joined!r}"
    )


class TestBlocageLpp79bAl3:
    """Art. 79b al. 3 : rachats à <3 ans du retrait capital -> déduction reprise.

    beads MINT_nosync-okl (review Codex) : les miroirs backend créditaient
    l'économie de toutes les années malgré le retrait capital modélisé.
    """

    def test_allocation_rachat_blocked_years_credit_no_saving(self):
        from app.services.arbitrage.allocation_annuelle import (
            _build_rachat_lpp_option,
        )
        option = _build_rachat_lpp_option(
            montant=10_000.0,
            potentiel_rachat=1_000_000.0,
            taux_marginal=0.30,
            annees=10,
            rendement_lpp=0.0,
            canton="ZH",
        )
        # Convention start-of-year : délai = annees - i ; bloqué ssi < 3
        # -> i=8,9 bloqués, 8 années créditées : 8 x 3'000 = 24'000.
        assert option.trajectory[-2].cumulative_tax_delta == -24_000.0

    def test_allocation_rachat_short_horizon_all_blocked(self):
        from app.services.arbitrage.allocation_annuelle import (
            _build_rachat_lpp_option,
        )
        option = _build_rachat_lpp_option(
            montant=10_000.0,
            potentiel_rachat=1_000_000.0,
            taux_marginal=0.30,
            annees=2,
            rendement_lpp=0.0,
            canton="ZH",
        )
        assert all(s.cumulative_tax_delta == 0.0 for s in option.trajectory)

    def test_rachat_vs_marche_short_horizon_no_saving(self):
        from app.services.arbitrage.rachat_vs_marche import (
            _build_rachat_option,
        )
        option = _build_rachat_option(
            montant=50_000.0,
            taux_marginal=0.35,
            annees_avant_retraite=2,
            rendement_lpp=0.0,
            taux_conversion=0.068,
            canton="ZH",
            is_married=False,
        )
        # Rachat en t=0, retrait à 2 ans -> déduction reprise (0 crédité).
        assert option.trajectory[0].cumulative_tax_delta == 0.0
