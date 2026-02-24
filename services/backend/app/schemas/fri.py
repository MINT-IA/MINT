"""
Pydantic v2 schemas for the FRI module (Sprint S39 — Beta Display).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - FriInputSchema — input data for FRI computation
    - FriBreakdownResponse — FRI breakdown result
    - FriDisplayResponse — display-safe FRI result
    - FriComputeRequest — request body for POST /fri/current
    - FriSimulateRequest / FriSimulateResponse — what-if simulation

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 14-16 (taux de conversion)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
    - FINMA circ. 2008/21 (gestion des risques)
"""

from typing import List, Literal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================

class FriBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Input schema
# ===========================================================================

class FriInputSchema(FriBaseModel):
    """Input data for FRI computation — mirrors FriInput dataclass."""

    # L — Liquidity
    liquid_assets: float = Field(
        default=0.0, ge=0.0,
        description="CHF en epargne liquide / comptes",
    )
    monthly_fixed_costs: float = Field(
        default=1.0, ge=1.0,
        description="CHF charges mensuelles fixes (min 1)",
    )
    short_term_debt_ratio: float = Field(
        default=0.0, ge=0.0, le=1.0,
        description="Ratio dette court-terme / actifs totaux (0-1)",
    )
    income_volatility: Literal["low", "medium", "high"] = Field(
        default="low",
        description="Volatilite des revenus: low, medium, high",
    )

    # F — Fiscal efficiency
    actual_3a: float = Field(
        default=0.0, ge=0.0,
        description="CHF verse en 3a cette annee",
    )
    max_3a: float = Field(
        default=7258.0, ge=0.0,
        description="CHF plafond 3a (7258 salarie, 36288 indep.)",
    )
    potentiel_rachat_lpp: float = Field(
        default=0.0, ge=0.0,
        description="CHF potentiel de rachat LPP",
    )
    rachat_effectue: float = Field(
        default=0.0, ge=0.0,
        description="CHF rachat LPP effectue",
    )
    taux_marginal: float = Field(
        default=0.0, ge=0.0, le=1.0,
        description="Taux marginal d'imposition (0-1)",
    )
    is_property_owner: bool = Field(
        default=False,
        description="Proprietaire immobilier",
    )
    amort_indirect: float = Field(
        default=0.0, ge=0.0,
        description="CHF amortissement indirect via 3a",
    )

    # R — Retirement readiness
    replacement_ratio: float = Field(
        default=0.0, ge=0.0,
        description="Ratio de remplacement projete (0-1+)",
    )

    # S — Structural risk
    disability_gap_ratio: float = Field(
        default=0.0, ge=0.0, le=1.0,
        description="Ecart entre besoin invalidite et couverture (0-1)",
    )
    has_dependents: bool = Field(
        default=False,
        description="A des personnes a charge",
    )
    death_protection_gap_ratio: float = Field(
        default=0.0, ge=0.0, le=1.0,
        description="Ecart de couverture deces (0-1)",
    )
    mortgage_stress_ratio: float = Field(
        default=0.0, ge=0.0, le=1.0,
        description="Charges hypothecaires / revenu brut (0-1)",
    )
    concentration_ratio: float = Field(
        default=0.0, ge=0.0, le=1.0,
        description="Plus gros actif / patrimoine net total (0-1)",
    )
    employer_dependency_ratio: float = Field(
        default=0.0, ge=0.0, le=1.0,
        description="(LPP + salaire) meme employeur / revenu total (0-1)",
    )

    # Metadata
    archetype: str = Field(
        default="swiss_native",
        description="Archetype financier de l'utilisateur",
    )
    age: int = Field(
        default=30, ge=18, le=100,
        description="Age de l'utilisateur",
    )
    canton: str = Field(
        default="VD",
        description="Canton de residence (2 lettres)",
    )


# ===========================================================================
# Response schemas
# ===========================================================================

class FriBreakdownResponse(FriBaseModel):
    """FRI breakdown result — 4 components + total."""

    liquidite: float = Field(..., description="Composante liquidite (0-25)")
    fiscalite: float = Field(..., description="Composante fiscalite (0-25)")
    retraite: float = Field(..., description="Composante retraite (0-25)")
    risque: float = Field(..., description="Composante risque structurel (0-25)")
    total: float = Field(..., description="Score total (0-100)")
    model_version: str = Field(..., description="Version du modele FRI")
    confidence_score: float = Field(
        ..., description="Score de confiance du profil (0-100)",
    )


class FriDisplayResponse(FriBaseModel):
    """Display-safe FRI result with actions and compliance."""

    breakdown: FriBreakdownResponse
    display_allowed: bool = Field(
        ..., description="True si le profil est assez complet pour afficher",
    )
    top_action: str = Field(
        ..., description="Action d'amelioration la plus impactante (francais)",
    )
    top_action_delta: float = Field(
        ..., description="Amelioration estimee du FRI si l'action est executee",
    )
    enrichment_message: str = Field(
        ..., description="Message si l'affichage n'est pas autorise",
    )
    disclaimer: str = Field(
        ..., description="Mention legale obligatoire",
    )
    sources: List[str] = Field(
        ..., description="References legales",
    )


# ===========================================================================
# Request schemas
# ===========================================================================

class FriComputeRequest(FriBaseModel):
    """Request body for POST /fri/current."""

    input_data: FriInputSchema = Field(
        ..., alias="inputData",
        description="Donnees financieres pour le calcul FRI",
    )
    confidence_score: float = Field(
        default=0.0, ge=0.0, le=100.0,
        description="Score de confiance du profil (0-100)",
    )


class FriSimulateRequest(FriBaseModel):
    """Request body for POST /fri/simulate-action."""

    input_data: FriInputSchema = Field(
        ..., alias="inputData",
        description="Donnees financieres actuelles",
    )
    action_type: str = Field(
        ...,
        description="Type d'action: add_3a, add_liquidity, add_rachat, reduce_mortgage",
    )
    confidence_score: float = Field(
        default=0.0, ge=0.0, le=100.0,
        description="Score de confiance du profil (0-100)",
    )


class FriSimulateResponse(FriBaseModel):
    """Response for POST /fri/simulate-action."""

    delta_fri: float = Field(
        ..., description="Amelioration du score FRI total",
    )
    new_breakdown: FriBreakdownResponse = Field(
        ..., description="Nouveau breakdown apres simulation",
    )
    action_description: str = Field(
        ..., description="Description de l'action simulee (francais)",
    )
    disclaimer: str = Field(
        ..., description="Mention legale obligatoire",
    )
    sources: List[str] = Field(
        ..., description="References legales",
    )
