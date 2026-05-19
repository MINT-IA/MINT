"""Pydantic v2 wire-shape models for `fact_event.value_enc` + `fact_event.confidence`.

Phase mint-data-architecture-v1-02 Plan 02-02 W1.

D-26 — EncryptedValue : typed JSONB wire shape for `fact_event.value_enc`.
  Locked fields : ct, iv, tag (reserved, Literal[''] per iter-2 C5),
  alg=Literal['AES-256-GCM'], dek_id, enc_v=1.
  `extra='forbid'` blocks silent wire-shape drift.

D-29 — EnhancedConfidence : 4-axis (c/a/f/u) + score + enrichmentPrompts
  for `fact_event.confidence`. iter-2 B11 cap: max 5 prompts x 200 chars
  each (TOAST-row-size discipline so a single fact_event row stays
  in-line and avoids pg_largeobject thrash).
"""
from __future__ import annotations

from typing import List, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class EncryptedValue(BaseModel):
    """D-26 wire shape for `fact_event.value_enc` JSONB column.

    AESGCM appends auth tag to ct (see services/backend/app/services/
    encryption/envelope.py line 52 — `aes.encrypt(nonce, plaintext, aad)`
    returns ciphertext||tag concatenated). The `tag` field below is
    reserved + typed as Literal[''] per iter-2 C5 to surface the fact
    that no separate tag string is shipped in the JSONB.
    """

    model_config = ConfigDict(extra="forbid")

    ct: str = Field(
        ..., description="base64 ciphertext (AESGCM output: ciphertext || auth-tag)"
    )
    iv: str = Field(
        ..., description="base64 96-bit nonce (NONCE_SIZE_BYTES from envelope.py)"
    )
    tag: Literal[""] = Field(
        default="",
        description="Reserved; AESGCM appends auth tag to ct. iter-2 C5: typed as "
        "Literal[''] to surface ambiguity to readers.",
    )
    alg: Literal["AES-256-GCM"] = Field(
        default="AES-256-GCM",
        description="Hard-coded; envelope.py uses AESGCM. Literal blocks alg drift.",
    )
    dek_id: str = Field(
        ..., description="Logical key ref, e.g. 'mint-master-v1' per D-02."
    )
    enc_v: int = Field(
        default=1, description="Envelope-format version for future DEK rotation."
    )


class EnhancedConfidence(BaseModel):
    """D-29 + iter-2 B11 confidence shape for `fact_event.confidence` JSONB.

    4-axis: c=completeness, a=accuracy, f=freshness, u=understanding,
    score=composite, enrichmentPrompts=questions to ask user to raise
    weak axes. iter-2 B11: enrichmentPrompts capped at 5 entries, each
    at most 200 chars (TOAST-row-size discipline).
    """

    model_config = ConfigDict(extra="forbid")

    c: float = Field(..., ge=0.0, le=1.0, description="completeness axis")
    a: float = Field(..., ge=0.0, le=1.0, description="accuracy axis")
    f: float = Field(..., ge=0.0, le=1.0, description="freshness axis")
    u: float = Field(..., ge=0.0, le=1.0, description="understanding axis")
    score: float = Field(..., ge=0.0, le=1.0, description="composite confidence score")
    enrichmentPrompts: List[str] = Field(
        default_factory=list,
        max_length=5,
        description="iter-2 B11: max 5 prompts of <= 200 chars each.",
    )

    @field_validator("enrichmentPrompts")
    @classmethod
    def _cap_prompt_length(cls, v: List[str]) -> List[str]:
        for prompt in v:
            if len(prompt) > 200:
                raise ValueError(
                    f"enrichmentPrompt too long ({len(prompt)} chars > 200): "
                    f"{prompt[:50]}... (iter-2 B11 cap)"
                )
        return v


__all__ = ["EncryptedValue", "EnhancedConfidence"]
