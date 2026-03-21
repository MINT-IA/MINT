"""
Coach Tools — Claude tool-calling definitions for the MINT coach.

This module defines the COACH_TOOLS list, which is passed verbatim to the
Anthropic API as the `tools` parameter on every coach conversation turn.

Each tool follows the Anthropic tool-use schema (name / description /
input_schema).  The Flutter app handles the tool-call result: the backend
returns the raw tool-use block and the mobile client executes the action
(widget render, navigation, data capture).

Architecture notes:
    - The LLM decides *intent*.  Flutter decides *routing* (RoutePlanner +
      ScreenRegistry + ReadinessGate).  The backend never emits a raw route.
    - `context_message` in route_to_screen MUST be educational and
      non-prescriptive (ComplianceGuard validates all LLM output).
    - All tool descriptions are in English (internal, never user-facing).

Sources:
    - docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §6
    - docs/BLUEPRINT_COACH_AI_LAYER.md
"""

from typing import Any

# ---------------------------------------------------------------------------
# Canonical intent tags understood by Flutter RoutePlanner
# ---------------------------------------------------------------------------

ROUTE_TO_SCREEN_INTENT_TAGS: list[str] = [
    "retirement_choice",
    "life_event_divorce",
    "life_event_birth",
    "life_event_marriage",
    "life_event_unemployment",
    "life_event_first_job",
    "budget_overview",
    "tax_optimization_3a",
    "cantonal_comparison",
    "disability_gap",
    "housing_purchase",
    "self_employment",
    "cross_border",
    "lpp_buyback",
    "pillar_3a_overview",
    "job_comparison",
    "debt_check",
    "lamal_franchise",
    "coverage_check",
    "gender_gap",
    "patrimoine_overview",
    "compound_interest",
    "leasing_simulation",
]

# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

COACH_TOOLS: list[dict[str, Any]] = [
    # ─────────────────────────────────────────────────────────────────
    # show_fact_card — inline educational widget
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "show_fact_card",
        "description": (
            "Display an educational fact card inline in the chat. "
            "Use for conceptual explanations, key numbers, or legal references. "
            "Do NOT use when a dedicated MINT screen exists for the topic."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Short title for the fact (max 60 chars).",
                },
                "content": {
                    "type": "string",
                    "description": "Educational content. Must be conditional and non-prescriptive.",
                },
                "source": {
                    "type": "string",
                    "description": "Legal or official source (e.g. 'LPP art. 14', 'LAVS art. 21').",
                },
                "highlight_value": {
                    "type": "string",
                    "description": "Optional key figure to highlight visually (e.g. '6.8%', '30 240 CHF').",
                },
            },
            "required": ["title", "content", "source"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # show_budget_snapshot — inline budget summary widget
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "show_budget_snapshot",
        "description": (
            "Display the user's budget snapshot inline in the chat. "
            "Use when the user asks about their current financial situation, "
            "remaining budget, or monthly overview. "
            "Requires netIncome to be present in the user profile."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "focus_category": {
                    "type": "string",
                    "description": (
                        "Optional category to highlight in the snapshot "
                        "(e.g. 'savings', 'fixed_costs', 'discretionary')."
                    ),
                },
            },
            "required": [],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # show_score_gauge — inline FRI score widget
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "show_score_gauge",
        "description": (
            "Display the user's Financial Readiness Index (FRI) score as an "
            "inline gauge widget. Use when the user asks about their score, "
            "their financial health, or how they are progressing."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "show_breakdown": {
                    "type": "boolean",
                    "description": "Whether to show the 4-axis breakdown (L/F/R/S). Default false.",
                },
            },
            "required": [],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # ask_user_input — request structured data from the user
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "ask_user_input",
        "description": (
            "Ask the user for a specific piece of missing data via a structured "
            "input chip or form. Use when a readiness gate is blocked due to a "
            "missing critical field. Ask only ONE piece of data at a time."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "field_key": {
                    "type": "string",
                    "description": (
                        "The CoachProfile field key being requested "
                        "(e.g. 'salaireBrut', 'age', 'canton', 'avoirLpp')."
                    ),
                },
                "prompt_text": {
                    "type": "string",
                    "description": (
                        "The question to ask the user. Must be short, friendly, "
                        "and non-prescriptive."
                    ),
                },
                "input_type": {
                    "type": "string",
                    "description": (
                        "Input type hint for Flutter: 'number', 'text', "
                        "'canton_picker', 'date', 'chips'. Default 'text'."
                    ),
                },
            },
            "required": ["field_key", "prompt_text"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # route_to_screen — intent-based screen routing
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "route_to_screen",
        "description": (
            "Route the user to a specific MINT screen based on their intent. "
            "The Flutter app will verify readiness before opening. "
            "Use this when the user's question maps to a specific MINT feature "
            "screen (simulator, life event flow, comparison tool). "
            "For simple conceptual questions, use show_fact_card instead. "
            "For budget or score queries, use show_budget_snapshot or "
            "show_score_gauge instead."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "intent": {
                    "type": "string",
                    "description": (
                        "The identified user intent tag. Must be one of the "
                        "registered intent tags: "
                        + ", ".join(ROUTE_TO_SCREEN_INTENT_TAGS)
                    ),
                },
                "confidence": {
                    "type": "number",
                    "description": (
                        "Confidence in the intent identification (0.0 to 1.0). "
                        "Use 0.8+ for clear intents, 0.5-0.8 for probable "
                        "intents. Below 0.5: ask a clarifying question instead "
                        "of routing."
                    ),
                },
                "context_message": {
                    "type": "string",
                    "description": (
                        "A brief message from the coach explaining why this "
                        "screen is relevant. Shown to the user before navigation. "
                        "Must be educational and non-prescriptive. "
                        "Use conditional language ('pourrait', 'dans ce scénario'). "
                        "Never use banned terms (garanti, optimal, tu devrais)."
                    ),
                },
            },
            "required": ["intent", "confidence", "context_message"],
        },
    },
]
