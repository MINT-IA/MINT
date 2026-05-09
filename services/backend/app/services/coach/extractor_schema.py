"""Pydantic v2 schema for the LLM extractor (Phase 91 Wave 1).

Source of truth for `key` whitelist: `coach_chat._SAVE_FACT_ALLOWED_KEYS`
(`services/backend/app/api/v1/endpoints/coach_chat.py:1081-1103`).

Range guards (e.g. birthYear bounds, canton enum) live in
`coach_chat._coerce_fact_value` and are applied at persistence time
in Wave 2, NOT at schema-validation time. This module only validates
the structural shape: key whitelist, confidence enum, source_quote
length, intent enum, list bounds.

Wave 1 status: defined + unit-tested. NOT YET imported by coach_chat
(Wave 2 wires it behind `COACH_DUAL_LLM_ENABLED`).

See `.planning/phases/91-mvp-extractor-v2/91-01-PLAN.md` Task 1.1
and `.planning/phases/91-mvp-extractor-v2/RESEARCH.md` §3.
"""
from __future__ import annotations

from typing import Literal, Union

from pydantic import BaseModel, Field, field_validator

# Mirror of `coach_chat._SAVE_FACT_ALLOWED_KEYS` (lines 1081-1103).
# Single source of truth invariant — pinned by
# `tests/test_extractor_schema.py::test_canonical_keys_mirror_coach_chat`.
# DO NOT paraphrase, drop, or reorder keys without updating coach_chat.py
# AND the invariant test in the same commit.
_ALLOWED_FACT_KEYS = Literal[
    # Identity / location
    "birthYear",
    "dateOfBirth",
    "canton",
    "commune",
    "householdType",
    "employmentStatus",
    "has2ndPillar",
    "goal",
    "targetRetirementAge",
    "gender",
    # Income
    "incomeNetMonthly",
    "incomeGrossMonthly",
    "incomeNetYearly",
    "incomeGrossYearly",
    "selfEmployedNetIncome",
    "employmentRate",
    "annualBonus",
    # LPP
    "lppInsuredSalary",
    "avoirLpp",
    "avoirLppObligatoire",
    "avoirLppSurobligatoire",
    "lppBuybackMax",
    "hasVoluntaryLpp",
    # 3a
    "pillar3aAnnual",
    "pillar3aBalance",
    # Savings / wealth / debt
    "savingsMonthly",
    "totalSavings",
    "wealthEstimate",
    "hasDebt",
    "totalDebt",
    # Spouse
    "spouseBirthYear",
    "spouseIncomeNetMonthly",
    "spouseAvsContributionYears",
    # AVS
    "hasAvsGaps",
    "avsContributionYears",
]

# Intent enum — RESEARCH §3 lines 243 + CONTEXT D-03.
# Replaces keyword-based regex `_classify_user_intent` in Wave 2.
_ALLOWED_INTENTS = Literal[
    "debt",
    "housing",
    "family",
    "career",
    "retirement",
    "taxes",
]


class ExtractedFact(BaseModel):
    """A single fact extracted by the LLM extractor.

    Schema-level guards:
      - `key` MUST be in `_SAVE_FACT_ALLOWED_KEYS` (Literal-typed).
      - `confidence` MUST be "high" or "medium" — "low" is forbidden
        (RESEARCH §3 « N'émets jamais low »).
      - `source_quote` MUST be a non-blank string ≤ 80 chars
        (RESEARCH §3 « max 80 chars »).
      - Substring validation against the actual user_message is
        applied at the caller layer (`llm_extractor._drop_hallucinated_quotes`),
        NOT here — schema doesn't see the user_message.

    Range guards on `value` (e.g. `birthYear ∈ [1900, currentYear+1]`)
    are applied at persistence time via `_coerce_fact_value`, NOT here.
    """

    model_config = {"extra": "forbid", "frozen": True}

    key: _ALLOWED_FACT_KEYS
    value: Union[int, float, str, bool]
    confidence: Literal["high", "medium"]
    source_quote: str = Field(..., min_length=1, max_length=80)

    @field_validator("source_quote")
    @classmethod
    def _quote_not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("source_quote must be non-blank")
        return v


class ExtractorOutput(BaseModel):
    """Top-level extractor LLM response payload.

    Defaults to empty lists so a failed extraction (or « 0-fact » turn
    like « merci ! ») is representable as `ExtractorOutput()` with no
    behavior change for downstream consumers.
    """

    model_config = {"extra": "forbid"}

    facts: list[ExtractedFact] = Field(default_factory=list, max_length=12)
    intents: list[_ALLOWED_INTENTS] = Field(default_factory=list, max_length=4)
