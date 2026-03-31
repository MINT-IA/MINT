"""
nLPD (new Swiss Data Protection Law) compliance endpoints.

POST /api/v1/privacy/export         — Export des donnees personnelles (nLPD art. 25)
POST /api/v1/privacy/delete         — Suppression des donnees personnelles (nLPD art. 32)
GET  /api/v1/privacy/consent-status — Statut des consentements (nLPD art. 6)
POST /api/v1/privacy/consent-update — Mise a jour d'un consentement (nLPD art. 6 al. 7)

All endpoints are stateless (no persistent data storage). Pure computation.
In production, these would interact with the real database layer.

V12-1: All endpoints use _user.id from JWT (require_current_user) instead of
client-supplied profile_id to prevent IDOR vulnerabilities.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.user import User

from app.schemas.privacy import (
    DataExportRequest,
    DataExportResponse,
    DataCategoryExport,
    DataDeletionRequest,
    DataDeletionResponse,
    DeletionCategoryDetail,
    ConsentStatusResponse,
    ConsentCategoryStatus,
    ConsentUpdateRequest,
    ConsentUpdateResponse,
)
from app.services.privacy_service import PrivacyService


router = APIRouter()

DISCLAIMER = (
    "Outil educatif de gestion de tes donnees personnelles. "
    "Ne constitue pas un avis juridique. "
    "Tes droits sont regis par la nLPD (RS 235.1) en vigueur depuis le 1er septembre 2023. "
    "Pour toute question, contacte un ou une specialiste en protection des donnees."
)


# ---------------------------------------------------------------------------
# Data Export (nLPD art. 25)
# ---------------------------------------------------------------------------

@router.post("/export", response_model=DataExportResponse)
def export_user_data(
    request: DataExportRequest,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> DataExportResponse:
    """Exporte toutes les donnees personnelles d'un utilisateur.

    Conforme a nLPD art. 25 (droit d'acces) et art. 28 (portabilite).
    Retourne un JSON lisible par machine avec toutes les donnees et metadonnees.

    V12-1: Uses _user.id (from JWT) instead of client-supplied profile_id
    to prevent IDOR (Insecure Direct Object Reference).

    Sources: nLPD art. 25, 28; OPDo art. 16-19.
    """
    service = PrivacyService()

    # V12-1: Use authenticated user ID, never client-supplied profile_id.
    user_id = _user.id

    # P2-18 nLPD art. 25: Fetch ALL user data from database for complete DSAR export.
    from app.models.profile_model import ProfileModel
    from app.models.document import DocumentModel
    from app.models.snapshot import SnapshotModel
    from app.models.analytics_event import AnalyticsEvent

    # Profile data
    profiles = db.query(ProfileModel).filter(ProfileModel.user_id == user_id).all()
    profile_data = {
        "user_id": user_id,
        "email": _user.email,
        "display_name": getattr(_user, "display_name", None),
        "created_at": str(getattr(_user, "created_at", None)),
        "profiles": [
            {"id": p.id, "data": p.data if hasattr(p, "data") else None}
            for p in profiles
        ],
    }

    # Sessions data
    sessions_data = []
    if request.include_sessions:
        from app.models.session_model import SessionModel
        profile_ids = [p.id for p in profiles]
        if profile_ids:
            sessions = db.query(SessionModel).filter(
                SessionModel.profile_id.in_(profile_ids)
            ).all()
            sessions_data = [
                {"id": s.id, "profile_id": s.profile_id, "created_at": str(s.created_at)}
                for s in sessions
            ]

    # Documents data
    documents_data = []
    if request.include_documents:
        docs = db.query(DocumentModel).filter(DocumentModel.user_id == user_id).all()
        documents_data = [
            {
                "id": d.id,
                "document_type": d.document_type,
                "upload_date": str(d.upload_date) if d.upload_date else None,
                "confidence": d.confidence,
                "extracted_fields": d.extracted_fields,
            }
            for d in docs
        ]

    # Snapshots data (included in reports)
    reports_data = []
    if request.include_reports:
        snapshots = db.query(SnapshotModel).filter(SnapshotModel.user_id == user_id).all()
        reports_data = [
            {
                "id": s.id,
                "created_at": str(s.created_at),
                "trigger": s.trigger,
                "fri_total": s.fri_total,
                "replacement_ratio": s.replacement_ratio,
            }
            for s in snapshots
        ]

    # Analytics data
    analytics_data = []
    if request.include_analytics:
        events = db.query(AnalyticsEvent).filter(AnalyticsEvent.user_id == user_id).all()
        analytics_data = [
            {"id": e.id, "event_type": e.event_type, "created_at": str(e.created_at)}
            for e in events
        ]

    # P1-nLPD: Conversation memory — consent records (coach memory consent state)
    from app.models.consent import ConsentModel
    consent_data = []
    consents = db.query(ConsentModel).filter(ConsentModel.user_id == user_id).all()
    consent_data = [
        {
            "id": c.id,
            "consent_type": c.consent_type,
            "enabled": c.enabled,
            "updated_at": str(c.updated_at),
        }
        for c in consents
    ]

    # P1-nLPD: Coach memory — embedded insights stored in pgvector (RAG memory).
    # These represent the coach's "memory" of user conversations and insights.
    coach_memory_data = []
    try:
        from sqlalchemy import text as sa_text
        rows = db.execute(
            sa_text(
                "SELECT doc_id, title, content, metadata, created_at "
                "FROM document_embeddings "
                "WHERE metadata::jsonb->>'user_id' = :uid "
                "AND doc_type = 'memory'"
            ),
            {"uid": user_id},
        ).fetchall()
        coach_memory_data = [
            {
                "doc_id": row[0],
                "title": row[1],
                "content": row[2],
                "metadata": row[3],
                "created_at": str(row[4]) if row[4] else None,
            }
            for row in rows
        ]
    except Exception:
        # pgvector not available (dev/CI with SQLite) — skip gracefully
        pass

    # P1-nLPD: Enrich profile_data with conversation history and coach memory
    profile_data["consents"] = consent_data
    profile_data["coach_memory"] = coach_memory_data

    result = service.export_user_data(
        profile_id=user_id,
        profile_data=profile_data,
        sessions_data=sessions_data,
        reports_data=reports_data,
        documents_data=documents_data,
        analytics_data=analytics_data,
        include_sessions=request.include_sessions,
        include_reports=request.include_reports,
        include_documents=request.include_documents,
        include_analytics=request.include_analytics,
    )

    categories_schema = [
        DataCategoryExport(
            categorie=c.categorie,
            nombre_enregistrements=c.nombre_enregistrements,
            description=c.description,
            base_legale=c.base_legale,
            duree_conservation=c.duree_conservation,
        )
        for c in result.categories
    ]

    return DataExportResponse(
        profile_id=result.profile_id,
        date_export=result.date_export,
        format_donnees=result.format_donnees,
        categories=categories_schema,
        donnees_profil=result.donnees_profil,
        donnees_sessions=result.donnees_sessions,
        donnees_rapports=result.donnees_rapports,
        donnees_documents=result.donnees_documents,
        donnees_analytics=result.donnees_analytics,
        politique_conservation=result.politique_conservation,
        responsable_traitement=result.responsable_traitement,
        chiffre_choc=result.chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Data Deletion (nLPD art. 32)
# ---------------------------------------------------------------------------

@router.post("/delete", response_model=DataDeletionResponse)
def delete_user_data(request: DataDeletionRequest, _user: User = Depends(require_current_user)) -> DataDeletionResponse:
    """Supprime les donnees personnelles d'un utilisateur.

    Conforme a nLPD art. 6 al. 4 et art. 32.
    Propose une suppression immediate ou avec un delai de grace de 30 jours.

    V12-1: Uses _user.id (from JWT) instead of client-supplied profile_id
    to prevent IDOR (Insecure Direct Object Reference).

    Sources: nLPD art. 6, 32; CO art. 127; OPDo art. 20-22.
    """
    service = PrivacyService()

    # V12-1: Use authenticated user ID, never client-supplied profile_id.
    user_id = _user.id

    # In production, counts would come from the database
    result = service.delete_user_data(
        profile_id=user_id,
        mode=request.mode.value,
        nb_sessions=0,
        nb_reports=0,
        nb_documents=0,
        nb_analytics=0,
        raison=request.raison,
    )

    categories_schema = [
        DeletionCategoryDetail(
            categorie=c.categorie,
            nombre_supprime=c.nombre_supprime,
            statut=c.statut,
            motif_conservation=c.motif_conservation,
        )
        for c in result.categories_traitees
    ]

    return DataDeletionResponse(
        profile_id=result.profile_id,
        mode=result.mode,
        date_demande=result.date_demande,
        date_suppression_effective=result.date_suppression_effective,
        delai_grace_jours=result.delai_grace_jours,
        categories_traitees=categories_schema,
        total_enregistrements_supprimes=result.total_enregistrements_supprimes,
        donnees_conservees_obligation_legale=result.donnees_conservees_obligation_legale,
        explication_conservation=result.explication_conservation,
        chiffre_choc=result.chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=result.sources,
        alertes=result.alertes,
    )


# ---------------------------------------------------------------------------
# Consent Status (nLPD art. 6)
# ---------------------------------------------------------------------------

@router.get("/consent-status", response_model=ConsentStatusResponse)
def get_consent_status(_user: User = Depends(require_current_user)) -> ConsentStatusResponse:
    """Retourne le statut actuel de tous les consentements.

    Conforme a nLPD art. 6 (principes de traitement) et art. 7 (Privacy by Design).
    Par defaut, seul le traitement contractuel (core_profile) est actif.

    V12-1: Uses _user.id (from JWT) instead of client-supplied path param
    to prevent IDOR (Insecure Direct Object Reference).

    Sources: nLPD art. 6, 7.
    """
    service = PrivacyService()

    # V12-1: Use authenticated user ID, never client-supplied profile_id.
    result = service.get_consent_status(
        profile_id=_user.id,
    )

    consentements_schema = [
        ConsentCategoryStatus(
            categorie=c.categorie,
            nom_affiche=c.nom_affiche,
            description=c.description,
            base_legale=c.base_legale,
            est_obligatoire=c.est_obligatoire,
            est_actif=c.est_actif,
            date_consentement=c.date_consentement,
            peut_etre_retire=c.peut_etre_retire,
            impact_retrait=c.impact_retrait,
        )
        for c in result.consentements
    ]

    return ConsentStatusResponse(
        profile_id=result.profile_id,
        date_verification=result.date_verification,
        consentements=consentements_schema,
        nb_consentements_actifs=result.nb_consentements_actifs,
        nb_consentements_optionnels=result.nb_consentements_optionnels,
        chiffre_choc=result.chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Consent Update (nLPD art. 6 al. 7)
# ---------------------------------------------------------------------------

@router.post("/consent-update", response_model=ConsentUpdateResponse)
def update_consent(request: ConsentUpdateRequest, _user: User = Depends(require_current_user)) -> ConsentUpdateResponse:
    """Met a jour un consentement pour une categorie de traitement.

    Le retrait du consentement est un droit fondamental (nLPD art. 6 al. 7).
    Le consentement pour core_profile (base contractuelle) ne peut pas etre retire.

    V12-1: Uses _user.id (from JWT) instead of client-supplied profile_id
    to prevent IDOR (Insecure Direct Object Reference).

    Sources: nLPD art. 6 al. 7.
    """
    service = PrivacyService()

    # V12-1: Use authenticated user ID, never client-supplied profile_id.
    try:
        result = service.update_consent(
            profile_id=_user.id,
            categorie=request.categorie.value,
            est_actif=request.est_actif,
        )
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Consentement requis — base contractuelle obligatoire (nLPD art. 6)",
        )

    return ConsentUpdateResponse(
        profile_id=result.profile_id,
        categorie=result.categorie,
        est_actif=result.est_actif,
        date_modification=result.date_modification,
        message=result.message,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )
