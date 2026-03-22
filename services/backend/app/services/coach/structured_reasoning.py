"""
Structured Reasoning Service — Sprint S52+ (Reasoning/Humanization Split).

Separates the reasoning layer from the humanization layer in the coach pipeline,
inspired by Cleo 3.0's architecture. The reasoning layer is DETERMINISTIC:
it reads profile data and produces structured facts. The LLM humanizes later.

Architecture:
    1. StructuredReasoningService.reason() — deterministic, no LLM call.
       Reads profile data → produces ReasoningOutput (facts, confidence, action).
    2. The ReasoningOutput is injected into the system prompt as a structured block.
    3. Claude humanizes this pre-computed analysis instead of reasoning from scratch.

Benefits:
    - Reasoning quality is not limited by the humanization style requirement.
    - Facts are verifiable and reproducible (same input → same output).
    - The LLM can focus on tone, empathy, and clarity — not arithmetic.
    - Supports A/B testing of humanization without changing the reasoning logic.

Compliance:
    - LSFin art. 3 (information financière)
    - LPD art. 6 (protection des données)
    - FINMA circular 2008/21

Sources:
    - docs/BLUEPRINT_COACH_AI_LAYER.md
    - docs/MINT_CAP_ENGINE_SPEC.md
    - OPP3 art. 7 (plafond 3a: 7'258 CHF/an)
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
"""

from __future__ import annotations

import datetime
from dataclasses import dataclass, field
from typing import Optional


# ─────────────────────────────────────────────────────────────────────────────
# Constants (2025/2026 — mirrored from CLAUDE.md §5)
# ─────────────────────────────────────────────────────────────────────────────

# 3a annual ceiling — salarié·e affiliated to LPP (OPP3 art. 7)
_3A_CEILING_SALARIED: float = 7_258.0

# Replacement rate threshold below which a gap warning is raised
_REPLACEMENT_RATE_GAP_THRESHOLD: float = 0.60

# Liquidity reserve: below this many months → deficit warning
_LIQUIDITY_DEFICIT_MONTHS: float = 3.0

# December: days before year-end within which the 3a deadline fires
_DECEMBER_DEADLINE_DAYS: int = 31

# LPP buyback: minimum significant amount to surface a rachat opportunity
_LPP_BUYBACK_MIN_CHF: float = 10_000.0

# Disclaimer — educational, LSFin compliant
_DISCLAIMER: str = (
    "Outil éducatif. Ne constitue pas un conseil financier au sens de la LSFin. "
    "Consulte un\u00b7e spécialiste pour une analyse adaptée à ta situation."
)


# ─────────────────────────────────────────────────────────────────────────────
# Output dataclass
# ─────────────────────────────────────────────────────────────────────────────


@dataclass
class ReasoningOutput:
    """Structured output from the deterministic reasoning layer.

    This is NOT LLM output — it is computed deterministically from the user's
    profile data. The LLM humanizes this structured result rather than
    reasoning from scratch.

    Fields:
        fact_tag: Machine-readable tag for the primary financial fact identified.
            One of: "deficit", "3a_deadline", "gap_warning", "rachat_opportunity",
            "3a_not_maxed", None.
        fact_label: Human-readable summary of the fact (internal — not shown to user).
        confidence: Confidence in the fact, 0.0–1.0. Reflects data completeness.
        suggested_action: What the user could do (educational, conditional language).
        intent_tag: ScreenRegistry intent tag for routing (if applicable).
        reasoning_trace: Internal explanation of why this fact was selected.
            Never shown to the user directly.
        supporting_data: Dict of CHF amounts, percentages, and dates that back
            the fact. Always contains numeric values for LLM reference.
        disclaimer: Compliance disclaimer (LSFin).
        sources: Legal references supporting the analysis.
    """

    fact_tag: Optional[str]
    fact_label: str
    confidence: float
    suggested_action: str
    intent_tag: Optional[str]
    reasoning_trace: str
    supporting_data: dict
    disclaimer: str = _DISCLAIMER
    sources: list = field(default_factory=list)

    def __post_init__(self) -> None:
        if not 0.0 <= self.confidence <= 1.0:
            raise ValueError(
                f"confidence must be between 0.0 and 1.0, got {self.confidence}"
            )

    def as_system_prompt_block(self) -> str:
        """Render as a structured block for injection into the system prompt.

        The LLM reads this block and humanizes it rather than computing it.
        Internal fields (reasoning_trace) are included so the LLM understands
        the context; they must never be shown verbatim to the user.
        """
        if self.fact_tag is None:
            return ""

        lines = [
            "ANALYSE PRÉALABLE (déterministe — à humaniser, ne pas citer verbatim) :",
            f"Fait : {self.fact_label} (confiance : {self.confidence:.0%})",
            f"Action suggérée : {self.suggested_action}",
        ]

        if self.supporting_data:
            data_parts = [
                f"{k} = {v}" for k, v in self.supporting_data.items()
            ]
            lines.append(f"Données : {' | '.join(data_parts)}")

        if self.intent_tag:
            lines.append(f"Écran cible : {self.intent_tag}")

        lines.append(
            f"Trace interne : {self.reasoning_trace}"
        )

        return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Fact detectors (pure functions — each returns Optional[ReasoningOutput])
