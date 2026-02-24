"""
Backward-compatible model alias for S46 confidence service.

ORCHESTRATOR originally referenced `confidence_models.py`.
Source-of-truth dataclasses live in `enhanced_confidence_models.py`.
"""

from app.services.confidence.enhanced_confidence_models import (  # noqa: F401
    ConfidenceBreakdown,
    ConfidenceResult,
    EnrichmentPrompt,
    FieldSource,
)
