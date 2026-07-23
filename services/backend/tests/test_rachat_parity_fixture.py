"""Parité croisée RACHAT ÉCHELONNÉ — côté backend (beads -81n/-97h).

Pendant mobile : apps/mobile/test/services/rachat_parity_fixture_test.dart.
Avant l'unification v2, coach (backend) et écran (mobile) donnaient des
conclusions bloc/étalé INVERSÉES sur les mêmes entrées.
"""

import json
from pathlib import Path

import pytest

from app.services.lpp_deep.rachat_echelonne_service import RachatEchelonneService

FIXTURE = (
    Path(__file__).resolve().parents[2].parent
    / "tools"
    / "fixtures"
    / "rachat_parity_v1.json"
)

_DATA = json.loads(FIXTURE.read_text(encoding="utf-8"))


@pytest.mark.parametrize("case", _DATA["cases"], ids=[c["id"] for c in _DATA["cases"]])
def test_rachat_backend_matches_shared_goldens(case):
    inp = case["inputs"]
    r = RachatEchelonneService().simulate(
        avoir_actuel=300_000,
        rachat_max=inp["rachat_max"],
        revenu_imposable=inp["revenu_imposable"],
        taux_marginal_estime=None,
        canton=inp["canton"],
        horizon_rachat_annees=inp["horizon"],
    )
    exp = case["expected"]
    tol = _DATA["tolerance_chf"]
    assert abs(r.bloc_economie_fiscale - exp["economie_bloc"]) <= tol
    assert abs(r.total_economie_fiscale - exp["economie_echelonnee"]) <= tol
    assert (r.economie_vs_bloc > 0) == exp["delta_positif_etale_gagne"], (
        "le SIGNE de la conclusion bloc/étalé doit être identique sur "
        "toutes les surfaces (anti-inversion)"
    )
