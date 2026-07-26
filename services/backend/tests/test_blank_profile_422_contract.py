"""Plan 06 W1-06-01 — Concern D parametrized contract test.

Single source of truth for « every W1-patched endpoint returns 422 on blank
profile » across Plans 02 + 03 + 06 (Batches A/B/C/D).

19 endpoints total covered :
  - Plan 02 (3) : arbitrage/allocation-annuelle, mortgage/affordability,
                  lpp-deep/rachat-echelonne
  - Plan 03 (4) : fiscal/wealth-tax/estimate, life-events/succession/simulate,
                  family/concubinage/succession, arbitrage/location-vs-propriete
  - Plan 06 Batch A (5) : arbitrage/rente-vs-capital, /rachat-vs-marche,
                          /calendrier-retraits, mortgage/imputed-rental,
                          mortgage/amortization
  - Plan 06 Batch B (5) : lpp-deep/epl, family/mariage/compare,
                          family/naissance/allocations, family/concubinage/compare,
                          mortgage/epl-combined
  - Plan 06 Batch C (5) : retirement/lpp/compare, independants/3a-independant,
                          independants/dividende-vs-salaire,
                          expat/frontalier/source-tax, expat/frontalier/lamal-option
  - Plan 06 Batch D (4) : life-events/divorce/simulate, life-events/donation/simulate,
                          unemployment/calculate, assurances/coverage/check

Pattern : strict-mode + blank profile + canton-less body → 422 with
`CoachToolIncomplete` envelope (camelCase: status / missingFields / hintFr).

LSFin (CLAUDE.md §1) : hintFr assertions use conversational ask vocabulary
(« besoin », « partager », « préciser ») — no banned terms.
"""
from __future__ import annotations

import pytest


# Reload the resolver in strict mode for the entire module — every contract
# test below asserts the strict-mode 422 path.
@pytest.fixture(autouse=True)
def _strict_mode(monkeypatch: pytest.MonkeyPatch):
    """Enable D-CE-08 strict mode for this module without reloading endpoint
    modules.

    AVOIDING IMPORTLIB.RELOAD on endpoint modules :
    each `importlib.reload(ep)` re-runs all `@limiter.limit("X/minute")`
    decorators in the module, which APPENDS to `slowapi.Limiter._route_limits`
    instead of replacing. After 11 endpoint reloads we end up with 154+ stale
    entries — when a downstream test hits `/api/v1/retirement/avs/estimate`,
    slowapi finds multiple matching limit specs and applies them all,
    causing every request to 429 instantly even with a fresh storage.

    Instead of reloading, we mutate the module-level constant
    `PROFILE_GROUNDING_STRICT_MODE` on the resolver directly. This is the only
    state the `raise_incomplete_as_422` helper actually reads — and it's read
    at call-time, not at decorator-stamp-time. No reload needed.
    """
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "true")
    from app.core import profile_resolver as pr
    monkeypatch.setattr(pr, "PROFILE_GROUNDING_STRICT_MODE", True)
    yield
    # monkeypatch.setattr is auto-undone on teardown — no manual restore.


# --------------------------------------------------------------------------- #
# W1 Grounded endpoint matrix                                                 #
# --------------------------------------------------------------------------- #
#
# Each entry :
#   path           — REST path
#   body_no_canton — minimal request body WITHOUT canton (the rest of the
#                    required fields supplied so Pydantic validation passes
#                    the canton-grounding-missing case)
# --------------------------------------------------------------------------- #


W1_GROUNDED_ENDPOINTS: list[tuple[str, dict]] = [
    # ---- Plan 02 (3) ----
    ("/api/v1/arbitrage/allocation-annuelle", {"montant_disponible": 10000, "taux_marginal": 0.30}),
    ("/api/v1/mortgage/affordability", {"prixAchat": 800000}),
    ("/api/v1/lpp-deep/rachat-echelonne", {"rachatMax": 50000}),
    # ---- Plan 03 (4) ----
    ("/api/v1/fiscal/wealth-tax/estimate", {"fortune_nette": 500000}),
    ("/api/v1/life-events/succession/simulate", {
        "fortuneTotale": 500000,
        "etatCivil": "celibataire",
        "aConjoint": False,
        "nombreEnfants": 1,
        "aParentsVivants": False,
        "aFratrie": False,
        "aConcubin": False,
        "aTestament": False,
    }),
    ("/api/v1/family/concubinage/succession", {}),
    ("/api/v1/arbitrage/location-vs-propriete", {
        "capitalDisponible": 200000,
        "loyerMensuelActuel": 2500,
        "prixBien": 800000,
    }),
    # ---- Plan 06 Batch A (5) ----
    ("/api/v1/arbitrage/rente-vs-capital", {
        "capital_lpp_total": 500000,
        "capital_obligatoire": 300000,
        "capital_surobligatoire": 200000,
        "rente_annuelle_proposee": 30000,
    }),
    ("/api/v1/arbitrage/rachat-vs-marche", {"montant": 50000, "taux_marginal": 0.30}),
    ("/api/v1/arbitrage/calendrier-retraits", {
        "assets": [
            {"type": "3a", "amount": 100000, "earliest_withdrawal_age": 60},
            {"type": "lpp", "amount": 300000, "earliest_withdrawal_age": 65},
        ],
    }),
    ("/api/v1/mortgage/imputed-rental", {"valeurVenale": 1000000}),
    ("/api/v1/mortgage/amortization", {
        "montantHypothecaire": 600000,
        "tauxInteret": 0.025,
    }),
    # ---- Plan 06 Batch B (5) ----
    ("/api/v1/lpp-deep/epl", {
        "avoirLppTotal": 300000,
        "avoirObligatoire": 200000,
        "avoirSurobligatoire": 100000,
        "age": 40,
        "montantRetraitSouhaite": 50000,
    }),
    ("/api/v1/family/mariage/compare", {"revenu_1": 100000, "revenu_2": 80000}),
    ("/api/v1/family/naissance/allocations", {"nb_enfants": 2, "ages_enfants": [3, 5]}),
    ("/api/v1/family/concubinage/compare", {"revenu_1": 100000, "revenu_2": 80000}),
    ("/api/v1/mortgage/epl-combined", {"avoir3a": 50000, "avoirLppTotal": 200000}),
    # ---- Plan 06 Batch C (5) ----
    ("/api/v1/retirement/lpp/compare", {"capital_lpp": 500000}),
    ("/api/v1/independants/3a-independant", {
        "revenu_net": 100000,
        "affilie_lpp": False,
        "taux_marginal_imposition": 0.30,
    }),
    ("/api/v1/independants/dividende-vs-salaire", {
        "benefice_disponible": 200000,
        "part_salaire": 0.5,
        "taux_marginal": 0.30,
    }),
    ("/api/v1/expat/frontalier/source-tax", {"salary": 100000}),
    ("/api/v1/expat/frontalier/lamal-option", {"age": 35}),
    # ---- Plan 06 Batch D (4) ----
    ("/api/v1/life-events/divorce/simulate", {
        "dureeMarriageAnnees": 10,
        "revenuAnnuelConjoint1": 100000,
        "revenuAnnuelConjoint2": 80000,
    }),
    ("/api/v1/life-events/donation/simulate", {
        "montant": 50000,
        "lienParente": "descendant",
    }),
    ("/api/v1/unemployment/calculate", {
        "gainAssureMensuel": 6000,
        "age": 40,
        "anneesCotisation": 24,
    }),
    ("/api/v1/assurances/coverage/check", {"statutProfessionnel": "salarie"}),
]


