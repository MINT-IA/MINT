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
        r"\bje\s+recommande\b",
        r"\brecommand[ée]e?s?\b",
        r"\bil\s+faudrait\s+verser\b",
        r"\bpense\s+à\s+verser\b",
    ]
]

# Nombres en LETTRES : le vocabulaire fermé n'en contient aucun — un
# montant écrit en toutes lettres est une invention par construction.
# (« un/une » exclus : articles.)
_SPELLED_NUMBER_RE = re.compile(
    r"\b(deux|trois|quatre|cinq|six|sept|huit|neuf|dix|onze|douze|treize|"
    r"quatorze|quinze|seize|vingt|trente|quarante|cinquante|soixante|"
    r"cents?|mille|millions?|milliards?)\b",
    re.IGNORECASE,
)

# Le coach n'a aucune autorité de fraîcheur au-delà de computedAt : tout
# jugement de péremption est une invention.
_STALENESS_RE = re.compile(
    r"\bpérimé|\bobsolète|\bplus\s+à\s+jour\b", re.IGNORECASE
)

# Dates complètes (ISO ou suisse) : autorisées comme TOUT, jamais en
# composantes isolées — « 08 CHF » ne doit pas hériter du « 08 » de la date.
_FULL_DATE_RE = re.compile(r"\b\d{4}-\d{2}-\d{2}\b|\b\d{2}\.\d{2}\.\d{4}\b")

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

    if _SPELLED_NUMBER_RE.search(answer):
        reasons.append("spelled-number-outside-vocabulary")
    if _STALENESS_RE.search(answer):
        reasons.append("staleness-claim-outside-authority")
    if attestation.state == "positive" and re.search(
        r"\bmarge[^.]{0,40}\b(nulle?|zéro)\b", answer, re.IGNORECASE
    ):
        reasons.append("state-contradiction:positive-said-zero")

    allowed_numbers = {
        _normalize_number(claim.value)
        for claim in build_allowed_claims(attestation)
        if claim.value.isdigit() or _NUMBER_RE.fullmatch(claim.value)
    }

    # Tokens de domaine : « 3a » / « pilier 3 » sont du vocabulaire
    # produit ; les dates COMPLÈTES conformes à computedAt sont retirées
    # en bloc AVANT le scan — leurs composantes isolées restent interdites.
    scannable = re.sub(r"\b3a\b|\bpilier\s*3\b", " ", answer)
    date_iso = attestation.computed_at[:10]
    date_ch = (
        f"{date_iso[8:10]}.{date_iso[5:7]}.{date_iso[0:4]}"
        if len(date_iso) == 10
        else ""
    )
    def _drop_matching_date(m: "re.Match[str]") -> str:
        return " " if m.group() in (date_iso, date_ch) else m.group()
    scannable = _FULL_DATE_RE.sub(_drop_matching_date, scannable)
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
