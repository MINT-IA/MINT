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
    # potentiel_rachat_lpp + is_property_owner : les 3 options capital
    # (3a, rachat_lpp, amort_indirect) DOIVENT exister — review #993 r1 :
    # une assertion conditionnelle sur une option absente ne teste rien.
    return compare_allocation_annuelle(
        montant_disponible=7056,
        taux_marginal=0.30,
        annees_avant_retraite=20,
        canton="ZH",
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


def test_married_arithmetic_lock_zh():
    """Verrou arithmétique (review #993 r1) : married < single ne suffit pas —
    un coefficient faux (0.99) passerait. On fige :

        impôt_marié = IFD inchangé + part_cantonale_célibataire × 0.73 (ZH)

    en recomposant la part cantonale depuis les constantes publiques.
    """
    from app.constants.social_insurance import married_capital_tax_discount_for
    from app.services.fiscal.cantonal_comparator import (
        CANTONAL_CAPITAL_TAX_CHF,
        CAPITAL_TAX_POINTS_AMOUNT,
        estimate_capital_withdrawal_tax,
    )

    discount = married_capital_tax_discount_for("ZH")
    assert discount == pytest.approx(0.73), "coefficient ZH gelé (Q5 audit)"

    amount = 200_000
    pts = CANTONAL_CAPITAL_TAX_CHF["ZH"]
    amts = CAPITAL_TAX_POINTS_AMOUNT
    ratio = (amount - amts[0]) / (amts[1] - amts[0])
    cantonal_single = pts[0] + ratio * (pts[1] - pts[0])

    single = estimate_capital_withdrawal_tax(amount, "ZH")
    married = estimate_capital_withdrawal_tax(amount, "ZH", is_married=True)
    # IFD identique des deux côtés -> l'écart == part cantonale × (1-0.73).
    assert single - married == pytest.approx(
        cantonal_single * (1 - discount), abs=0.02
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
