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

    # ⭐ Nouveaux champs pour statut d'emploi et 2e pilier
    employmentStatus: Optional[str] = None
    has2ndPillar: Optional[bool] = None
    legalForm: Optional[str] = None
    selfEmployedNetIncome: Optional[float] = None
    hasVoluntaryLpp: Optional[bool] = None
    primaryActivity: Optional[str] = None

    # ⭐ Nouveaux champs pour AVS
    hasAvsGaps: Optional[bool] = None
    avsContributionYears: Optional[int] = None
    spouseAvsContributionYears: Optional[int] = None

    # ⭐ Nouveaux champs pour modèle fiscal MVP (Chantier 1)
    commune: Optional[str] = None  # NPA ou nom commune → multiplicateur précis
    isChurchMember: bool = False  # Impôt ecclésiastique
    pillar3aAnnual: Optional[float] = None  # Versement annuel 3a → déduction fiscale


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

    # ⭐ Nouveaux champs
    employmentStatus: Optional[str] = None
    has2ndPillar: Optional[bool] = None
    legalForm: Optional[str] = None
    selfEmployedNetIncome: Optional[float] = None
    hasVoluntaryLpp: Optional[bool] = None
    primaryActivity: Optional[str] = None
    hasAvsGaps: Optional[bool] = None
    avsContributionYears: Optional[int] = None
    spouseAvsContributionYears: Optional[int] = None
    commune: Optional[str] = None
    isChurchMember: Optional[bool] = None
    pillar3aAnnual: Optional[float] = None


class Profile(ProfileBase):
    id: UUID4
    createdAt: datetime

    model_config = ConfigDict(from_attributes=True)
