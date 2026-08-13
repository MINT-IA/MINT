"""
Lego C1 — claim-checker déterministe du twin-read (beat c6).

Un chiffre de la réponse doit appartenir au VOCABULAIRE FERMÉ dérivé de
l'attestation (sortie du seul outil autorisé). Aucune recommandation,
aucun terme banni LSFin, aucun pourcentage ni seuil (ils n'existent pas
dans l'outil). Violation = rejet AVANT rendu — la copie de secours sans
chiffre part à la place et rien n'est consommé.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from app.schemas.coach_twin_read import Attested3aMargin, TwinReadClaim

# Recommandations interdites (LSFin : information, jamais conseil).
_RECOMMENDATION_PATTERNS = [
    re.compile(p, re.IGNORECASE)
    for p in [
        r"\btu\s+devrais\b",
        r"\bvous\s+devriez\b",
        r"\bje\s+te\s+conseille\b",
        r"\bje\s+vous\s+conseille\b",
        r"\bil\s+faut\s+que\s+tu\s+verses\b",
        r"\bverse\s+maintenant\b",
        r"\binvestis\b",
        r"\bplace\s+ton\s+argent\b",
    ]
]

# Termes bannis LSFin (sous-ensemble canonique — CLAUDE.md TOP #1).
_BANNED_TERMS = [
    "garanti",
    "garantie",
    "optimal",
    "optimale",
    "meilleur",
    "meilleure",
    "sans risque",
    "certain",
    "assuré",
    "parfait",
]

# Un nombre = suite de chiffres, séparateurs suisses tolérés (7'258, 7 258,
# 7258.50). Les années sont des nombres comme les autres.
_NUMBER_RE = re.compile(r"\d[\d'’  ]*\d|\d")

_PERCENT_RE = re.compile(r"\d\s*%")


def build_allowed_claims(attestation: Attested3aMargin) -> list[TwinReadClaim]:
    """Le vocabulaire fermé : chaque claim avec sa provenance."""
    francs_floor = attestation.amount_cents // 100
    return [
        TwinReadClaim(
            source_ref="attestation.amountCents",
            value=str(attestation.amount_cents),
        ),
        TwinReadClaim(
            source_ref="attestation.amountFrancsFloor",
            value=str(francs_floor),
        ),
        TwinReadClaim(
            source_ref="attestation.taxYear",
            value=str(attestation.tax_year),
        ),
        TwinReadClaim(
            source_ref="attestation.state",
            value=attestation.state,
        ),
        TwinReadClaim(
            source_ref="attestation.freshness",
            value=attestation.computed_at,
        ),
    ]


def _normalize_number(raw: str) -> str:
    return re.sub(r"['’  ]", "", raw)


@dataclass
class ClaimCheckResult:
    accepted: bool
    reasons: list[str] = field(default_factory=list)


def check_answer(
    answer: str, attestation: Attested3aMargin
) -> ClaimCheckResult:
    """Validation déterministe AVANT rendu — jamais probabiliste."""
    reasons: list[str] = []

    lowered = answer.lower()
    for term in _BANNED_TERMS:
        if term in lowered:
            reasons.append(f"banned-term:{term}")
    for pattern in _RECOMMENDATION_PATTERNS:
        if pattern.search(answer):
            reasons.append(f"recommendation:{pattern.pattern}")
    if _PERCENT_RE.search(answer):
        # Aucun pourcentage n'existe dans la sortie outil : par
        # construction, tout % est une invention.
        reasons.append("percent-outside-tool-output")

    allowed_numbers = {
        _normalize_number(claim.value)
        for claim in build_allowed_claims(attestation)
        if claim.value.isdigit() or _NUMBER_RE.fullmatch(claim.value)
    }
    # La fraîcheur (date ISO) autorise ses composantes numériques.
    date_part = attestation.computed_at[:10]
    for piece in re.split(r"[^0-9]", date_part):
        if piece:
            allowed_numbers.add(piece)

    # Tokens de domaine : « 3a » / « pilier 3 » sont du vocabulaire
    # produit, pas des chiffres inventés.
    scannable = re.sub(r"\b3a\b|\bpilier\s*3\b", " ", answer)
    for match in _NUMBER_RE.finditer(scannable):
        normalized = _normalize_number(match.group())
        if normalized not in allowed_numbers:
            reasons.append(f"number-outside-vocabulary:{normalized}")

    if attestation.state == "zero" and str(
        attestation.amount_cents // 100
    ) != "0":
        # Cohérence interne de l'attestation — défense en profondeur.
        reasons.append("state-amount-mismatch")

    return ClaimCheckResult(accepted=not reasons, reasons=reasons)


SAFE_FALLBACK_ANSWER = (
    "Je ne peux pas produire un éclairage fiable pour le moment. "
    "Ta marge attestée reste visible dans ta situation."
)
