"""is_married exposé dans les 4 API de retrait capital (beads MINT_nosync-uwv).

Depuis la bascule modèle v2 (-2i2 PR B), ces services appellent
``estimate_capital_withdrawal_tax`` en célibataire systématique : le
coefficient cantonal marié (audit swiss-brain 2026-04-18 Q5, ex. ZH 0.73)
existe dans le moteur mais n'est branché nulle part — review Codex #991 r1
finding 3. Ce module verrouille l'exposition bout-en-bout : paramètre
service + champ requête Pydantic.

Convention : ``is_married`` par défaut False/None — comportement historique
inchangé pour tous les appelants existants.
"""

import pytest

from app.schemas.arbitrage import AllocationAnnuelleRequest
from app.schemas.lpp_deep import EPLRequest
from app.schemas.mortgage import EplCombinedRequest
from app.schemas.retirement import LppConversionRequest
from app.services.arbitrage.allocation_annuelle import compare_allocation_annuelle
from app.services.lpp_deep.epl_service import EPLService
from app.services.mortgage.epl_combined_service import EplCombinedService
from app.services.retirement.lpp_conversion_service import LppConversionService


# ────────────────────────────────────────────────────────────
# Services — le paramètre existe et produit un impôt marié < célibataire
# (ZH : coefficient cantonal 0.73 sur la part cantonale/communale)
# ────────────────────────────────────────────────────────────


def _allocation(is_married: bool):
    return compare_allocation_annuelle(
        montant_disponible=7056,
        taux_marginal=0.30,
        annees_avant_retraite=20,
        canton="ZH",
        is_married=is_married,
    )


def test_allocation_annuelle_married_lowers_withdrawal_tax():
    single = _allocation(False)
    married = _allocation(True)
    by_id_s = {o.id: o for o in single.options}
    by_id_m = {o.id: o for o in married.options}
    # L'impôt de retrait plus bas améliore la valeur terminale nette 3a.
    assert by_id_m["3a"].terminal_value > by_id_s["3a"].terminal_value
    # Et l'option rachat LPP (même retrait capital au terme).
    if "rachat_lpp" in by_id_s:
        assert (
            by_id_m["rachat_lpp"].terminal_value
            > by_id_s["rachat_lpp"].terminal_value
        )


def test_epl_service_married_lowers_impot():
    kwargs = dict(
        avoir_lpp_total=400000,
        avoir_obligatoire=250000,
        avoir_surobligatoire=150000,
        age=45,
        montant_retrait_souhaite=200000,
        canton="ZH",
    )
    single = EPLService().simulate(**kwargs, is_married=False)
    married = EPLService().simulate(**kwargs, is_married=True)
    assert married.impot_retrait_estime < single.impot_retrait_estime
    assert single.impot_retrait_estime > 0


def test_epl_combined_married_lowers_impot_3a():
    kwargs = dict(
        avoir_3a=80000,
        avoir_lpp_total=300000,
        avoir_obligatoire=200000,
        avoir_surobligatoire=100000,
        age=40,
        canton="ZH",
    )
    single = EplCombinedService().calculate(**kwargs, is_married=False)
    married = EplCombinedService().calculate(**kwargs, is_married=True)
    assert married.detail.impot_3a < single.detail.impot_3a
    assert single.detail.impot_3a > 0
    assert married.detail.impot_lpp < single.detail.impot_lpp


def test_lpp_conversion_married_coherent_both_sides():
    """is_married s'applique aux DEUX côtés (rente ET capital).

    Ne brancher que le capital biaiserait la comparaison en faveur du
    capital (impôt marié réduit d'un seul côté) — orientation de fait.
    """
    kwargs = dict(capital_lpp=500000, canton="ZH")
    single = LppConversionService().compare(**kwargs)
    married = LppConversionService().compare(**kwargs, is_married=True)
    # Capital : impôt retrait marié < célibataire -> net plus haut.
    assert married.option_capital_net > single.option_capital_net
    # Rente : splitting -> impôt revenu annuel marié <= célibataire.
    assert married.rente_impot_annuel < single.rente_impot_annuel
    assert married.option_rente_nette_annuelle > single.option_rente_nette_annuelle


def test_lpp_conversion_override_marginal_still_respected():
    """L'override explicite taux_marginal_revenu garde la priorité (compat)."""
    r = LppConversionService().compare(
        capital_lpp=500000,
        canton="ZH",
        taux_marginal_revenu=0.25,
        is_married=True,
    )
    assert r.rente_impot_annuel == pytest.approx(
        r.option_rente_annuelle * 0.25, abs=0.01
    )


# ────────────────────────────────────────────────────────────
# Schémas de requête — champ exposé, défaut None, alias camelCase
# (pattern identique à RenteVsCapitalRequest.is_married)
# ────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "model,payload",
    [
        (
            AllocationAnnuelleRequest,
            {"montantDisponible": 7056, "tauxMarginal": 0.3},
        ),
        (
            EPLRequest,
            {
                "avoirLppTotal": 400000,
                "avoirObligatoire": 250000,
                "avoirSurobligatoire": 150000,
                "age": 45,
                "montantRetraitSouhaite": 200000,
            },
        ),
        (EplCombinedRequest, {"avoir3a": 80000}),
        (LppConversionRequest, {"capitalLpp": 500000}),
    ],
    ids=["allocation", "epl", "epl_combined", "lpp_conversion"],
)
def test_request_schemas_expose_is_married(model, payload):
    default = model.model_validate(payload)
    assert default.is_married is None, "défaut None = comportement historique"
    flagged = model.model_validate({**payload, "isMarried": True})
    assert flagged.is_married is True
