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
