import logging
from pydantic import BaseModel, Field, ConfigDict, model_validator
from enum import Enum
from typing import Optional
from datetime import datetime

from app.schemas.voice_cursor import VoicePreference

logger = logging.getLogger(__name__)
_CURRENT_YEAR = datetime.now().year
MIN_BIRTH_YEAR = 1900
MAX_BIRTH_YEAR = _CURRENT_YEAR + 1
MAX_PROFILE_MONEY = 10_000_000
MAX_PROFILE_DEBT = 1_000_000_000
MAX_AVS_CONTRIBUTION_YEARS = 44
MAX_PILLAR3A_ANNUAL = 36_288
_SPOUSE_FIELDS = (
    "spouseBirthYear",
    "spouseIncomeNetMonthly",
    "spouseAvsContributionYears",
)


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
    birthYear: Optional[int] = Field(None, ge=MIN_BIRTH_YEAR, le=MAX_BIRTH_YEAR)
    dateOfBirth: Optional[str] = None  # ISO 8601 date string (e.g. "1981-06-15")
    canton: Optional[str] = None
    householdType: HouseholdType
    incomeNetMonthly: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    incomeGrossYearly: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    savingsMonthly: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    totalSavings: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    totalDebt: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_DEBT)
    lppInsuredSalary: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    avoirLpp: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    lppBuybackMax: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    pillar3aBalance: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    hasDebt: bool = False
    goal: Goal = Goal.other
    factfindCompletionIndex: float = 0.0

    # ⭐ Nouveaux champs pour statut d'emploi et 2e pilier
    employmentStatus: Optional[str] = None
    has2ndPillar: Optional[bool] = None
    legalForm: Optional[str] = None
    selfEmployedNetIncome: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    hasVoluntaryLpp: Optional[bool] = None
    primaryActivity: Optional[str] = None

    # ⭐ Genre (AVS21 transitional reference ages — LAVS art. 21 al. 1)
    gender: Optional[str] = None  # 'M', 'F', or None (unknown)

    # ⭐ FATCA / archetype signals (sub-phase 01.5 R6 — Pydantic gap closure)
    # Tri-state semantics (R4 from 01.5-REVIEWS.md):
    #   - None  = signal not collected yet (do NOT coerce to False)
    #   - True  = user self-declared US tax person (FATCA subject → hard gate)
    #   - False = user self-declared NOT US tax person
    # Nationality uses ISO 3166-1 alpha-2 (e.g. "CH", "US", "FR"); free-form string
    # to remain consistent with existing camelCase Optional[str] convention.
    nationality: Optional[str] = Field(
        None,
        max_length=8,
        description="ISO 3166-1 alpha-2 country code (e.g. 'CH', 'US'). Optional.",
    )
    usTaxPerson: Optional[bool] = Field(
        None,
        description=(
            "FATCA self-declaration tri-state. None = not asked yet, "
            "True = US person (gate to /waitlist), False = explicitly NOT US person."
        ),
    )

    # ⭐ Nouveaux champs pour AVS
    hasAvsGaps: Optional[bool] = None
    avsContributionYears: Optional[int] = Field(None, ge=0, le=MAX_AVS_CONTRIBUTION_YEARS)
    spouseBirthYear: Optional[int] = Field(None, ge=MIN_BIRTH_YEAR, le=MAX_BIRTH_YEAR)
    spouseIncomeNetMonthly: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    spouseAvsContributionYears: Optional[int] = Field(None, ge=0, le=MAX_AVS_CONTRIBUTION_YEARS)

    # ⭐ Nouveaux champs pour modèle fiscal MVP (Chantier 1)
    commune: Optional[str] = None  # NPA ou nom commune → multiplicateur précis
    isChurchMember: bool = False  # Impôt ecclésiastique
    pillar3aAnnual: Optional[float] = Field(None, ge=0, le=MAX_PILLAR3A_ANNUAL)  # Max indépendant sans LPP
    wealthEstimate: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_DEBT)

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
    # ⭐ Phase 11 (VOICE-09/10) — rolling 30-day gravity event log.
    # Each entry: {"ts": ISO8601, "gravity": "G1"|"G2"|"G3"}.
    # Used by fragility_detector_service to detect ≥3 G2/G3 in a 14-day window.
    # No PII: only the gravity label + timestamp are persisted.
    recentGravityEvents: list[dict] = Field(
        default_factory=list,
        description="Rolling 30-day list of gravity events (Phase 11 fragility detector).",
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

    @model_validator(mode='after')
    def validate_single_household_has_no_spouse_fields(self):
        if self.householdType == HouseholdType.single and any(
            getattr(self, key) is not None for key in _SPOUSE_FIELDS
        ):
            raise ValueError("single household cannot include spouse fields")
        return self


class ProfileCreate(ProfileBase):
    pass


class ProfileUpdate(BaseModel):
    birthYear: Optional[int] = Field(None, ge=MIN_BIRTH_YEAR, le=MAX_BIRTH_YEAR)
    dateOfBirth: Optional[str] = Field(
        None,
        pattern=r"^\d{4}-\d{2}-\d{2}$",
        description="Date de naissance ISO 8601 (ex: 1981-06-15)",
    )
    canton: Optional[str] = None
    householdType: Optional[HouseholdType] = None
    incomeNetMonthly: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    incomeGrossYearly: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    savingsMonthly: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    totalSavings: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    totalDebt: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_DEBT)
    lppInsuredSalary: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    avoirLpp: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    lppBuybackMax: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    pillar3aBalance: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
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
    selfEmployedNetIncome: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    hasVoluntaryLpp: Optional[bool] = None
    primaryActivity: Optional[str] = None
    hasAvsGaps: Optional[bool] = None
    avsContributionYears: Optional[int] = Field(None, ge=0, le=MAX_AVS_CONTRIBUTION_YEARS)
    spouseBirthYear: Optional[int] = Field(None, ge=MIN_BIRTH_YEAR, le=MAX_BIRTH_YEAR)
    spouseIncomeNetMonthly: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    spouseAvsContributionYears: Optional[int] = Field(None, ge=0, le=MAX_AVS_CONTRIBUTION_YEARS)
    # FIX-114: Couple financial fields for household calculations
    spouseSalaryGrossAnnual: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    spouseEmploymentStatus: Optional[str] = None
    householdGrossIncome: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_MONEY)
    commune: Optional[str] = None
    isChurchMember: Optional[bool] = None
    pillar3aAnnual: Optional[float] = Field(None, ge=0, le=MAX_PILLAR3A_ANNUAL)
    wealthEstimate: Optional[float] = Field(None, ge=0, le=MAX_PROFILE_DEBT)
    targetRetirementAge: Optional[int] = Field(
        None, ge=58, le=70,
        description="Age cible de retraite (defaut: age legal)",
    )
    # ⭐ Voice cursor (Phase 02-03)
    voiceCursorPreference: Optional[VoicePreference] = None
    n5IssuedThisWeek: Optional[int] = Field(None, ge=0)
    fragileModeEnteredAt: Optional[datetime] = None
    recentGravityEvents: Optional[list[dict]] = None

    # ⭐ FATCA / archetype signals (sub-phase 01.5 R6 — Pydantic gap closure).
    # Mirror of ProfileBase fields with identical tri-state semantics (R4).
    # ProfileUpdate is a BaseModel (NOT a ProfileBase subclass), so the declaration
    # must be explicit. None = not asked yet; True = US person; False = explicit non-US.
    nationality: Optional[str] = Field(
        None,
        max_length=8,
        description="ISO 3166-1 alpha-2 country code (e.g. 'CH', 'US'). Optional.",
    )
    usTaxPerson: Optional[bool] = Field(
        None,
        description=(
            "FATCA self-declaration tri-state. None = not asked yet, "
            "True = US person (gate to /waitlist), False = explicitly NOT US person."
        ),
    )


class Profile(ProfileBase):
    id: str  # String in DB, not necessarily UUID4 (legacy/anonymous profiles)
    createdAt: datetime

    model_config = ConfigDict(from_attributes=True)