# ─────────────────────────────────────────────────────────────────────────────


def _detect_deficit(profile: dict) -> Optional[ReasoningOutput]:
    """Detect a monthly budget deficit from profile data.

    Triggers when monthly_income - monthly_expenses < 0 OR
    months_liquidity < _LIQUIDITY_DEFICIT_MONTHS.

    Args:
        profile: Profile context dict.

    Returns:
        ReasoningOutput if a deficit is detected, None otherwise.
    """
    months_liquidity: Optional[float] = profile.get("months_liquidity")
    monthly_income: Optional[float] = profile.get("monthly_income")
    monthly_expenses: Optional[float] = profile.get("monthly_expenses")

    # Case 1: explicit income/expense pair → compute deficit
    if monthly_income is not None and monthly_expenses is not None:
        deficit = monthly_income - monthly_expenses
        if deficit < 0:
            confidence = 0.75 if profile.get("data_source") == "user_input" else 0.55
            return ReasoningOutput(
                fact_tag="deficit",
                fact_label=(
                    f"Déficit mensuel estimé de CHF {abs(deficit):,.0f}"
                ),
                confidence=confidence,
                suggested_action=(
                    "Revoir les postes de dépenses pour identifier les marges "
                    "de réduction potentielles."
                ),
                intent_tag="budget_review",
                reasoning_trace=(
                    f"monthly_income={monthly_income} CHF, "
                    f"monthly_expenses={monthly_expenses} CHF, "
                    f"deficit={deficit:.0f} CHF/mois"
                ),
                supporting_data={
                    "revenu_mensuel_CHF": round(monthly_income, 0),
                    "charges_mensuelles_CHF": round(monthly_expenses, 0),
                    "deficit_CHF": round(abs(deficit), 0),
                },
                sources=["Recommandation générale de gestion budgétaire"],
            )

    # Case 2: liquidity proxy → low reserve signals a de-facto deficit situation
    if months_liquidity is not None and months_liquidity < _LIQUIDITY_DEFICIT_MONTHS:
        confidence = 0.60
        return ReasoningOutput(
            fact_tag="deficit",
            fact_label=(
                f"Réserve de liquidités insuffisante : "
                f"{months_liquidity:.1f} mois de charges"
            ),
            confidence=confidence,
            suggested_action=(
                "Reconstituer une réserve de précaution d'au moins 3 mois "
                "de charges avant tout autre investissement."
            ),
            intent_tag="budget_review",
            reasoning_trace=(
                f"months_liquidity={months_liquidity:.1f} < seuil "
                f"{_LIQUIDITY_DEFICIT_MONTHS} mois"
            ),
            supporting_data={
                "mois_liquidites": round(months_liquidity, 1),
                "seuil_recommande_mois": _LIQUIDITY_DEFICIT_MONTHS,
            },
            sources=["Recommandation générale : 3-6 mois de charges en réserve"],
        )

    return None


