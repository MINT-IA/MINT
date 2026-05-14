"""Wave 1a D-03 — get_budget_status response model.

camelCase aliases via pydantic.alias_generators.to_camel match the
backend AGENT contract (CLAUDE.md §1).
"""
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class BudgetSnapshotResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        frozen=True,
    )

    monthly_income: Decimal
    monthly_expenses: Decimal
    monthly_surplus: Decimal
    months_liquidity: float
    inputs_hash: str = Field(..., min_length=64, max_length=64)
    computed_at: datetime
