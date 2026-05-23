"""Pydantic v2 schemas for the Waitlist endpoint — sub-phase 01.5.

POST /api/v1/waitlist — captures email + consent metadata when the
mobile WaitlistScreen renders because the user's archetype is NOT in
the calibrated set.

API convention : camelCase via `alias_generator=to_camel` (matches
`anonymous_chat.py` schema pattern).

Single-source-of-truth for the allowed values : the Literal types here
mirror `app/models/waitlist_entry.py::_ALLOWED_*` tuples. Drift between
the two is caught by the test suite (test_waitlist.py asserts equality).

Compliance :
- LSFin art. 8(3) safe harbor — withhold service when suitability fails
- nLPD art. 6 — data minimization (email + archetype + locale only)
- UCA art. 3(1)(o) — explicit prior consent for commercial email
  (consentGiven=true required, validator rejects false)
"""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from pydantic.alias_generators import to_camel


# Mirror of `app/models/waitlist_entry.py::_ALLOWED_*`. See test_waitlist.py
# for the parity assertion.
ArchetypeSlug = Literal[
    "expat_us",
    "expat_eu",
    "cross_border",
    "independent_no_lpp",
    "couple_one_works",
    "senior_post_64",
    "unknown",
    "other",
]

LocaleSlug = Literal["fr", "en", "de", "es", "it", "pt"]

SourceSlug = Literal["onboarding_hard_gate", "settings", "other"]


class WaitlistRequest(BaseModel):
    """Mobile → backend payload for the waitlist opt-in.

    `consentGiven` MUST be true. UCA art. 3(1)(o) requires prior consent
    for commercial email — a false value is a contract violation between
    the mobile client and the backend, not a recoverable input error.
    """

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    email: EmailStr = Field(
        ...,
        description="User opt-in email. Validated with Pydantic EmailStr.",
    )
    archetype: ArchetypeSlug = Field(
        ...,
        description="Detected archetype that triggered the hard gate.",
    )
    locale: LocaleSlug = Field(
        ...,
        description="Locale the screen was rendered in (one of the 6 ARB locales).",
    )
    source: SourceSlug = Field(
        default="other",
        description="Where the gate fired from (analytics + onboarding tuning).",
    )
    consent_given: bool = Field(
        ...,
        description=(
            "Explicit opt-in checkbox state. UCA art. 3(1)(o) requires "
            "prior consent for commercial email."
        ),
    )

    @field_validator("consent_given")
    @classmethod
    def _consent_must_be_true(cls, value: bool) -> bool:
        if value is not True:
            raise ValueError(
                "consentGiven must be true. UCA art. 3(1)(o) prior-consent "
                "requirement for commercial email."
            )
        return value


class WaitlistResponse(BaseModel):
    """Backend → mobile success payload."""

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    id: str = Field(
        ...,
        description="Server-generated UUID for the captured waitlist entry.",
    )
    created_at: datetime = Field(
        ...,
        description="UTC timestamp the row was persisted.",
    )
    legal_entity: str = Field(
        default="MINT SA",
        description="Data controller named at the moment of capture.",
    )
    retention_purge_after: Optional[datetime] = Field(
        default=None,
        description="nLPD retention bound — server may auto-purge after this date.",
    )