def _detect_3a_deadline(profile: dict, today: Optional[datetime.date] = None) -> Optional[ReasoningOutput]:
    """Detect the year-end 3a contribution deadline in December.

    Triggers when:
    - Current date is in December (within _DECEMBER_DEADLINE_DAYS days of year-end)
    - AND 3a contribution for the year is below the ceiling

    Args:
        profile: Profile context dict.

    Returns:
        ReasoningOutput if the 3a deadline is approaching, None otherwise.
    """
    today = today or datetime.date.today()
    year_end = datetime.date(today.year, 12, 31)
    days_remaining = (year_end - today).days

    if days_remaining > _DECEMBER_DEADLINE_DAYS:
        return None

    existing_3a_ytd: float = profile.get("existing_3a_ytd", 0.0) or 0.0
    annual_3a_contribution: float = (
        profile.get("annual_3a_contribution", existing_3a_ytd) or 0.0
    )
    ceiling = _3A_CEILING_SALARIED
    remaining_3a = max(0.0, ceiling - annual_3a_contribution)

    if remaining_3a <= 0.0:
        return None

    tax_saving_potential: float = profile.get("tax_saving_potential", 0.0) or 0.0
    # Estimate tax saving proportional to remaining contribution if not provided
    if tax_saving_potential <= 0 and annual_3a_contribution < ceiling:
        # Conservative estimate: ~25% marginal rate
        tax_saving_potential = remaining_3a * 0.25

    confidence = 0.80  # Date-based detection is high-confidence

    return ReasoningOutput(
        fact_tag="3a_deadline",
        fact_label=(
            f"Délai de versement 3a : {days_remaining} jours restants "
            f"(plafond {ceiling:,.0f} CHF/an)"
        ),
        confidence=confidence,
        suggested_action=(
            "Vérifier le montant déjà versé cette année et envisager "
            "un versement complémentaire avant le 31 décembre."
        ),
        intent_tag="tax_optimization_3a",
        reasoning_trace=(
            f"today={today.isoformat()}, days_remaining={days_remaining}, "
            f"annual_3a_contribution={annual_3a_contribution:.0f} CHF, "
            f"ceiling={ceiling:.0f} CHF, remaining_3a={remaining_3a:.0f} CHF"
        ),
        supporting_data={
            "plafond_3a_CHF": ceiling,
            "deja_verse_CHF": round(annual_3a_contribution, 0),
            "restant_CHF": round(remaining_3a, 0),
            "jours_restants": days_remaining,
            "economie_fiscale_estimee_CHF": round(tax_saving_potential, 0),
        },
        sources=[
            "OPP3 art. 7 (plafond 3a : 7'258 CHF/an pour les salariés affiliés LPP)",
            "LIFD art. 33 (déduction 3a du revenu imposable)",
        ],
    )


def _detect_gap_warning(profile: dict) -> Optional[ReasoningOutput]:
    """Detect a retirement replacement rate below the 60% threshold.

    Triggers when replacement_ratio < _REPLACEMENT_RATE_GAP_THRESHOLD.

    Args:
        profile: Profile context dict.

    Returns:
        ReasoningOutput if a gap warning is warranted, None otherwise.
    """
    replacement_ratio: Optional[float] = profile.get("replacement_ratio")
    if replacement_ratio is None:
        return None

    if replacement_ratio >= _REPLACEMENT_RATE_GAP_THRESHOLD:
        return None

    monthly_income: Optional[float] = profile.get("monthly_income")
    monthly_retirement: Optional[float] = profile.get("monthly_retirement_income")

    gap_monthly: Optional[float] = None
    if monthly_income is not None:
        projected = monthly_income * replacement_ratio
        gap_monthly = monthly_income - projected

    # Confidence depends on data richness
    has_lpp = profile.get("lpp_capital") is not None
    has_avs = profile.get("avs_rente") is not None
    confidence = 0.70 if (has_lpp and has_avs) else 0.50

    supporting: dict = {
        "taux_remplacement_pct": round(replacement_ratio * 100, 1),
        "seuil_alerte_pct": round(_REPLACEMENT_RATE_GAP_THRESHOLD * 100, 0),
    }
    if monthly_income is not None:
        supporting["revenu_actuel_CHF"] = round(monthly_income, 0)
    if monthly_retirement is not None:
        supporting["revenu_retraite_projete_CHF"] = round(monthly_retirement, 0)
    if gap_monthly is not None:
        supporting["ecart_mensuel_CHF"] = round(gap_monthly, 0)

    return ReasoningOutput(
        fact_tag="gap_warning",
        fact_label=(
            f"Taux de remplacement estimé : {replacement_ratio * 100:.0f}% "
            f"(seuil indicatif : {_REPLACEMENT_RATE_GAP_THRESHOLD * 100:.0f}%)"
        ),
        confidence=confidence,
        suggested_action=(
            "Explorer les leviers pour combler l'écart : versements 3a, "
            "rachat LPP, ou épargne libre selon la situation."
        ),
        intent_tag="retirement_projection",
        reasoning_trace=(
            f"replacement_ratio={replacement_ratio:.2f} < "
            f"threshold={_REPLACEMENT_RATE_GAP_THRESHOLD:.2f}, "
            f"has_lpp={has_lpp}, has_avs={has_avs}"
        ),
        supporting_data=supporting,
        sources=[
            "LAVS art. 21-29 (rente AVS)",
            "LPP art. 15-16 (bonifications vieillesse)",
        ],
    )


def _detect_rachat_opportunity(profile: dict) -> Optional[ReasoningOutput]:
    """Detect a significant LPP buyback (rachat) opportunity.

    Triggers when lpp_buyback_max >= _LPP_BUYBACK_MIN_CHF.

    Args:
        profile: Profile context dict.

    Returns:
        ReasoningOutput if a buyback opportunity exists, None otherwise.
    """
    lpp_buyback_max: Optional[float] = profile.get("lpp_buyback_max")
    if lpp_buyback_max is None or lpp_buyback_max < _LPP_BUYBACK_MIN_CHF:
        return None

    tax_saving_potential: Optional[float] = profile.get("tax_saving_potential")
    lpp_capital: Optional[float] = profile.get("lpp_capital")

    # Conservative tax saving estimate: ~25% marginal rate if not provided
    if tax_saving_potential is None:
        tax_saving_potential = lpp_buyback_max * 0.25

    confidence = 0.65 if profile.get("lpp_certificate_year") else 0.45

    supporting: dict = {
        "rachat_max_CHF": round(lpp_buyback_max, 0),
        "economie_fiscale_estimee_CHF": round(tax_saving_potential, 0),
    }
    if lpp_capital is not None:
        supporting["avoir_lpp_actuel_CHF"] = round(lpp_capital, 0)

    return ReasoningOutput(
        fact_tag="rachat_opportunity",
        fact_label=(
            f"Rachat LPP possible jusqu'à CHF {lpp_buyback_max:,.0f} "
            f"(économie fiscale estimée : CHF {tax_saving_potential:,.0f})"
        ),
        confidence=confidence,
        suggested_action=(
            "Vérifier le certificat de prévoyance pour confirmer le montant "
            "maximal de rachat et simuler l'impact fiscal."
        ),
        intent_tag="lpp_rachat",
        reasoning_trace=(
            f"lpp_buyback_max={lpp_buyback_max:.0f} CHF >= "
            f"min_threshold={_LPP_BUYBACK_MIN_CHF:.0f} CHF, "
            f"lpp_certificate_year={profile.get('lpp_certificate_year')}"
        ),
        supporting_data=supporting,
        sources=[
            "LPP art. 33 (rachat des années de cotisation manquantes)",
            "LIFD art. 81 (déductibilité des rachats LPP)",
            "OPP2 art. 60a (délai de blocage 3 ans avant retraite)",
        ],
    )


def _detect_3a_not_maxed(profile: dict, today: Optional[datetime.date] = None) -> Optional[ReasoningOutput]:
    """Detect when 3a contributions are below the annual ceiling outside December.

    This is a lower-priority fact surfaced when no higher-priority fact applies.
    December-specific logic is handled by _detect_3a_deadline.

    Args:
        profile: Profile context dict.

    Returns:
        ReasoningOutput if 3a is not maxed and not December, None otherwise.
    """
    # Don't double-fire with the December deadline detector
    today = today or datetime.date.today()
    year_end = datetime.date(today.year, 12, 31)
    days_remaining = (year_end - today).days
    if days_remaining <= _DECEMBER_DEADLINE_DAYS:
        return None

    tax_saving_potential: Optional[float] = profile.get("tax_saving_potential")
    annual_3a_contribution: float = profile.get("annual_3a_contribution", 0.0) or 0.0
    ceiling = _3A_CEILING_SALARIED

    if annual_3a_contribution >= ceiling:
        return None

    if tax_saving_potential is None or tax_saving_potential <= 0:
        return None

    remaining = ceiling - annual_3a_contribution
    confidence = 0.60

    return ReasoningOutput(
        fact_tag="3a_not_maxed",
        fact_label=(
            f"Pilier 3a non maximisé : {annual_3a_contribution:,.0f} CHF versés "
            f"sur {ceiling:,.0f} CHF (plafond 2025/2026)"
        ),
        confidence=confidence,
        suggested_action=(
            "Envisager d'augmenter les versements 3a pour réduire la charge "
            "fiscale et renforcer la prévoyance."
        ),
        intent_tag="tax_optimization_3a",
        reasoning_trace=(
            f"annual_3a_contribution={annual_3a_contribution:.0f} CHF < "
            f"ceiling={ceiling:.0f} CHF, remaining={remaining:.0f} CHF, "
            f"tax_saving_potential={tax_saving_potential:.0f} CHF"
        ),
        supporting_data={
            "plafond_3a_CHF": ceiling,
            "deja_verse_CHF": round(annual_3a_contribution, 0),
            "restant_CHF": round(remaining, 0),
            "economie_fiscale_potentielle_CHF": round(tax_saving_potential, 0),
        },
        sources=[
            "OPP3 art. 7 (plafond 3a : 7'258 CHF/an pour les salariés affiliés LPP)",
            "LIFD art. 33 (déduction 3a du revenu imposable)",
        ],
    )


