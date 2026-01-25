from pydantic import BaseModel, UUID4
from enum import Enum


class PartnerKind(str, Enum):
    pillar3a = "pillar3a"
    mortgage = "mortgage"
    taxes = "taxes"
    insurance = "insurance"
    investing = "investing"


class Partner(BaseModel):
    id: str
    kind: PartnerKind
    name: str
    disclosure: str
    url: str


class PartnerClick(BaseModel):
    profileId: UUID4
    partnerId: str
    kind: str
