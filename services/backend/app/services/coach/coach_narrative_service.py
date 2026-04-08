"""
Coach Narrative Service — Sprint S35.

Generates 4 independent personalized narrative components:
    1. greeting — Dashboard welcome message
    2. score_summary — FRI score explanation
    3. tip_narrative — Actionable educational tip
    4. premier_eclairage_reframe — Confidence-anchored reframe

Architecture:
    - Currently uses FallbackTemplates (deterministic, no LLM).
    - Each component passes through ComplianceGuard validation.
    - When BYOK LLM is integrated, LLM output will be validated first;
      fallback templates are used when ComplianceGuard rejects LLM output.

Rules:
    - No banned terms (garanti, certain, optimal, etc.)
    - No prescriptive language (tu devrais, tu dois, il faut)
    - Educational tone, conditional language
    - Disclaimer on every response
    - All text in French (informal "tu")

Sources:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)
    - FINMA circular 2008/21 (operational risk)
"""

from app.services.coach.coach_models import (
    CoachContext,
    CoachNarrativeResult,
    ComponentType,
)
from app.services.coach.compliance_guard import ComplianceGuard
from app.services.coach.fallback_templates import FallbackTemplates


STANDARD_DISCLAIMER = (
    "Outil educatif simplifie. "
    "Ne constitue pas un conseil financier (LSFin)."
)

STANDARD_SOURCES = [
    "LSFin art. 3 (information financiere)",
    "LPD art. 6 (protection des donnees)",
]


class CoachNarrativeService:
    """Generates personalized, compliance-validated coach narratives.

    Each generate_* method:
        1. Produces text via FallbackTemplates (deterministic).
        2. Validates through ComplianceGuard.
        3. Falls back to template if guard rejects (should not happen
           for deterministic templates, but safety net is in place).
    """

    def __init__(self):
        self._guard = ComplianceGuard()

    def generate_greeting(self, ctx: CoachContext) -> str:
        """Generate a personalized dashboard greeting.

        Args:
            ctx: CoachContext with user data.

        Returns:
            Compliant greeting string (max 30 words).
        """
        text = FallbackTemplates.greeting(ctx)
        result = self._guard.validate(
            text, context=ctx, component_type=ComponentType.greeting
        )
        if result.use_fallback:
            # Template should always be compliant; this is a safety net
            return FallbackTemplates.greeting(ctx)
        return result.sanitized_text

    def generate_score_summary(self, ctx: CoachContext) -> str:
        """Generate FRI score summary with trend.

        Args:
            ctx: CoachContext with FRI data.

        Returns:
            Compliant score summary string (max 80 words).
        """
        text = FallbackTemplates.score_summary(ctx)
        result = self._guard.validate(
            text, context=ctx, component_type=ComponentType.score_summary
        )
        if result.use_fallback:
            return FallbackTemplates.score_summary(ctx)
        return result.sanitized_text

    def generate_tip_narrative(self, ctx: CoachContext) -> str:
        """Generate an educational tip based on financial indicators.

        Args:
            ctx: CoachContext with financial indicators.

        Returns:
            Compliant tip string (max 120 words).
        """
        text = FallbackTemplates.tip_narrative(ctx)
        result = self._guard.validate(
            text, context=ctx, component_type=ComponentType.tip
        )
        if result.use_fallback:
            return FallbackTemplates.tip_narrative(ctx)
        return result.sanitized_text

    def generate_premier_eclairage_reframe(self, ctx: CoachContext) -> str:
        """Generate premier éclairage reframe anchored on confidence score.

        Args:
            ctx: CoachContext with confidence_score.

        Returns:
            Compliant reframe string (max 100 words).
        """
        text = FallbackTemplates.premier_eclairage_reframe(ctx)
        result = self._guard.validate(
            text, context=ctx, component_type=ComponentType.premier_eclairage
        )
        if result.use_fallback:
            return FallbackTemplates.premier_eclairage_reframe(ctx)
        return result.sanitized_text

    def generate_all(self, ctx: CoachContext) -> CoachNarrativeResult:
        """Generate all 4 components independently.

        Each component is generated and validated separately.
        Failure in one component does not affect others.

        Args:
            ctx: CoachContext with all user data.

        Returns:
            CoachNarrativeResult with all 4 components + metadata.
        """
        greeting = self.generate_greeting(ctx)
        score_summary = self.generate_score_summary(ctx)
        tip_narrative = self.generate_tip_narrative(ctx)
        premier_eclairage_reframe = self.generate_premier_eclairage_reframe(ctx)

        return CoachNarrativeResult(
            greeting=greeting,
            score_summary=score_summary,
            tip_narrative=tip_narrative,
            premier_eclairage_reframe=premier_eclairage_reframe,
            used_fallback={
                "greeting": True,
                "score_summary": True,
                "tip_narrative": True,
                "premier_eclairage_reframe": True,
            },
            disclaimer=STANDARD_DISCLAIMER,
            sources=list(STANDARD_SOURCES),
        )
