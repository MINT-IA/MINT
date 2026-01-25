from pydantic import BaseModel, UUID4, ConfigDict
from typing import List, Optional
from enum import Enum
from .common import Impact


class NextActionType(str, Enum):
    learn = "learn"
    simulate = "simulate"
    checklist = "checklist"
    partner_handoff = "partner_handoff"
    external_resource = "external_resource"


class NextAction(BaseModel):
    type: NextActionType
    label: str
    deepLink: Optional[str] = None
    partnerId: Optional[str] = None


class EvidenceLink(BaseModel):
    label: str
    url: str


class Recommendation(BaseModel):
    id: UUID4
    kind: str
    title: str
    summary: str
    why: List[str]
    assumptions: List[str]
    impact: Impact
    risks: List[str]
    alternatives: List[str]
    evidenceLinks: List[EvidenceLink] = []
    nextActions: List[NextAction]

    model_config = ConfigDict(from_attributes=True)


class RecommendationPreviewRequest(BaseModel):
    profileId: UUID4
    focusKind: Optional[str] = None
