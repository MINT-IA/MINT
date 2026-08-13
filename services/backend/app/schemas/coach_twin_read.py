"""
Lego C1 — « Éclairer ma marge 3a » : schémas FERMÉS du twin-read.

Contrat : product/mint_next/storyboard/coach_twin_read_3a.storyboard.json.
Chaque niveau est extra='forbid' : un champ inconnu à N'IMPORTE quelle
profondeur est un 422 — l'enveloppe ne transporte QUE l'attestation
publique et ses hashes, jamais les faits scellés ni le contexte legacy.

API convention: camelCase field names via alias_generator, ConfigDict.
"""

from __future__ import annotations

import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel

TWIN_READ_CONTRACT_VERSION = 1

_HEX64_RE = re.compile(r"^[a-f0-9]{64}$")
_ENGINE_VERSION_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")

# La question est bornée : assez pour une vraie question, trop court pour
# une exfiltration de dossier.
MAX_QUESTION_LENGTH = 280


class TwinReadConsentReceipt(BaseModel):
    """Reçu de consentement twin-read — présence et FORME validées ici.

    La preuve de non-révocation d'un reçu anonyme est par construction
    locale (le gate mobile bloque avant HTTP) ; le serveur exige un reçu
    bien formé, jamais un blob libre.
    """

    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, extra="forbid"
    )

    receipt_id: str = Field(min_length=8, max_length=64)
    purpose: Literal["twin_read_3a_margin"]
    version: int = Field(ge=1, le=100)
    granted_at: str = Field(min_length=10, max_length=40)

    @field_validator("receipt_id")
    @classmethod
    def _receipt_id_shape(cls, v: str) -> str:
        if not re.fullmatch(r"[A-Za-z0-9_-]{8,64}", v):
            raise ValueError("receiptId must be an opaque token")
        return v


class Attested3aMargin(BaseModel):
    """L'attestation PUBLIQUE de marge — la seule matière lisible par C1."""

    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, extra="forbid"
    )

    amount_cents: int = Field(ge=0, le=10_000_000_00)
    currency: Literal["CHF"]
    tax_year: int = Field(ge=2020, le=2100)
    state: Literal["positive", "zero", "unknown"]
    computed_at: str = Field(min_length=10, max_length=40)
    engine_version: str = Field(min_length=1, max_length=64)
    inputs_hash: str
    registry_hash: str

    @field_validator("inputs_hash", "registry_hash")
    @classmethod
    def _hex64(cls, v: str) -> str:
        if not _HEX64_RE.fullmatch(v):
            raise ValueError("hash must be 64 lowercase hex chars")
        return v

    @field_validator("engine_version")
    @classmethod
    def _engine_version_shape(cls, v: str) -> str:
        if not _ENGINE_VERSION_RE.fullmatch(v):
            raise ValueError("engineVersion has an unexpected shape")
        return v


class TwinRead3aMarginRequest(BaseModel):
    """Enveloppe fermée C1 — rien d'autre ne passe, à aucun niveau."""

    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, extra="forbid"
    )

    contract_version: Literal[1]
    purpose: Literal["explain_attested_3a_margin"]
    question: str = Field(min_length=1, max_length=MAX_QUESTION_LENGTH)
    session_id: str = Field(min_length=36, max_length=36)
    operation_key: str
    consent_receipt: TwinReadConsentReceipt
    attestation: Attested3aMargin

    @field_validator("operation_key")
    @classmethod
    def _operation_key_hex(cls, v: str) -> str:
        if not _HEX64_RE.fullmatch(v):
            raise ValueError("operationKey must be 64 lowercase hex chars")
        return v


class TwinReadClaim(BaseModel):
    """Un claim autorisé du vocabulaire fermé, avec sa provenance."""

    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, extra="forbid"
    )

    source_ref: Literal[
        "attestation.amountCents",
        "attestation.amountFrancsFloor",
        "attestation.taxYear",
        "attestation.state",
        "attestation.freshness",
    ]
    value: str


class TwinRead3aMarginResponse(BaseModel):
    """Réponse validée : le texte affiché + le vocabulaire qui l'autorise."""

    model_config = ConfigDict(
        populate_by_name=True, alias_generator=to_camel, extra="forbid"
    )

    contract_version: Literal[1]
    answer: str
    claims: list[TwinReadClaim]
    tool_invoked: Literal["read_attested_3a_margin"]
    quota_consumed: bool
    messages_remaining: int = Field(ge=0, le=3)
    replayed: bool = False
