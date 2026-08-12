"""Wave 1a D-03 — get_cross_pillar_analysis response model.

camelCase aliases via pydantic.alias_generators.to_camel — matches the
backend AGENT contract (CLAUDE.md §1) and the sibling plan-01
BudgetSnapshotResponse / plan-02 RetirementProjectionResponse pattern.

Note on `annual_3a_contribution` -> `annual3aContribution` alias: the
pydantic.alias_generators.to_camel function preserves digits adjacent to
letters, so `annual_3a_contribution` correctly maps to
`annual3aContribution` (verified in CONTEXT D-02 must_haves and plan-01's
identical pattern). If this ever changes, override with an explicit
`Field(..., alias="annual3aContribution")`.
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class CrossPillarAnalysisResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        frozen=True,
    )

    annual_3a_contribution: Decimal
    # None = plafond 3a inconnu (grand 3a sans revenu déterminant) — jamais un
    # zéro fabriqué (revue Codex G1). Le coach affiche alors la règle.
    three_a_ceiling: Optional[Decimal]
    three_a_remaining: Optional[Decimal]
    lpp_buyback_max: Decimal
    lpp_capital: Decimal
    tax_saving_potential: Decimal
    inputs_hash: str = Field(..., min_length=64, max_length=64)
    computed_at: datetime
