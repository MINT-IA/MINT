"""Phase 96 D-12 — SerializedCardContext schema.

Carries financial_core values + grounding key candidates from a UI card
into the narrator's system prompt. NO PII : no IBAN, no name, no NPA,
no employer (enforced by `tools/checks/pii_fixture_scan.py` + the
`extra="forbid"` config + the `computed_facts` scalar validator below).

Per CONTEXT D-12 :
- Pydantic v2 `frozen=True, extra="forbid"` (precedent
  `services/backend/app/services/coach/grounding_pack.py:51`).
- camelCase aliases via `to_camel` (precedent
  `services/backend/app/schemas/coach_chat.py`).
- `computed_facts` values are scalar `Decimal | int | str` ONLY. Nested
  dicts, lists, bool, and None are forbidden by the validator — this
  forces the narrator prompt to receive flat key/value pairs only.

CLAUDE.md rule 3 — card_type accepts the full 18-life-event taxonomy
(pillar_3a, lpp_retirement, mortgage, family_planning, career_change,
debt_management, tax_optimization, education, divorce, health, etc.).
NOT a retirement-only enum. The narrator framing remains generic across
the 18 life events.
"""
from __future__ import annotations

from decimal import Decimal
from typing import Any, Dict, List, Optional, Union

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel


# Allowed value types for `computed_facts` dict — scalar only.
# bool is NOT included because bool is a subclass of int in Python ; the
# validator below rejects it explicitly to avoid silent coercion.
_ALLOWED_FACT_TYPES = (Decimal, int, str)


class SerializedCardContext(BaseModel):
    """Card snapshot passed to the narrator for source-card context injection.

    Frozen, extra-forbid, scalar-only `computed_facts`. The full
    18-life-event taxonomy is accepted via the free-form `card_type` /
    `life_event` strings ; max_length caps prevent abuse.
    """

    model_config = ConfigDict(
        frozen=True,
        extra="forbid",
        populate_by_name=True,
        alias_generator=to_camel,
    )

    card_id: str = Field(..., min_length=1, max_length=128)
    card_type: str = Field(..., min_length=1, max_length=64)
    computed_facts: Dict[str, Union[Decimal, int, str]] = Field(
        default_factory=dict
    )
    grounding_keys: List[str] = Field(default_factory=list)
    life_event: Optional[str] = Field(default=None, max_length=64)
    canton: Optional[str] = Field(default=None, min_length=2, max_length=2)
    archetype: Optional[str] = Field(default=None, max_length=32)

    @field_validator("computed_facts", mode="before")
    @classmethod
    def _validate_facts_scalar_only(
        cls, v: Any
    ) -> Any:
        """Reject nested dicts / lists / bool / None values.

        `mode="before"` runs the validator against the RAW input dict
        before Pydantic's Union coercion. This matters because :
        - bool → int coercion would silently flip True to 1.
        - None → str coercion would yield '' under some Union shapes.
        - dict / list values would also be silently dropped by some
          Union arms.

        The validator forbids these ambiguous types up-front, keeping the
        narrator prompt source surface to flat scalar pairs.
        """
        if not isinstance(v, dict):
            return v  # Let Pydantic produce a clean "not a dict" error.
        for key, value in v.items():
            # bool is a subclass of int — reject before isinstance(int).
            if isinstance(value, bool):
                raise ValueError(
                    f"computed_facts[{key!r}]: bool not allowed (must be Decimal|int|str)"
                )
            if value is None:
                raise ValueError(
                    f"computed_facts[{key!r}]: None not allowed (must be Decimal|int|str)"
                )
            if not isinstance(value, _ALLOWED_FACT_TYPES):
                raise ValueError(
                    f"computed_facts[{key!r}]: must be Decimal|int|str, "
                    f"got {type(value).__name__}"
                )
        return v
