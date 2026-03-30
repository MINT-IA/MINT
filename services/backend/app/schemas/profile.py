from pydantic import BaseModel, Field, UUID4, ConfigDict
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
    dateOfBirth: Optional[str] = None  # ISO 8601 date string (e.g. "1981-06-15")
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

    # ⭐ Genre (AVS21 transitional reference ages — LAVS art. 21 al. 1)
    gender: Optional[str] = None  # 'M', 'F', or None (unknown)

    # ⭐ Nouveaux champs pour AVS
    hasAvsGaps: Optional[bool] = None
    avsContributionYears: Optional[int] = None
    spouseAvsContributionYears: Optional[int] = None

    # ⭐ Nouveaux champs pour modèle fiscal MVP (Chantier 1)
    commune: Optional[str] = None  # NPA ou nom commune → multiplicateur précis
    isChurchMember: bool = False  # Impôt ecclésiastique
    pillar3aAnnual: Optional[float] = None  # Versement annuel 3a → déduction fiscale
    wealthEstimate: Optional[float] = None  # Fortune nette estimée → impôt sur la fortune


class ProfileCreate(ProfileBase):
    pass


class ProfileUpdate(BaseModel):
    birthYear: Optional[int] = Field(None, ge=1900, le=2025)  # FIX-069
    dateOfBirth: Optional[str] = Field(
        None,
        pattern=r"^\d{4}-\d{2}-\d{2}",
        description="Date de naissance ISO 8601 (ex: 1981-06-15)",
    )
    canton: Optional[str] = None
    householdType: Optional[HouseholdType] = None
    incomeNetMonthly: Optional[float] = Field(None, ge=0)  # FIX-069
    incomeGrossYearly: Optional[float] = Field(None, ge=0)  # FIX-069
    savingsMonthly: Optional[float] = None
    totalSavings: Optional[float] = None
    lppInsuredSalary: Optional[float] = None
    hasDebt: Optional[bool] = None
    goal: Optional[Goal] = None
    factfindCompletionIndex: Optional[float] = None

    # ⭐ Nouveaux champs
    gender: Optional[str] = None
    # FIX-146: Accept both FR (salarie/independant) and EN (employee/self_employed)
    employmentStatus: Optional[str] = Field(
        None,
        pattern=r"^(salarie|independant|retraite|employee|self_employed|retired|mixed|unemployed|student)$",
    )
    has2ndPillar: Optional[bool] = None
    legalForm: Optional[str] = None
    selfEmployedNetIncome: Optional[float] = None
    hasVoluntaryLpp: Optional[bool] = None
    primaryActivity: Optional[str] = None
    hasAvsGaps: Optional[bool] = None
    avsContributionYears: Optional[int] = None
    spouseAvsContributionYears: Optional[int] = None
    # FIX-114: Couple financial fields for household calculations
    spouseSalaryGrossAnnual: Optional[float] = Field(None, ge=0)
    spouseEmploymentStatus: Optional[str] = None
    householdGrossIncome: Optional[float] = Field(None, ge=0)
    commune: Optional[str] = None
    isChurchMember: Optional[bool] = None
    pillar3aAnnual: Optional[float] = None
    wealthEstimate: Optional[float] = None


class Profile(ProfileBase):
    id: UUID4
    createdAt: datetime

    model_config = ConfigDict(from_attributes=True)
