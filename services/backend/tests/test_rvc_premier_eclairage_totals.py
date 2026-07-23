"""Premier éclairage RvC backend — valeurs économiques TOTALES.

beads MINT_nosync-h5i (audit). Bug prouvé sur dev
(rente_vs_capital.py::_build_premier_eclairage) : le chiffre choc comparait
`terminal_value` des deux options, or pour la rente c'est le revenu net
CUMULÉ tandis que pour le capital c'est le solde RÉSIDUEL après retraits SWR
— les retraits déjà consommés disparaissaient du bilan (pommes/oranges).
Le moteur mobile fait juste (capitalTotalValue = Σ retraits + résiduel).

Les tests recalculent les totaux depuis les trajectoires RÉELLES retournées
par compare_rente_vs_capital — aucun chiffre fabriqué.
"""
import re

from app.services.arbitrage.rente_vs_capital import compare_rente_vs_capital


def _totals(result):
    rente = next(o for o in result.options if o.id == "full_rente")
    capital = next(o for o in result.options if o.id == "full_capital")
    capital_total = (
        sum(s.annual_cashflow for s in capital.trajectory)
        + capital.terminal_value
    )
    return rente.terminal_value, capital_total, capital.terminal_value


def _delta_in_text(text):
    m = re.search(r"représenter ([\d,]+) CHF", text)
    assert m, f"pas de delta dans le premier éclairage : {text!r}"
    return float(m.group(1).replace(",", ""))


def test_eclairage_delta_is_total_economic_value():
    result = compare_rente_vs_capital(
        capital_lpp_total=500000.0,
        capital_obligatoire=400000.0,
        capital_surobligatoire=100000.0,
        rente_annuelle_proposee=34000.0,
        canton="VD",
        horizon=25,
    )
    rente_total, capital_total, residual = _totals(result)
    expected_delta = round(abs(capital_total - rente_total))

    delta_shown = _delta_in_text(result.premier_eclairage)
    assert abs(delta_shown - expected_delta) <= 1, (
        f"delta affiché {delta_shown} != |Σ retraits + résiduel − rente "
        f"cumulée| = {expected_delta} (l'ancien code affichait "
        f"|résiduel − rente| = {round(abs(residual - rente_total))})"
    )


def test_eclairage_branch_follows_total_not_residual():
    """Cas à bascule : résiduel < rente cumulée MAIS total capital > rente.

    L'ancien code annonçait « la rente pourrait représenter X de plus »
    alors qu'en valeur économique totale c'est le capital qui est devant —
    le sens même du chiffre choc était inversé.
    """
    result = compare_rente_vs_capital(
        capital_lpp_total=500000.0,
        capital_obligatoire=400000.0,
        capital_surobligatoire=100000.0,
        rente_annuelle_proposee=20000.0,  # rente basse -> cumul modéré
        canton="VD",
        horizon=30,  # long horizon -> retraits cumulés dominants
        taux_retrait=0.05,
    )
    rente_total, capital_total, residual = _totals(result)
    # Préconditions du cas à bascule — si le moteur change et qu'elles ne
    # tiennent plus, le test doit être re-calibré, pas rendu vert par hasard.
    assert residual < rente_total, "précondition: résiduel < rente cumulée"
    assert capital_total > rente_total, "précondition: total capital > rente"

    assert "le retrait en capital" in result.premier_eclairage, (
        "le chiffre choc doit suivre la valeur totale (capital devant), "
        f"pas le seul résiduel : {result.premier_eclairage!r}"
    )


def test_eclairage_wording_names_total_economic_value():
    """Review Codex PR #971 : le libellé doit nommer la métrique réelle
    (« valeur economique totale »), pas « revenus cumules » / « patrimoine
    cumule » qui ne décrivent plus ce qui est comparé."""
    for rente in (20000.0, 60000.0):  # les deux branches
        result = compare_rente_vs_capital(
            capital_lpp_total=500000.0,
            capital_obligatoire=400000.0,
            capital_surobligatoire=100000.0,
            rente_annuelle_proposee=rente,
            canton="VD",
            horizon=25,
        )
        assert "valeur économique" in result.premier_eclairage, (
            result.premier_eclairage
        )


def test_sensitivity_spread_uses_total_values():
    """Review Codex PR #971 : la sensitivity Tornado répétait l'asymétrie
    (compute_terminal_spread sur terminal_value bruts). Le spread RvC doit
    passer par les valeurs économiques totales."""
    from app.services.arbitrage.rente_vs_capital import (
        _rvc_total_value_spread,
        _total_economic_value,
    )

    result = compare_rente_vs_capital(
        capital_lpp_total=500000.0,
        capital_obligatoire=400000.0,
        capital_surobligatoire=100000.0,
        rente_annuelle_proposee=34000.0,
        canton="VD",
        horizon=25,
    )
    totals = [_total_economic_value(o) for o in result.options]
    assert _rvc_total_value_spread(result.options) == max(totals) - min(totals)

    capital = next(o for o in result.options if o.id == "full_capital")
    assert _total_economic_value(capital) > capital.terminal_value, (
        "le total capital doit ré-additionner les retraits consommés"
    )

    # Verrou de câblage : la sensitivity RvC ne repasse plus par le spread
    # générique sur terminal_value bruts.
    from pathlib import Path

    source = (
        Path(__file__).resolve().parents[1]
        / "app/services/arbitrage/rente_vs_capital.py"
    ).read_text(encoding="utf-8")
    assert "compute_terminal_spread(" not in source, (
        "rente_vs_capital ne doit plus appeler compute_terminal_spread "
        "(asymétrie résiduel-vs-cumulé) — utiliser _rvc_total_value_spread"
    )
