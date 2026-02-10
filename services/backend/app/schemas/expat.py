"""
Pydantic v2 schemas for the Expat module (frontalier, expatriation).

Sprint S23 — Expatriation + Frontaliers.
API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - Frontalier: impot a la source, quasi-resident, regle 90 jours,
      charges sociales, option LAMal
    - Expat: forfait fiscal, double imposition, lacunes AVS,
      planification depart, comparaison fiscale
"""

from enum import Enum
from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import Dict, List, Optional


# ===========================================================================
# Base config
# ===========================================================================

class ExpatBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Enums
# ===========================================================================

class MaritalStatus(str, Enum):
    """Etat civil."""
    celibataire = "celibataire"
    marie = "marie"


class ResidenceCountry(str, Enum):
    """Pays de residence pour frontaliers."""
    FR = "FR"
    DE = "DE"
    IT = "IT"
    AT = "AT"


class TargetCountry(str, Enum):
    """Pays de destination pour comparaison fiscale."""
    FR = "FR"
    DE = "DE"
    IT = "IT"
    AT = "AT"
    UK = "UK"
    US = "US"
    ES = "ES"
    PT = "PT"


class IncomeType(str, Enum):
    """Types de revenus pour la double imposition."""
    salaire = "salaire"
    pension_avs = "pension_avs"
    pension_lpp = "pension_lpp"
    dividendes = "dividendes"
    interets = "interets"
    immobilier = "immobilier"


# ===========================================================================
# Frontalier — Impot a la source
# ===========================================================================

class SourceTaxRequest(ExpatBaseModel):
    """Requete pour le calcul d'impot a la source frontalier."""

    salary: float = Field(
        ..., ge=0,
        description="Salaire brut annuel (CHF)",
    )
    canton: str = Field(
        default="VD", min_length=2, max_length=2,
        description="Canton de travail (2 lettres)",
    )
    marital_status: MaritalStatus = Field(
        default=MaritalStatus.celibataire,
        description="Etat civil (celibataire ou marie)",
    )
    children: int = Field(
        default=0, ge=0,
        description="Nombre d'enfants a charge",
    )
    church_tax: bool = Field(
        default=False,
        description="Affiliation a une eglise reconnue (impot ecclesiastique)",
    )


class SourceTaxResponse(ExpatBaseModel):
    """Reponse pour le calcul d'impot a la source frontalier."""

    salaire_brut: float = Field(..., description="Salaire brut annuel (CHF)")
    canton: str = Field(..., description="Canton de travail")
    impot_source: float = Field(..., description="Impot a la source estime (CHF)")
    taux_effectif: float = Field(..., description="Taux effectif d'imposition (%)")
    impot_ordinaire_estime: float = Field(..., description="Impot ordinaire estime pour comparaison (CHF)")
    taux_ordinaire_estime: float = Field(..., description="Taux ordinaire estime (%)")
    difference: float = Field(..., description="Difference source - ordinaire (CHF)")
    regime_special: Optional[str] = Field(None, description="Regime special (quasi_resident, italie)")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Frontalier — Quasi-resident
# ===========================================================================

class QuasiResidentRequest(ExpatBaseModel):
    """Requete pour la verification quasi-resident."""

    ch_income: float = Field(
        ..., ge=0,
        description="Revenu annuel gagne en Suisse (CHF)",
    )
    worldwide_income: float = Field(
        ..., ge=0,
        description="Revenu mondial total (CHF)",
    )
    canton: str = Field(
        default="GE", min_length=2, max_length=2,
        description="Canton de travail (2 lettres)",
    )


class QuasiResidentResponse(ExpatBaseModel):
    """Reponse pour la verification quasi-resident."""

    eligible: bool = Field(..., description="Eligible au statut quasi-resident")
    revenu_ch: float = Field(..., description="Revenu suisse (CHF)")
    revenu_mondial: float = Field(..., description="Revenu mondial total (CHF)")
    ratio_ch: float = Field(..., description="Part du revenu suisse (%)")
    seuil_requis: float = Field(..., description="Seuil requis (%)")
    economie_potentielle: float = Field(..., description="Economie estimee si eligible (CHF)")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Frontalier — Regle des 90 jours
# ===========================================================================

class NinetyDayRuleRequest(ExpatBaseModel):
    """Requete pour la simulation de la regle des 90 jours."""

    home_office_days: int = Field(
        ..., ge=0,
        description="Nombre de jours de teletravail depuis le domicile a l'etranger",
    )
    commute_days: int = Field(
        ..., ge=0,
        description="Nombre de jours de deplacement en Suisse",
    )


class NinetyDayRuleResponse(ExpatBaseModel):
    """Reponse pour la simulation de la regle des 90 jours."""

    jours_teletravail: int = Field(..., description="Jours de teletravail a l'etranger")
    jours_deplacement_ch: int = Field(..., description="Jours en Suisse")
    depasse_seuil: bool = Field(..., description="Depasse le seuil de 90 jours")
    pays_imposition: str = Field(..., description="Pays d'imposition resultant")
    risque: str = Field(..., description="Niveau de risque (faible, moyen, eleve)")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Frontalier — Charges sociales
