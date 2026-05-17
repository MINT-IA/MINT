"""Wave 1c-A3 (D-A3-01) — shared response envelope for coach internal tools.

Discriminated-union Pydantic v2 RootModel keyed on `status`. Tool dispatchers
in `app.api.v1.endpoints.coach_chat._execute_internal_tool` return a JSON-encoded
instance of this model (via `.model_dump_json(by_alias=True)`) as the
`tool_result.content` payload.

Rationale (see `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-
CONTEXT.md` §D-A3-01): when a chip-emitter cannot compute because the user
profile lacks required fields, returning a structured `status="incomplete"`
payload (NOT a typed exception, NOT `is_error: true`) preserves coaching
register and lets the narrator ask the user explicitly. Data gaps are not
tool failures.

LSFin compliance (CLAUDE.md §1 + §5 NEVER #5): any default `hint_fr` text
embedded in fixtures / docstrings stays clear of the project's LSFin
banned-term list (see CLAUDE.md §1 #1). 100% French accents.
"""
from __future__ import annotations

from typing import Annotated, Any, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, RootModel, field_validator
from pydantic.alias_generators import to_camel


_MAX_MISSING_FIELDS = 3   # D-A3-01 conversational handshake cap


class _Base(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        frozen=True,
    )


class CoachToolOk(_Base):
    """Happy path. `data` carries the existing per-tool payload unchanged."""

    status: Literal["ok"] = "ok"
    data: dict[str, Any]


class CoachToolIncomplete(_Base):
    """Profile lacks required inputs. Narrator must ask the user."""

    status: Literal["incomplete"] = "incomplete"
    missing_fields: list[str] = Field(..., min_length=1)
    hint_fr: str = Field(..., min_length=10)

    @field_validator("missing_fields")
    @classmethod
    def _cap_missing_fields(cls, v: list[str]) -> list[str]:
        if len(v) > _MAX_MISSING_FIELDS:
            raise ValueError(
                f"missing_fields capped at {_MAX_MISSING_FIELDS} per "
                "conversational-handshake decision D-A3-01"
            )
        return v


class CoachToolPolicyBlocked(_Base):
    """Future LSFin/FINMA gate. Defined now to avoid a second migration."""

    status: Literal["policy_blocked"] = "policy_blocked"
    reason_code: str
    message_fr: str


CoachToolResponse = RootModel[
    Annotated[
        Union[CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked],
        Field(discriminator="status"),
    ]
]


# ─────── Parallel Change V2 (Phase mint-calc-engine-v1 W2-04, D-CE-19) ───────
# Fowler Parallel Change pattern. V2 ships ALONGSIDE V1 — V1 is NOT modified.
# V1 retirement happens in a SEPARATE follow-up PR (Plan 11 or post-phase).
# Migration budget: ≤200 LOC ≤1 day per panel proof (CONTEXT D-CE-19).
#
# Concern B (latency_tier field): Flutter routes V2 responses to the right
# rendering surface — chip (L1 < 500 ms) vs narrative loader (L2/L3, 2-8 s).
# The field is SERVER-EMITTED, never client-input (threat T-mint-calc-10-01).
# ─────────────────────────────────────────────────────────────────────


LatencyTier = Literal["L1", "L2", "L3"]
"""L1 = chip surface (atomic chiffrage, sub-500ms cache hit).
L2 = narrative loader medium-budget (2-4s combinatorial arbitrage).
L3 = narrative loader long-budget (4-8s multi-option scenarios)."""


_INPUTS_PROVENANCE_LITERALS = Literal["user_input", "default", "derived"]
"""Plan 17 W4 (D-CE-17 composite scorecard) — per-field provenance audit trail.

Values :
  - ``"user_input"`` — field was in ``body.model_fields_set`` (client supplied
    it explicitly, even if None).
  - ``"default"``    — field was filled from the user's profile via the
    ``from_profile`` marker (server-side fallback from profile).
  - ``"derived"``    — field fell through to the Pydantic default (typically
    None or a schema-defined fallback). No profile data, no client input.
"""


class CoachToolOkV2(_Base):
    """V2 happy path — adds latency_tier server-side hint for Flutter routing.

    Plan 17 W4 (D-CE-17) adds the optional ``inputs_provenance`` audit field
    for per-field « real profile / default / derived » signal. Field is
    OPTIONAL with default ``{}`` for backwards-compatibility with Plan 10
    Wave-1a callers that don't emit provenance yet.
    """

    status: Literal["ok"] = "ok"
    data: dict[str, Any]
    latency_tier: LatencyTier = Field(
        ...,
        description=(
            "L1=chip <500ms, L2-L3=narrative loader 2-8s. Server-emitted, "
            "never client-input."
        ),
    )
    inputs_provenance: dict[str, _INPUTS_PROVENANCE_LITERALS] = Field(
        default_factory=dict,
        description=(
            "D-CE-17 audit trail. Per-field origin: user_input (body) / "
            "default (profile-driven server-side fallback) / derived "
            "(Pydantic default). Optional, defaults to empty dict for "
            "backwards-compatibility with Plan 10 Wave-1a callers."
        ),
    )


class CoachToolIncompleteV2(_Base):
    """V2 missing-fields handshake. Defaults latency_tier=L1 (sub-500ms 422)."""

    status: Literal["incomplete"] = "incomplete"
    missing_fields: list[str] = Field(..., min_length=1)
    hint_fr: str = Field(..., min_length=10)
    latency_tier: LatencyTier = Field(
        default="L1",
        description="Incomplete always L1 (sub-500ms 422 envelope).",
    )

    @field_validator("missing_fields")
    @classmethod
    def _cap_missing_fields_v2(cls, v: list[str]) -> list[str]:
        if len(v) > _MAX_MISSING_FIELDS:
            raise ValueError(
                f"missing_fields capped at {_MAX_MISSING_FIELDS} per "
                "conversational-handshake decision D-A3-01"
            )
        return v


class CoachToolPolicyBlockedV2(_Base):
    """V2 LSFin/FINMA gate envelope. Defaults latency_tier=L1."""

    status: Literal["policy_blocked"] = "policy_blocked"
    reason_code: str
    message_fr: str
    latency_tier: LatencyTier = Field(default="L1")


CoachToolResponseV2 = RootModel[
    Annotated[
        Union[CoachToolOkV2, CoachToolIncompleteV2, CoachToolPolicyBlockedV2],
        Field(discriminator="status"),
    ]
]
