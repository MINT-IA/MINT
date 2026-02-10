"""
Pydantic v2 schemas for the Family module (mariage, naissance, concubinage).

Sprint S22 — Evenements de vie : Famille.
API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - Mariage: comparaison fiscale, regimes matrimoniaux, rente de survivant
    - Naissance: conge parental APG, allocations familiales, deductions fiscales, career gap
    - Concubinage: comparaison mariage vs concubinage, succession, checklist
"""

from enum import Enum
from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import Dict, List, Optional


# ===========================================================================
# Base config
# ===========================================================================

class FamilyBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Enums
# ===========================================================================

class RegimeMatrimonialType(str, Enum):
    """Types de regimes matrimoniaux suisses."""
    participation_acquets = "participation_acquets"
    separation_biens = "separation_biens"
    communaute_biens = "communaute_biens"


# ===========================================================================
# Mariage — Comparaison fiscale
# ===========================================================================

class MariageFiscalRequest(FamilyBaseModel):
    """Requete pour la comparaison fiscale mariage."""

    revenu_1: float = Field(
        ..., ge=0,
        description="Revenu imposable annuel personne 1 (CHF)",
    )
    revenu_2: float = Field(
        ..., ge=0,
        description="Revenu imposable annuel personne 2 (CHF)",
    )
    canton: str = Field(
        default="ZH", min_length=2, max_length=2,
        description="Code canton (2 lettres)",
    )
    enfants: int = Field(
        default=0, ge=0,
        description="Nombre d'enfants a charge",
    )


