"""Phase mint-calc-engine-v1 W1 Plan 04 — L4 invariant wedge endpoint.

L4 = « Surfacer les invariants ». The « thing nobody tells you ».
Doctrinally aligned with docs/MINT_IDENTITY.md « Mint te dit ce que
personne n'a intérêt à te dire ». Finding 5 of CONTEXT.md : L4 is MINT's
strongest LSFin moat — pure information générale + legal article ref,
no user-profile data, no ranking surface.

This module ships the FIRST L4 endpoint (« 33% plafond de charge » mortgage
cap invariant) as the wedge for L2/L3 which carry higher LSFin risk and need
typed payload contracts first. Per D-CE-15 the response model is the
discriminated `L4InvariantPayload` from `app.models.lucidity`.

Threats covered :
  - T-mint-calc-04-04 (Spoofing) : `Depends(require_current_user)` returns
    401 on missing/invalid JWT.
  - T-mint-calc-04-03 (Information disclosure) : response is information
    générale only (no user-profile fields), so authentication is sufficient.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.core.auth import require_current_user
from app.models.lucidity import L4InvariantPayload
from app.models.user import User


router = APIRouter()


@router.get("/invariants/mortgage-cap", response_model=L4InvariantPayload)
def lucidity_invariant_mortgage_cap(
    _user: User = Depends(require_current_user),
) -> L4InvariantPayload:
    """L4 wedge invariant : 33% mortgage tenability cap.

    Returns the canonical FR condition text + ASB directive legal reference.
    No user-profile input required — this is information générale.

    Sources : Directives ASB (FINMA) sur le crédit hypothécaire. Le plafond
    de charge de 33% ne relève PAS de la loi sur le crédit à la consommation
    (qui exclut explicitement le crédit hypothécaire de son champ).
    Doctrine : MINT_IDENTITY.md « Mint te dit ce que personne n'a intérêt
    à te dire ».
    """
    return L4InvariantPayload(
        legal_article_ref="Directives ASB (FINMA)",
        condition_text_fr=(
            "Quel que soit le scénario d'investissement, "
            "ta capacité d'emprunt hypothécaire reste plafonnée à "
            "33% de tes revenus bruts annuels selon les directives ASB "
            "(taux d'intérêt théorique 5% pour le calcul de la charge)."
        ),
    )
