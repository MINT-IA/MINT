import logging
from pydantic import BaseModel, Field, UUID4, ConfigDict, model_validator
from enum import Enum
from typing import Optional
from datetime import datetime

from app.schemas.voice_cursor import VoicePreference

logger = logging.getLogger(__name__)


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
    incomeNetMonthly: Optional[float] = Field(None, ge=0, le=10_000_000)
    incomeGrossYearly: Optional[float] = Field(None, ge=0, le=10_000_000)
    savingsMonthly: Optional[float] = Field(None, ge=0, le=10_000_000)
    totalSavings: Optional[float] = Field(None, ge=0, le=10_000_000)
    lppInsuredSalary: Optional[float] = Field(None, ge=0, le=10_000_000)
    hasDebt: bool = False
    goal: Goal = Goal.other
    factfindCompletionIndex: float = 0.0

    # ⭐ Nouveaux champs pour statut d'emploi et 2e pilier
    employmentStatus: Optional[str] = None
    has2ndPillar: Optional[bool] = None
    legalForm: Optional[str] = None
    selfEmployedNetIncome: Optional[float] = Field(None, ge=0, le=10_000_000)
    hasVoluntaryLpp: Optional[bool] = None
    primaryActivity: Optional[str] = None

    # ⭐ Genre (AVS21 transitional reference ages — LAVS art. 21 al. 1)
    gender: Optional[str] = None  # 'M', 'F', or None (unknown)

    # ⭐ Nouveaux champs pour AVS
    hasAvsGaps: Optional[bool] = None
    avsContributionYears: Optional[int] = Field(None, ge=0, le=44)
    spouseAvsContributionYears: Optional[int] = Field(None, ge=0, le=44)

    # ⭐ Nouveaux champs pour modèle fiscal MVP (Chantier 1)
    commune: Optional[str] = None  # NPA ou nom commune → multiplicateur précis
    isChurchMember: bool = False  # Impôt ecclésiastique
    pillar3aAnnual: Optional[float] = Field(None, ge=0, le=36_288)  # Max indépendant sans LPP
    wealthEstimate: Optional[float] = Field(None, ge=0, le=1_000_000_000)

    # ⭐ Retraite flexible (LAVS art. 40, LPP art. 13)
    targetRetirementAge: Optional[int] = Field(
        None, ge=58, le=70,
        description="Age cible de retraite (defaut: age legal)",
    )

    # ⭐ Voice cursor (Phase 02-03 / VOICE-09/10/13 — see voice_cursor.json contract)
    # voiceCursorPreference: user-chosen tone, default 'direct' (per ROADMAP).
    # n5IssuedThisWeek: rolling 7-day N5 emission counter (Phase 11 server-authoritative).
    # fragileModeEnteredAt: nullable timestamp; non-null = fragile mode active (capped at N3).
    voiceCursorPreference: VoicePreference = Field(
        default=VoicePreference.direct,
        description="User tone preference (soft/direct/unfiltered). Default: direct.",
    )
    n5IssuedThisWeek: int = Field(
        default=0, ge=0,
        description="Rolling 7-day N5 emission counter (Phase 11 cap enforcement).",
    )
    fragileModeEnteredAt: Optional[datetime] = Field(
        default=None,
        description="Timestamp when fragile mode was entered. Null = not active.",
    )

    @model_validator(mode='after')
    def validate_employment_lpp_consistency(self):
        """Warn if employee above LPP threshold claims no 2nd pillar.

        LPP art. 7: salaried workers earning > 22'680 CHF/year are
        mandatorily insured. We log a warning but don't reject — the
        user may not know their LPP status.
        """
        if (
            self.employmentStatus in ("salarie", "employee")
            and self.incomeGrossYearly is not None
            and self.incomeGrossYearly > 22_680
            and self.has2ndPillar is False
        ):
            logger.warning(
                "Employment/LPP inconsistency: salaried with gross %.0f > 22'680 "
                "but has2ndPillar=False. LPP affiliation is mandatory (LPP art. 7).",
                self.incomeGrossYearly,
            )
        return self


class ProfileCreate(ProfileBase):
    pass


class ProfileUpdate(BaseModel):
    birthYear: Optional[int] = Field(None, ge=1900, le=2025)  # FIX-069
    dateOfBirth: Optional[str] = Field(
        None,
        pattern=r"^\d{4}-\d{2}-\d{2}$",
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
    selfEmployedNetIncome: Optional[float] = Field(None, ge=0, le=10_000_000)
    hasVoluntaryLpp: Optional[bool] = None
    primaryActivity: Optional[str] = None
    hasAvsGaps: Optional[bool] = None
    avsContributionYears: Optional[int] = Field(None, ge=0, le=44)
    spouseAvsContributionYears: Optional[int] = Field(None, ge=0, le=44)
    # FIX-114: Couple financial fields for household calculations
    spouseSalaryGrossAnnual: Optional[float] = Field(None, ge=0)
    spouseEmploymentStatus: Optional[str] = None
    householdGrossIncome: Optional[float] = Field(None, ge=0)
    commune: Optional[str] = None
    isChurchMember: Optional[bool] = None
    pillar3aAnnual: Optional[float] = Field(None, ge=0, le=36_288)
    wealthEstimate: Optional[float] = Field(None, ge=0, le=1_000_000_000)
    targetRetirementAge: Optional[int] = Field(
        None, ge=58, le=70,
        description="Age cible de retraite (defaut: age legal)",
    )
    # ⭐ Voice cursor (Phase 02-03)
    voiceCursorPreference: Optional[VoicePreference] = None
    n5IssuedThisWeek: Optional[int] = Field(None, ge=0)
    fragileModeEnteredAt: Optional[datetime] = None


class Profile(ProfileBase):
    id: UUID4
    createdAt: datetime

    model_config = ConfigDict(from_attributes=True)
