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
    "get_regulatory_constant",
    # STAB-12 (07-04 / AUDIT_COACH_WIRING rows 7-9): these three tools have
    # no Flutter renderer case — they are backend-only acknowledgements that
    # let the LLM track state ("goal set", "step done", "insight saved")
    # without rendering a widget. Marking them internal prevents silent
    # drop at the mobile renderer. Persistence is deferred to v3.0 memory
    # layer; for now the backend returns an acknowledgement string so the
    # agent loop can continue without dead-end tool calls.
    "set_goal",
    "mark_step_completed",
    "save_insight",
    # P14 commitment devices: ack-only handlers (persistence via dedicated endpoint in Plan 02)
    "record_commitment",
    "save_pre_mortem",
    # P15 coach intelligence: provenance and earmark tools (persist immediately)
    "save_provenance",
    "save_earmark",
    "remove_earmark",
    # P16 couple mode: save_partner_estimate / update_partner_estimate are
    # Flutter-bound tools (intercepted by widget_renderer for SecureStorage).
    # They MUST NOT appear here — routing through INTERNAL_TOOL_NAMES would
    # prevent Flutter from receiving them. See COUP-01/COUP-04.
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
    "expert_consultation",
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
                "prefill": {
                    "type": "object",
                    "description": (
                        "Optional key-value map of profile fields to pre-populate the "
                        "target screen. Keys match CoachProfile field names: "
                        "avoirLppTotal, salaireBrutMensuel, tauxConversion, ageRetraite, "
                        "canton, epargneLiquide, rachatMaximum. "
                        "Only include fields with confirmed values from the user's profile "
                        "context. Omit entirely if no values are known."
                    ),
                    "additionalProperties": True,
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
    # ─────────────────────────────────────────────────────────────────
    # get_regulatory_constant — INTERNAL: look up Swiss regulatory constants
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "get_regulatory_constant",
        "category": "read",
        "access_level": "user_scoped",
        "description": (
            "Look up a Swiss financial regulatory constant from the official "
            "registry (LPP, AVS, 3a, mortgage, capital tax, LAMal, etc.). "
            "Use this when you need an exact legal value to answer the user's "
            "question — for example pillar 3a limits, LPP conversion rate, AVS "
            "pension amounts, or cantonal capital withdrawal tax rates. "
            "This tool is handled internally by the backend."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "key": {
                    "type": "string",
                    "description": (
                        "The constant key, e.g. 'pillar3a.max_with_lpp', "
                        "'avs.max_monthly_pension', 'lpp.conversion_rate', "
                        "'mortgage.theoretical_rate', 'capital_tax.cantonal.VS'. "
                        "Use dotted notation matching the registry keys."
                    ),
                },
                "canton": {
                    "type": "string",
                    "description": (
                        "Canton code for cantonal parameters (e.g. 'VS', 'ZH', 'GE'). "
                        "Only needed for capital_tax.cantonal.* keys. Optional."
                    ),
                },
            },
            "required": ["key"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # record_check_in — WRITE: record monthly contributions check-in
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "record_check_in",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Record the user's monthly check-in contributions. "
            "Use ONLY after the user has answered all contribution questions for the current month. "
            "Displays a summary card in chat and persists data to the user's profile. "
            "Never call this tool preemptively — wait for the user to provide actual amounts."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "month": {
                    "type": "string",
                    "description": "ISO month string YYYY-MM (e.g. '2026-04')",
                },
                "versements": {
                    "type": "object",
                    "description": (
                        "Map of contribution_id to amount in CHF "
                        "(e.g. {'3a_julien': 500.0, 'epargne_libre': 200.0})"
                    ),
                },
                "summary_message": {
                    "type": "string",
                    "description": (
                        "Coach summary to display to user "
                        "(e.g. 'Parfait, 500 CHF sur le 3a et 200 CHF en épargne libre. C'est noté\u00a0!')"
                    ),
                },
            },
            "required": ["month", "versements", "summary_message"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # generate_financial_plan — WRITE: calculator-backed plan generation (Flutter-bound)
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "generate_financial_plan",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Generate a personalized financial plan based on the user's goal. "
            "The plan is computed by Flutter-side calculators (financial_core), "
            "NOT by the LLM. Only the narrative field may come from the coach. "
            "Use when the user asks for a plan, a roadmap, or a strategy to "
            "reach a financial goal. This tool is forwarded to Flutter for "
            "execution — the backend does NOT generate the plan itself."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "goal": {
                    "type": "string",
                    "description": (
                        "Human-readable description of the financial goal "
                        "(e.g. 'Acheter un appartement \u00e0 Sion', "
                        "'Optimiser mon 3e pilier', 'Constituer un fonds d\u2019urgence')."
                    ),
                },
                "monthly_amount": {
                    "type": "number",
                    "description": (
                        "Suggested monthly contribution in CHF. This is a coaching "
                        "suggestion \u2014 the actual plan amount is computed by calculators."
                    ),
                },
                "milestones": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": (
                        "List of milestone descriptions for the plan "
                        "(e.g. ['Ouvrir un compte 3a', 'Premier versement', "
                        "'Atteindre 7258 CHF/an'])."
                    ),
                },
                "projected_outcome": {
                    "type": "string",
                    "description": (
                        "Brief projected outcome description using conditional "
                        "language. Must include a disclaimer that this is "
                        "educational, not a guarantee."
                    ),
                },
                "narrative": {
                    "type": "string",
                    "description": (
                        "Coach narrative explaining the plan in human terms. "
                        "Must be educational and non-prescriptive. "
                        "Use conditional language ('pourrait', 'dans ce sc\u00e9nario')."
                    ),
                },
            },
            "required": ["goal", "narrative"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # generate_document — WRITE: pre-filled document generation (Flutter-bound)
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "generate_document",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Generate a pre-filled document for the user (fiscal declaration prep, "
            "pension fund letter, LPP buyback request). The document is read-only "
            "— MINT never submits it. The user reviews and uses it independently. "
            "Use when the user asks about preparing a tax declaration, writing to "
            "their pension fund, or requesting an LPP buyback. "
            "This tool is forwarded to Flutter for execution — the backend does "
            "NOT generate the document itself."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "document_type": {
                    "type": "string",
                    "enum": [
                        "fiscal_declaration",
                        "pension_fund_letter",
                        "lpp_buyback_request",
                    ],
                    "description": (
                        "Type of document to generate: "
                        "'fiscal_declaration' = pre-filled tax declaration fields, "
                        "'pension_fund_letter' = formal letter to pension fund, "
                        "'lpp_buyback_request' = LPP buyback request form."
                    ),
                },
                "context": {
                    "type": "string",
                    "description": (
                        "Brief summary of what the user asked for, used to "
                        "customize the document generation. Do not include PII."
                    ),
                },
            },
            "required": ["document_type", "context"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # record_commitment — WRITE/INTERNAL: persist implementation intention
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "record_commitment",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Record an implementation intention (WHEN/WHERE/IF-THEN) after a "
            "Layer 4 insight. The backend acknowledges and persists the commitment. "
            "This tool is handled internally by the backend."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "when_text": {
                    "type": "string",
                    "description": (
                        "WHEN part of the intention "
                        "(e.g. 'Ce lundi, quand tu recevras ta fiche de paie')."
                    ),
                },
                "where_text": {
                    "type": "string",
                    "description": (
                        "WHERE part of the intention "
                        "(e.g. 'Sur ton app bancaire 3a')."
                    ),
                },
                "if_then_text": {
                    "type": "string",
                    "description": (
                        "IF-THEN part of the intention "
                        "(e.g. 'Si le solde est insuffisant pour 604 CHF, verse au moins 200 CHF')."
                    ),
                },
                "reminder_at": {
                    "type": "string",
                    "description": (
                        "Optional ISO 8601 datetime for a reminder "
                        "(e.g. '2026-04-15T09:00:00Z'). Omit if no reminder needed."
                    ),
                },
            },
            "required": ["when_text", "where_text", "if_then_text"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # save_pre_mortem — WRITE/INTERNAL: persist pre-mortem risk scenario
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "save_pre_mortem",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Save a pre-mortem risk scenario before an irrevocable financial "
            "decision (EPL, capital withdrawal, 3a closure). The backend "
            "acknowledges and persists the entry. This tool is handled internally."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "decision_type": {
                    "type": "string",
                    "enum": ["epl", "capital_withdrawal", "pillar_3a_closure"],
                    "description": (
                        "Type of irrevocable decision: "
                        "'epl' = EPL (retrait anticipé 2e pilier pour achat immobilier), "
                        "'capital_withdrawal' = retrait en capital du 2e pilier, "
                        "'pillar_3a_closure' = clôture du 3e pilier."
                    ),
                },
                "decision_context": {
                    "type": "string",
                    "description": (
                        "Optional context about the decision being considered "
                        "(e.g. 'Achat appartement à Sion, EPL de 50k envisagé')."
                    ),
                },
                "user_response": {
                    "type": "string",
                    "description": (
                        "The user's response to the pre-mortem prompt: what could "
                        "go wrong if this decision turns out badly."
                    ),
                },
            },
            "required": ["decision_type", "user_response"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # save_provenance — WRITE/INTERNAL: record who recommended a financial product
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "save_provenance",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Record who recommended a financial product to the user. "
            "Call when the user mentions who proposed or sold them a product "
            "(3a, LPP, assurance, hypotheque). Internal — handled by backend."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "product_type": {
                    "type": "string",
                    "description": "Type of financial product: '3a', 'lpp', 'assurance_vie', 'hypotheque', 'placement', 'prevoyance', 'autre'.",
                },
                "recommended_by": {
                    "type": "string",
                    "description": "Who recommended the product (e.g. 'mon banquier', 'un ami', 'Uncle Patrick').",
                },
                "institution": {
                    "type": "string",
                    "description": "Optional: financial institution (e.g. 'UBS', 'PostFinance', 'Swiss Life').",
                },
            },
            "required": ["product_type", "recommended_by"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # save_earmark — WRITE/INTERNAL: tag money with relational/emotional meaning
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "save_earmark",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Tag a sum of money with its relational or emotional origin. "
            "Call when the user associates money with a person, event, or purpose "
            "('l'argent de mamie', 'le compte pour les enfants', 'mon heritage'). "
            "Internal — handled by backend."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "label": {
                    "type": "string",
                    "description": "The earmark label as the user expressed it (e.g. 'l'argent de mamie').",
                },
                "source_description": {
                    "type": "string",
                    "description": "Optional context about the origin (e.g. 'heritage de grand-mere en 2019').",
                },
                "amount_hint": {
                    "type": "string",
                    "description": "Optional approximate amount as expressed by user (e.g. 'environ 50k', '~30000').",
                },
            },
            "required": ["label"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # remove_earmark — WRITE/INTERNAL: delete an earmark tag by label
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "remove_earmark",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Remove an earmark tag when the user asks to forget it. "
            "Call when user says 'oublie le tag sur l'argent de mamie' or similar. "
            "Internal — handled by backend."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "label": {
                    "type": "string",
                    "description": "The earmark label to remove (e.g. 'l'argent de mamie').",
                },
            },
            "required": ["label"],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # save_partner_estimate — WRITE/INTERNAL (ack-only): partner data stays on device
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "save_partner_estimate",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Store an estimate about the user's partner. "
            "Backend acknowledges only — actual data persisted by Flutter locally. "
            "Fields: estimated_salary (annual CHF), estimated_age (int), "
            "estimated_lpp (CHF), estimated_3a (CHF), estimated_canton (2-letter)."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "estimated_salary": {
                    "type": "number",
                    "description": "Partner's estimated annual gross salary in CHF",
                },
                "estimated_age": {
                    "type": "integer",
                    "description": "Partner's estimated age",
                },
                "estimated_lpp": {
                    "type": "number",
                    "description": "Partner's estimated LPP assets in CHF",
                },
                "estimated_3a": {
                    "type": "number",
                    "description": "Partner's estimated 3a capital in CHF",
                },
                "estimated_canton": {
                    "type": "string",
                    "description": "Partner's canton of residence (2-letter, e.g. VS, ZH)",
                },
            },
            "required": [],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # update_partner_estimate — WRITE/INTERNAL (ack-only): update partner estimate
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "update_partner_estimate",
        "category": "write",
        "access_level": "user_scoped",
        "description": (
            "Update a previously stored partner estimate field. "
            "Backend acknowledges only — actual data persisted by Flutter locally. "
            "Fields: estimated_salary (annual CHF), estimated_age (int), "
            "estimated_lpp (CHF), estimated_3a (CHF), estimated_canton (2-letter)."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "estimated_salary": {
                    "type": "number",
                    "description": "Partner's estimated annual gross salary in CHF",
                },
                "estimated_age": {
                    "type": "integer",
                    "description": "Partner's estimated age",
                },
                "estimated_lpp": {
                    "type": "number",
                    "description": "Partner's estimated LPP assets in CHF",
                },
                "estimated_3a": {
                    "type": "number",
                    "description": "Partner's estimated 3a capital in CHF",
                },
                "estimated_canton": {
                    "type": "string",
                    "description": "Partner's canton of residence (2-letter, e.g. VS, ZH)",
                },
            },
            "required": [],
        },
    },
    # ─────────────────────────────────────────────────────────────────
    # show_commitment_card — READ: Flutter-bound editable commitment card
    # ─────────────────────────────────────────────────────────────────
    {
        "name": "show_commitment_card",
        "category": "read",
        "access_level": "user_scoped",
        "description": (
            "Display an editable commitment card (WHEN/WHERE/IF-THEN) inline "
            "in chat. The user can accept, edit, or dismiss the commitment. "
            "This tool is forwarded to Flutter for rendering — the backend "
            "does NOT handle it internally."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "when_text": {
                    "type": "string",
                    "description": "WHEN part of the intention.",
                },
                "where_text": {
                    "type": "string",
                    "description": "WHERE part of the intention.",
                },
                "if_then_text": {
                    "type": "string",
                    "description": "IF-THEN part of the intention.",
                },
            },
            "required": ["when_text", "where_text", "if_then_text"],
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