# ─────────────────────────────────────────────────────────────────────────────
# Null output (empty profile or no fact detected)
# ─────────────────────────────────────────────────────────────────────────────


def _null_output() -> ReasoningOutput:
    """Return a null ReasoningOutput when no fact can be identified."""
    return ReasoningOutput(
        fact_tag=None,
        fact_label="Aucun fait prioritaire identifié",
        confidence=0.0,
        suggested_action="",
        intent_tag=None,
        reasoning_trace="Profil insuffisant ou aucun seuil franchi.",
        supporting_data={},
        disclaimer=_DISCLAIMER,
        sources=[],
    )


# ─────────────────────────────────────────────────────────────────────────────
# Main service
# ─────────────────────────────────────────────────────────────────────────────


class StructuredReasoningService:
    """Deterministic reasoning layer — produces structured facts from profile data.

    This is NOT an LLM call. It reads the user's profile context and applies
    rule-based analysis to produce a single prioritized ReasoningOutput.
    The LLM humanizes this output in a separate step.

    Priority order (first match wins):
        1. deficit — monthly budget deficit or liquidity below 3 months
        2. 3a_deadline — December year-end with unfilled 3a ceiling
        3. gap_warning — replacement rate below 60%
        4. rachat_opportunity — LPP buyback ≥ 10'000 CHF available
        5. 3a_not_maxed — 3a below ceiling (outside December)
        6. None — insufficient data to surface a meaningful fact

    Usage:
        output = StructuredReasoningService.reason(
            user_message="Comment puis-je réduire mes impôts ?",
            profile_context={"tax_saving_potential": 2000, "annual_3a_contribution": 3000},
            memory_block=None,
        )
        system_prompt += "\\n\\n" + output.as_system_prompt_block()
    """

    @staticmethod
    def reason(
        user_message: str,
        profile_context: Optional[dict],
        memory_block: Optional[str] = None,
        today: Optional[datetime.date] = None,
    ) -> ReasoningOutput:
        """Extract structured financial reasoning from user context.

        Deterministic — same input always produces same output. No LLM call.

        Args:
            user_message: The user's message (used for future message-aware
                reasoning extensions; not used in current rule-based logic).
            profile_context: Aggregated, non-identifying profile data.
                Expected keys (all optional): monthly_income, monthly_expenses,
                months_liquidity, replacement_ratio, annual_3a_contribution,
                existing_3a_ytd, tax_saving_potential, lpp_buyback_max,
                lpp_capital, lpp_certificate_year, avs_rente, data_source.
            memory_block: Serialized CapMemory block (not used in current
                implementation; reserved for future lifecycle-aware reasoning).

        Returns:
            ReasoningOutput with the highest-priority financial fact identified.
            Returns a null output (fact_tag=None) when the profile is empty
            or no threshold is crossed.
        """
        if not profile_context:
            return _null_output()

        profile = profile_context  # alias for brevity
        effective_today = today or datetime.date.today()

        # Priority 1: Deficit / low liquidity
        result = _detect_deficit(profile)
        if result is not None:
            return result

        # Priority 2: December 3a deadline
        result = _detect_3a_deadline(profile, effective_today)
        if result is not None:
            return result

        # Priority 3: Retirement replacement rate gap
        result = _detect_gap_warning(profile)
        if result is not None:
            return result

        # Priority 4: LPP buyback opportunity
        result = _detect_rachat_opportunity(profile)
        if result is not None:
            return result

        # Priority 5: 3a not maxed (lower priority, outside December)
        result = _detect_3a_not_maxed(profile, effective_today)
        if result is not None:
            return result

        return _null_output()
