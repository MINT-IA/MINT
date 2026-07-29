"""is_married exposé dans les 4 API de retrait capital (beads MINT_nosync-uwv).

Depuis la bascule modèle v2 (-2i2 PR B), ces services appellent
``estimate_capital_withdrawal_tax`` avec ``is_married`` : la part cantonale
mariée est interpolée sur l'étalon ESTV ``CANTONAL_CAPITAL_TAX_MARRIED_CHF``
(triage AnnAssign #1095 — le rabais forfaitaire par canton, inventé, a été
supprimé). Ce module verrouille l'exposition bout-en-bout : paramètre service
+ champ requête Pydantic. Cantons de démonstration : VD (réduction mariée
cantonale réelle sur toute la grille) ; ZH ne réduit pas ≤ 250k (fait ESTV).

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
# (VD : réduction mariée cantonale ESTV réelle sur la part cantonale/communale)
# ────────────────────────────────────────────────────────────


def _allocation(is_married: bool):
    # potentiel_rachat_lpp + is_property_owner : les 3 options capital
    # (3a, rachat_lpp, amort_indirect) DOIVENT exister — review #993 r1 :
    # une assertion conditionnelle sur une option absente ne teste rien.
    return compare_allocation_annuelle(
        montant_disponible=7056,
        taux_marginal=0.30,
        annees_avant_retraite=20,
        canton="VD",
        potentiel_rachat_lpp=100000,
        is_property_owner=True,
        is_married=is_married,
    )


def test_allocation_annuelle_married_lowers_withdrawal_tax():
    single = _allocation(False)
    married = _allocation(True)
    by_id_s = {o.id: o for o in single.options}
    by_id_m = {o.id: o for o in married.options}
    # Les 3 options à retrait capital sont présentes ET améliorées.
    for oid in ("3a", "rachat_lpp", "amort_indirect"):
        assert oid in by_id_s, f"option {oid} absente : le test ne prouve rien"
        assert by_id_m[oid].terminal_value > by_id_s[oid].terminal_value, oid
    # Invest libre : pas de retrait capital 2e/3e pilier — mais depuis la
    # migration -cm4 l'impôt fortune est marié-aware (socle d'exonération
    # doublé, WealthTaxService) : marié >= célibataire par un AUTRE canal.
    assert (
        by_id_m["invest_libre"].terminal_value
        >= by_id_s["invest_libre"].terminal_value
    )
    assert (
        by_id_m["invest_libre"].cumulative_tax_impact
        <= by_id_s["invest_libre"].cumulative_tax_impact
    )


def test_allocation_sensitivity_variants_thread_is_married():
    """Les variantes tornado (closure _build_variant_options) reçoivent
    is_married — tornado_*_high/low sont calculés UNIQUEMENT via les
    variantes, pas via les options de base (review #993 r1)."""
    single = _allocation(False)
    married = _allocation(True)
    assert (
        married.sensitivity["tornado_rendement_3a_high"]
        != single.sensitivity["tornado_rendement_3a_high"]
    )
    assert (
        married.sensitivity["tornado_taux_marginal_low"]
        != single.sensitivity["tornado_taux_marginal_low"]
    )


def test_epl_service_married_lowers_impot():
    kwargs = dict(
        avoir_lpp_total=400000,
        avoir_obligatoire=250000,
        avoir_surobligatoire=150000,
        age=45,
        montant_retrait_souhaite=200000,
        canton="VD",
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
        canton="VD",
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


def test_married_arithmetic_lock_vd():
    """Verrou arithmétique : on fige, à un point HORS grille (200k, VD), la
    mécanique EXACTE des DEUX parts marié (cantonale ESTV + IFD art. 38 al. 2
    ESTV), recomposées depuis les tables publiques :

        impôt_marié = min( IFD_marié(interp, borné célibataire)
                           + part_cantonale_MARIÉE(interp), célibataire )

    L'écart single−married = (IFD_cél − IFD_marié) + (cant_cél − cant_marié).
    """
    from app.services.fiscal.cantonal_comparator import (
        _cantonal_capital_pts,
        _ifd_married_capital,
        _ifd_single_capital,
        _interpolate_capital_points,
        CANTONAL_CAPITAL_TAX_CHF,
        CANTONAL_CAPITAL_TAX_MARRIED_CHF,
        estimate_capital_withdrawal_tax,
    )

    amount = 200_000.0
    cant_single = _interpolate_capital_points(
        _cantonal_capital_pts(CANTONAL_CAPITAL_TAX_CHF, "VD"), amount
    )
    cant_married = _interpolate_capital_points(
        _cantonal_capital_pts(CANTONAL_CAPITAL_TAX_MARRIED_CHF, "VD"), amount
    )
    ifd_single = _ifd_single_capital(amount)
    ifd_married = _ifd_married_capital(amount)
    # Cantonal : réduction mariée VD réelle (verrou non trivial). IFD :
    # marié <= célibataire toujours (borne), mais l'écart est faible en
    # milieu de segment (interp linéaire vs barème courbe du célibataire).
    assert cant_single - cant_married > 100
    assert 0.0 <= ifd_single - ifd_married

    single = estimate_capital_withdrawal_tax(amount, "VD")
    married = estimate_capital_withdrawal_tax(amount, "VD", is_married=True)
    assert single == pytest.approx(ifd_single + cant_single, abs=0.02)
    assert married == pytest.approx(ifd_married + cant_married, abs=0.02)
    assert single - married == pytest.approx(
        (ifd_single - ifd_married) + (cant_single - cant_married), abs=0.02
    )


def test_services_thread_identity_to_canonical_model():
    """Chaque service marié == le modèle canonique marié AU CENTIME —
    prouve le threading exact (pas un rabais recomposé localement)."""
    from app.services.fiscal.cantonal_comparator import (
        estimate_capital_withdrawal_tax,
    )

    epl = EPLService().simulate(
        avoir_lpp_total=400000,
        avoir_obligatoire=250000,
        avoir_surobligatoire=150000,
        age=45,
        montant_retrait_souhaite=200000,
        canton="ZH",
        is_married=True,
    )
    assert epl.impot_retrait_estime == pytest.approx(
        estimate_capital_withdrawal_tax(
            epl.montant_effectif, "ZH", is_married=True
        ),
        abs=0.01,
    )

    combined = EplCombinedService().calculate(
        avoir_3a=80000,
        avoir_lpp_total=300000,
        avoir_obligatoire=200000,
        avoir_surobligatoire=100000,
        age=40,
        canton="ZH",
        is_married=True,
    )
    assert combined.detail.impot_3a == pytest.approx(
        estimate_capital_withdrawal_tax(80000, "ZH", is_married=True), abs=0.01
    )

    conv = LppConversionService().compare(
        capital_lpp=500000, canton="ZH", is_married=True
    )
    assert conv.option_capital_impot == pytest.approx(
        estimate_capital_withdrawal_tax(500000, "ZH", is_married=True), abs=0.01
    )


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
