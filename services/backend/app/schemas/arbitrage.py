"""
Pydantic v2 schemas for the Arbitrage module (Sprint S32-S33).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - RenteVsCapitalRequest / RenteVsCapitalResponse
    - AllocationAnnuelleRequest / AllocationAnnuelleResponse
    - LocationVsProprieteRequest / LocationVsProprieteResponse (Sprint S33)
    - RachatVsMarcheRequest / RachatVsMarcheResponse (Sprint S33)
    - CalendrierRetraitsRequest / CalendrierRetraitsResponse (Sprint S33)
    - Shared: YearlySnapshotSchema, TrajectoireOptionSchema, ArbitrageResultSchema

Sources:
    - LPP art. 14 (taux de conversion minimum)
    - LPP art. 37 (choix rente/capital)
    - LPP art. 79b (rachat LPP, blocage 3 ans)
    - LIFD art. 22 (imposition des rentes)
    - LIFD art. 38 (imposition du capital de prevoyance)
    - OPP3 art. 7 (plafond 3a)
    - CO art. 253ss (bail)
    - FINMA Tragbarkeitsrechnung
"""

from typing import Dict, List, Optional

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================

class ArbitrageBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Shared schemas
# ===========================================================================

class YearlySnapshotSchema(ArbitrageBaseModel):
    """Snapshot annuel de l'evolution du patrimoine."""

    year: int = Field(..., description="Annee de la simulation")
    net_patrimony: float = Field(..., description="Patrimoine net en fin d'annee (CHF)")
    annual_cashflow: float = Field(..., description="Flux net annuel (CHF)")
    cumulative_tax_delta: float = Field(
        ..., description="Delta fiscal cumule vs baseline (CHF)"
    )


class TrajectoireOptionSchema(ArbitrageBaseModel):
    """Une option de trajectoire dans la comparaison d'arbitrage."""

    id: str = Field(..., description="Identifiant de l'option")
    label: str = Field(..., description="Libelle de l'option (francais)")
    trajectory: List[YearlySnapshotSchema] = Field(
        ..., description="Trajectoire annee par annee"
    )
    terminal_value: float = Field(
        ..., description="Patrimoine net en fin d'horizon (CHF)"
    )
    cumulative_tax_impact: float = Field(
        ..., description="Impact fiscal cumule sur l'horizon (CHF)"
    )


class ArbitrageResultSchema(ArbitrageBaseModel):
    """Resultat complet d'une comparaison d'arbitrage."""

    options: List[TrajectoireOptionSchema] = Field(
        ..., description="Liste des options comparees"
    )
    breakeven_year: int = Field(
        ..., description="Annee de croisement des courbes (-1 si jamais)"
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc: delta le plus marquant"
    )
    display_summary: str = Field(
        ..., description="Resume en une phrase (francais, tu informel)"
    )
    hypotheses: List[str] = Field(
        ..., description="Liste des hypotheses utilisees"
    )
    disclaimer: str = Field(
        ..., description="Disclaimer legal (outil educatif, LSFin)"
    )
    sources: List[str] = Field(
        ..., description="References legales suisses"
    )
    confidence_score: float = Field(
        ..., description="Score de confiance (0-100%)"
    )
    sensitivity: Dict[str, float] = Field(
        ..., description="Analyse de sensibilite: parametre -> impact de +/-1%"
    )


# ===========================================================================
# Rente vs Capital
# ===========================================================================

