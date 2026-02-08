from pydantic import BaseModel, UUID4, ConfigDict
from enum import Enum
from typing import Dict, Any
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
    profileId: UUID4
    kind: ScenarioKind
    inputs: Dict[str, Any]


class Scenario(ScenarioCreate):
    id: UUID4
    outputs: Dict[str, Any]
    createdAt: datetime

    model_config = ConfigDict(from_attributes=True)
