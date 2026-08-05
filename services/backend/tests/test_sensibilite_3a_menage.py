"""Tests — service L2/L3 « sensibilite 3a selon l'etat civil » (Batch A).

Contrat backend-canonical (NEVER#3) : la sensibilite d'une deduction 3a sur
l'impot sur le revenu est recalculee cote backend et renvoyee sous
``L3EclairePayload`` (discriminateur `_payload.py:level`). ZERO nouveau calcul
financier : le service reutilise
``fiscal.cantonal_comparator.estimate_tax_saving`` (difference d'impot),
l'agregation menage/deductions de ``family.mariage_service`` (LIFD art. 33
al. 2 / art. 35) et ``rules_engine.get_3a_ceiling`` (plafond OPP3 art. 7).

Point cle metier : pour un menage marie, le franc de 3a mord au taux marginal
du MENAGE (imposition commune, LIFD art. 9 al. 1). Le revenu du conjoint est
inconnu -> la sensibilite honnete est une FOURCHETTE bornee par deux
hypotheses (conjoint sans revenu ; conjoint a revenu comparable), jamais un
chiffre unique nu.
"""
from __future__ import annotations

import pytest

from app.models.lucidity import L3EclairePayload
from app.models.lucidity._payload import _CascadeEffect
from app.services.fiscal.cantonal_comparator import (
    DISCLAIMER as CANONICAL_DISCLAIMER,
    estimate_tax_saving,
)
from app.services.family.mariage_service import (
    DEDUCTION_ASSURANCES_MARIES,
    DEDUCTION_MARIES,
    deduction_double_activite,
)
from app.services.rules_engine import PILIER_3A_PLAFOND_AVEC_LPP
from app.services.fiscal.sensibilite_3a_service import (
    DISCLAIMER,
    sensibilite_3a_menage,
)


# ---------------------------------------------------------------------------
# Helpers — reproduisent la reference canonique cote test (pas de duplication
# de la logique fiscale : on APPELLE les memes fonctions que le service).
# ---------------------------------------------------------------------------

_CITATION = "cantonal_comparator__estimate_tax_saving"
_BAND_LOW = 0.90
_BAND_HIGH = 1.10


def _household_imposable(revenu_1: float, revenu_2: float) -> float:
    r2 = max(0.0, revenu_2)
    combine = max(0.0, revenu_1) + r2
    deductions = (
        DEDUCTION_MARIES
        + DEDUCTION_ASSURANCES_MARIES
        + deduction_double_activite(revenu_1, r2)
    )
    return max(0.0, combine - deductions)


def _effect(payload: L3EclairePayload) -> _CascadeEffect:
    assert len(payload.cascade_effects) == 1
    return payload.cascade_effects[0]


def _spread(payload: L3EclairePayload) -> float:
    eff = _effect(payload)
    return eff.delta_haut - eff.delta_bas


# ---------------------------------------------------------------------------
# Test 1 — celibataire : L3 valide, fourchette non collapsee, delta_bas<haut.
# ---------------------------------------------------------------------------


def test_celibataire_returns_l3_with_non_collapsed_band() -> None:
    payload = sensibilite_3a_menage(
        revenu_imposable=100_000.0,
        canton="ZH",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil="celibataire",
    )
    assert isinstance(payload, L3EclairePayload)
    assert payload.level.value == "L3"
    eff = _effect(payload)
    assert eff.delta_bas < eff.delta_haut  # jamais collapsee quand economie > 0
    assert eff.delta_bas > 0.0


# ---------------------------------------------------------------------------
# Test 2 — concubinage == celibataire (taxation separee ; invariant scelle R4_13).
# ---------------------------------------------------------------------------


def test_concubinage_equals_celibataire() -> None:
    common = dict(
        revenu_imposable=90_000.0,
        canton="VD",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
    )
    concubin = sensibilite_3a_menage(etat_civil="concubinage", **common)
    single = sensibilite_3a_menage(etat_civil="celibataire", **common)
    assert _effect(concubin).delta_bas == _effect(single).delta_bas
    assert _effect(concubin).delta_haut == _effect(single).delta_haut


# ---------------------------------------------------------------------------
# Test 3 — marie (conjoint inconnu) : bande PLUS LARGE que celibataire
# (l'incertitude sur le revenu du conjoint elargit la fourchette).
# ---------------------------------------------------------------------------


def test_marie_conjoint_inconnu_band_wider_than_celibataire() -> None:
    common = dict(
        revenu_imposable=90_000.0,
        canton="GE",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
    )
    marie = sensibilite_3a_menage(etat_civil="marie", **common)
    single = sensibilite_3a_menage(etat_civil="celibataire", **common)
    assert _spread(marie) > _spread(single)


