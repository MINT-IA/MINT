"""
Pydantic v2 schemas for the Independants module.

Sprint S18 — Module Independants complet.
API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - AVS cotisations (self-employed contributions)
    - IJM (income loss insurance)
    - 3a independant (enhanced 3a for self-employed)
    - Dividende vs Salaire (dividend/salary optimizer)
    - LPP volontaire (voluntary pension fund)
"""

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import List


# ===========================================================================
# AVS Cotisations Schemas
# ===========================================================================

class AvsCotisationsRequest(BaseModel):
    """Request for AVS self-employed contribution calculation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    revenu_net_activite: float = Field(
        ..., description="Revenu net de l'activite independante (CHF)", ge=0
    )


class AvsCotisationsResponse(BaseModel):
    """Response for AVS contribution calculation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    cotisation_avs_ai_apg: float = Field(
        ..., description="Cotisation AVS/AI/APG totale (CHF)"
    )
    taux_effectif: float = Field(
        ..., description="Taux effectif applique"
    )
    comparaison_salarie: float = Field(
        ..., description="Cotisation qu'un-e salarie-e paierait sur le meme revenu (CHF)"
    )
    difference_vs_salarie: float = Field(
        ..., description="Surcout par rapport a un-e salarie-e (CHF)"
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )


# ===========================================================================
# IJM Schemas
# ===========================================================================

class IjmRequest(BaseModel):
    """Request for IJM (income loss insurance) simulation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    revenu_mensuel: float = Field(
        ..., description="Revenu mensuel (CHF)", ge=0
    )
    age: int = Field(
        ..., description="Age de la personne", ge=18, le=70
    )
    delai_carence: int = Field(
        30, description="Delai de carence en jours (30, 60 ou 90)"
    )


class IjmResponse(BaseModel):
    """Response for IJM simulation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    indemnite_journaliere: float = Field(
        ..., description="Indemnite journaliere estimee (80% du revenu journalier) (CHF)"
    )
    prime_mensuelle: float = Field(
        ..., description="Prime mensuelle estimee (CHF)"
    )
    prime_annuelle: float = Field(
        ..., description="Prime annuelle estimee (CHF)"
    )
    cout_sans_couverture: float = Field(
        ..., description="Perte de revenu pendant le delai de carence sans IJM (CHF)"
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    alertes: List[str] = Field(
        default_factory=list, description="Alertes et recommandations"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )


# ===========================================================================
# Pillar 3a Independant Schemas
# ===========================================================================

class Pillar3aIndepRequest(BaseModel):
    """Request for enhanced 3a calculation for self-employed."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    revenu_net: float = Field(
        ..., description="Revenu net annuel (CHF)", ge=0
    )
    affilie_lpp: bool = Field(
        ..., description="Affilie-e a un LPP volontaire?"
    )
    taux_marginal_imposition: float = Field(
        ..., description="Taux marginal d'imposition estime (0-1)", ge=0, le=1
    )
    canton: str = Field(
        "ZH", description="Code canton (ex: ZH, VD, GE)", min_length=2, max_length=2
    )


class Pillar3aIndepResponse(BaseModel):
    """Response for 3a calculation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    plafond_applicable: float = Field(
        ..., description="Plafond 3a applicable (CHF)"
    )
    economie_fiscale: float = Field(
        ..., description="Economie fiscale estimee (CHF)"
    )
    comparaison_salarie: float = Field(
        ..., description="Economie fiscale si salarie-e (CHF)"
    )
    avantage_independant: float = Field(
        ..., description="Avantage supplementaire de l'independant-e (CHF)"
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )


# ===========================================================================
# Dividende vs Salaire Schemas
# ===========================================================================

class DividendeVsSalaireRequest(BaseModel):
    """Request for dividend vs salary optimization."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    benefice_disponible: float = Field(
        ..., description="Benefice disponible a distribuer (CHF)", ge=0
    )
    part_salaire: float = Field(
        ..., description="Part proposee en salaire (0-1)", ge=0, le=1
    )
    taux_marginal: float = Field(
        ..., description="Taux marginal d'imposition estime (0-1)", ge=0, le=1
    )
    canton: str = Field(
        "ZH", description="Code canton (ex: ZH, VD, GE)", min_length=2, max_length=2
    )


class GrapheDataPointResponse(BaseModel):
    """A single point on the sensitivity curve."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    split_salaire: float = Field(
        ..., description="Proportion salaire (0-1)"
    )
    charge_totale: float = Field(
        ..., description="Charge totale (CHF)"
    )


class DividendeVsSalaireResponse(BaseModel):
    """Response for dividend vs salary optimization."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    charge_totale_salaire: float = Field(
        ..., description="Charge totale si 100% salaire (CHF)"
    )
    charge_totale_dividende: float = Field(
        ..., description="Charge totale avec le split propose (CHF)"
    )
    charge_totale_tout_dividende: float = Field(
        ..., description="Charge totale si 100% dividende (CHF)"
    )
    split_optimal_indicatif: float = Field(
        ..., description="Split salaire/dividende indicatif le plus avantageux (0-1)"
    )
    economies: float = Field(
        ..., description="Economies par rapport a 100% salaire (CHF)"
    )
    alerte_requalification: bool = Field(
        ..., description="Risque de requalification fiscale?"
    )
    graphe_data: List[GrapheDataPointResponse] = Field(
        default_factory=list,
        description="Courbe de sensibilite: charge vs split (pas de 10%)",
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )


# ===========================================================================
# LPP Volontaire Schemas
# ===========================================================================

class LppVolontaireRequest(BaseModel):
    """Request for voluntary LPP simulation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    revenu_net: float = Field(
        ..., description="Revenu net annuel (CHF)", ge=0
    )
    age: int = Field(
        ..., description="Age de la personne", ge=18, le=70
    )
    taux_marginal: float = Field(
        ..., description="Taux marginal d'imposition estime (0-1)", ge=0, le=1
    )


class LppVolontaireResponse(BaseModel):
    """Response for voluntary LPP simulation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    salaire_coordonne: float = Field(
        ..., description="Salaire coordonne (CHF)"
    )
    cotisation_annuelle: float = Field(
        ..., description="Cotisation annuelle LPP (CHF)"
    )
    economie_fiscale: float = Field(
        ..., description="Economie fiscale estimee (CHF)"
    )
    comparaison_sans_lpp: float = Field(
        ..., description="Capital retraite perdu sans LPP (CHF/an)"
    )
    taux_bonification: float = Field(
        ..., description="Taux de bonification de vieillesse applique"
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )
