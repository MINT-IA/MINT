"""
Reengagement + Consent endpoints — Sprint S40.

POST /api/v1/reengagement/messages   — personalized reengagement messages
GET  /api/v1/reengagement/consent    — consent dashboard (all 3 toggles)
GET  /api/v1/reengagement/byok-detail — BYOK field detail

All endpoints are stateless (no data storage). Pure computation on the fly.

Sources:
    - OPP3 art. 7 (plafond 3a)
    - LPD art. 6 (principes de traitement)
    - nLPD art. 5 let. f (profilage)
    - LSFin art. 3 (information financiere)
"""

from fastapi import APIRouter

from app.schemas.reengagement import (
    ByokDetailResponse,
    ConsentDashboardResponse,
    ConsentStateResponse,
    ReengagementMessageResponse,
    ReengagementRequest,
    ReengagementResponse,
)
from app.services.reengagement.consent_manager import ConsentManager
from app.services.reengagement.reengagement_engine import ReengagementEngine

router = APIRouter()


@router.post(
    "/messages",
    response_model=ReengagementResponse,
    summary="Generer les messages de reengagement personnalises",
    description=(
        "Genere des messages de reengagement bases sur le calendrier fiscal "
        "suisse et les donnees personnelles de l'utilisateur. "
        "Chaque message contient un nombre personnel et une contrainte "
        "temporelle. Outil educatif — ne constitue pas un conseil financier "
        "(LSFin)."
    ),
)
async def generate_messages(request: ReengagementRequest) -> ReengagementResponse:
    """Generate personalized reengagement messages for today.

    Checks calendar triggers and generates messages with personal numbers.
    """
    engine = ReengagementEngine()
    messages = engine.generate_messages(
        today=request.today,
        canton=request.canton,
        tax_saving_3a=request.tax_saving_3a,
        fri_total=request.fri_total,
        fri_delta=request.fri_delta,
        replacement_ratio=request.replacement_ratio,
    )

    message_responses = [
        ReengagementMessageResponse(
            trigger=msg.trigger.value,
            title=msg.title,
            body=msg.body,
            deeplink=msg.deeplink,
            personal_number=msg.personal_number,
            time_constraint=msg.time_constraint,
            month=msg.month,
        )
        for msg in messages
    ]

    return ReengagementResponse(
        messages=message_responses,
        count=len(message_responses),
    )


@router.get(
    "/consent",
    response_model=ConsentDashboardResponse,
    summary="Tableau de bord des consentements",
    description=(
        "Retourne les 3 consentements independants avec leurs descriptions, "
        "champs partages, champs jamais partages, et statut revocable. "
        "Tous les consentements sont OFF par defaut (opt-in, nLPD)."
    ),
)
async def get_consent_dashboard() -> ConsentDashboardResponse:
    """Return consent dashboard with all 3 consents OFF by default."""
    manager = ConsentManager()
    dashboard = manager.get_default_dashboard()

    consent_responses = [
        ConsentStateResponse(
            consent_type=cs.consent_type.value,
            enabled=cs.enabled,
            label=cs.label,
            detail=cs.detail,
            never_sent=cs.never_sent,
            revocable=cs.revocable,
        )
        for cs in dashboard.consents
    ]

    return ConsentDashboardResponse(
        consents=consent_responses,
        disclaimer=dashboard.disclaimer,
        sources=dashboard.sources,
    )


@router.get(
    "/byok-detail",
    response_model=ByokDetailResponse,
    summary="Detail des champs BYOK",
    description=(
        "Retourne exactement quels champs sont envoyes au fournisseur LLM "
        "et quels champs ne sont JAMAIS envoyes. Transparence totale."
    ),
)
async def get_byok_detail() -> ByokDetailResponse:
    """Return BYOK field detail — sent vs never-sent."""
    manager = ConsentManager()
    detail = manager.get_byok_detail()

    return ByokDetailResponse(
        sent_fields=detail["sent_fields"],
        never_sent_fields=detail["never_sent_fields"],
        disclaimer=detail["disclaimer"],
        sources=detail["sources"],
    )