class RenteVsCapitalRequest(ArbitrageBaseModel):
    """Requete pour la comparaison rente vs capital LPP."""

    capital_lpp_total: float = Field(
        ..., ge=0,
        description="Capital LPP total a la retraite (CHF)",
    )
    capital_obligatoire: float = Field(
        ..., ge=0,
        description="Part obligatoire du capital LPP (CHF)",
    )
    capital_surobligatoire: float = Field(
        ..., ge=0,
        description="Part surobligatoire du capital LPP (CHF)",
    )
    rente_annuelle_proposee: float = Field(
        ..., ge=0,
        description="Rente annuelle proposee par la caisse (CHF)",
    )
    taux_conversion_obligatoire: Optional[float] = Field(
        default=None,
        description="Taux de conversion obligatoire (defaut: 6.8%)",
    )
    taux_conversion_surobligatoire: Optional[float] = Field(
        default=None,
        description="Taux de conversion surobligatoire (defaut: 5%)",
    )
    canton: Optional[str] = Field(
        default=None, min_length=2, max_length=2,
        description="Canton de domicile fiscal (defaut: VD)",
    )
    age_retraite: Optional[int] = Field(
        default=None, ge=58, le=70,
        description="Age de retraite (defaut: 65)",
    )
    taux_retrait: Optional[float] = Field(
        default=None,
        description="Taux de retrait SWR sur le capital (defaut: 4%)",
    )
    rendement_capital: Optional[float] = Field(
        default=None,
        description="Rendement net du capital apres retraite (defaut: 3%)",
    )
    inflation: Optional[float] = Field(
        default=None,
        description="Taux d'inflation (defaut: 2%)",
    )
    horizon: Optional[int] = Field(
        default=None, ge=1, le=50,
        description="Horizon de simulation en annees (defaut: 25)",
    )
    is_married: Optional[bool] = Field(
        default=None,
        description="Marie·e (splitting fiscal, defaut: False)",
    )


class RenteVsCapitalResponse(ArbitrageResultSchema):
    """Resultat de la comparaison rente vs capital LPP."""
    pass


# ===========================================================================
# Allocation Annuelle
# ===========================================================================

class AllocationAnnuelleRequest(ArbitrageBaseModel):
    """Requete pour la comparaison d'allocation annuelle."""

    montant_disponible: float = Field(
        ..., ge=0,
        description="Montant disponible pour allocation (CHF/an)",
    )
    taux_marginal: float = Field(
        ..., ge=0, le=0.50,
        description="Taux marginal d'imposition (0.0 - 0.50)",
    )
    a3a_maxed: Optional[bool] = Field(
        default=None,
        description="3a deja verse au maximum cette annee (defaut: False)",
    )
    potentiel_rachat_lpp: Optional[float] = Field(
        default=None, ge=0,
        description="Potentiel de rachat LPP disponible (CHF, defaut: 0)",
    )
    is_property_owner: Optional[bool] = Field(
        default=None,
        description="Proprietaire d'un bien immobilier (defaut: False)",
    )
    taux_hypothecaire: Optional[float] = Field(
        default=None,
        description="Taux hypothecaire actuel (defaut: 1.5%)",
    )
    annees_avant_retraite: Optional[int] = Field(
        default=None, ge=1, le=50,
        description="Annees avant la retraite (defaut: 20)",
    )
    rendement_3a: Optional[float] = Field(
        default=None,
        description="Rendement attendu du 3a (defaut: 2%)",
    )
    rendement_lpp: Optional[float] = Field(
        default=None,
        description="Rendement caisse LPP (defaut: 1.25%)",
    )
    rendement_marche: Optional[float] = Field(
        default=None,
        description="Rendement marche libre (defaut: 4%)",
    )
    canton: Optional[str] = Field(
        default=None, min_length=2, max_length=2,
        description="Canton de domicile fiscal (defaut: VD)",
    )


class AllocationAnnuelleResponse(ArbitrageResultSchema):
    """Resultat de la comparaison d'allocation annuelle."""
    pass


# ===========================================================================
# Location vs Propriete (Sprint S33)
# ===========================================================================

