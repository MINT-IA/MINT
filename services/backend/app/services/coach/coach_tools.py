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
    - `retrieve_memories` is an INTERNAL tool: the backend intercepts
      tool_use blocks with this name, searches the memory_block locally,
      and returns a tool_result so the LLM can continue its response.
      This tool is NEVER forwarded to Flutter.
    - `category` and `access_level` are backend metadata fields.  They are
      NOT sent to the LLM but are used for access control and filtering:
        * get_read_only_tools() strips WRITE tools for low-trust contexts.
        * get_tools_by_category() allows targeted tool injection per flow.

Tool categories (ToolCategory enum):
    NAVIGATE — opens a screen (route_to_screen)
    READ     — displays info inline (show_*, ask_user_input)
    WRITE    — modifies user state (set_goal, mark_step_completed, save_insight)
    SEARCH   — semantic memory search (retrieve_memories)

Sources:
    - docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §6
    - docs/BLUEPRINT_COACH_AI_LAYER.md
"""

from enum import Enum
from typing import Any

# ---------------------------------------------------------------------------
# Tool category — used by backend for access control (never sent to LLM)
# ---------------------------------------------------------------------------


class ToolCategory(str, Enum):
    NAVIGATE = "navigate"  # route_to_screen — opens a screen
    READ = "read"          # show_*, ask_user_input — displays info inline
    WRITE = "write"        # set_goal, mark_step_completed, save_insight — modifies state
    SEARCH = "search"      # retrieve_memories — semantic memory search


# ---------------------------------------------------------------------------
# Internal tools handled by the backend (not forwarded to Flutter)
# ---------------------------------------------------------------------------

INTERNAL_TOOL_NAMES: list[str] = [
    "retrieve_memories",
    "get_budget_status",
    "get_retirement_projection",
    "get_cross_pillar_analysis",
    "get_cap_status",
    "get_couple_optimization",
]

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
        "category": "read",
        "access_level": "user_scoped",
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
        "category": "read",
        "access_level": "user_scoped",
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
        "category": "read",
        "access_level": "user_scoped",
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
        "category": "read",
        "access_level": "user_scoped",
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
    # retrieve_memories — INTERNAL: search user memory (backend-handled)
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "retrieve_memories",
        "category": "search",
        "access_level": "user_scoped",
        "description": (
            "Search the user's conversation memory for past insights, goals, and "
            "screen visits. Use this when the user references something they "
            "discussed before, or when you want to provide continuity from past "
            "sessions. This tool is handled internally by the backend — it never "
            "reaches the Flutter app. The result is injected back into the "
            "conversation so you can use it in your next response."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "topic": {
                    "type": "string",
                    "description": (
                        "The topic to search for in memory (e.g. 'retraite', "
                        "'lpp', 'budget', '3a'). Use the user's own words or "
                        "financial topics."
                    ),
                },
                "max_results": {
                    "type": "integer",
                    "description": (
                        "Maximum number of memory entries to return "
                        "(default 3, max 5)."
                    ),
                    "default": 3,
                },
            },
            "required": ["topic"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # route_to_screen — intent-based screen routing
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "route_to_screen",
        "category": "navigate",
        "access_level": "user_scoped",
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
    # ─────────────────────────────────────────────────────────────────
    # set_goal — WRITE: set the user's active financial goal
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "set_goal",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Set the user's primary financial goal. Use when the user declares "
            "a new focus area or explicitly states a financial objective. "
            "The goal_intent_tag must match a registered intent tag so that "
            "the CapEngine can surface relevant widgets and nudges."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "goal_intent_tag": {
                    "type": "string",
                    "description": (
                        "The goal intent tag identifying the focus area "
                        "(e.g. 'retirement_choice', 'budget_overview', "
                        "'housing_purchase', 'tax_optimization_3a')."
                    ),
                },
                "reason": {
                    "type": "string",
                    "description": (
                        "Brief reason for the goal change, derived from the "
                        "user's own words. Used for memory and continuity."
                    ),
                },
            },
            "required": ["goal_intent_tag"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # mark_step_completed — WRITE: mark a CapSequence step as done
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "mark_step_completed",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Mark a step in the user's financial plan (CapSequence) as "
            "completed or skipped. Use when the user confirms they have taken "
            "an action (e.g. 'I opened my 3a account', 'I skipped the LPP "
            "buyback for now'). Never mark steps without explicit confirmation."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "step_id": {
                    "type": "string",
                    "description": (
                        "The CapSequence step identifier to mark "
                        "(e.g. 'open_3a', 'lpp_buyback_check', 'avs_voluntary')."
                    ),
                },
                "outcome": {
                    "type": "string",
                    "enum": ["completed", "skipped"],
                    "description": (
                        "'completed' if the user has done the step, "
                        "'skipped' if they have decided not to."
                    ),
                },
            },
            "required": ["step_id", "outcome"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # save_insight — WRITE: persist a conversation insight to memory
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "save_insight",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Save an important insight from the current conversation for "
            "future reference. Use when the user shares a key fact, decision, "
            "concern, or goal that should influence future coach responses. "
            "Keep the summary factual and concise (max 200 chars). "
            "Do NOT save PII (names, IBAN, employer, exact address)."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "topic": {
                    "type": "string",
                    "description": (
                        "Short topic label for the insight "
                        "(e.g. 'retraite', 'lpp', 'logement', '3a', 'budget')."
                    ),
                },
                "summary": {
                    "type": "string",
                    "description": (
                        "Brief factual summary of the insight (max 200 chars). "
                        "Use conditional language. No PII."
                    ),
                },
                "type": {
                    "type": "string",
                    "enum": ["goal", "decision", "concern", "fact"],
                    "description": (
                        "Classification of the insight: "
                        "'goal' = user objective, "
                        "'decision' = choice the user has made, "
                        "'concern' = worry or blocker, "
                        "'fact' = factual data point shared by the user."
                    ),
                },
            },
            "required": ["topic", "summary", "type"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # DATA LOOKUP TOOLS — INTERNAL: read pre-computed data from profile_context
    # These tools let the LLM READ the user's financial calculations
    # (budget, retirement, cross-pillar, cap) so it can reason about them.
    # Executed by the backend agent loop, never forwarded to Flutter.
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "get_budget_status",
        "category": "read",
        "access_level": "user_scoped",
        "description": (
            "Get the user's current budget status including monthly free margin, "
            "savings rate, and budget stage. Use when you need to reason about "
            "the user's financial situation, remaining budget, or spending capacity. "
            "Returns structured data as text. This tool is handled internally."
        ),
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "get_retirement_projection",
        "category": "read",
        "access_level": "user_scoped",
        "description": (
            "Get the user's retirement projection including replacement rate, "
            "projected gap, and pillar breakdown. Use when the user asks about "
            "retirement income, pension, or how much they will receive. "
            "Returns structured data as text. This tool is handled internally."
        ),
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "get_cross_pillar_analysis",
        "category": "read",
        "access_level": "user_scoped",
        "description": (
            "Get cross-pillar optimization insights: 3a gap, LPP buyback potential, "
            "tax optimization, and coordination between pillars. Use when the user "
            "asks about optimizing their financial situation across pillars. "
            "Returns structured data as text. This tool is handled internally."
        ),
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "get_cap_status",
        "category": "read",
        "access_level": "user_scoped",
        "description": (
            "Get the user's current Cap du jour (priority action), sequence progress, "
            "and next recommended step. Use when you need to know what the user "
            "should focus on next or their progress toward their financial goal. "
            "Returns structured data as text. This tool is handled internally."
        ),
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "get_couple_optimization",
        "category": "read",
        "access_level": "user_scoped",
        "description": (
            "Get couple-level financial optimization analysis. Compares scenarios "
            "for the user and their partner: who should buy back LPP first, who "
            "should contribute to 3a first (FATCA-aware), AVS couple cap impact, "
            "and marriage penalty analysis. Use when the user is in a couple and "
            "asks about joint financial decisions, partner coordination, or "
            "marriage impact. This tool is handled internally."
        ),
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
]


# ---------------------------------------------------------------------------
# Access-control helpers (backend use only — strip before sending to LLM)
# ---------------------------------------------------------------------------


def get_tools_by_category(category: ToolCategory) -> list[dict[str, Any]]:
    """Return tools filtered by category.

    These dicts include the backend-only 'category' and 'access_level'
    fields.  Strip them before passing to the Anthropic API if needed.
    """
    return [t for t in COACH_TOOLS if t.get("category") == category.value]


def get_read_only_tools() -> list[dict[str, Any]]:
    """Return only read + navigate + search tools (no write tools).

    Use this in low-trust or guest contexts where state mutations must
    be blocked.  Write tools (set_goal, mark_step_completed, save_insight)
    are excluded.
    """
    return [t for t in COACH_TOOLS if t.get("category") != ToolCategory.WRITE.value]


def get_llm_tools() -> list[dict[str, Any]]:
    """Return COACH_TOOLS cleaned for the Anthropic API.

    Uses an ALLOWLIST of fields required by the Anthropic tool-use API
    (name, description, input_schema).  Any backend-only field (category,
    access_level, or future additions) is automatically excluded.

    Always use this function when passing tools to orchestrator.query().
    Never pass COACH_TOOLS raw to the LLM.
    """
    _LLM_ALLOWED_FIELDS = {"name", "description", "input_schema"}
    return [
        {k: v for k, v in tool.items() if k in _LLM_ALLOWED_FIELDS}
        for tool in COACH_TOOLS
    ]
