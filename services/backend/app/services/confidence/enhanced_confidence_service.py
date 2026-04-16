"""
# ════════════════════════════════════════════════════════════════════════════
# CONFIDENCE DOCTRINE (see docs/SOURCE_OF_TRUTH_MATRIX.md §3)
#
# This service is the AUTHORITATIVE SOURCE OF TRUTH for confidence scoring.
# It governs: feature gates, global UI confidence bars, enrichment ranking.
#
# The 3 confidence systems and their governance:
#   1. THIS FILE → authoritative, 4-axis geometric mean, via /confidence API
#   2. enhanced_confidence_service.dart (mobile) → offline fallback (3-axis)
#   3. confidence_scorer.dart (financial_core) → projection quality only
#
# Any new confidence-related feature should consume this service via API.
# The mobile fallback exists only for offline UX, not for decision-making.
# ════════════════════════════════════════════════════════════════════════════

Backend confidence: 4 axes (completeness, accuracy, freshness, understanding), geometric mean.
Used by /confidence API endpoint.

Pure functions for multi-dimensional confidence measurement:
- score_completeness: champs remplis, ponderes par importance
- score_accuracy: qualite des sources (open_banking > document > user_entry)
- score_freshness: fraicheur des donnees (< 1 mois = 100, > 12 mois = 25)
- score_understanding: comprehension financiere (literacy + engagement)
- compute_confidence: moyenne geometrique 4 axes + feature gates + enrichment prompts
- rank_enrichment_prompts: actions classees par impact sur le score

Sources:
    - DATA_ACQUISITION_STRATEGY.md, section "Confidence Scoring Evolution"
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - OPP3 art. 7 (3e pilier)
    - LIFD art. 38 (imposition du capital)
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Dict, List, Optional

from app.services.document_parser.document_models import DATA_SOURCE_ACCURACY

from app.services.confidence.enhanced_confidence_models import (
    ConfidenceBreakdown,
    ConfidenceResult,
    EnrichmentPrompt,
    FieldSource,
)


# ============================================================================
# Constants
# ============================================================================

# Weight of each axis in the overall confidence score
WEIGHT_COMPLETENESS = 0.40
WEIGHT_ACCURACY = 0.35
WEIGHT_FRESHNESS = 0.25

# Profile fields with importance weights (higher = more impact on projections)
# Fields critical for retirement, tax, and arbitrage projections are weighted higher.
PROFILE_FIELD_WEIGHTS: Dict[str, float] = {
    # Identity / core
    "age": 1.0,
    "canton": 0.8,
    "salaire_brut": 1.0,
    "salaire_net": 0.6,
    # LPP (2nd pillar) — critical for retirement + arbitrage
    "lpp_total": 1.0,
    "lpp_obligatoire": 1.0,
    "lpp_surobligatoire": 0.8,
    "lpp_insured_salary": 0.7,
    "conversion_rate_oblig": 0.9,
    "conversion_rate_suroblig": 0.7,
    "buyback_potential": 0.6,
    "employee_lpp_contribution": 0.5,
    # AVS (1st pillar)
    "avs_contribution_years": 0.9,
    "avs_ramd": 0.9,
    # 3a (pillar 3a)
    "pillar_3a_balance": 0.7,
    # Tax
    "taux_marginal": 0.9,
    "taxable_income": 0.7,
    "taxable_wealth": 0.5,
    # Mortgage / property
    "mortgage_remaining": 0.5,
    "mortgage_rate": 0.4,
    "property_value": 0.4,
    # Family / situation
    "is_married": 0.5,
    "nb_children": 0.4,
    "monthly_expenses": 0.6,
    # Employment
    "is_independant": 0.6,
    "has_lpp": 0.7,
}

# Freshness decay thresholds (months -> score)
FRESHNESS_THRESHOLDS = [
    (1, 1.00),    # < 1 month
    (3, 0.90),    # 1-3 months
    (6, 0.75),    # 3-6 months
    (12, 0.50),   # 6-12 months
]
FRESHNESS_FLOOR = 0.25  # > 12 months

# Understanding axis constants (Dart parity)
LITERACY_BASES = {"beginner": 30.0, "intermediate": 55.0, "advanced": 85.0}
SESSION_BONUS_PER_CHECKIN = 2.0
SESSION_BONUS_CAP = 40.0
WEIGHT_LITERACY = 0.50
WEIGHT_SESSION = 0.30
WEIGHT_EDUCATION = 0.20

# Enrichment prompt catalog: what actions improve confidence and by how much
_ENRICHMENT_CATALOG: List[Dict] = [
    {
        "field_name": "lpp_total",
        "action": "Scanne ton certificat de prevoyance LPP",
        "impact_points": 27.0,
        "method": "document_scan",
        "related_fields": [
            "lpp_obligatoire", "lpp_surobligatoire", "lpp_insured_salary",
            "conversion_rate_oblig", "conversion_rate_suroblig",
            "buyback_potential", "employee_lpp_contribution",
        ],
    },
    {
        "field_name": "avs_contribution_years",
        "action": "Demande ton extrait de compte individuel AVS (ahv-iv.ch)",
        "impact_points": 22.0,
        "method": "avs_request",
        "related_fields": ["avs_ramd"],
    },
    {
        "field_name": "taux_marginal",
        "action": "Scanne ta declaration fiscale ou ton avis de taxation",
        "impact_points": 18.0,
        "method": "document_scan",
        "related_fields": ["taxable_income", "taxable_wealth"],
    },
    {
        "field_name": "salaire_brut",
        "action": "Connecte ton compte bancaire via Open Banking",
        "impact_points": 20.0,
        "method": "open_banking",
        "related_fields": [
            "salaire_net", "monthly_expenses", "pillar_3a_balance",
        ],
    },
    {
        "field_name": "pillar_3a_balance",
        "action": "Scanne ton attestation 3a ou connecte ton compte 3a",
        "impact_points": 8.0,
        "method": "document_scan",
        "related_fields": [],
    },
    {
        "field_name": "mortgage_remaining",
        "action": "Scanne ton attestation hypothecaire",
        "impact_points": 12.0,
        "method": "document_scan",
        "related_fields": ["mortgage_rate", "property_value"],
    },
    {
        "field_name": "monthly_expenses",
        "action": "Entre tes charges mensuelles ou connecte Open Banking",
        "impact_points": 6.0,
        "method": "manual_entry",
        "related_fields": [],
    },
    {
        "field_name": "is_married",
        "action": "Complete ta situation familiale (marie-e, enfants)",
        "impact_points": 5.0,
        "method": "manual_entry",
        "related_fields": ["nb_children"],
    },
]


# ============================================================================
# Pure functions
# ============================================================================


def score_completeness(profile: dict) -> float:
    """Calcule le score de completude (0-100) du profil.

    Chaque champ est pondere par son importance pour les projections financieres.
    Un profil completement rempli = 100. Un profil vide = 0.

    Args:
        profile: Dictionnaire du profil utilisateur (cles = noms de champs).

    Returns:
        Score de completude 0-100.
    """
    if not PROFILE_FIELD_WEIGHTS:
        return 0.0

    total_weight = sum(PROFILE_FIELD_WEIGHTS.values())
    filled_weight = 0.0

    for field_name, weight in PROFILE_FIELD_WEIGHTS.items():
        if _is_field_filled(profile.get(field_name)):
            filled_weight += weight

    if total_weight == 0:
        return 0.0

    return round(min(100.0, (filled_weight / total_weight) * 100), 1)


def _is_field_filled(value: object) -> bool:
    """Retourne True si une valeur de profil est consideree comme renseignee.

    Regles:
    - bool: True et False sont tous deux renseignes
    - None / "": non renseignes
    - nombres (incl. 0): renseignes
    - autres types: truthy => renseignes
    """
    if isinstance(value, bool):
        return True
    if value is None:
        return False
    if isinstance(value, str):
        return value.strip() != ""
    if isinstance(value, (int, float)):
        return True
    return bool(value)


def score_accuracy(field_sources: List[FieldSource]) -> float:
    """Calcule le score de precision (0-100) base sur la qualite des sources.

    Chaque source a un poids de fiabilite (open_banking=1.0, user_entry=0.5, etc.).
    Le score est la moyenne ponderee des accuracy weights, ponderee par l'importance
    du champ dans le profil.

    Args:
        field_sources: Liste des sources de champs du profil.

    Returns:
        Score de precision 0-100.
    """
    if not field_sources:
        return 0.0

    weighted_accuracy_sum = 0.0
    total_weight = 0.0

    for fs in field_sources:
        field_weight = PROFILE_FIELD_WEIGHTS.get(fs.field_name, 0.5)
        source_accuracy = DATA_SOURCE_ACCURACY.get(fs.source, 0.25)
        weighted_accuracy_sum += source_accuracy * field_weight
        total_weight += field_weight

    if total_weight == 0:
        return 0.0

    return round(min(100.0, (weighted_accuracy_sum / total_weight) * 100), 1)


def _compute_field_freshness(updated_at: str, now: Optional[datetime] = None) -> float:
    """Calcule la fraicheur d'un champ individuel (0-1).

    Decay:
        < 1 mois:   1.00
        1-3 mois:   0.90
        3-6 mois:   0.75
        6-12 mois:  0.50
        > 12 mois:  0.25

    Args:
        updated_at: Date ISO 8601 de derniere mise a jour.
        now: Date de reference (default: maintenant UTC).

    Returns:
        Score de fraicheur 0-1.
    """
    if now is None:
        now = datetime.now(timezone.utc)

    try:
        # Parse ISO datetime — handle both with and without timezone
        dt = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
    except (ValueError, AttributeError):
        return FRESHNESS_FLOOR

    age_days = (now - dt).total_seconds() / 86400.0
    if age_days < 0:
        # Future date — treat as fresh
        return 1.0

    age_months = age_days / 30.44  # average days per month

    for threshold_months, score in FRESHNESS_THRESHOLDS:
        if age_months < threshold_months:
            return score

    return FRESHNESS_FLOOR


def score_freshness(
    field_sources: List[FieldSource],
    now: Optional[datetime] = None,
) -> float:
    """Calcule le score de fraicheur (0-100) des donnees du profil.

    Moyenne ponderee des freshness scores par champ, ponderee par importance.

    Args:
        field_sources: Liste des sources de champs du profil.
        now: Date de reference (default: maintenant UTC).

    Returns:
        Score de fraicheur 0-100.
    """
    if not field_sources:
        return 0.0

    weighted_freshness_sum = 0.0
    total_weight = 0.0

    for fs in field_sources:
        field_weight = PROFILE_FIELD_WEIGHTS.get(fs.field_name, 0.5)
        field_fresh = _compute_field_freshness(fs.updated_at, now=now)
        weighted_freshness_sum += field_fresh * field_weight
        total_weight += field_weight

    if total_weight == 0:
        return 0.0

    return round(min(100.0, (weighted_freshness_sum / total_weight) * 100), 1)


def score_understanding(profile: dict) -> float:
    """Compute understanding score (0-100) from literacy level and engagement.

    Formula: literacyBase * 0.50 + sessionBonus * 0.30 + educationBonus * 0.20

    Args:
        profile: dict with optional keys 'financial_literacy_level' and 'check_in_count'

    Returns:
        Understanding score 0-100.
    """
    literacy_level = profile.get("financial_literacy_level", "beginner")
    literacy_base = LITERACY_BASES.get(str(literacy_level).lower(), 30.0)

    check_in_count = profile.get("check_in_count", 0)
    if not isinstance(check_in_count, (int, float)):
        check_in_count = 0
    session_bonus = min(check_in_count * SESSION_BONUS_PER_CHECKIN, SESSION_BONUS_CAP)

    education_bonus = 0.0  # placeholder for future education tracking

    understanding = (
        literacy_base * WEIGHT_LITERACY
        + session_bonus * WEIGHT_SESSION
        + education_bonus * WEIGHT_EDUCATION
    )
    return round(min(100.0, max(0.0, understanding)), 1)


def _geo_mean_4(c: float, a: float, f: float, u: float) -> float:
    """4-axis geometric mean with shift to avoid zero (Dart parity)."""
    vals = [(x + 1.0) / 101.0 for x in [c, a, f, u]]
    product = vals[0] * vals[1] * vals[2] * vals[3]
    geo = product ** 0.25
    return min(100.0, max(0.0, geo * 101.0 - 1.0))


def _compute_feature_gates(overall: float) -> Dict[str, bool]:
    """Determine les fonctionnalites debloquees selon le score global.

    Feature gates:
        < 30%:  basic_premier_eclairage_only
        30-50%: + standard_projections
        50-70%: + arbitrage_comparisons (with uncertainty bands)
        70-85%: + precise_arbitrage + fri_scoring
        > 85%:  + full_precision + longitudinal_tracking

    Args:
        overall: Score de confiance global (0-100).

    Returns:
        Dict de feature gates (nom -> actif/inactif).
    """
    return {
        "basic_premier_eclairage_only": True,  # always available
        "standard_projections": overall >= 30.0,
        "arbitrage_comparisons": overall >= 50.0,
        "precise_arbitrage": overall >= 70.0,
        "fri_scoring": overall >= 70.0,
        "full_precision": overall >= 85.0,
        "longitudinal_tracking": overall >= 85.0,
    }


def rank_enrichment_prompts(
    profile: dict,
    field_sources: List[FieldSource],
) -> List[EnrichmentPrompt]:
    """Classe les actions d'enrichissement par impact decroissant.

    Pour chaque action du catalogue, calcule l'impact reel en fonction
    de ce qui est deja rempli/source dans le profil.

    Actions deja completees (champ rempli + source de bonne qualite) sont
    exclues ou ont un impact reduit.

    Args:
        profile: Dictionnaire du profil utilisateur.
        field_sources: Liste des sources existantes.

    Returns:
        Liste d'EnrichmentPrompt classee par impact decroissant.
    """
    # Build lookup for existing sources
    source_by_field: Dict[str, FieldSource] = {
        fs.field_name: fs for fs in field_sources
    }

    prompts: List[EnrichmentPrompt] = []

    for catalog_entry in _ENRICHMENT_CATALOG:
        primary_field = catalog_entry["field_name"]
        base_impact = catalog_entry["impact_points"]
        related_fields = catalog_entry["related_fields"]

        # Check if primary field is already well-sourced
        existing_source = source_by_field.get(primary_field)
        primary_filled = profile.get(primary_field) is not None and profile.get(primary_field) != ""

        if primary_filled and existing_source:
            # Field already has a good source — reduce impact
            source_quality = DATA_SOURCE_ACCURACY.get(existing_source.source, 0.25)
            if source_quality >= 0.85:
                # Already well sourced (document_scan or better) — skip
                continue
            # Partial credit: reduce impact proportionally
            base_impact *= (1.0 - source_quality)

        # Check related fields: if many are missing, higher impact
        missing_related = sum(
            1 for rf in related_fields
            if profile.get(rf) is None or profile.get(rf) == ""
        )
        total_related = len(related_fields) if related_fields else 1

        # Bonus for filling multiple missing related fields
        related_bonus = (missing_related / max(total_related, 1)) * base_impact * 0.3

        effective_impact = round(base_impact + related_bonus, 1)

        if effective_impact < 1.0:
            continue

        prompts.append(EnrichmentPrompt(
            field_name=primary_field,
            action=catalog_entry["action"],
            impact_points=effective_impact,
            method=catalog_entry["method"],
            priority=0,  # will be set below
        ))

    # Sort by impact descending
    prompts.sort(key=lambda p: p.impact_points, reverse=True)

    # Assign priority ranks (1 = highest impact)
    for i, prompt in enumerate(prompts):
        prompt.priority = i + 1

    return prompts


def compute_confidence(
    profile: dict,
    field_sources: List[FieldSource],
    now: Optional[datetime] = None,
) -> ConfidenceResult:
    """Calcule le score de confiance complet sur 4 axes.

    Combine completeness, accuracy, freshness et understanding
    via une moyenne geometrique, genere les feature gates et classe les
    enrichment prompts par impact.

    Args:
        profile: Dictionnaire du profil utilisateur.
        field_sources: Liste des sources de champs.
        now: Date de reference pour la fraicheur (default: maintenant UTC).

    Returns:
        ConfidenceResult complet avec breakdown, gates, prompts et compliance.
    """
    completeness = score_completeness(profile)
    accuracy = score_accuracy(field_sources)
    freshness = score_freshness(field_sources, now=now)
    understanding = score_understanding(profile)

    # 4-axis geometric mean (Dart parity)
    overall = round(_geo_mean_4(completeness, accuracy, freshness, understanding), 1)

    breakdown = ConfidenceBreakdown(
        completeness=completeness,
        accuracy=accuracy,
        freshness=freshness,
        understanding=understanding,
        overall=overall,
    )

    feature_gates = _compute_feature_gates(overall)
    enrichment_prompts = rank_enrichment_prompts(profile, field_sources)

    return ConfidenceResult(
        breakdown=breakdown,
        enrichment_prompts=enrichment_prompts,
        feature_gates=feature_gates,
    )
