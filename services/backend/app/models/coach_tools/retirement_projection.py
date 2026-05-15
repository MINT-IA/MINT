"""Wave 1a D-03 — get_retirement_projection response model.

camelCase aliases via pydantic.alias_generators.to_camel match the
backend AGENT contract (CLAUDE.md §1).

Units (panel obs-a5f5f19baeb3119b C4):
  replacement_ratio: float in [0.0, 1.0] — RATIO not percent. The
    orchestrator divides RetirementBudget.taux_remplacement (PERCENT 0-100)
    by 100 before populating this field.
  avs_rente: Decimal monthly CHF (NOT annual).
  lpp_capital: Optional[Decimal] CHF, net of capital-withdrawal tax. None
    when the profile has no LPP avoir (H3 nullable contract).
  monthly_retirement_income / monthly_gap / current_monthly_income: Decimal
    CHF/month.
  inputs_hash: 64-char lowercase hex SHA-256 of canonical-JSON profile slice
    (Phase 95 DAG-INVALIDATION pattern).
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class RetirementProjectionResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        frozen=True,
    )

    replacement_ratio: float
    avs_rente: Decimal
    lpp_capital: Optional[Decimal] = None
    monthly_retirement_income: Decimal
    monthly_gap: Decimal
    current_monthly_income: Decimal
    inputs_hash: str = Field(..., min_length=64, max_length=64)
    computed_at: datetime
