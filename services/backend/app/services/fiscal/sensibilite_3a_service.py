"""Service L2/L3 — sensibilité d'un versement 3a selon l'état civil (Batch A).

NEVER#3 (frontière L1/L2) : la sensibilité d'une déduction 3a sur l'impôt sur
le revenu est un recompute L2/L3 backend-canonical. Ce module N'INTRODUIT AUCUN
nouveau calcul fiscal : il assemble un ``L3EclairePayload`` à partir de trois
briques canoniques existantes —

  * ``fiscal.cantonal_comparator.estimate_tax_saving`` : la différence d'impôt
    exacte (jamais « déduction × taux marginal »), déjà calibrée sur l'étalon
    ESTV (barème IFD 2026 + points cantonaux), état civil marié via le facteur
    de splitting ×0.80 (approximation LHID, dite et assumée) ;
  * ``family.mariage_service`` : l'agrégation du ménage marié (revenus combinés)
    et ses déductions de couple (double activité LIFD art. 33 al. 2, personnes
    mariées LIFD art. 35) ;
  * ``rules_engine.get_3a_ceiling`` : le plafond 3a applicable (OPP3 art. 7).

Point clé métier (honnêteté) : pour un ménage marié, le franc de 3a mord au
taux marginal du MÉNAGE (imposition commune, LIFD art. 9 al. 1), qui dépend du
revenu du conjoint. Ce revenu est souvent inconnu au moment de l'estimation.
Le service ne renvoie donc jamais un chiffre nu : il renvoie une FOURCHETTE
bornée par deux hypothèses explicites (conjoint sans revenu ; conjoint à revenu
comparable). Quand le revenu du conjoint est fourni, la fourchette se resserre.

LSFin : estimation éducative, jamais une promesse ni un conseil. Le disclaimer
canonique (``cantonal_comparator.DISCLAIMER``) est ré-exporté ici pour que la
surface produit l'attache au payload.
"""
from __future__ import annotations

from math import isfinite

from app.models.lucidity._payload import L3EclairePayload, _CascadeEffect
from app.services.fiscal.cantonal_comparator import (
    CANTONAL_COMMUNAL_TAX_CHF,
    DISCLAIMER as _CANONICAL_DISCLAIMER,
    estimate_tax_saving,
)
from app.services.fiscal.civil_status import is_married_civil_status
from app.services.family.mariage_service import (
    DEDUCTION_MARIES,
    deduction_double_activite,
)
from app.services.rules_engine import get_3a_ceiling

__all__ = ["sensibilite_3a_menage", "DISCLAIMER"]

# Ré-export du disclaimer canonique (réutilisation, pas de copie divergente).
DISCLAIMER = _CANONICAL_DISCLAIMER

# citation_key = l'outil de récupération déterministe qui produit le chiffre
# (doctrine coach « forced tool invocation » + nom du descripteur au registre).
_CITATION_KEY = "cantonal_comparator__estimate_tax_saving"

# Enveloppe de modélisation ±10% autour de l'économie estimée — même convention
# que rules_engine.calculate_tax_potential (fourchette « ~bas-haut » d'une
# économie 3a). Le modèle est une estimation éducative (chef-lieu, revenu
# imposable simplifié, barèmes SG/TI 2025) : la bande dit cette incertitude.
_BAND_LOW = 0.90
_BAND_HIGH = 1.10

# L'économie 3a sur le revenu est ANNUELLE et récurrente à chaque versement :
# l'horizon L3 minimal (1 an) est la seule affirmation honnête sans âge/retraite.
_HORIZON_ANNUEL = 1

# Normalisation « qui est marié » — source UNIQUE partagée avec le coach
# (``coaching_engine``) via ``fiscal.civil_status`` : aucune copie divergente de
# la liste des statuts (LIFD art. 9 al. 1 / al. 1bis).
_is_married = is_married_civil_status


def _finite_float(name: str, value: object, *, allow_none: bool = False) -> float | None:
    """Coerce en float fini, ou ValueError contractuel (revue Codex F3)."""
    if value is None:
        if allow_none:
            return None
        raise ValueError(f"{name} est requis.")
    try:
        f = float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        raise ValueError(f"{name} doit être numérique, reçu {value!r}.")
    if not isfinite(f):
        raise ValueError(f"{name} doit être un nombre fini, reçu {value!r}.")
    return f


def _household_imposable(
    revenu_1: float, revenu_2: float, *, apply_double_activite: bool = True
) -> float:
    """Revenu imposable du ménage marié à partir de DEUX revenus DÉJÀ IMPOSABLES.

    Contrat d'entrée : ``revenu_1``/``revenu_2`` sont des revenus IMPOSABLES
    individuels (déductions personnelles déjà appliquées). On ne retranche donc
    QUE les déductions SPÉCIFIQUES à l'imposition commune, absentes d'un
    imposable célibataire :

      - déduction pour personnes mariées (LIFD art. 35 al. 1 let. c) ;
      - déduction pour double activité des époux (LIFD art. 33 al. 2), UNIQUEMENT
        si ``apply_double_activite`` (les DEUX époux exercent une activité
        lucrative — revue Codex G2 : deux imposables génériques ne le prouvent
        pas, ils peuvent inclure rente/immeuble).

    Résultat 18'600 pour (20'000, 10'000) « deux actifs » = APPROXIMATION à
    ~100 CHF près (revue Codex G4/P3) : le delta assurance marié (3'700 vs
    2×1'800 = 100) n'est pas modélisé — l'assurance est déjà dans l'imposable
    individuel, jamais retranchée deux fois. Ce n'est donc pas une dérivation
    exacte au franc.

    DETTE dite (Codex G2) : l'assiette réelle de l'art. 33 al. 2 est 50% du
    REVENU D'ACTIVITÉ le plus bas ; ici on l'approxime sur le revenu imposable
    fourni (proportionnalité non modélisée faute d'entrée « part d'activité »).

    Limite dite : déduction par enfant (LIFD art. 35 al. 1 let. a) non modélisée
    -> divulguée « ménage sans enfants à charge » dans ``hypothese_fr``.
    """
    r2 = max(0.0, revenu_2)
    combine = max(0.0, revenu_1) + r2
    deductions = DEDUCTION_MARIES
    if apply_double_activite:
        deductions += deduction_double_activite(revenu_1, r2)
    return max(0.0, combine - deductions)


