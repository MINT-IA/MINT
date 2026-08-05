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

from app.models.lucidity._payload import L3EclairePayload, _CascadeEffect
from app.services.fiscal.cantonal_comparator import (
    DISCLAIMER as _CANONICAL_DISCLAIMER,
    estimate_tax_saving,
)
from app.services.family.mariage_service import (
    DEDUCTION_ASSURANCES_MARIES,
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

# Imposition commune (LIFD art. 9 al. 1 / al. 1bis) : mariage ET partenariat
# enregistré sont taxés conjointement. Le concubinage reste une taxation
# séparée (identique au célibataire) — il n'appartient donc PAS à cet ensemble.
_MARRIED_STATUSES = frozenset(
    {
        "marie",
        "marié",
        "marie_pacse",
        "marié_pacsé",
        "marie_pacsé",
        "pacse",
        "pacsé",
        "partenariat",
        "partenariat_enregistre",
        "partenariat_enregistré",
        "registered_partnership",
    }
)


def _is_married(etat_civil: str) -> bool:
    """Normalise l'état civil AU NIVEAU DU SERVICE (LIFD art. 9 al. 1bis).

    Tout état inconnu retombe sur ``False`` (taxation séparée, hypothèse
    conservatrice : pas d'agrégation de ménage fabriquée).
    """
    return (etat_civil or "").strip().lower() in _MARRIED_STATUSES


def _household_imposable(revenu_1: float, revenu_2: float) -> float:
    """Revenu imposable du ménage marié — réutilise les déductions de couple de
    ``mariage_service`` (LIFD art. 33 al. 2 / art. 35). Aucun barème réécrit.
    """
    r2 = max(0.0, revenu_2)
    combine = max(0.0, revenu_1) + r2
    deductions = (
        DEDUCTION_MARIES
        + DEDUCTION_ASSURANCES_MARIES
        + deduction_double_activite(revenu_1, r2)
    )
    return max(0.0, combine - deductions)


def sensibilite_3a_menage(
    revenu_imposable: float,
    canton: str,
    versement_3a: float | None,
    etat_civil: str,
    revenu_imposable_conjoint: float | None = None,
    employment_status: str | None = None,
    has_lpp: bool | None = None,
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
        borne, horizon annuel.
    """
    plafond = get_3a_ceiling(employment_status, has_lpp)
    demande = plafond if versement_3a is None else versement_3a
    versement = max(0.0, min(demande, plafond))  # borné au plafond (OPP3 art. 7)
    # Le montant AFFICHÉ est le plafond seulement si l'appelant n'a rien demandé
    # (``None``) ou a demandé au moins le plafond (clampé) — la mention
    # « (plafond OPP3 art. 7) » ne doit pas qualifier un montant sous-plafond.
    montant_au_plafond = versement_3a is None or versement_3a >= plafond

    revenu = max(0.0, revenu_imposable)

    if not _is_married(etat_civil):
        raw_bas = raw_haut = estimate_tax_saving(
            revenu, versement, canton, is_married=False
        )
        hypothese_fr = (
            "Estimation au chef-lieu, revenu imposable simplifié, imposition "
            "séparée (célibataire ou concubinage). Les déductions réelles "
            "varient selon ta commune et ta situation."
        )
    elif revenu_imposable_conjoint is not None:
        imposable = _household_imposable(revenu, revenu_imposable_conjoint)
        raw_bas = raw_haut = estimate_tax_saving(
            imposable, versement, canton, is_married=True
        )
        hypothese_fr = (
            "Estimation sur le revenu imposable combiné du ménage (imposition "
            "commune, LIFD art. 9 al. 1), déductions de couple appliquées "
            "(double activité art. 33 al. 2, personnes mariées art. 35). "
            "Barème marié approximé par un splitting forfaitaire (LHID)."
        )
    else:
        raw_bas = estimate_tax_saving(
            _household_imposable(revenu, 0.0), versement, canton, is_married=True
        )
        raw_haut = estimate_tax_saving(
            _household_imposable(revenu, revenu), versement, canton, is_married=True
        )
        hypothese_fr = (
            "Fourchette selon le revenu imposable de ton conjoint (imposition "
            "commune, LIFD art. 9 al. 1) : borne basse si le conjoint est sans "
            "revenu, borne haute si le conjoint a un revenu comparable au tien. "
            "La fourchette se resserre si le revenu du conjoint est connu."
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
