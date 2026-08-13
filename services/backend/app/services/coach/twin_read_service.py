"""
Lego C1 — service twin-read : outil READ-ONLY FORCÉ + claim-check (c5+c6).

Le LLM n'a qu'UN outil (read_attested_3a_margin), son invocation est
forcée au premier appel, le tool-result reproduit UNIQUEMENT
l'attestation validée et ses claims dérivés. Aucun outil d'écriture
n'existe sur ce chemin. La réponse passe le claim-checker déterministe
AVANT de sortir d'ici — sinon TwinReadRejectedError.
"""

from __future__ import annotations

import json
import logging

from app.schemas.coach_twin_read import Attested3aMargin, TwinReadClaim
from app.services.coach.twin_read_claim_checker import (
    build_allowed_claims,
    check_answer,
)
from app.services.llm.router import LLMRequest, get_router

logger = logging.getLogger(__name__)

READ_TOOL_NAME = "read_attested_3a_margin"

# L'unique outil du chemin C1 — lecture seule par construction : il n'a
# aucun paramètre d'écriture et son résultat est fabriqué CÔTÉ SERVEUR
# depuis l'attestation validée, jamais depuis le modèle.
_READ_TOOL = {
    "name": READ_TOOL_NAME,
    "description": (
        "Read the attested 3a margin of the user's financial twin. "
        "Returns the ONLY numbers you are allowed to quote."
    ),
    "input_schema": {"type": "object", "properties": {}},
}

_SYSTEM = (
    "Tu es l'éclairage MINT : tu EXPLIQUES une marge 3a déjà calculée et "
    "attestée, en français, pour un public 18-99. Règles absolues : "
    "information pédagogique uniquement, jamais de recommandation "
    "personnalisée (aucun « tu devrais »), jamais de produit, de rendement "
    "promis ni d'optimisation ; aucun terme parmi : garanti, optimal, "
    "meilleur, certain, assuré, sans risque, parfait. Tu ne cites QUE les "
    "chiffres retournés par ton outil (montant, année) — aucun autre "
    "nombre, aucun pourcentage, aucun seuil. Mentionne l'année fiscale et "
    "la date de calcul. Termine par la limite : cet éclairage repose "
    "uniquement sur la marge attestée, corriger ou compléter la situation "
    "passe par l'écran Ma situation."
)


class TwinReadRejectedError(Exception):
    """Réponse rejetée par le claim-checker — rien ne doit être rendu."""

    def __init__(self, reasons: list[str]):
        super().__init__("twin-read answer rejected")
        self.reasons = reasons


class TwinReadToolNotInvokedError(Exception):
    """Le modèle n'a pas invoqué l'outil forcé — réponse invalide."""


def _tool_result_payload(attestation: Attested3aMargin) -> dict:
    claims = build_allowed_claims(attestation)
    return {
        "attestation": attestation.model_dump(by_alias=True),
        "allowed_claims": [c.model_dump(by_alias=True) for c in claims],
    }


async def generate_eclairage(
    question: str, attestation: Attested3aMargin
) -> tuple[str, list[TwinReadClaim]]:
    """Deux passes : tool_use forcé → tool_result serveur → texte validé."""
    router = get_router()

    first = await router.invoke(
        LLMRequest(
            model="haiku",
            system=_SYSTEM,
            messages=[{"role": "user", "content": question}],
            tools=[_READ_TOOL],
            tool_choice={"type": "tool", "name": READ_TOOL_NAME},
            max_tokens=512,
            purpose="coach_twin_read_3a",
        )
    )
    tool_use = next(
        (
            block
            for block in first.content
            if getattr(block, "type", None) == "tool_use"
            and getattr(block, "name", None) == READ_TOOL_NAME
        ),
        None,
    )
    if tool_use is None:
        raise TwinReadToolNotInvokedError()

    second = await router.invoke(
        LLMRequest(
            model="haiku",
            system=_SYSTEM,
            messages=[
                {"role": "user", "content": question},
                {
                    "role": "assistant",
                    "content": [
                        {
                            "type": "tool_use",
                            "id": tool_use.id,
                            "name": READ_TOOL_NAME,
                            "input": {},
                        }
                    ],
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "tool_result",
                            "tool_use_id": tool_use.id,
                            "content": json.dumps(
                                _tool_result_payload(attestation),
                                ensure_ascii=False,
                            ),
                        }
                    ],
                },
            ],
            tools=[_READ_TOOL],
            max_tokens=512,
            purpose="coach_twin_read_3a",
        )
    )
    answer = "".join(
        getattr(block, "text", "")
        for block in second.content
        if getattr(block, "type", None) == "text"
    ).strip()
    if not answer:
        raise TwinReadRejectedError(["empty-answer"])

    verdict = check_answer(answer, attestation)
    if not verdict.accepted:
        logger.info("twin-read rejected: %s", verdict.reasons)
        raise TwinReadRejectedError(verdict.reasons)

    return answer, build_allowed_claims(attestation)