class MariageFiscalResponse(FamilyBaseModel):
    """Reponse pour la comparaison fiscale mariage."""

    impot_celibataires_total: float = Field(
        ..., description="Impot total en tant que 2 celibataires (CHF)",
    )
    impot_maries_total: float = Field(
        ..., description="Impot total en tant que couple marie (CHF)",
    )
    difference: float = Field(
        ..., description="Difference (positif = penalite mariage, negatif = bonus)",
    )
    est_penalite_mariage: bool = Field(
        ..., description="True si les maries paient plus",
    )
    detail_celibataire_1: float = Field(
        ..., description="Impot celibataire personne 1 (CHF)",
    )
    detail_celibataire_2: float = Field(
        ..., description="Impot celibataire personne 2 (CHF)",
    )
    revenus_cumules: float = Field(
        ..., description="Revenu total combine (CHF)",
    )
    deductions_mariage: float = Field(
        ..., description="Total des deductions specifiques au mariage (CHF)",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Mariage — Regime matrimonial
# ===========================================================================

class RegimeMatrimonialRequest(FamilyBaseModel):
    """Requete pour la simulation de regime matrimonial."""

    patrimoine_1: float = Field(
        ..., ge=0,
        description="Patrimoine total personne 1 (CHF)",
    )
    patrimoine_2: float = Field(
        ..., ge=0,
        description="Patrimoine total personne 2 (CHF)",
    )
    regime: RegimeMatrimonialType = Field(
        default=RegimeMatrimonialType.participation_acquets,
        description="Type de regime matrimonial",
    )


class RegimeMatrimonialResponse(FamilyBaseModel):
    """Reponse pour la simulation de regime matrimonial."""

    regime: str = Field(
        ..., description="Type de regime",
    )
    description: str = Field(
        ..., description="Description pedagogique du regime",
    )
    part_conjoint_1: float = Field(
        ..., description="Part patrimoine conjoint 1 (CHF)",
    )
    part_conjoint_2: float = Field(
        ..., description="Part patrimoine conjoint 2 (CHF)",
    )
    patrimoine_total: float = Field(
        ..., description="Patrimoine total (CHF)",
    )
    explication: str = Field(
        ..., description="Explication de la repartition",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Mariage — Rente de survivant
# ===========================================================================

class SurvivorBenefitsRequest(FamilyBaseModel):
    """Requete pour l'estimation des rentes de survivant."""

    rente_lpp: float = Field(
        ..., ge=0,
        description="Rente LPP mensuelle du defunt (CHF)",
    )
    rente_avs: float = Field(
        ..., ge=0,
        description="Rente AVS mensuelle du defunt (CHF)",
    )


class SurvivorBenefitsResponse(FamilyBaseModel):
    """Reponse pour l'estimation des rentes de survivant."""

    rente_survivant_avs_mensuelle: float = Field(
        ..., description="Rente AVS survivant mensuelle (CHF)",
    )
    rente_survivant_avs_annuelle: float = Field(
        ..., description="Rente AVS survivant annuelle (CHF)",
    )
    rente_survivant_lpp_mensuelle: float = Field(
        ..., description="Rente LPP survivant mensuelle (CHF)",
    )
    rente_survivant_lpp_annuelle: float = Field(
        ..., description="Rente LPP survivant annuelle (CHF)",
    )
    total_survivant_mensuel: float = Field(
        ..., description="Total mensuel (CHF)",
    )
    total_survivant_annuel: float = Field(
        ..., description="Total annuel (CHF)",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Naissance — Conge parental (APG)
# ===========================================================================

class CongeParentalRequest(FamilyBaseModel):
    """Requete pour le calcul du conge parental APG."""

    salaire_mensuel: float = Field(
        ..., gt=0,
        description="Salaire mensuel brut (CHF)",
    )
    is_mother: bool = Field(
        default=True,
        description="True pour maternite, False pour paternite",
    )


class CongeParentalResponse(FamilyBaseModel):
    """Reponse pour le calcul du conge parental APG."""

    type_conge: str = Field(
        ..., description="Type de conge (maternite ou paternite)",
    )
    duree_semaines: int = Field(
        ..., description="Duree en semaines",
    )
    duree_jours: int = Field(
        ..., description="Duree en jours",
    )
    salaire_journalier: float = Field(
        ..., description="Salaire journalier de base (CHF)",
    )
    apg_journalier: float = Field(
        ..., description="APG journalier (80%, plafonne) (CHF)",
    )
    apg_total: float = Field(
        ..., description="Total APG sur la duree (CHF)",
    )
    perte_revenu: float = Field(
        ..., description="Perte de revenu estimee (CHF)",
    )
    est_plafonne: bool = Field(
        ..., description="True si le max CHF 220/jour est atteint",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Naissance — Allocations familiales
# ===========================================================================

class AllocationsFamilialesRequest(FamilyBaseModel):
    """Requete pour l'estimation des allocations familiales."""

    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton (2 lettres)",
    )
    nb_enfants: int = Field(
        ..., ge=1,
        description="Nombre d'enfants",
    )
    ages_enfants: List[int] = Field(
        ...,
        description="Liste des ages des enfants",
    )


class AllocationsFamilialesResponse(FamilyBaseModel):
    """Reponse pour l'estimation des allocations familiales."""

    canton: str = Field(
        ..., description="Code canton",
    )
    nb_enfants: int = Field(
        ..., description="Nombre d'enfants",
    )
    allocation_mensuelle_par_enfant: Dict[int, float] = Field(
        ..., description="Montant mensuel par age d'enfant",
    )
    total_mensuel: float = Field(
        ..., description="Total mensuel (CHF)",
    )
    total_annuel: float = Field(
        ..., description="Total annuel (CHF)",
    )
    detail: List[str] = Field(
        default_factory=list,
        description="Detail par enfant",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Naissance — Impact fiscal enfant
# ===========================================================================

class ImpactFiscalEnfantRequest(FamilyBaseModel):
    """Requete pour le calcul de l'impact fiscal des enfants."""

    revenu_imposable: float = Field(
        ..., ge=0,
        description="Revenu imposable annuel (CHF)",
    )
    taux_marginal: float = Field(
        ..., ge=0, le=1,
        description="Taux marginal d'imposition (decimal, ex: 0.30)",
    )
    nb_enfants: int = Field(
        ..., ge=1,
        description="Nombre d'enfants a charge",
    )
    frais_garde: float = Field(
        default=0.0, ge=0,
        description="Frais de garde annuels effectifs (CHF)",
    )


class ImpactFiscalEnfantResponse(FamilyBaseModel):
    """Reponse pour le calcul de l'impact fiscal des enfants."""

    nb_enfants: int = Field(
        ..., description="Nombre d'enfants",
    )
    deduction_enfants: float = Field(
        ..., description="Deduction totale enfants (CHF)",
    )
    deduction_frais_garde: float = Field(
        ..., description="Deduction frais de garde (CHF)",
    )
    deduction_totale: float = Field(
        ..., description="Total deductions (CHF)",
    )
    economie_impot_estimee: float = Field(
        ..., description="Economie d'impot estimee (CHF)",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Naissance — Career gap
# ===========================================================================

class CareerGapRequest(FamilyBaseModel):
    """Requete pour la projection d'impact d'interruption de carriere."""

    salaire_annuel: float = Field(
        ..., gt=0,
        description="Salaire annuel brut de reference (CHF)",
    )
    duree_interruption_mois: int = Field(
        ..., ge=1,
        description="Duree de l'interruption en mois",
    )
    age: int = Field(
        default=35, ge=25, le=65,
        description="Age au moment de l'interruption",
    )


class CareerGapResponse(FamilyBaseModel):
    """Reponse pour la projection d'impact d'interruption de carriere."""

    duree_interruption_mois: int = Field(
        ..., description="Duree en mois",
    )
    salaire_annuel: float = Field(
        ..., description="Salaire de reference (CHF)",
    )
    perte_lpp_annuelle: float = Field(
        ..., description="Perte annuelle de bonification LPP (CHF)",
    )
    perte_lpp_totale: float = Field(
        ..., description="Perte LPP totale sur la duree (CHF)",
    )
    perte_3a_annuelle: float = Field(
        ..., description="Perte potentielle 3a par annee (CHF)",
    )
    perte_3a_totale: float = Field(
        ..., description="Perte 3a totale sur la duree (CHF)",
    )
    perte_revenu_totale: float = Field(
        ..., description="Perte totale de revenu (CHF)",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Concubinage — Comparaison mariage vs concubinage
# ===========================================================================

class ConcubinageCompareRequest(FamilyBaseModel):
    """Requete pour la comparaison mariage vs concubinage."""

    revenu_1: float = Field(
        ..., ge=0,
        description="Revenu annuel personne 1 (CHF)",
    )
    revenu_2: float = Field(
        ..., ge=0,
        description="Revenu annuel personne 2 (CHF)",
    )
    canton: str = Field(
        default="ZH", min_length=2, max_length=2,
        description="Code canton (2 lettres)",
    )
    enfants: int = Field(
        default=0, ge=0,
        description="Nombre d'enfants",
    )
    patrimoine: float = Field(
        default=0.0, ge=0,
        description="Patrimoine total du couple (CHF)",
    )


class ComparisonItemSchema(FamilyBaseModel):
    """Un point de comparaison mariage vs concubinage."""
    domaine: str = Field(..., description="Domaine compare")
    mariage: str = Field(..., description="Description cote mariage")
    concubinage: str = Field(..., description="Description cote concubinage")
    avantage: str = Field(..., description="Qui a l'avantage: mariage, concubinage, neutre")


class ConcubinageCompareResponse(FamilyBaseModel):
    """Reponse pour la comparaison mariage vs concubinage."""

    comparaisons: List[ComparisonItemSchema] = Field(
        ..., description="Liste des points de comparaison",
    )
    score_protection_mariage: int = Field(
        ..., description="Score de protection mariage (sur 10)",
    )
    score_protection_concubinage: int = Field(
        ..., description="Score de protection concubinage (sur 10)",
    )
    impot_celibataires_total: float = Field(
        ..., description="Impot en tant que 2 celibataires (CHF)",
    )
    impot_maries_total: float = Field(
        ..., description="Impot en tant que couple marie (CHF)",
    )
    difference_fiscale: float = Field(
        ..., description="Difference fiscale (CHF)",
    )
    impot_succession_conjoint: float = Field(
        ..., description="Impot de succession si conjoint (CHF)",
    )
    impot_succession_concubin: float = Field(
        ..., description="Impot de succession si concubin (CHF)",
    )
    synthese: str = Field(
        ..., description="Synthese pedagogique",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Concubinage — Succession
# ===========================================================================

class SuccessionRequest(FamilyBaseModel):
    """Requete pour la comparaison d'impot sur les successions."""

    patrimoine: float = Field(
        ..., ge=0,
        description="Patrimoine a transmettre (CHF)",
    )
    canton: str = Field(
        default="ZH", min_length=2, max_length=2,
        description="Code canton (2 lettres)",
    )
    is_married: bool = Field(
        default=False,
        description="True pour conjoint, False pour concubin",
    )


class SuccessionResponse(FamilyBaseModel):
    """Reponse pour la comparaison d'impot sur les successions."""

    canton: str = Field(
        ..., description="Code canton",
    )
    patrimoine: float = Field(
        ..., description="Patrimoine transmis (CHF)",
    )
    impot_conjoint: float = Field(
        ..., description="Impot si conjoint survivant (CHF)",
    )
    impot_concubin: float = Field(
        ..., description="Impot si concubin survivant (CHF)",
    )
    difference: float = Field(
        ..., description="Difference impot concubin - conjoint (CHF)",
    )
    taux_conjoint: float = Field(
        ..., description="Taux effectif conjoint",
    )
    taux_concubin: float = Field(
        ..., description="Taux effectif concubin",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Concubinage — Checklist
# ===========================================================================

class ChecklistConcubinageResponse(FamilyBaseModel):
    """Reponse pour la checklist concubinage."""

    items: List[str] = Field(
        ..., description="Liste des actions recommandees",
    )
    priorite_haute: List[str] = Field(
        ..., description="Actions urgentes",
    )
    priorite_moyenne: List[str] = Field(
        ..., description="Actions importantes",
    )
    priorite_basse: List[str] = Field(
        ..., description="Actions de confort",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )
