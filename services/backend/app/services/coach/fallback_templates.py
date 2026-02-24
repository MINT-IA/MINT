"""
Fallback Templates — Sprint S35 (Coach Narrative Service).

Deterministic, compliance-safe templates that personalize coach output
using CoachContext WITHOUT any LLM call.

These templates are the ONLY output path until BYOK LLM integration
is available. Even after LLM integration, they serve as fallback when
ComplianceGuard rejects LLM output (use_fallback=True).

Rules:
    - NEVER use banned terms (garanti, certain, optimal, meilleur, etc.)
    - NEVER use prescriptive language (tu devrais, tu dois, il faut)
    - ALWAYS use conditional / educational tone
    - ALWAYS anchor on concrete numbers from CoachContext
    - All text in French (informal "tu")

Sources:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)
"""

from app.services.coach.coach_models import CoachContext


class FallbackTemplates:
    """Deterministic templates for coach narrative components.

    Each method returns a compliant French string personalized
    with data from CoachContext. No LLM involved.
    """

    @staticmethod
    def greeting(ctx: CoachContext) -> str:
        """Generate a personalized greeting.

        Priority:
            1. Fiscal season deadline
            2. Positive FRI delta
            3. Default score display
        """
        if ctx.fiscal_season == "3a_deadline":
            return f"{ctx.first_name}, pense a ton 3a avant la fin de l'annee."

        if ctx.days_since_last_visit == 0:
            return f"Bon retour, {ctx.first_name}."

        if ctx.fri_delta > 0:
            return (
                f"Salut {ctx.first_name}. "
                f"+{ctx.fri_delta:.0f} points depuis ta derniere visite."
            )

        return (
            f"Salut {ctx.first_name}. "
            f"Ton score de solidite : {ctx.fri_total:.0f}/100."
        )

    @staticmethod
    def score_summary(ctx: CoachContext) -> str:
        """Generate a FRI score summary with trend.

        Describes the current score and direction of change.
        """
        if ctx.fri_delta > 0:
            trend = f"En progression de {ctx.fri_delta:.0f} points."
        elif ctx.fri_delta < 0:
            trend = f"En recul de {abs(ctx.fri_delta):.0f} points."
        else:
            trend = "Stable."

        return (
            f"Solidite financiere : {ctx.fri_total:.0f}/100. {trend}"
        )

    @staticmethod
    def tip_narrative(ctx: CoachContext) -> str:
        """Generate an educational tip based on financial indicators.

        Priority:
            1. Tax saving potential > CHF 1'000
            2. Liquidity reserve < 3 months
            3. Replacement ratio < 55%
            4. Default encouragement
        """
        if ctx.tax_saving_potential > 1000:
            chf = f"{ctx.tax_saving_potential:,.0f}".replace(",", "'")
            return (
                f"{ctx.first_name}, un versement 3a pourrait reduire "
                f"ton impot d'environ CHF {chf} cette annee. "
                "Simule l'impact sur ton profil."
            )

        if ctx.months_liquidity < 3:
            return (
                f"Ta reserve de liquidite couvre environ "
                f"{ctx.months_liquidity:.1f} mois. "
                "Un objectif de 3 a 6 mois est souvent "
                "considere comme une base solide."
            )

        if ctx.replacement_ratio < 0.55:
            pct = ctx.replacement_ratio * 100
            return (
                f"Ton taux de remplacement estime a la retraite est de "
                f"{pct:.0f}%. Explore les options "
                "pour combler l'ecart dans le simulateur."
            )

        return (
            f"Ton score de solidite est de {ctx.fri_total:.0f}/100. "
            "Continue a affiner ton profil pour des estimations plus precises."
        )

    @staticmethod
    def chiffre_choc_reframe(ctx: CoachContext) -> str:
        """Reframe a chiffre choc with confidence context.

        Anchors on the confidence score to encourage profile enrichment.
        """
        return (
            f"Ce chiffre est base sur {ctx.confidence_score:.0f}% "
            "de donnees concretes. "
            "Plus tu precises ton profil, plus l'estimation s'affine."
        )
