"""
Coach services — Sprint S34 (Compliance Guard).

Provides compliance validation, hallucination detection, and prompt registry
for all LLM-generated coach outputs. This is a BLOCKER for any LLM feature.

No LLM output reaches the user without passing through ComplianceGuard.
"""

from app.services.coach.coach_models import (
    ComplianceResult,
    CoachContext,
    HallucinatedNumber,
    ComponentType,
)
from app.services.coach.compliance_guard import ComplianceGuard
from app.services.coach.hallucination_detector import HallucinationDetector
from app.services.coach.prompt_registry import PromptRegistry

__all__ = [
    "ComplianceResult",
    "CoachContext",
    "HallucinatedNumber",
    "ComponentType",
    "ComplianceGuard",
    "HallucinationDetector",
    "PromptRegistry",
]