class LocationVsProprieteRequest(ArbitrageBaseModel):
    """Requete pour la comparaison location vs achat immobilier."""

    capital_disponible: float = Field(
        ..., ge=0,
        description="Capital disponible pour l'apport (CHF)",
    )
    loyer_mensuel_actuel: float = Field(
        ..., ge=0,
        description="Loyer mensuel actuel (CHF)",
    )
    prix_bien: float = Field(
        ..., ge=0,
        description="Prix du bien immobilier (CHF)",
    )
    canton: Optional[str] = Field(
        default=None, min_length=2, max_length=2,
        description="Canton de domicile fiscal (defaut: VD)",
    )
    horizon_annees: Optional[int] = Field(
        default=None, ge=1, le=50,
        description="Horizon de simulation en annees (defaut: 20)",
    )
    rendement_marche: Optional[float] = Field(
        default=None,
        description="Rendement marche si location + investissement (defaut: 4%)",
    )
    appreciation_immo: Optional[float] = Field(
        default=None,
        description="Appreciation immobiliere annuelle (defaut: 1.5%)",
    )
    taux_hypotheque: Optional[float] = Field(
        default=None,
        description="Taux hypothecaire reel (defaut: 2%)",
    )
    taux_entretien: Optional[float] = Field(
        default=None,
        description="Frais d'entretien en % du prix (defaut: 1%)",
    )
    is_married: Optional[bool] = Field(
        default=None,
        description="Marie·e (splitting fiscal, defaut: False)",
    )


class LocationVsProprieteResponse(ArbitrageResultSchema):
    """Resultat de la comparaison location vs achat."""
    pass


# ===========================================================================
# Rachat LPP vs Marche (Sprint S33)
# ===========================================================================

class RachatVsMarcheRequest(ArbitrageBaseModel):
    """Requete pour la comparaison rachat LPP vs investissement libre."""

    montant: float = Field(
        ..., ge=0,
        description="Montant a investir ou racheter (CHF)",
    )
    taux_marginal: float = Field(
        ..., ge=0, le=0.50,
        description="Taux marginal d'imposition (0.0 - 0.50)",
    )
    annees_avant_retraite: Optional[int] = Field(
        default=None, ge=1, le=50,
        description="Annees avant la retraite (defaut: 20)",
    )
    rendement_lpp: Optional[float] = Field(
        default=None,
        description="Rendement LPP en caisse (defaut: 1.25%)",
    )
    rendement_marche: Optional[float] = Field(
        default=None,
        description="Rendement marche libre (defaut: 4%)",
    )
    taux_conversion: Optional[float] = Field(
        default=None,
        description="Taux de conversion LPP (defaut: 6.8%)",
    )
    canton: Optional[str] = Field(
        default=None, min_length=2, max_length=2,
        description="Canton de domicile fiscal (defaut: VD)",
    )
    is_married: Optional[bool] = Field(
        default=None,
        description="Marie·e (splitting fiscal, defaut: False)",
    )


class RachatVsMarcheResponse(ArbitrageResultSchema):
    """Resultat de la comparaison rachat LPP vs investissement libre."""
    pass


# ===========================================================================
# Calendrier de Retraits (Sprint S33)
# ===========================================================================

class RetirementAssetSchema(ArbitrageBaseModel):
    """Un avoir de prevoyance eligible au retrait."""

    type: str = Field(
        ..., description="Type d'avoir: '3a', 'lpp', 'libre_passage'"
    )
    amount: float = Field(
        ..., ge=0, description="Montant actuel (CHF)"
    )
    earliest_withdrawal_age: int = Field(
        ..., ge=55, le=70,
        description="Age minimum de retrait (3a: 59/60, LPP: 58-65)",
    )


class CalendrierRetraitsRequest(ArbitrageBaseModel):
    """Requete pour la comparaison de calendrier de retraits."""

    assets: List[RetirementAssetSchema] = Field(
        ..., min_length=1,
        description="Liste des avoirs de prevoyance",
    )
    age_retraite: Optional[int] = Field(
        default=None, ge=58, le=70,
        description="Age de retraite (defaut: 65)",
    )
    canton: Optional[str] = Field(
        default=None, min_length=2, max_length=2,
        description="Canton de domicile fiscal (defaut: VD)",
    )
    is_married: Optional[bool] = Field(
        default=None,
        description="Marie·e (splitting fiscal, defaut: False)",
    )


class CalendrierRetraitsResponse(ArbitrageResultSchema):
    """Resultat de la comparaison de calendrier de retraits."""
    pass