# --------------------------------------------------------------------------- #
# Test — blank profile → 422 with CoachToolIncomplete envelope                #
# --------------------------------------------------------------------------- #


@pytest.mark.parametrize("path,body", W1_GROUNDED_ENDPOINTS)
def test_blank_profile_yields_422_with_envelope(
    client_with_blank_profile, path, body
):
    """Every W1-grounded endpoint returns 422 + CoachToolIncomplete envelope
    when profile is blank and body lacks the grounded field(s)."""
    resp = client_with_blank_profile.post(path, json=body)
    assert resp.status_code == 422, (
        f"{path}: expected 422 with CoachToolIncomplete envelope, "
        f"got {resp.status_code}: {resp.text[:300]}"
    )
    payload = resp.json()
    detail = payload.get("detail", {})
    assert isinstance(detail, dict), (
        f"{path}: expected CoachToolIncomplete envelope dict, got "
        f"Pydantic stock validation error: {detail!r}"
    )
    assert detail.get("status") == "incomplete", (
        f"{path}: envelope status wrong: {detail!r}"
    )
    assert "missingFields" in detail, (
        f"{path}: missingFields missing: {detail!r}"
    )
    assert isinstance(detail["missingFields"], list)
    assert len(detail["missingFields"]) >= 1
    # Cap=3 inherited from Plan 01 envelope — never exceed.
    assert len(detail["missingFields"]) <= 3, (
        f"{path}: missingFields cap=3 violated: {detail['missingFields']!r}"
    )
    assert "hintFr" in detail, f"{path}: hintFr missing: {detail!r}"
    # LSFin sanity : hintFr must contain conversational ask vocabulary.
    hint_lower = detail["hintFr"].lower()
    assert any(
        kw in hint_lower
        for kw in ("besoin", "partager", "préciser", "envisager", "pourrait")
    ), f"{path}: hintFr lacks conversational ask vocabulary: {detail['hintFr']!r}"


# --------------------------------------------------------------------------- #
# Regression guard — coverage scoreboard                                       #
# --------------------------------------------------------------------------- #


def test_w1_endpoint_count_meets_target():
    """Sanity check that this contract test covers ≥25 W1-grounded endpoints
    per Plan 06 acceptance criterion (Task 2 success_criteria)."""
    # Cumulative W0 closure target after Plan 06 :
    # Plan 02 (3) + Plan 03 (4) + Plan 06 (4 batches × 4-5) = 26 endpoints.
    assert len(W1_GROUNDED_ENDPOINTS) >= 25, (
        f"W1_GROUNDED_ENDPOINTS coverage shrank to {len(W1_GROUNDED_ENDPOINTS)} — "
        "did a Plan 06 batch get rolled back without updating this test?"
    )


def test_at_least_seven_endpoint_files_grounded():
    """`grep -lE 'Depends\\(get_profile_filled\\)'` over the endpoints dir
    must return ≥10 files post-Plan-06 (target was ≥7 in Plan 06 acceptance)."""
    import subprocess
    result = subprocess.run(
        ["grep", "-l", "Depends(get_profile_filled)"]
        + [
            f"app/api/v1/endpoints/{name}.py"
            for name in [
                "arbitrage", "mortgage", "lpp_deep", "wealth_tax",
                "life_events", "family", "retirement", "independants",
                "expat", "unemployment", "assurances",
            ]
        ],
        capture_output=True,
        text=True,
        cwd=".",
    )
    grounded_files = [line for line in result.stdout.splitlines() if line.strip()]
    assert len(grounded_files) >= 10, (
        f"Expected ≥10 grounded endpoint files, got {len(grounded_files)}: "
        f"{grounded_files}"
    )
