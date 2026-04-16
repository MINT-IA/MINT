"""Granular consent receipts (ISO/IEC 29184:2020) — v2.7 Phase 29 PRIV-01."""

from app.services.consent.consent_service import ConsentService, consent_service
from app.services.consent.merkle_chain import append_receipt, verify_chain
from app.services.consent.receipt_builder import (
    build_receipt,
    compute_policy_hash,
    piiprincipal_hash,
)

__all__ = [
    "ConsentService",
    "consent_service",
    "append_receipt",
    "verify_chain",
    "build_receipt",
    "compute_policy_hash",
    "piiprincipal_hash",
]
