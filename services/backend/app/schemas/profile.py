from pydantic import BaseModel, UUID4, ConfigDict
from enum import Enum
from typing import Optional
from datetime import datetime


class HouseholdType(str, Enum):
    single = "single"
    couple = "couple"
    concubine = "concubine"
    family = "family"


class Goal(str, Enum):
    house = "house"
    retire = "retire"
    emergency = "emergency"
    invest = "invest"
    optimize_taxes = "optimize_taxes"
    other = "other"


class ProfileBase(BaseModel):
    birthYear: Optional[int] = None
    canton: Optional[str] = None
    householdType: HouseholdType
    incomeNetMonthly: Optional[float] = None
    incomeGrossYearly: Optional[float] = None
    savingsMonthly: Optional[float] = None
    totalSavings: Optional[float] = None
    lppInsuredSalary: Optional[float] = None
    hasDebt: bool = False
    goal: Goal = Goal.other
    factfindCompletionIndex: float = 0.0


class ProfileCreate(ProfileBase):
    pass


class ProfileUpdate(BaseModel):
    birthYear: Optional[int] = None
    canton: Optional[str] = None
    householdType: Optional[HouseholdType] = None
    incomeNetMonthly: Optional[float] = None
    incomeGrossYearly: Optional[float] = None
    savingsMonthly: Optional[float] = None
    totalSavings: Optional[float] = None
    lppInsuredSalary: Optional[float] = None
    hasDebt: Optional[bool] = None
    goal: Optional[Goal] = None
    factfindCompletionIndex: Optional[float] = None


class Profile(ProfileBase):
    id: UUID4
    createdAt: datetime

    model_config = ConfigDict(from_attributes=True)
