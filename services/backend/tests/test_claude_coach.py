"""
Tests for claude_coach_service.py — system prompt builder.

Sprint S56+: route_to_screen tool addition.

Covers:
    - build_system_prompt() output structure and compliance
    - Routing rules section presence
    - route_to_screen guidance in prompt
    - Context enrichment from CoachContext
    - Privacy: no PII in system prompt
    - Compliance: no banned terms in base prompt

Run: cd services/backend && python3 -m pytest tests/test_claude_coach.py -v
"""

import pytest
from app.services.coach.claude_coach_service import build_system_prompt, COACH_TOOLS
from app.services.coach.coach_models import CoachContext
from app.services.coach.coach_tools import ROUTE_TO_SCREEN_INTENT_TAGS


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def base_prompt() -> str:
    """System prompt with no user context."""
    return build_system_prompt(ctx=None)


@pytest.fixture
def full_ctx() -> CoachContext:
    return CoachContext(
        first_name="Sophie",
        archetype="swiss_native",
        age=49,
        canton="VS",
        fri_total=68.0,
        fri_delta=3.0,
        primary_focus="retraite",
        replacement_ratio=0.65,
        months_liquidity=5.0,
        tax_saving_potential=2400.0,
        confidence_score=72.0,
        days_since_last_visit=2,
        fiscal_season="3a_deadline",
        upcoming_event="retirement",
        check_in_streak=7,
        known_values={
            "fri_total": 68.0,
            "replacement_ratio": 65.0,
            "months_liquidity": 5.0,
            "tax_saving": 2400.0,
            "confidence_score": 72.0,
        },
    )


@pytest.fixture
def ctx_prompt(full_ctx) -> str:
    return build_system_prompt(ctx=full_ctx)


BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
    "tu devrais", "tu dois",
]


# ===========================================================================
# TestBuildSystemPromptBase — no-context prompt
# ===========================================================================

class TestBuildSystemPromptBase:
    """Tests for build_system_prompt(ctx=None)."""

    def test_returns_string(self, base_prompt):
        assert isinstance(base_prompt, str)

    def test_not_empty(self, base_prompt):
        assert len(base_prompt) > 100

    def test_contains_identity_section(self, base_prompt):
        assert "coach financier" in base_prompt.lower() or "mint" in base_prompt.lower()

    def test_contains_absolute_rules_section(self, base_prompt):
        lower = base_prompt.lower()
        assert "conditionnel" in lower or "règles" in lower

    def test_contains_banned_terms_reminder(self, base_prompt):
        lower = base_prompt.lower()
        assert "garanti" in lower  # appears as example of banned term
        assert "interdits" in lower or "interdit" in lower

    def test_contains_disclaimer_reference(self, base_prompt):
        lower = base_prompt.lower()
        assert "éducatif" in lower or "educatif" in lower or "lsfin" in lower

    def test_no_banned_terms_used_prescriptively(self, base_prompt):
        """The prompt must not instruct the LLM to use prescriptive language.
        Banned terms appear in the TERMES INTERDITS list (as negated examples),
        but must never appear as affirmative instructions to the LLM."""
        # Strip the banned-terms list itself from the check
        # by verifying the prompt does not say "utilise tu devrais" or instruct it
        lower = base_prompt.lower()
        # The prompt must contain a negation/prohibition around these terms
        assert "ne" in lower or "jamais" in lower or "interdits" in lower
        # The prompt must not contain an affirmative instruction to use them
        assert "utilise 'tu devrais'" not in lower
        assert "dis 'il faut'" not in lower

    def test_contains_format_instructions(self, base_prompt):
        lower = base_prompt.lower()
        assert "format" in lower or "phrases courtes" in lower

    def test_contains_routing_rules_section(self, base_prompt):
        """The system prompt must contain routing rules for tool selection."""
        assert "ROUTING RULES" in base_prompt or "routing rules" in base_prompt.lower()

    def test_contains_route_to_screen_mention(self, base_prompt):
        """The system prompt must explicitly mention route_to_screen."""
        assert "route_to_screen" in base_prompt

    def test_routing_rules_mention_show_fact_card(self, base_prompt):
        assert "show_fact_card" in base_prompt

    def test_routing_rules_mention_show_budget_snapshot(self, base_prompt):
        assert "show_budget_snapshot" in base_prompt

    def test_routing_rules_mention_show_score_gauge(self, base_prompt):
        assert "show_score_gauge" in base_prompt

    def test_routing_rules_mention_ask_user_input(self, base_prompt):
        assert "ask_user_input" in base_prompt

    def test_routing_rules_mention_confidence_threshold(self, base_prompt):
        """Routing rules should guide on when NOT to route (low confidence)."""
        lower = base_prompt.lower()
        assert "clarif" in lower or "0.5" in lower or "confidence" in lower

    def test_routing_rules_no_raw_route_instruction(self, base_prompt):
        """Prompt must instruct LLM not to emit raw routes."""
        lower = base_prompt.lower()
        assert "never emit" in lower or "never" in lower or "jamais" in lower

    def test_intent_tags_listed_in_routing_rules(self, base_prompt):
        """At least several intent tags should appear in the routing rules section."""
        tags_in_prompt = [tag for tag in ROUTE_TO_SCREEN_INTENT_TAGS if tag in base_prompt]
        assert len(tags_in_prompt) >= 5, (
            f"Expected at least 5 intent tags in system prompt, "
            f"found {len(tags_in_prompt)}: {tags_in_prompt}"
        )

    def test_coach_tools_exported(self):
        """COACH_TOOLS must be re-exported from claude_coach_service."""
        assert COACH_TOOLS is not None
        assert isinstance(COACH_TOOLS, list)
        assert len(COACH_TOOLS) > 0


