"""
Confidence endpoints — Sprint S46: Enhanced Confidence Scoring.

POST /api/v1/confidence/score        — score complet avec breakdown multi-dimensionnel
POST /api/v1/confidence/enrichments  — top actions pour ameliorer la precision
POST /api/v1/confidence/gates        — feature gates (fonctionnalites debloquees)

All endpoints are stateless (no data storage). Pure computation on the fly.

Sources:
    - DATA_ACQUISITION_STRATEGY.md, section "Confidence Scoring Evolution"
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - OPP3 art. 7 (3e pilier)
    - LIFD art. 38 (imposition du capital)
"""

from fastapi import APIRouter, Request
from app.core.rate_limit import limiter

from app.schemas.confidence import (
    ConfidenceScoreRequest,
    ConfidenceScoreResponse,
    ConfidenceBreakdownSchema,
    EnrichmentPromptSchema,
    EnrichmentRequest,
    EnrichmentResponse,
    FeatureGatesRequest,
    FeatureGatesResponse,
)
from app.services.document_parser.document_models import DataSource
from app.services.confidence.enhanced_confidence_models import FieldSource
from app.services.confidence.enhanced_confidence_service import (
    compute_confidence,
)

router = APIRouter()

# ============================================================================
# Compliance constants
# ============================================================================

_DISCLAIMER = (
    "Cet outil est educatif et ne constitue pas un conseil financier, "
    "fiscal ou juridique personnalise. Le score de confiance mesure "
    "la qualite des donnees fournies, pas la fiabilite des projections. "
    "Consulte un-e specialiste pour ta situation personnelle (LSFin art. 3)."
)

_SOURCES = [
    "LPP art. 7 (seuil d'entree: 22'680 CHF)",
    "LPP art. 8 (deduction de coordination: 26'460 CHF)",
    "LPP art. 14 (taux de conversion minimum: 6.8%)",
    "LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)",
    "LAVS art. 29ter (duree cotisation complete: 44 ans)",
    "LAVS art. 34 (rente maximale: 2'520 CHF/mois)",
    "OPP3 art. 7 (plafond 3a: 7'258 CHF / 36'288 CHF)",
    "LIFD art. 38 (imposition du capital de prevoyance)",
]

# Feature gate thresholds (overall confidence score)
_GATE_THRESHOLDS = [
    (30.0, "standard_projections"),
    (50.0, "arbitrage_comparisons"),
    (70.0, "precise_arbitrage"),
    (85.0, "full_precision"),
]


# ============================================================================
# Helpers
# ============================================================================

def _parse_field_sources(raw_sources: list) -> list[FieldSource]:
    """Convert schema FieldSourceSchema list to domain FieldSource list."""
    result = []
    for fs in raw_sources:
        try:
            source_enum = DataSource(fs.source)
        except ValueError:
            source_enum = DataSource.system_estimate
        result.append(FieldSource(
            field_name=fs.field_name,
            source=source_enum,
            updated_at=fs.updated_at,
            value=fs.value,
        ))
    return result


# ============================================================================
# POST /score
# ============================================================================

@router.post("/score", response_model=ConfidenceScoreResponse)
@limiter.limit("30/minute")
def score_confidence(request: Request, body: ConfidenceScoreRequest) -> ConfidenceScoreResponse:
    """Calcule le score de confiance complet sur 4 axes.

    Combine completeness, accuracy, freshness et understanding
    via une moyenne geometrique. Genere les feature gates et classe les
    enrichment prompts par impact decroissant.

    Returns:
        ConfidenceScoreResponse avec breakdown, enrichment_prompts,
        feature_gates, disclaimer et sources legales.
    """
    profile = {k: v for k, v in body.profile.items() if v is not None}
    field_sources = _parse_field_sources(body.field_sources)

    result = compute_confidence(profile, field_sources)

    return ConfidenceScoreResponse(
        breakdown=ConfidenceBreakdownSchema(
            completeness=result.breakdown.completeness,
            accuracy=result.breakdown.accuracy,
            freshness=result.breakdown.freshness,
            understanding=result.breakdown.understanding,
            overall=result.breakdown.overall,
        ),
        enrichment_prompts=[
            EnrichmentPromptSchema(
                field_name=ep.field_name,
                action=ep.action,
                impact_points=ep.impact_points,
                method=ep.method,
                priority=ep.priority,
            )
            for ep in result.enrichment_prompts
        ],
        feature_gates=result.feature_gates,
        disclaimer=_DISCLAIMER,
        sources=_SOURCES,
    )


# ============================================================================
# POST /enrichments
# ============================================================================

@router.post("/enrichments", response_model=EnrichmentResponse)
@limiter.limit("30/minute")
def get_enrichments(request: Request, body: EnrichmentRequest) -> EnrichmentResponse:
    """Retourne les top actions pour ameliorer la precision du profil.

    Classe les actions d'enrichissement par impact decroissant.
    Les actions deja completees sont exclues ou ont un impact reduit.

    Returns:
        EnrichmentResponse avec prompts, current confidence, disclaimer.
    """
    profile = {k: v for k, v in body.profile.items() if v is not None}
    field_sources = _parse_field_sources(body.field_sources)

    result = compute_confidence(profile, field_sources)
    prompts = result.enrichment_prompts[:body.max_prompts]

    return EnrichmentResponse(
        enrichment_prompts=[
            EnrichmentPromptSchema(
                field_name=ep.field_name,
                action=ep.action,
                impact_points=ep.impact_points,
                method=ep.method,
                priority=ep.priority,
            )
            for ep in prompts
        ],
        current_confidence=result.breakdown.overall,
        disclaimer=_DISCLAIMER,
        sources=_SOURCES,
    )


# ============================================================================
# POST /gates
# ============================================================================

@router.post("/gates", response_model=FeatureGatesResponse)
@limiter.limit("30/minute")
def get_feature_gates(request: Request, body: FeatureGatesRequest) -> FeatureGatesResponse:
    """Retourne les fonctionnalites debloquees selon le niveau de confiance.

    Feature gates:
        < 30%:  basic_premier_eclairage_only
        30-50%: + standard_projections
        50-70%: + arbitrage_comparisons (with uncertainty bands)
        70-85%: + precise_arbitrage + fri_scoring
        > 85%:  + full_precision + longitudinal_tracking

    Returns:
        FeatureGatesResponse avec gates, overall, et progression.
    """
    profile = {k: v for k, v in body.profile.items() if v is not None}
    field_sources = _parse_field_sources(body.field_sources)

    result = compute_confidence(profile, field_sources)
    overall = result.breakdown.overall

    # Find next gate to unlock
    next_gate_name = None
    points_to_next = None
    for threshold, gate_name in _GATE_THRESHOLDS:
        if overall < threshold:
            next_gate_name = gate_name
            points_to_next = round(threshold - overall, 1)
            break

    return FeatureGatesResponse(
        feature_gates=result.feature_gates,
        overall_confidence=overall,
        next_gate_name=next_gate_name,
        points_to_next_gate=points_to_next,
        disclaimer=_DISCLAIMER,
    )