# ---------------------------------------------------------------------------
# Test 4 — marie / marie_pacse / partenariat : meme traitement (LIFD art. 9
# al. 1bis, normalisation AU NIVEAU DU SERVICE).
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("statut", ["marie", "marie_pacse", "partenariat"])
def test_married_synonyms_treated_identically(statut: str) -> None:
    ref = sensibilite_3a_menage(
        revenu_imposable=110_000.0,
        canton="BE",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil="marie",
    )
    got = sensibilite_3a_menage(
        revenu_imposable=110_000.0,
        canton="BE",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil=statut,
    )
    assert _effect(got).delta_bas == _effect(ref).delta_bas
    assert _effect(got).delta_haut == _effect(ref).delta_haut


# ---------------------------------------------------------------------------
# Test 5 — marie conjoint None : les bornes correspondent EXACTEMENT aux deux
# hypotheses (conjoint 0 ; conjoint comparable), via estimate_tax_saving.
# ---------------------------------------------------------------------------


def test_married_none_band_brackets_conjoint_assumptions() -> None:
    revenu = 90_000.0
    versement = PILIER_3A_PLAFOND_AVEC_LPP
    canton = "ZH"
    payload = sensibilite_3a_menage(
        revenu_imposable=revenu,
        canton=canton,
        versement_3a=versement,
        etat_civil="marie",
    )
    raw_bas = estimate_tax_saving(
        _household_imposable(revenu, 0.0), versement, canton, is_married=True
    )
    raw_haut = estimate_tax_saving(
        _household_imposable(revenu, revenu), versement, canton, is_married=True
    )
    eff = _effect(payload)
    assert eff.delta_bas == pytest.approx(round(_BAND_LOW * raw_bas, 2))
    assert eff.delta_haut == pytest.approx(round(_BAND_HIGH * raw_haut, 2))
    assert eff.delta_bas <= eff.delta_haut


# ---------------------------------------------------------------------------
# Test 6 — conjoint connu : bande resserree vs conjoint inconnu.
# ---------------------------------------------------------------------------


def test_known_conjoint_narrows_band() -> None:
    common = dict(
        revenu_imposable=90_000.0,
        canton="ZH",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil="marie",
    )
    inconnu = sensibilite_3a_menage(**common)
    connu = sensibilite_3a_menage(revenu_imposable_conjoint=60_000.0, **common)
    assert _spread(connu) < _spread(inconnu)


# ---------------------------------------------------------------------------
# Test 7 — conjoint connu : point = estimate_tax_saving sur imposable menage,
# borne par le +/-10% (preuve de reutilisation, ZERO nouveau calcul).
# ---------------------------------------------------------------------------


def test_known_conjoint_point_reuses_canonical_saving() -> None:
    revenu, conjoint, versement, canton = 90_000.0, 60_000.0, PILIER_3A_PLAFOND_AVEC_LPP, "ZH"
    payload = sensibilite_3a_menage(
        revenu_imposable=revenu,
        canton=canton,
        versement_3a=versement,
        etat_civil="marie",
        revenu_imposable_conjoint=conjoint,
    )
    point = estimate_tax_saving(
        _household_imposable(revenu, conjoint), versement, canton, is_married=True
    )
    eff = _effect(payload)
    assert eff.delta_bas == pytest.approx(round(_BAND_LOW * point, 2))
    assert eff.delta_haut == pytest.approx(round(_BAND_HIGH * point, 2))


# ---------------------------------------------------------------------------
# Test 8 — revenu 0 : seul cas ou la fourchette peut honnetement etre [0, 0]
# (pas de revenu imposable -> pas d'economie).
# ---------------------------------------------------------------------------


def test_zero_income_returns_honest_zero_band() -> None:
    payload = sensibilite_3a_menage(
        revenu_imposable=0.0,
        canton="ZH",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil="marie",
    )
    eff = _effect(payload)
    assert eff.delta_bas == 0.0
    assert eff.delta_haut == 0.0


# ---------------------------------------------------------------------------
# Test 9 — versement None -> plafond OPP3 (get_3a_ceiling), salarie+LPP.
# ---------------------------------------------------------------------------


def test_versement_none_uses_opp3_ceiling() -> None:
    common = dict(revenu_imposable=100_000.0, canton="ZH", etat_civil="celibataire")
    implicite = sensibilite_3a_menage(
        versement_3a=None, employment_status="salarie", has_lpp=True, **common
    )
    explicite = sensibilite_3a_menage(
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP, **common
    )
    assert _effect(implicite).delta_bas == _effect(explicite).delta_bas
    assert _effect(implicite).delta_haut == _effect(explicite).delta_haut


# ---------------------------------------------------------------------------
# Test 10 — versement au-dessus du plafond : borne au plafond (pas de
# deduction illegale modelisee, OPP3 art. 7).
# ---------------------------------------------------------------------------