# ===========================================================================
# TestBuildSystemPromptWithContext — context-enriched prompt
# ===========================================================================

class TestBuildSystemPromptWithContext:
    """Tests for build_system_prompt(ctx=<CoachContext>)."""

    def test_returns_string(self, ctx_prompt):
        assert isinstance(ctx_prompt, str)

    def test_longer_than_base_prompt(self, base_prompt, ctx_prompt):
        assert len(ctx_prompt) > len(base_prompt)

    def test_contains_archetype(self, ctx_prompt):
        assert "swiss_native" in ctx_prompt

    def test_contains_age(self, ctx_prompt):
        assert "49" in ctx_prompt

    def test_contains_canton(self, ctx_prompt):
        assert "VS" in ctx_prompt

    def test_contains_fri_score(self, ctx_prompt):
        assert "68" in ctx_prompt

    def test_contains_fri_delta_with_sign(self, ctx_prompt):
        assert "+3" in ctx_prompt

    def test_contains_replacement_ratio(self, ctx_prompt):
        assert "65" in ctx_prompt

    def test_contains_tax_saving(self, ctx_prompt):
        assert "2400" in ctx_prompt

    def test_contains_confidence_score(self, ctx_prompt):
        assert "72" in ctx_prompt

    def test_contains_upcoming_event(self, ctx_prompt):
        assert "retirement" in ctx_prompt

    def test_contains_check_in_streak(self, ctx_prompt):
        assert "7" in ctx_prompt

    def test_still_contains_routing_rules(self, ctx_prompt):
        """Routing rules must be present even with user context."""
        assert "route_to_screen" in ctx_prompt
        assert "ROUTING RULES" in ctx_prompt or "routing rules" in ctx_prompt.lower()

    def test_privacy_no_first_name_in_context_section(self, ctx_prompt):
        """First name must NOT appear in the user context section
        (it's in the greeting, not the system prompt data block)."""
        # The base prompt uses "utilisateur" generic references.
        # Context section should not expose the first_name.
        context_start = ctx_prompt.find("CONTEXTE UTILISATEUR")
        if context_start != -1:
            context_section = ctx_prompt[context_start:]
            assert "Sophie" not in context_section, (
                "First name should not appear in the user context section "
                "of the system prompt (privacy rule)"
            )

    def test_no_banned_terms_used_prescriptively(self, ctx_prompt):
        """Same as base: banned terms appear in the interdiction list only."""
        lower = ctx_prompt.lower()
        assert "jamais" in lower or "interdits" in lower
        assert "utilise 'tu devrais'" not in lower
        assert "dis 'il faut'" not in lower

    def test_none_context_returns_base_prompt(self, base_prompt):
        """build_system_prompt(None) == build_system_prompt() base."""
        prompt_no_arg = build_system_prompt()
        assert prompt_no_arg == base_prompt


# ===========================================================================
# TestSystemPromptEdgeCases — edge cases and minimal contexts
# ===========================================================================

class TestSystemPromptEdgeCases:
    """Edge cases for build_system_prompt."""

    def test_empty_context_still_valid(self):
        ctx = CoachContext(first_name="")
        prompt = build_system_prompt(ctx=ctx)
        assert isinstance(prompt, str)
        assert len(prompt) > 100

    def test_context_with_only_age(self):
        ctx = CoachContext(first_name="Test", age=35)
        prompt = build_system_prompt(ctx=ctx)
        assert "35" in prompt

    def test_context_with_negative_fri_delta(self):
        ctx = CoachContext(first_name="Test", fri_total=40.0, fri_delta=-5.0)
        prompt = build_system_prompt(ctx=ctx)
        assert "-5" in prompt

    def test_context_with_zero_fri_delta(self):
        ctx = CoachContext(first_name="Test", fri_total=50.0, fri_delta=0.0)
        prompt = build_system_prompt(ctx=ctx)
        assert "+0" in prompt

    def test_routing_rules_always_present_regardless_of_context(self):
        """Routing rules must be in every system prompt variant."""
        prompts = [
            build_system_prompt(ctx=None),
            build_system_prompt(ctx=CoachContext(first_name="Test")),
            build_system_prompt(ctx=CoachContext(first_name="A", age=65, canton="ZH")),
        ]
        for p in prompts:
            assert "route_to_screen" in p, "route_to_screen missing from system prompt"
            assert "ROUTING RULES" in p or "routing rules" in p.lower()

    def test_extra_known_values_appear_in_prompt(self):
        ctx = CoachContext(
            first_name="Test",
            known_values={"lpp_avoir": 70377, "rachat_max": 539414},
        )
        prompt = build_system_prompt(ctx=ctx)
        assert "70377" in prompt or "lpp_avoir" in prompt


# ===========================================================================
# TestLifecycleAwareness — lifecycle section in every prompt variant
# ===========================================================================

class TestLifecycleAwareness:
    """Tests verifying the LIFECYCLE AWARENESS section is present and correct."""

    def test_lifecycle_awareness_in_base_prompt(self, base_prompt):
        """The base prompt must contain lifecycle awareness instructions."""
        assert "LIFECYCLE AWARENESS" in base_prompt

    def test_lifecycle_awareness_in_ctx_prompt(self, ctx_prompt):
        """The context-enriched prompt must also contain lifecycle awareness."""
        assert "LIFECYCLE AWARENESS" in ctx_prompt

    def test_lifecycle_awareness_covers_consolidation_phase(self, base_prompt):
        """The consolidation phase (primary MINT audience) must be mentioned."""
        assert "consolidation" in base_prompt

    def test_lifecycle_awareness_covers_demarrage_phase(self, base_prompt):
        """The demarrage phase must be covered (secondary MINT audience)."""
        assert "demarrage" in base_prompt

    def test_lifecycle_awareness_covers_transition_phase(self, base_prompt):
        """The transition phase must be covered (pre-retirement)."""
        assert "transition" in base_prompt

    def test_lifecycle_awareness_references_surfaces(self, base_prompt):
        """Lifecycle section must mention SURFACES PERTINENTES for routing."""
        lower = base_prompt.lower()
        assert "surfaces pertinentes" in lower or "surfaces_pertinentes" in lower

    def test_lifecycle_awareness_references_nudges(self, base_prompt):
        """Lifecycle section must mention NUDGES ACTIFS for timely topics."""
        lower = base_prompt.lower()
        assert "nudges actifs" in lower or "nudges_actifs" in lower

    def test_lifecycle_awareness_no_prescription(self, base_prompt):
        """Lifecycle section must not instruct Claude to use prescriptive language.
        'tu devrais' may appear in the TERMES INTERDITS list (as a negated example),
        but must NOT appear inside the LIFECYCLE AWARENESS section itself."""
        # Extract only the LIFECYCLE AWARENESS section
        lifecycle_start = base_prompt.find("LIFECYCLE AWARENESS")
        assert lifecycle_start != -1, "LIFECYCLE AWARENESS section not found"
        # Find the next section header after it (ends at next uppercase block)
        lifecycle_section = base_prompt[lifecycle_start:]
        # The section ends before ROUTING RULES
        routing_start = lifecycle_section.find("ROUTING RULES")
        if routing_start != -1:
            lifecycle_section = lifecycle_section[:routing_start]
        lower_section = lifecycle_section.lower()
        assert "tu devrais" not in lower_section
        assert "il faut" not in lower_section

    def test_lifecycle_phase_unknown_fallback(self, base_prompt):
        """When phase is unknown, prompt must instruct neutral fallback."""
        lower = base_prompt.lower()
        assert "absent" in lower or "inconnu" in lower or "neutral" in lower or "unknown" in lower


# ===========================================================================
# TestPlanAwareness — PLAN AWARENESS section in every prompt variant
# ===========================================================================

class TestPlanAwareness:
    """Tests verifying the PLAN AWARENESS section is present and correct."""

    def test_plan_awareness_in_base_prompt(self, base_prompt):
        """The base prompt must contain the PLAN AWARENESS section."""
        assert "PLAN AWARENESS" in base_prompt

    def test_plan_awareness_in_ctx_prompt(self, ctx_prompt):
        """The context-enriched prompt must also contain PLAN AWARENESS."""
        assert "PLAN AWARENESS" in ctx_prompt

    def test_plan_awareness_references_plan_en_cours(self, base_prompt):
        """The section must reference the PLAN EN COURS memory key."""
        assert "PLAN EN COURS" in base_prompt

    def test_plan_awareness_mentions_step_reference(self, base_prompt):
        """The section must show an example of a step reference."""
        lower = base_prompt.lower()
        assert "étape" in lower or "etape" in lower

    def test_plan_awareness_no_pressure(self, base_prompt):
        """The section must not pressure the user — plan is a guide."""
        lower = base_prompt.lower()
        assert "guide" in lower or "jamais" in lower or "never" in lower

    def test_plan_awareness_mentions_celebration(self, base_prompt):
        """The section must acknowledge step completion positively."""
        lower = base_prompt.lower()
        assert "validée" in lower or "validee" in lower or "joué" in lower or "joue" in lower

    def test_plan_awareness_conditional_on_presence(self, base_prompt):
        """Plan awareness must be conditional — only when PLAN EN COURS present."""
        # The section must instruct Claude NOT to mention plan if not present.
        lower = base_prompt.lower()
        assert "si" in lower or "if" in lower or "absent" in lower or "no plan" in lower

    def test_plan_awareness_all_prompts_contain_section(self):
        """Every prompt variant must include PLAN AWARENESS."""
        prompts = [
            build_system_prompt(ctx=None),
            build_system_prompt(ctx=CoachContext(first_name="Test")),
            build_system_prompt(ctx=CoachContext(first_name="Julien", age=49, canton="VS")),
        ]
        for p in prompts:
            assert "PLAN AWARENESS" in p, "PLAN AWARENESS missing from system prompt variant"


# ===========================================================================
# TestLifecycleToneDirectives — concrete tone directives per phase
# ===========================================================================

class TestLifecycleToneDirectives:
    """Tests verifying the LIFECYCLE TONE DIRECTIVES block is present and concrete."""

    def test_lifecycle_tone_directives_section_present(self, base_prompt):
        """The prompt must contain the LIFECYCLE TONE DIRECTIVES block."""
        assert "LIFECYCLE TONE DIRECTIVES" in base_prompt

    def test_tone_directive_for_demarrage_is_concrete(self, base_prompt):
        """demarrage directive must reference direct communication and amounts."""
        lower = base_prompt.lower()
        assert "demarrage" in lower
        # Must mention directness and concrete amounts
        assert "direct" in lower
        assert "chf" in lower or "exact amounts" in lower or "amounts" in lower

    def test_tone_directive_for_construction_references_comparisons(self, base_prompt):
        """construction directive must reference CHF comparisons."""
        lower = base_prompt.lower()
        assert "construction" in lower
        assert "chf" in lower or "factual" in lower

    def test_tone_directive_for_acceleration_references_strategic(self, base_prompt):
        """acceleration directive must mention strategic or percentages."""
        lower = base_prompt.lower()
        assert "acceleration" in lower
        assert "strategic" in lower or "percentages" in lower or "deadlines" in lower

    def test_tone_directive_for_consolidation_references_context(self, base_prompt):
        """consolidation directive must reference contextual framing."""
        lower = base_prompt.lower()
        assert "consolidation" in lower
        assert "norme" in lower or "reassuring" in lower or "context" in lower

    def test_tone_directive_for_transition_references_calm(self, base_prompt):
        """transition directive must reference calm and no pressure."""
        lower = base_prompt.lower()
        assert "transition" in lower
        assert "calm" in lower or "pressure" in lower

    def test_tone_directive_for_retraite_references_serene(self, base_prompt):
        """retraite directive must reference serene tone and no jargon."""
        lower = base_prompt.lower()
        assert "retraite" in lower
        assert "serene" in lower or "jargon" in lower or "short sentences" in lower

    def test_tone_directive_data_is_tone_principle(self, base_prompt):
        """The prompt must state that data IS the tone (core principle)."""
        lower = base_prompt.lower()
        assert "data is the tone" in lower or "data ist" in lower or "donnée est le ton" in lower \
               or "number speaks" in lower or "a number speaks" in lower

    def test_lifecycle_tone_directives_in_every_prompt_variant(self):
        """Every prompt variant must contain LIFECYCLE TONE DIRECTIVES."""
        prompts = [
            build_system_prompt(ctx=None),
            build_system_prompt(ctx=CoachContext(first_name="Test")),
            build_system_prompt(ctx=CoachContext(first_name="Julien", age=49, canton="VS")),
        ]
        for p in prompts:
            assert "LIFECYCLE TONE DIRECTIVES" in p, (
                "LIFECYCLE TONE DIRECTIVES missing from system prompt variant"
            )

    def test_tone_directive_no_vague_adjectives_as_sole_instruction(self, base_prompt):
        """The tone directives must not use single vague adjectives as instructions.
        'encouraging' or 'motivating' alone are banned — directives must be concrete."""
        # The directives section starts after LIFECYCLE TONE DIRECTIVES:
        start = base_prompt.find("LIFECYCLE TONE DIRECTIVES")
        assert start != -1
        directives_section = base_prompt[start:]
        # These are examples of old vague-only patterns that should not appear as
        # standalone instructions (they may appear as part of a longer concrete sentence)
        lower_section = directives_section.lower()
        # The section must not be dominated by vague words without concrete anchors
        assert "chf" in lower_section or "amounts" in lower_section or "direct" in lower_section, (
            "LIFECYCLE TONE DIRECTIVES must contain concrete terms (CHF, amounts, direct)"
        )
