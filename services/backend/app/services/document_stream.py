"""SSE streaming wrapper around understand_document() — Phase 28-02.

Yields a canonical sequence of typed events that the client renders as a
"Tom Hanks reading the document" UX:

    stage:received          (immediate ack — < 50 ms)
    stage:preflight         (about to dispatch to Vision)
    stage:classify_confirmed payload={document_class, issuer_guess, summary}
    field × N               (ordered by EMOTIONAL_IMPORTANCE per doc class)
    narrative               (optional — coach commentary + commitment)
    done                    payload={render_mode, overall_confidence, ...}

Field events are emitted in *emotional importance* order, NOT in the order
Vision returned them — high-stakes numbers (LPP avoir, salaire assuré) hit
the user's eyes first because that's what triggers the "I see it" moment.

Reject + encrypted paths skip the field/narrative events and go straight
to done so the client can swap to the appropriate render_mode UI.
"""
from __future__ import annotations

import asyncio
import logging
from typing import Any, AsyncGenerator, Optional

from app.schemas.document_understanding import (
    DocumentUnderstandingResult,
    ExtractionStatus,
)
from app.services.document_vision_service import understand_document

logger = logging.getLogger(__name__)

# ── Emotional importance ranking per document class ────────────────────────
# RESEARCH §3: order field events by what triggers the user's "I see it"
# moment, not by Vision's reading order. LPP avoir before tauxConversion
# before bonification, etc.

EMOTIONAL_IMPORTANCE: dict[str, list[str]] = {
    "lpp_certificate": [
        "avoirLppTotal",
        "salaireAssure",
        "tauxConversion",
        "rachatMaximum",
        "bonificationVieillesse",
        "avoirLppObligatoire",
        "avoirLppSurobligatoire",
    ],
    "salary_certificate": [
        "salaireBrutAnnuel",
        "salaireNetAnnuel",
        "bonus",
        "lppDeduit",
        "avsDeduit",
    ],
    "pillar_3a_attestation": [
        "solde3a",
        "versementAnnuel",
        "fournisseur",
    ],
    "tax_declaration": [
        "revenuImposable",
        "fortuneImposable",
        "tauxMarginal",
        "impotCantonal",
        "impotFederal",
    ],
    "avs_extract": [
        "renteEstimee",
        "anneesCotisation",
        "ramd",
    ],
    "payslip": [
        "salaireNetMensuel",
        "salaireBrutMensuel",
        "deductions",
    ],
    "mortgage_attestation": [
        "soldeRestant",
        "tauxInteret",
        "amortissementAnnuel",
    ],
    # All other classes fall back to PDF reading order.
}

# Skipped statuses where field/narrative events make no sense.
_SKIP_FIELDS_STATUSES = {
    ExtractionStatus.non_financial,
    ExtractionStatus.rejected_local,
    ExtractionStatus.encrypted_needs_password,
    ExtractionStatus.parse_error,
}


def _ordered_fields(result: DocumentUnderstandingResult) -> list:
    """Re-order extracted fields by EMOTIONAL_IMPORTANCE for the doc class."""
    order = EMOTIONAL_IMPORTANCE.get(result.document_class.value)
    if not order:
        return list(result.extracted_fields)

    rank = {name: i for i, name in enumerate(order)}
    sentinel = len(order) + 1

    def _key(field):
        return rank.get(field.field_name, sentinel)

    return sorted(result.extracted_fields, key=_key)


async def stream_understanding(
    file_bytes: bytes,
    *,
    user_id: str,
    canton: Optional[str] = None,
    lang: Optional[str] = None,
    file_sha: Optional[str] = None,
    profile_archetype: Optional[str] = None,
    profile_first_name: Optional[str] = None,
    profile_last_name: Optional[str] = None,
    partner_first_name: Optional[str] = None,
    db: Any = None,
    field_stagger_seconds: float = 0.05,
) -> AsyncGenerator[dict, None]:
    """Yield SSE events while wrapping the unary understand_document() call.

    Each yielded value is a `{"event": str, "data": dict}` envelope ready to
    be serialised by the FastAPI EventSourceResponse layer.
    """
    # Pre-call ack — fires before we hold any I/O so the user sees life
    # within the first 50 ms.
    yield {"event": "stage", "data": {"stage": "received"}}
    yield {"event": "stage", "data": {"stage": "preflight"}}

    try:
        result = await understand_document(
            file_bytes=file_bytes,
            user_id=user_id,
            canton=canton,
            lang=lang,
            file_sha=file_sha,
            profile_archetype=profile_archetype,
            profile_first_name=profile_first_name,
            profile_last_name=profile_last_name,
            partner_first_name=partner_first_name,
            db=db,
        )
    except Exception as exc:
        logger.error("stream_understanding: understand_document failed err=%s", exc)
        yield {
            "event": "done",
            "data": {
                "render_mode": "reject",
                "overall_confidence": 0.0,
                "error": "extraction_failed",
            },
        }
        return

    # Classify confirmed — single coalesced event with the human-readable summary.
    yield {
        "event": "stage",
        "data": {
            "stage": "classify_confirmed",
            "payload": {
                "document_class": result.document_class.value,
                "issuer_guess": result.issuer_guess,
                "subtype": result.subtype,
                "classification_confidence": result.classification_confidence,
                "summary": result.summary,
            },
        },
    }

    # Field-by-field reveal, ordered by emotional importance.
    if result.extraction_status not in _SKIP_FIELDS_STATUSES:
        for field in _ordered_fields(result):
            confidence_value = (
                field.confidence.value
                if hasattr(field.confidence, "value")
                else str(field.confidence)
            )
            yield {
                "event": "field",
                "data": {
                    "name": field.field_name,
                    "value": field.value,
                    "confidence": confidence_value,
                    "source_text": field.source_text,
                },
            }
            if field_stagger_seconds > 0:
                await asyncio.sleep(field_stagger_seconds)

    # Narrative + commitment device (optional).
    if result.narrative:
        commitment_payload = (
            result.commitment_suggestion.model_dump(by_alias=True)
            if result.commitment_suggestion is not None
            else None
        )
        yield {
            "event": "narrative",
            "data": {
                "text": result.narrative,
                "commitment": commitment_payload,
            },
        }

    # Done — carries the render_mode + Document Memory diff payload.
    diff_payload = None
    if result.diff_from_previous:
        diff_payload = {
            k: v.model_dump(by_alias=True) if hasattr(v, "model_dump") else v
            for k, v in result.diff_from_previous.items()
        }

    yield {
        "event": "done",
        "data": {
            "render_mode": result.render_mode.value,
            "overall_confidence": result.overall_confidence,
            "extraction_status": result.extraction_status.value,
            "diff_from_previous": diff_payload,
            "third_party_detected": result.third_party_detected,
            "third_party_name": result.third_party_name,
            "fingerprint": result.fingerprint,
            "questions_for_user": result.questions_for_user,
        },
    }


__all__ = ["stream_understanding", "EMOTIONAL_IMPORTANCE"]
