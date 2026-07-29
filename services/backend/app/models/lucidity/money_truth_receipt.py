"""MoneyTruthReceipt v1 — contrat de vérité chiffrée (Tranche firstJob PR-B).

Ce modèle ENVELOPPE une valeur L1 (single-number, offline-capable) avec sa
provenance : inputs normalisés, hash déterministe des inputs, millésime,
sources datées, bande d'incertitude et confiance. Il ne remplace PAS le
discriminateur `_payload.py` (L1ChiffrePayload …) ; il l'enrichit — le receipt
accompagne la valeur dans l'enveloppe `CoachToolOk.data` (SPEC §4.2).

Réutilisation obligatoire (SPEC §4.2, pas de réinvention) :
- `inputs_hash` ← `app.services.coach.inputs_hash.compute_inputs_hash`
  (SHA256 hex de JSON canonique RFC 8785, floats quantifiés Decimal(0.01)).
  Le miroir Dart (`money_truth_receipt.dart`) porte le MÊME algorithme, validé
  octet pour octet par `tools/fixtures/money_truth_receipt_v1.json`.
- `confidence` ← forme fil `EnhancedConfidence`
  (`app.schemas.enhanced_confidence`, mêmes 4 axes que
  `confidence_scorer.dart:995`) — pas de nouveau scorer (NEVER #3 / règle 4).
- Persistance (PR-E, hors de ce fichier) ← `ProjectionAuditRecord`
  (`inputs_hash → scenario_inputs_hash`, `hash(value) → output_hash`,
  `engine_version → constants_version_hash + app_version`).

Doctrine de type (miroir de `_payload.py`, SPEC §4.1) :
- `extra="forbid"` : AUCUN champ inconnu ne peut être ajouté. Les champs de
  classement (`recommended*` / `best*` / `top_pick` / `preferred` / `winning*`
  et paraphrases) n'ont donc PAS de nom de champ à peupler — impossibilité de
  schéma (cohérent NEVER #5 / LSFin art. 8).
- `frozen=True` : aucune mutation post-construction (pas d'altération de la
  valeur après validation).
- Sérialisation camelCase (`alias_generator=to_camel`, `populate_by_name=True`)
  pour l'alignement octet avec le miroir Dart et le transport Pydantic v2.

Producteur v1 : le claim `firstjob.net_salary.v1`, émis par
`app.services.first_job.onboarding_service` (le net firstJob backend produit le
receipt). Le receipt v1 reste INTERNE (pas exposé via OpenAPI ; le portage API
= PR-E).

Références
----------
- .planning/phases/mint-2-0-first-experience-rente-capital/TRANCHE-FIRSTJOB-SPEC.md
  §4 (schéma 16 champs, §4.1 exigences range/confidence/taxYear/fixtures),
  §6 (découpage PR-B).
- app/models/lucidity/_payload.py (doctrine extra=forbid + frozen).
- app/services/coach/inputs_hash.py (compute_inputs_hash réutilisé).
"""
from __future__ import annotations

from types import MappingProxyType
from typing import Any, Literal, Mapping, Optional, Tuple

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_serializer,
    field_validator,
    model_validator,
)
from pydantic.alias_generators import to_camel

from app.schemas.enhanced_confidence import EnhancedConfidence

# ---------------------------------------------------------------------------
# Claim id du producteur v1 (SPEC D3 / §4.1). Le seul claim câblé en PR-B.
# ---------------------------------------------------------------------------

FIRST_JOB_NET_SALARY_CLAIM_ID = "firstjob.net_salary.v1"


class _MoneyTruthBase(BaseModel):
    """Config partagée : forbid extras + immuable + camelCase (SPEC §4.1)."""

    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        populate_by_name=True,
        alias_generator=to_camel,
    )


class MoneyTruthSource(_MoneyTruthBase):
    """Une source datée derrière la valeur (SPEC §4.1 `sources[]`).

    `vintage` = millésime de la source (ex. 2026 pour les taux de cotisation,
    2022 pour une statistique OFS ESS). Ne JAMAIS confondre avec `tax_year`
    (millésime des règles de cotisation appliquées) — SPEC §4.1 précision.
    """

    id: str = Field(..., min_length=1)
    label: str = Field(..., min_length=1)
    vintage: int = Field(..., ge=1900, le=2100)


class MoneyTruthRange(_MoneyTruthBase):
    """Bande d'incertitude {low, high} sur la valeur (SPEC §4.1 `range`).

    Chaque borne est un RECALCUL du service avec une hypothèse bornante
    basse / haute (PAS un pourcentage arbitraire) — SPEC §4.1 précision.
    """

    low: float
    high: float

    @model_validator(mode="after")
    def _low_le_high(self) -> "MoneyTruthRange":
        if self.low > self.high:
            raise ValueError(
                f"MoneyTruthRange invalide : low ({self.low}) > high ({self.high})."
            )
        return self


class MoneyTruthReceipt(_MoneyTruthBase):
    """Contrat de vérité chiffrée v1 — enveloppe une valeur L1 + sa provenance.

    Champs (SPEC §4.1). `range` et `confidence` sont nullables EN GÉNÉRAL mais
    REQUIS pour `claim_id == firstjob.net_salary.v1` (validateur ci-dessous ;
    A3 les affiche).
    """

    claim_id: str = Field(..., min_length=1)
    receipt_id: str = Field(..., min_length=1)
    # Immutabilité PROFONDE (frozen=True n'est que superficiel) : les
    # collections sont gelées à la construction — `inputs` en MappingProxyType,
    # `assumptions`/`sources` en tuples — pour que la valeur et sa provenance ne
    # puissent pas être altérées après validation (tamper-evidence).
    inputs: Mapping[str, Any]
    inputs_hash: str = Field(..., min_length=64, max_length=64)
    jurisdiction: str = Field(..., min_length=1)
    tax_year: int = Field(..., ge=1900, le=2100)
    base: Literal["brut", "net"]
    civil_status: str = Field(..., min_length=1)
    assumptions: Tuple[str, ...]
    engine: str = Field(..., min_length=1)
    engine_version: str = Field(..., min_length=1)
    rounding: str = Field(..., min_length=1)
    sources: Tuple[MoneyTruthSource, ...] = Field(..., min_length=1)
    value: float
    range: Optional[MoneyTruthRange] = None
    confidence: Optional[EnhancedConfidence] = None
    computed_at: str = Field(..., min_length=1)

    @field_validator("inputs", mode="after")
    @classmethod
    def _freeze_inputs(cls, v: Mapping[str, Any]) -> Mapping[str, Any]:
        """Gèle `inputs` en vue lecture-seule (mutation post-construction -> erreur)."""
        return MappingProxyType(dict(v))

    @field_serializer("inputs")
    def _serialize_inputs(self, v: Mapping[str, Any], _info: Any) -> dict:
        """Sérialise la MappingProxyType en dict JSON standard."""
        return dict(v)

    @model_validator(mode="after")
    def _net_salary_requires_band_and_confidence(self) -> "MoneyTruthReceipt":
        """`range` + `confidence` REQUIS pour firstjob.net_salary.v1 (SPEC §4.1).

        L'appareil de lucidité (bande + confiance) ne peut pas manquer sur le
        premier chiffre — le rendre nullable pour ce claim casserait A3.
        """
        if self.claim_id == FIRST_JOB_NET_SALARY_CLAIM_ID:
            if self.range is None:
                raise ValueError(
                    f"claim {FIRST_JOB_NET_SALARY_CLAIM_ID} exige un `range` "
                    "(bande d'incertitude) non nul — SPEC §4.1 / A3."
                )
            if self.confidence is None:
                raise ValueError(
                    f"claim {FIRST_JOB_NET_SALARY_CLAIM_ID} exige une "
                    "`confidence` non nulle — SPEC §4.1 / A3."
                )
        return self


__all__ = [
    "FIRST_JOB_NET_SALARY_CLAIM_ID",
    "MoneyTruthReceipt",
    "MoneyTruthRange",
    "MoneyTruthSource",
]
