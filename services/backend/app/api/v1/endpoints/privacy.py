"""
nLPD (new Swiss Data Protection Law) compliance endpoints.

POST /api/v1/privacy/export         — Export des donnees personnelles (nLPD art. 25)
POST /api/v1/privacy/delete         — Suppression des donnees personnelles (nLPD art. 32)
GET  /api/v1/privacy/consent-status — Statut des consentements (nLPD art. 6)
POST /api/v1/privacy/consent-update — Mise a jour d'un consentement (nLPD art. 6 al. 7)

All endpoints are stateless (no persistent data storage). Pure computation.
In production, these would interact with the real database layer.
"""

from fastapi import APIRouter, HTTPException

from app.schemas.privacy import (
    DataExportRequest,
    DataExportResponse,
    DataCategoryExport,
    DataDeletionRequest,
    DataDeletionResponse,
    DeletionCategoryDetail,
    ConsentStatusRequest,
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
def export_user_data(request: DataExportRequest) -> DataExportResponse:
    """Exporte toutes les donnees personnelles d'un utilisateur.

    Conforme a nLPD art. 25 (droit d'acces) et art. 28 (portabilite).
    Retourne un JSON lisible par machine avec toutes les donnees et metadonnees.

    Sources: nLPD art. 25, 28; OPDo art. 16-19.
    """
    service = PrivacyService()

    # In production, these would be fetched from the database.
    # Here we simulate with sample data to demonstrate the structure.
    sample_profile = {
        "profile_id": request.profile_id,
        "status": "active",
    }

    result = service.export_user_data(
        profile_id=request.profile_id,
        profile_data=sample_profile,
        sessions_data=[],
        reports_data=[],
        documents_data=[],
        analytics_data=[],
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
def delete_user_data(request: DataDeletionRequest) -> DataDeletionResponse:
    """Supprime les donnees personnelles d'un utilisateur.

    Conforme a nLPD art. 6 al. 4 et art. 32.
    Propose une suppression immediate ou avec un delai de grace de 30 jours.

    Sources: nLPD art. 6, 32; CO art. 127; OPDo art. 20-22.
    """
    service = PrivacyService()

    # In production, counts would come from the database
    result = service.delete_user_data(
        profile_id=request.profile_id,
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
def get_consent_status(profile_id: str) -> ConsentStatusResponse:
    """Retourne le statut actuel de tous les consentements.

    Conforme a nLPD art. 6 (principes de traitement) et art. 7 (Privacy by Design).
    Par defaut, seul le traitement contractuel (core_profile) est actif.

    Sources: nLPD art. 6, 7.
    """
    service = PrivacyService()

    # In production, consents would be fetched from the database
    result = service.get_consent_status(
        profile_id=profile_id,
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
def update_consent(request: ConsentUpdateRequest) -> ConsentUpdateResponse:
    """Met a jour un consentement pour une categorie de traitement.

    Le retrait du consentement est un droit fondamental (nLPD art. 6 al. 7).
    Le consentement pour core_profile (base contractuelle) ne peut pas etre retire.

    Sources: nLPD art. 6 al. 7.
    """
    service = PrivacyService()

    try:
        result = service.update_consent(
            profile_id=request.profile_id,
            categorie=request.categorie.value,
            est_actif=request.est_actif,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return ConsentUpdateResponse(
        profile_id=result.profile_id,
        categorie=result.categorie,
        est_actif=result.est_actif,
        date_modification=result.date_modification,
        message=result.message,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )
