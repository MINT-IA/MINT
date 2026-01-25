"""
Partners endpoint - list partners and track clicks.
MVP: Static partner list, in-memory click tracking.
"""

from typing import List
from fastapi import APIRouter
from app.schemas.partner import Partner, PartnerKind, PartnerClick
from app.schemas.common import OkResponse

router = APIRouter()

# Static partner list for MVP
_partners: List[Partner] = [
    Partner(
        id="pillar3a-1",
        kind=PartnerKind.pillar3a,
        name="VIAC",
        disclosure="Mint peut recevoir une commission si vous ouvrez un compte.",
        url="https://viac.ch",
    ),
    Partner(
        id="pillar3a-2",
        kind=PartnerKind.pillar3a,
        name="Finpension",
        disclosure="Mint peut recevoir une commission si vous ouvrez un compte.",
        url="https://finpension.ch",
    ),
    Partner(
        id="investing-1",
        kind=PartnerKind.investing,
        name="Interactive Brokers",
        disclosure="Mint peut recevoir une commission si vous ouvrez un compte.",
        url="https://interactivebrokers.com",
    ),
    Partner(
        id="mortgage-1",
        kind=PartnerKind.mortgage,
        name="Hypothèques.ch",
        disclosure="Mint peut recevoir une commission pour les demandes qualifiées.",
        url="https://hypotheques.ch",
    ),
    Partner(
        id="taxes-1",
        kind=PartnerKind.taxes,
        name="TaxFix Suisse",
        disclosure="Mint peut recevoir une commission si vous utilisez ce service.",
        url="https://taxfix.ch",
    ),
]

# In-memory click tracking
_clicks: List[dict] = []


@router.get("", response_model=List[Partner])
def list_partners() -> List[Partner]:
    """List all partners with disclosure."""
    return _partners


@router.post("/click", response_model=OkResponse)
def partner_click(click: PartnerClick) -> OkResponse:
    """Track a partner click event."""
    _clicks.append(
        {
            "profileId": str(click.profileId),
            "partnerId": click.partnerId,
            "kind": click.kind,
        }
    )
    return OkResponse(ok=True)
