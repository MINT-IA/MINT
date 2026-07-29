"""Phase mint-calc-engine-v1 — D-CE-15 typed lucidity payloads.

L1-L4 Pydantic v2 discriminated union. `extra="forbid"` kills paraphrase
ranking creep at type level. The field `recommended_option` (and 5
paraphrase variants) cannot exist on L2/L3 payloads — schema impossibility.

See `app.models.lucidity._payload` module docstring for full rationale.
"""
from app.models.lucidity._payload import (
    L1ChiffrePayload,
    L2ComparePayload,
    L3EclairePayload,
    L4InvariantPayload,
    LucidityLevel,
    LucidityPayload,
)
from app.models.lucidity.money_truth_receipt import (
    FIRST_JOB_NET_SALARY_CLAIM_ID,
    MoneyTruthRange,
    MoneyTruthReceipt,
    MoneyTruthSource,
)

__all__ = [
    "L1ChiffrePayload",
    "L2ComparePayload",
    "L3EclairePayload",
    "L4InvariantPayload",
    "LucidityLevel",
    "LucidityPayload",
    "FIRST_JOB_NET_SALARY_CLAIM_ID",
    "MoneyTruthReceipt",
    "MoneyTruthRange",
    "MoneyTruthSource",
]