# ===========================================================================

class SocialChargesRequest(ExpatBaseModel):
    """Requete pour la comparaison des charges sociales."""

    salary: float = Field(
        ..., ge=0,
        description="Salaire brut annuel (CHF)",
    )
    country_of_residence: ResidenceCountry = Field(
        default=ResidenceCountry.FR,
        description="Pays de residence (FR, DE, IT, AT)",
    )


class SocialChargesResponse(ExpatBaseModel):
    """Reponse pour la comparaison des charges sociales."""

    salaire_brut: float = Field(..., description="Salaire brut annuel (CHF)")
    pays_residence: str = Field(..., description="Pays de residence")
    avs_ai_apg_employe: float = Field(..., description="AVS/AI/APG part salarie (CHF)")
    ac_employe: float = Field(..., description="AC part salarie (CHF)")
    ac_solidarite: float = Field(..., description="AC solidarite (CHF)")
    lpp_employe: float = Field(..., description="LPP part salarie (CHF)")
    aanp_employe: float = Field(..., description="AANP part salarie (CHF)")
    total_ch_employe: float = Field(..., description="Total CH part salarie (CHF)")
    total_ch_employeur: float = Field(..., description="Total CH part employeur (CHF)")
    total_residence_employe: float = Field(..., description="Total residence part salarie (CHF)")
    total_residence_employeur: float = Field(..., description="Total residence part employeur (CHF)")
    difference_employe: float = Field(..., description="Difference CH - residence, part salarie (CHF)")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Frontalier — Option LAMal
# ===========================================================================

class LamalOptionRequest(ExpatBaseModel):
    """Requete pour la comparaison LAMal vs assurance residence."""

    age: int = Field(
        ..., ge=18, le=100,
        description="Age de la personne",
    )
    canton: str = Field(
        default="GE", min_length=2, max_length=2,
        description="Canton de travail (2 lettres)",
    )
    family_size: int = Field(
        default=1, ge=1,
        description="Taille de la famille (1 = seul)",
    )
    residence_country: ResidenceCountry = Field(
        default=ResidenceCountry.FR,
        description="Pays de residence (FR, DE, IT, AT)",
    )


class LamalOptionResponse(ExpatBaseModel):
    """Reponse pour la comparaison LAMal vs assurance residence."""

    canton: str = Field(..., description="Canton de travail")
    pays_residence: str = Field(..., description="Pays de residence")
    prime_lamal_mensuelle: float = Field(..., description="Prime LAMal mensuelle (CHF)")
    prime_lamal_annuelle: float = Field(..., description="Prime LAMal annuelle (CHF)")
    prime_residence_mensuelle: float = Field(..., description="Prime pays de residence mensuelle (CHF)")
    prime_residence_annuelle: float = Field(..., description="Prime pays de residence annuelle (CHF)")
    economie_lamal: float = Field(..., description="Economie si LAMal (CHF/an, negatif = LAMal plus cher)")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Expat — Forfait fiscal
# ===========================================================================

class ForfaitFiscalRequest(ExpatBaseModel):
    """Requete pour la simulation du forfait fiscal."""

    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Canton de residence (2 lettres)",
    )
    living_expenses: float = Field(
        ..., ge=0,
        description="Depenses de train de vie annuelles (CHF)",
    )
    actual_income: float = Field(
        ..., ge=0,
        description="Revenu reel annuel (CHF)",
    )


class ForfaitFiscalResponse(ExpatBaseModel):
    """Reponse pour la simulation du forfait fiscal."""

    canton: str = Field(..., description="Canton de residence")
    eligible: bool = Field(..., description="Eligible au forfait fiscal")
    base_forfaitaire: float = Field(..., description="Base forfaitaire retenue (CHF)")
    depenses_reelles: float = Field(..., description="Depenses declarees (CHF)")
    revenu_reel: float = Field(..., description="Revenu reel (CHF)")
    impot_forfait: float = Field(..., description="Impot forfaitaire estime (CHF)")
    impot_ordinaire: float = Field(..., description="Impot ordinaire sur le revenu reel (CHF)")
    economie: float = Field(..., description="Economie forfait vs ordinaire (CHF)")
    conditions: List[str] = Field(default_factory=list, description="Conditions d'eligibilite")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Expat — Double imposition
# ===========================================================================

class DoubleTaxationRequest(ExpatBaseModel):
    """Requete pour l'analyse de double imposition."""

    residence_country: TargetCountry = Field(
        ...,
        description="Pays de residence",
    )
    income_types: Optional[List[IncomeType]] = Field(
        default=None,
        description="Types de revenus a analyser (si None, tous les types)",
    )


class DoubleTaxationResponse(ExpatBaseModel):
    """Reponse pour l'analyse de double imposition."""

    pays_residence: str = Field(..., description="Pays de residence")
    convention_existe: bool = Field(..., description="CDI en vigueur")
    date_convention: str = Field(..., description="Date de la convention")
    repartition: Dict[str, str] = Field(..., description="Type de revenu -> pays qui impose")
    taux_dividendes_max: float = Field(..., description="Retenue max sur dividendes (%)")
    taux_interets_max: float = Field(..., description="Retenue max sur interets (%)")
    optimisations: List[str] = Field(default_factory=list, description="Conseils d'optimisation")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Expat — Lacunes AVS
