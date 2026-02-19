from datetime import datetime
from typing import Optional

from pydantic import BaseModel
from enum import Enum


class HealthResponse(BaseModel):
    status: str


class DetailedHealthResponse(BaseModel):
    status: str
    version: str
    environment: str
    database: str
    timestamp: datetime


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