def test_versement_above_ceiling_is_clamped() -> None:
    common = dict(
        revenu_imposable=120_000.0,
        canton="ZH",
        etat_civil="celibataire",
        employment_status="salarie",
        has_lpp=True,
    )
    trop = sensibilite_3a_menage(versement_3a=20_000.0, **common)
    plafond = sensibilite_3a_menage(versement_3a=PILIER_3A_PLAFOND_AVEC_LPP, **common)
    assert _effect(trop).delta_bas == _effect(plafond).delta_bas
    assert _effect(trop).delta_haut == _effect(plafond).delta_haut


# ---------------------------------------------------------------------------
# Test 11 — aucun terme banni LSFin dans la copie (primary_choice + hypotheses).
# ---------------------------------------------------------------------------


def test_no_banned_lsfin_terms_in_copy() -> None:
    banned = (
        "garanti", "optimal", "meilleur", "certain",
        "sans risque", "parfait", "assure ",
    )
    payload = sensibilite_3a_menage(
        revenu_imposable=95_000.0,
        canton="VD",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil="marie",
    )
    texts = [payload.primary_choice_fr] + [
        e.hypothese_fr for e in payload.cascade_effects
    ]
    blob = " ".join(texts).lower()
    for term in banned:
        assert term not in blob, f"terme banni LSFin present : {term!r}"


# ---------------------------------------------------------------------------
# Test 12 — citation_key canonique (outil de recuperation, doctrine coach).
# ---------------------------------------------------------------------------


def test_citation_key_is_canonical_tool() -> None:
    payload = sensibilite_3a_menage(
        revenu_imposable=100_000.0,
        canton="ZH",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil="celibataire",
    )
    assert _effect(payload).citation_key == _CITATION


# ---------------------------------------------------------------------------
# Test 13 — cascade_effects est TYPE (_CascadeEffect), pas un dict libre, et
# rejette tout champ extra (extra=forbid herite de _LucidityBase).
# ---------------------------------------------------------------------------


def test_cascade_effect_is_typed_and_forbids_extra() -> None:
    from pydantic import ValidationError

    payload = sensibilite_3a_menage(
        revenu_imposable=100_000.0,
        canton="ZH",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil="celibataire",
    )
    assert isinstance(payload.cascade_effects[0], _CascadeEffect)
    with pytest.raises(ValidationError):
        _CascadeEffect(
            domain_fr="Impot sur le revenu",
            delta_bas=100.0,
            delta_haut=200.0,
            hypothese_fr="x" * 25,
            citation_key=_CITATION,
            recommended_option="verser",  # champ interdit
        )


# ---------------------------------------------------------------------------
# Test 14 — le module reexporte le disclaimer canonique (reutilisation).
# ---------------------------------------------------------------------------


def test_module_reexports_canonical_disclaimer() -> None:
    assert DISCLAIMER == CANONICAL_DISCLAIMER


# ---------------------------------------------------------------------------
# Test 15 — etat civil inconnu -> traite comme celibataire (conservateur).
# ---------------------------------------------------------------------------


def test_unknown_status_defaults_to_single() -> None:
    common = dict(
        revenu_imposable=100_000.0,
        canton="ZH",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
    )
    inconnu = sensibilite_3a_menage(etat_civil="statut_bidon", **common)
    single = sensibilite_3a_menage(etat_civil="celibataire", **common)
    assert _effect(inconnu).delta_bas == _effect(single).delta_bas
    assert _effect(inconnu).delta_haut == _effect(single).delta_haut


# ---------------------------------------------------------------------------
# Test 16 — invariant delta_bas <= delta_haut sur une grille cantons/revenus.
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("canton", ["ZH", "GE", "VD", "ZG", "TI"])
@pytest.mark.parametrize("revenu", [30_000.0, 80_000.0, 180_000.0])
@pytest.mark.parametrize("statut", ["celibataire", "marie", "marie_pacse"])
def test_delta_bas_le_delta_haut_invariant(canton, revenu, statut) -> None:
    payload = sensibilite_3a_menage(
        revenu_imposable=revenu,
        canton=canton,
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil=statut,
    )
    eff = _effect(payload)
    assert eff.delta_bas <= eff.delta_haut


# ---------------------------------------------------------------------------
# Test 17 — horizon_years honnete (economie annuelle recurrente, >= 1).
# ---------------------------------------------------------------------------


def test_horizon_years_is_annual_minimum() -> None:
    payload = sensibilite_3a_menage(
        revenu_imposable=100_000.0,
        canton="ZH",
        versement_3a=PILIER_3A_PLAFOND_AVEC_LPP,
        etat_civil="celibataire",
    )
    assert payload.horizon_years == 1
