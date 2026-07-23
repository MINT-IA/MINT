"""Parité croisée RvC — côté backend (beads MINT_nosync-axj).

La fixture partagée ``tools/fixtures/rvc_parity_v1.json`` pine les sorties du
moteur canonique (rente_vs_capital.py, L2 comparer) ; le miroir Dart
(``arbitrage_engine.dart``) pine LES MÊMES valeurs dans
``apps/mobile/test/services/financial_core/rvc_parity_fixture_test.dart``.
Toute dérive unilatérale casse la suite du côté qui dérive : le chiffre servi
ne doit JAMAIS dépendre de la surface (écran backend-first vs fallback
offline vs plan/summary).
"""

import json
from pathlib import Path

import pytest

from app.services.arbitrage.rente_vs_capital import compare_rente_vs_capital

FIXTURE = (
    Path(__file__).resolve().parents[2].parent
    / "tools"
    / "fixtures"
    / "rvc_parity_v1.json"
)


def _load_cases():
    data = json.loads(FIXTURE.read_text(encoding="utf-8"))
    return data["tolerance_chf"], data["cases"]


TOL, CASES = _load_cases()


@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_rvc_backend_matches_shared_goldens(case):
    """Le moteur canonique reproduit les goldens partagés au centime."""
    inp = case["inputs"]
    kwargs = dict(
        capital_lpp_total=inp["capital_lpp_total"],
        capital_obligatoire=inp["capital_obligatoire"],
        capital_surobligatoire=inp["capital_surobligatoire"],
        rente_annuelle_proposee=inp["rente_annuelle_proposee"],
        canton=inp["canton"],
        is_married=inp["is_married"],
    )
    if inp["horizon"] is not None:
        kwargs["horizon"] = inp["horizon"]

    result = compare_rente_vs_capital(**kwargs)
    expected = case["expected"]

    assert result.breakeven_year == expected["breakeven_year"], (
        "breakeven relatif (années après retraite) — sémantique unifiée -axj"
    )
    by_id = {o.id: o for o in result.options}
    for oid in ("full_rente", "full_capital", "mixed"):
        assert abs(by_id[oid].terminal_value - expected[oid]["terminal_value"]) <= TOL, (
            f"{oid}.terminal_value: {by_id[oid].terminal_value} != "
            f"{expected[oid]['terminal_value']}"
        )
        assert (
            abs(by_id[oid].cumulative_tax_impact - expected[oid]["cumulative_tax_impact"])
            <= TOL
        ), (
            f"{oid}.cumulative_tax_impact: {by_id[oid].cumulative_tax_impact} != "
            f"{expected[oid]['cumulative_tax_impact']}"
        )


def test_default_horizon_is_30():
    """Défaut unifié avec le moteur mobile (l'ancien 25 backend ≠ 30 mobile)."""
    import inspect

    sig = inspect.signature(compare_rente_vs_capital)
    assert sig.parameters["horizon"].default == 30
