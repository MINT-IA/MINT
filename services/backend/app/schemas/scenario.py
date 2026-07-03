from pydantic import BaseModel, UUID4, ConfigDict, Field
from enum import Enum
from typing import Dict, Any, List, Optional
from datetime import datetime


class ScenarioKind(str, Enum):
    compound_interest = "compound_interest"
    leasing = "leasing"
    pillar3a = "pillar3a"
    lpp_buyback = "lpp_buyback"
    mortgage = "mortgage"
    avs_gap = "avs_gap"
    house_savings = "house_savings"
    retirement = "retirement"
    succession = "succession"
    consumer_credit = "consumer_credit"
    debt_risk = "debt_risk"
    rente_vs_capital = "rente_vs_capital"


class ScenarioCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    profileId: UUID4
    kind: ScenarioKind
    inputs: Dict[str, Any]
    inputProvenance: Dict[str, Any] = Field(default_factory=dict)
    scenarioId: Optional[str] = None
    profileOwnerId: Optional[str] = None


class Scenario(ScenarioCreate):
    id: UUID4
    outputs: Dict[str, Any]
    createdAt: datetime
    confidenceMode: str = "educational"
    enhancedConfidence: Dict[str, Any] = Field(default_factory=dict)
    disclaimer: str = ""
    sources: List[str] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class PaginatedScenariosResponse(BaseModel):
    """Paginated list of scenarios."""

    model_config = ConfigDict(from_attributes=True)

    items: List[Scenario] = Field(..., description="Liste des scenarios")
    total: int = Field(..., description="Nombre total de scenarios")
    limit: int = Field(..., description="Limite par page")
    offset: int = Field(..., description="Offset courant")