def sensibilite_3a_menage(
    revenu_imposable: float,
    canton: str,
    versement_3a: float | None,
    etat_civil: str,
    revenu_imposable_conjoint: float | None = None,
    employment_status: str | None = None,
    has_lpp: bool | None = None,
    deux_revenus_activite: bool | None = None,
) -> L3EclairePayload:
    """Sensibilité d'un versement 3a sur l'impôt sur le revenu, selon l'état civil.

    Args:
        revenu_imposable: revenu imposable annuel de la personne (CHF).
        canton: code canton (2 lettres, ex. « ZH »).
        versement_3a: versement 3a envisagé (CHF) ; ``None`` -> plafond OPP3.
        etat_civil: « celibataire » / « concubinage » / « marie » /
            « marie_pacse » / « partenariat » (normalisé, casse indifférente).
        revenu_imposable_conjoint: revenu imposable du conjoint (CHF) ; ``None``
            -> fourchette élargie entre deux hypothèses bornantes.
        employment_status: statut d'emploi (pour dériver le plafond si versement
            ``None``) ; ``salarie`` / ``independant`` ...
        has_lpp: affiliation LPP (pour le plafond OPP3 art. 7) si versement
            ``None``.

    Returns:
        ``L3EclairePayload`` : un effet cascade « Impôt sur le revenu » portant
        une fourchette basse/haute (jamais un chiffre nu) + l'hypothèse qui la
        borne, horizon annuel. Estimation « ménage sans enfants à charge »
        (la déduction par enfant n'est pas modélisée — cf. ``_household_imposable``).

    Raises:
        ValueError: si ``canton`` n'est pas l'un des 26 codes cantonaux
            canoniques (fail-closed : on refuse « XX » plutôt que de renvoyer la
            moyenne-26 du modèle sous-jacent) ; ou si un montant est non fini
            (NaN/Inf), qui produirait sinon une bande [0,0] ou « 0 CHF »
            trompeuse (revue Codex P2-c).
    """
    # Coercition + fail-closed (revue Codex P2-c/F3) : Decimal / chaîne numérique
    # -> float ; NaN/Inf/non numérique -> ValueError CONTRACTUEL (jamais un
    # TypeError brut ni un zéro crédible).
    revenu_imposable = _finite_float("revenu_imposable", revenu_imposable)
    versement_3a = _finite_float("versement_3a", versement_3a, allow_none=True)
    revenu_imposable_conjoint = _finite_float(
        "revenu_imposable_conjoint", revenu_imposable_conjoint, allow_none=True
    )

    canton_norm = (canton or "").strip().upper()
    if canton_norm not in CANTONAL_COMMUNAL_TAX_CHF:
        raise ValueError(
            f"Canton inconnu : {canton!r}. Codes valides : "
            f"{', '.join(sorted(CANTONAL_COMMUNAL_TAX_CHF))}."
        )

    # OPP3 art. 7 : le grand 3a (non affilié au 2e pilier) est borné à 20% du
    # revenu déterminant. get_3a_ceiling renvoie None si le grand 3a est dû sans
    # revenu — ici revenu_imposable est requis et fini ; le seul cas None est
    # revenu <= 0 (non affilié), où l'économie est nulle de toute façon.
    plafond = get_3a_ceiling(employment_status, has_lpp, annual_income=revenu_imposable)
    if plafond is None:
        plafond = 0.0
    demande = plafond if versement_3a is None else versement_3a
    versement = max(0.0, min(demande, plafond))  # borné au plafond (OPP3 art. 7)
    # Le montant AFFICHÉ est le plafond seulement si l'appelant n'a rien demandé
    # (``None``) ou a demandé au moins le plafond (clampé) — la mention
    # « (plafond OPP3 art. 7) » ne doit pas qualifier un montant sous-plafond.
    montant_au_plafond = versement_3a is None or versement_3a >= plafond

    revenu = max(0.0, revenu_imposable)

    # Double activité (LIFD art. 33 al. 2) : appliquée si les DEUX époux
    # exercent une activité lucrative. True -> applique ; False -> non ; None
    # (défaut) -> applique EN DIVULGUANT l'hypothèse (direction prudente : imposable
    # plus bas -> économie plus basse). Revue Codex G2.
    _apply_da = deux_revenus_activite is not False
    _da_caveat = (
        " En supposant que les deux revenus proviennent d'une activité lucrative "
        "(double activité, LIFD art. 33 al. 2)."
        if _apply_da and deux_revenus_activite is None
        else ""
    )

    if not _is_married(etat_civil):
        raw_bas = raw_haut = estimate_tax_saving(
            revenu, versement, canton_norm, is_married=False
        )
        hypothese_fr = (
            "Estimation au chef-lieu, revenu imposable simplifié, imposition "
            "séparée (célibataire ou concubinage). Les déductions réelles "
            "varient selon ta commune et ta situation."
        )
    elif revenu_imposable_conjoint is not None:
        imposable = _household_imposable(
            revenu, revenu_imposable_conjoint, apply_double_activite=_apply_da
        )
        raw_bas = raw_haut = estimate_tax_saving(
            imposable, versement, canton_norm, is_married=True
        )
        hypothese_fr = (
            "Estimation sur le revenu imposable combiné du ménage sans enfants "
            "à charge (imposition commune, LIFD art. 9 al. 1), déductions "
            "spécifiques au couple appliquées (personnes mariées art. 35"
            + (", double activité art. 33 al. 2" if _apply_da else "")
            + "). Barème marié approximé par un splitting forfaitaire (LHID)."
            + _da_caveat
        )
    else:
        raw_bas = estimate_tax_saving(
            _household_imposable(revenu, 0.0, apply_double_activite=_apply_da),
            versement, canton_norm, is_married=True,
        )
        raw_haut = estimate_tax_saving(
            _household_imposable(revenu, revenu, apply_double_activite=_apply_da),
            versement, canton_norm, is_married=True,
        )
        # Formulation DIRECTION-NEUTRE : le modèle n'est pas monotone partout
        # (le tri défensif ci-dessous peut inverser raw_bas/raw_haut, ex. VS
        # ~152'500, FR ~200'000), donc on n'assigne PAS « borne basse = conjoint
        # sans revenu » — on borne par les deux hypothèses sans direction fixe.
        hypothese_fr = (
            "Fourchette bornée par deux hypothèses sur le revenu imposable de "
            "ton conjoint (imposition commune, LIFD art. 9 al. 1) : conjoint "
            "sans revenu, ou conjoint à revenu comparable au tien. Ménage sans "
            "enfants à charge, déductions spécifiques au couple appliquées "
            "(art. 35" + (", double activité art. 33 al. 2" if _apply_da else "")
            + "). Si ton conjoint gagne plus que toi, l'économie réelle peut "
            "dépasser cette fourchette. La fourchette se resserre si le revenu "
            "du conjoint est connu." + _da_caveat
        )

    # Tri défensif des bornes brutes AVANT l'enveloppe ±10%. L'interpolation de
    # ``estimate_tax_saving`` est monotone croissante en revenu (borne basse =
    # ménage le plus bas), donc raw_bas <= raw_haut est attendu — mais on trie
    # explicitement : une exception de validation en production (le validateur
    # ``_CascadeEffect._enforce_band_order`` LÈVE) serait pire que l'anomalie
    # qu'elle signale. La construction du payload reste ainsi totale.
    raw_lo, raw_hi = min(raw_bas, raw_haut), max(raw_bas, raw_haut)
    delta_bas = round(_BAND_LOW * raw_lo, 2)
    delta_haut = round(_BAND_HIGH * raw_hi, 2)

    effet = _CascadeEffect(
        domain_fr="Impôt sur le revenu",
        delta_bas=delta_bas,
        delta_haut=delta_haut,
        hypothese_fr=hypothese_fr,
        citation_key=_CITATION_KEY,
    )

    montant_fr = f"{versement:,.0f}".replace(",", "'")
    if montant_au_plafond:
        primary_choice_fr = (
            f"Si tu verses jusqu'à {montant_fr} CHF à ton pilier 3a cette "
            f"année (plafond OPP3 art. 7), voici l'effet estimé sur ton impôt "
            f"sur le revenu."
        )
    else:
        primary_choice_fr = (
            f"Si tu verses {montant_fr} CHF à ton pilier 3a cette année, voici "
            f"l'effet estimé sur ton impôt sur le revenu."
        )

    return L3EclairePayload(
        primary_choice_fr=primary_choice_fr,
        cascade_effects=[effet],
        horizon_years=_HORIZON_ANNUEL,
    )