# ===========================================================================

class AVSGapRequest(ExpatBaseModel):
    """Requete pour l'estimation des lacunes AVS."""

    years_abroad: int = Field(
        ..., ge=0,
        description="Nombre d'annees a l'etranger sans cotisation AVS CH",
    )
    years_in_ch: int = Field(
        ..., ge=0,
        description="Nombre d'annees de cotisation en Suisse",
    )


class AVSGapResponse(ExpatBaseModel):
    """Reponse pour l'estimation des lacunes AVS."""

    annees_cotisation_ch: int = Field(..., description="Annees cotisees en Suisse")
    annees_a_letranger: int = Field(..., description="Annees a l'etranger")
    annees_totales: int = Field(..., description="Total des annees")
    annees_manquantes: int = Field(..., description="Annees manquantes pour rente complete")
    rente_estimee_mensuelle: float = Field(..., description="Rente AVS estimee mensuelle (CHF)")
    rente_max_mensuelle: float = Field(..., description="Rente AVS maximale mensuelle (CHF)")
    reduction_mensuelle: float = Field(..., description="Reduction mensuelle (CHF)")
    reduction_annuelle: float = Field(..., description="Reduction annuelle (CHF)")
    cotisation_volontaire_possible: bool = Field(..., description="Peut cotiser a l'AVS facultative")
    cotisation_min: float = Field(..., description="Cotisation min annuelle (CHF)")
    cotisation_max: float = Field(..., description="Cotisation max annuelle (CHF)")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Expat — Planification de depart
# ===========================================================================

class DeparturePlanRequest(ExpatBaseModel):
    """Requete pour la planification de depart."""

    departure_date: str = Field(
        ...,
        description="Date de depart prevue (format YYYY-MM-DD)",
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Canton de domicile actuel (2 lettres)",
    )
    pillar_3a_balance: float = Field(
        ..., ge=0,
        description="Solde du 3e pilier a (CHF)",
    )
    lpp_balance: float = Field(
        ..., ge=0,
        description="Solde LPP / libre passage (CHF)",
    )


class ChecklistItem(ExpatBaseModel):
    """Un element de la checklist de depart."""
    priorite: str = Field(..., description="Priorite (haute, moyenne, basse)")
    action: str = Field(..., description="Action a effectuer")
    delai: str = Field(..., description="Delai recommande")


class DeparturePlanResponse(ExpatBaseModel):
    """Reponse pour la planification de depart."""

    date_depart: str = Field(..., description="Date de depart prevue")
    canton: str = Field(..., description="Canton de domicile")
    pillar_3a_balance: float = Field(..., description="Solde 3e pilier (CHF)")
    lpp_balance: float = Field(..., description="Solde LPP (CHF)")
    impot_capital_3a: float = Field(..., description="Impot sur le retrait 3a (CHF)")
    impot_capital_lpp: float = Field(..., description="Impot sur le retrait LPP (CHF)")
    delai_retrait_3a: str = Field(..., description="Delai pour retirer le 3a")
    checklist: List[ChecklistItem] = Field(default_factory=list, description="Checklist de depart")
    timing_optimal: str = Field(..., description="Conseil sur le timing optimal")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")


# ===========================================================================
# Expat — Comparaison fiscale internationale
# ===========================================================================

class TaxComparisonRequest(ExpatBaseModel):
    """Requete pour la comparaison fiscale internationale."""

    salary: float = Field(
        ..., ge=0,
        description="Salaire brut annuel (CHF)",
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Canton CH actuel (2 lettres)",
    )
    target_country: TargetCountry = Field(
        ...,
        description="Pays de destination",
    )


class TaxComparisonResponse(ExpatBaseModel):
    """Reponse pour la comparaison fiscale internationale."""

    salaire_brut: float = Field(..., description="Salaire brut annuel (CHF)")
    canton: str = Field(..., description="Canton CH actuel")
    pays_cible: str = Field(..., description="Pays de destination")
    impot_ch: float = Field(..., description="Impot total CH (CHF)")
    charges_sociales_ch: float = Field(..., description="Charges sociales CH (CHF)")
    total_ch: float = Field(..., description="Total prelevements CH (CHF)")
    net_ch: float = Field(..., description="Revenu net CH (CHF)")
    impot_cible: float = Field(..., description="Impot total pays cible (CHF)")
    charges_sociales_cible: float = Field(..., description="Charges sociales pays cible (CHF)")
    total_cible: float = Field(..., description="Total prelevements pays cible (CHF)")
    net_cible: float = Field(..., description="Revenu net pays cible (CHF)")
    difference_nette: float = Field(..., description="Net CH - Net cible (positif = CH avantageux)")
    exit_tax_note: str = Field(..., description="Note sur l'exit tax")
    recommandation: str = Field(..., description="Recommandation pedagogique")
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(default_factory=list, description="Sources legales")
