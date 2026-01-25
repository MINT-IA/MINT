from pydantic import BaseModel
from enum import Enum


class HealthResponse(BaseModel):
    status: str


class OkResponse(BaseModel):
    ok: bool


class Period(str, Enum):
    monthly = "monthly"
    yearly = "yearly"
    oneoff = "oneoff"


class Impact(BaseModel):
    amountCHF: float
    # Use forward reference or simple importing if needed, but Enum is usually safe
    period: Period
