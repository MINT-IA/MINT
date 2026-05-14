"""Wave 1a D-03 — ``get_couple_optimization`` Pydantic v2 response model.

Nested structure mirrors Dart ``CoupleOptimizationResult``. camelCase
aliases via ``to_camel`` (CLAUDE.md §1 backend AGENT contract).

Units:
  ``saving_delta`` / ``monthly_reduction`` / ``annual_delta`` /
  ``*_rente*`` — ``Decimal`` CHF.
  ``cap_applied`` / ``has_penalty`` — bool.
  ``winner`` — str (snake_case ``"main_user" | "conjoint" | "no_preference"``;
  see ``CoupleWinner`` enum decision in
  ``services/backend/app/services/couple_optimizer/couple_optimizer.py``).
  ``inputs_hash`` — 64-char lowercase hex SHA-256 of canonical-JSON profile
  slice (Phase 95 DAG-INVALIDATION pattern).
"""

from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class LppBuybackOrderResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, frozen=True
    )
    winner: str
    saving_delta: Decimal
    reason: str
    trade_off: str


class Pillar3aOrderResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, frozen=True
    )
    winner: str
    saving_delta: Decimal
    reason: str
    trade_off: str


class AvsCapResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, frozen=True
    )
    cap_applied: bool
    monthly_reduction: Decimal
    user_rente_before_cap: Decimal
    conjoint_rente_before_cap: Decimal
    total_after_cap: Decimal


class MarriagePenaltyResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, frozen=True
    )
    has_penalty: bool
    annual_delta: Decimal
    trade_off: str


class CoupleOptimizationResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, frozen=True
    )
    lpp_buyback: Optional[LppBuybackOrderResponse] = None
    pillar_3a: Optional[Pillar3aOrderResponse] = None
    avs_cap: Optional[AvsCapResponse] = None
    marriage_penalty: Optional[MarriagePenaltyResponse] = None
    inputs_hash: str = Field(..., min_length=64, max_length=64)
    computed_at: datetime
