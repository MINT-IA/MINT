"""JWT-derived lifecycle endpoints for manual-partner accountability receipts."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.partner_accountability import (
    ACCOUNTABILITY_KIND,
    PURPOSE,
    SUBJECT_KIND,
    PartnerAccountabilityReceiptCreate,
    PartnerAccountabilityConflictResponse,
    PartnerAccountabilityReceiptList,
    PartnerAccountabilityReceiptResponse,
)
from app.services.feature_flags import FeatureFlags
from app.services.partner_accountability.receipt_builder import (
    AccountabilityConfigurationError,
)
from app.services.partner_accountability.service import (
    PartnerAccountabilityActorUnavailable,
    PartnerAccountabilityConflict,
    PartnerAccountabilityNotFound,
    PartnerAccountabilityService,
    PartnerAccountabilityVersionNotCurrent,
)


router = APIRouter()


def _disabled() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={"code": "partner_accountability_disabled"},
    )


def _configuration_incomplete() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail={"code": "partner_accountability_configuration_incomplete"},
    )


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail={"code": "partner_accountability_receipt_not_found"},
    )


def _serialize(service: PartnerAccountabilityService, row) -> dict:
    return {
        "receiptId": row.receipt_id,
        "subjectKind": SUBJECT_KIND,
        "accountabilityKind": ACCOUNTABILITY_KIND,
        "purpose": PURPOSE,
        "noticeVersion": row.notice_version,
        "policyVersion": row.policy_version,
        "declaredAt": row.declared_at,
        "expiresAt": row.expires_at,
        "revokedAt": row.revoked_at,
        "erasedAt": row.erased_at,
        "status": service.status_of(row),
    }


@router.post(
    "/receipts",
    response_model=PartnerAccountabilityReceiptResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        status.HTTP_200_OK: {"model": PartnerAccountabilityReceiptResponse},
        status.HTTP_409_CONFLICT: {
            "model": PartnerAccountabilityConflictResponse,
            "description": (
                "Receipt conflict, version mismatch, or actor deletion race."
            ),
        },
    },
)
def create_receipt(
    body: PartnerAccountabilityReceiptCreate,
    response: Response,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    owner_token = body.subject_owner_token.get_secret_value()
    try:
        owner_id = UUID(owner_token)
    except (TypeError, ValueError, AttributeError):
        owner_id = None
    if owner_id is None or owner_id.version != 4 or str(owner_id) != owner_token:
        raise HTTPException(
            status_code=422,
            detail={"code": "partner_accountability_owner_token_invalid"},
        )
    if not FeatureFlags.get_flags()["partner_lpp_accountability_enabled"]:
        raise _disabled()
    service = PartnerAccountabilityService(db)
    try:
        row, created = service.create(actor_id=str(current_user.id), body=body)
    except AccountabilityConfigurationError:
        raise _configuration_incomplete() from None
    except PartnerAccountabilityVersionNotCurrent:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "partner_accountability_version_not_current"},
        ) from None
    except PartnerAccountabilityActorUnavailable:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "partner_accountability_actor_unavailable"},
        ) from None
    except PartnerAccountabilityConflict:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "partner_accountability_receipt_conflict"},
        ) from None
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    return _serialize(service, row)


@router.get("/receipts", response_model=PartnerAccountabilityReceiptList)
def list_receipts(
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    service = PartnerAccountabilityService(db)
    try:
        rows = service.list_for_actor(actor_id=str(current_user.id))
    except AccountabilityConfigurationError:
        raise _configuration_incomplete() from None
    return {"receipts": [_serialize(service, row) for row in rows]}


@router.get(
    "/receipts/{receipt_id}/status",
    response_model=PartnerAccountabilityReceiptResponse,
)
def get_receipt_status(
    receipt_id: UUID,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    service = PartnerAccountabilityService(db)
    try:
        row = service.get_status(
            actor_id=str(current_user.id),
            receipt_id=receipt_id,
        )
    except AccountabilityConfigurationError:
        raise _configuration_incomplete() from None
    except PartnerAccountabilityNotFound:
        raise _not_found() from None
    return _serialize(service, row)


@router.post(
    "/receipts/{receipt_id}/revoke",
    response_model=PartnerAccountabilityReceiptResponse,
)
def revoke_receipt(
    receipt_id: UUID,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    service = PartnerAccountabilityService(db)
    try:
        row = service.revoke(
            actor_id=str(current_user.id),
            receipt_id=receipt_id,
        )
    except AccountabilityConfigurationError:
        raise _configuration_incomplete() from None
    except PartnerAccountabilityNotFound:
        raise _not_found() from None
    return _serialize(service, row)


@router.delete("/receipts/{receipt_id}", status_code=status.HTTP_204_NO_CONTENT)
def erase_receipt(
    receipt_id: UUID,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    try:
        PartnerAccountabilityService(db).erase(
            actor_id=str(current_user.id),
            receipt_id=receipt_id,
        )
    except AccountabilityConfigurationError:
        raise _configuration_incomplete() from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
