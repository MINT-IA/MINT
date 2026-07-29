"""Schémas API du store/resolve MoneyTruthReceipt (Tranche firstJob PR-E, E1).

Wire camelCase (Pydantic v2, ``alias_generator=to_camel``). Le corps du receipt
lui-même est le modèle canonique ``MoneyTruthReceipt`` (déjà camelCase). Ces
schémas enveloppent l'écriture (store) et la lecture (resolve) — SPEC §4.3.
"""
from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

from app.models.lucidity.money_truth_receipt import MoneyTruthReceipt


class _ReceiptApiBase(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


class StoreReceiptRequest(_ReceiptApiBase):
    """Écriture idempotente d'un receipt (SPEC §4.3 clause 1)."""

    receipt: MoneyTruthReceipt
    anonymous_session_id: Optional[str] = Field(
        default=None,
        min_length=8,
        max_length=64,
        description=(
            "Session anonyme propriétaire quand la requête n'est pas "
            "authentifiée (store /first-job pré-auth). Ignoré si un JWT est "
            "présent (le scope propriétaire prend alors user.id)."
        ),
    )


class StoreReceiptResponse(_ReceiptApiBase):
    """Résultat de l'écriture."""

    status: str = Field(description="'stored' (nouveau) | 'duplicate' (no-op).")
    receipt_id: str
    inputs_hash: str


class ResolveReceiptRequest(_ReceiptApiBase):
    """Résolution scopée propriétaire (SPEC §4.3 clauses 2-3)."""

    receipt_id: str = Field(min_length=1, max_length=64)
    inputs_hash: str = Field(min_length=1, max_length=64)
    receipt_inputs: Optional[dict[str, Any]] = Field(
        default=None,
        description=(
            "Inputs normalisés portés par le payload d'entrée (cas pending : "
            "receipt pas encore synchronisé). Le coach répond depuis ces inputs "
            "quand la ligne n'est pas résolvable pour ce propriétaire."
        ),
    )
    anonymous_session_id: Optional[str] = Field(
        default=None,
        min_length=8,
        max_length=64,
        description="Session anonyme propriétaire (résolution non authentifiée).",
    )


class ResolveReceiptResponse(_ReceiptApiBase):
    """Résultat de la résolution."""

    status: str = Field(description="'resolved' | 'pending' | 'not_found'.")
    receipt: Optional[MoneyTruthReceipt] = Field(
        default=None,
        description="Receipt complet — présent SEULEMENT quand status='resolved'.",
    )
    inputs: Optional[dict[str, Any]] = Field(
        default=None,
        description="Inputs échos — présents quand status='pending'.",
    )


__all__ = [
    "StoreReceiptRequest",
    "StoreReceiptResponse",
    "ResolveReceiptRequest",
    "ResolveReceiptResponse",
]
