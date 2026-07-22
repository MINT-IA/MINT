"""Receipt RvC — mode certificat (beads MINT_nosync-8wy).

Bug prouvé sur dev : `_rvc_calculation_receipt` flaguait `current_age`
« missing » inconditionnellement, alors que `compare_rente_vs_capital` ne le
consomme JAMAIS (aucune projection côté serveur). Conséquence : tout appel
certificat (valeurs réelles, sans âge) recevait readiness != ready et
missing_required_inputs non vide -> le receipt mobile fail-closed bloquait
le bloc résultat de l'écran.
"""
from app.api.v1.endpoints.arbitrage import _rvc_calculation_receipt
from app.services.arbitrage.rente_vs_capital import compare_rente_vs_capital


def _resolved(current_age=None):
    return {
        "capital_lpp_total": 650000.0,
        "capital_obligatoire": 500000.0,
        "capital_surobligatoire": 150000.0,
        "rente_annuelle_proposee": 37000.0,
        "taux_conversion_obligatoire": 0.068,
        "taux_conversion_surobligatoire": 0.05,
        "canton": "GE",
        "age_retraite": 65,
        "taux_retrait": 0.04,
        "rendement_capital": 0.03,
        "inflation": 0.02,
        "horizon": 25,
        "is_married": False,
        "current_age": current_age,
    }


def _result():
    return compare_rente_vs_capital(
        capital_lpp_total=650000.0,
        capital_obligatoire=500000.0,
        capital_surobligatoire=150000.0,
        rente_annuelle_proposee=37000.0,
        canton="GE",
    )


def test_certificate_call_without_age_is_ready():
    receipt = _rvc_calculation_receipt(resolved=_resolved(), result=_result())
    assert receipt.missing_required_inputs == [], (
        "current_age n'est pas un intrant du calcul backend — le flaguer "
        "missing bloquait tout résultat du mode certificat"
    )
    assert receipt.readiness == "ready"
    # Métadonnée exposée telle quelle (None accepté côté mobile).
    assert receipt.assumptions["current_age"] is None


def test_age_still_exposed_as_metadata_when_provided():
    receipt = _rvc_calculation_receipt(
        resolved=_resolved(current_age=45), result=_result()
    )
    assert receipt.readiness == "ready"
    assert receipt.assumptions["current_age"] == 45


def test_backend_calc_never_consumes_current_age():
    """Verrou structurel : le jour où compare_rente_vs_capital accepte un
    current_age (projection serveur), ce test force à re-décider la règle
    du receipt au lieu d'en hériter silencieusement."""
    import inspect

    params = inspect.signature(compare_rente_vs_capital).parameters
    assert "current_age" not in params, (
        "compare_rente_vs_capital consomme désormais current_age : "
        "ré-évaluer la règle missing_inputs du receipt (MINT_nosync-8wy)"
    )
