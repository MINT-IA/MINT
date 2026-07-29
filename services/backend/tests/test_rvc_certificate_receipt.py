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


def _resolved(current_age=None, input_mode=None, **overrides):
    resolved = {
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
        "input_mode": input_mode,
    }
    resolved.update(overrides)
    return resolved


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


def test_estimate_mode_without_age_still_flagged():
    """Review Codex PR #970 : le mobile annonce input_mode — une estimation
    incomplète (mode estimate, pas d'âge) doit rester bloquée côté backend,
    exactement comme le moteur local la bloque."""
    receipt = _rvc_calculation_receipt(
        resolved=_resolved(input_mode="estimate"), result=_result()
    )
    assert "current_age" in receipt.missing_required_inputs
    assert receipt.readiness != "ready"


def test_estimate_mode_with_age_is_ready():
    receipt = _rvc_calculation_receipt(
        resolved=_resolved(current_age=45, input_mode="estimate"),
        result=_result(),
    )
    assert receipt.missing_required_inputs == []
    assert receipt.readiness == "ready"


def test_zero_inputs_still_flagged():
    """Review Codex PR #970 : retirer le flag current_age ne doit pas rendre
    la readiness inconditionnelle — les intrants poubelle restent flagués
    (miroir de la liste du moteur mobile)."""
    receipt = _rvc_calculation_receipt(
        resolved=_resolved(
            capital_lpp_total=0.0,
            capital_obligatoire=0.0,
            capital_surobligatoire=0.0,
            rente_annuelle_proposee=0.0,
        ),
        result=_result(),
    )
    assert "capital_lpp_total" in receipt.missing_required_inputs
    assert "rente_annuelle_proposee" in receipt.missing_required_inputs
    assert receipt.readiness != "ready"


def test_junk_rates_flagged_like_mobile_engine():
    receipt = _rvc_calculation_receipt(
        resolved=_resolved(taux_retrait=0.0, taux_conversion_obligatoire=0.0),
        result=_result(),
    )
    assert "safe_withdrawal_rate" in receipt.missing_required_inputs
    assert "conversion_rate_obligatory" in receipt.missing_required_inputs


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
