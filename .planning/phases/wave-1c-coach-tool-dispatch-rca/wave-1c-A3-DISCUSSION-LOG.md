---
description: Wave 1c-A3 discussion log — audit trail of the 4 expert panels (ai-engineer / prompt-engineer / context-manager / architect-review) that produced wave-1c-A3-CONTEXT.md on 2026-05-15. Panel verdicts, dissent, WebSearch URLs. Not for downstream agent input — decisions live in CONTEXT.md.
---

# Wave 1c-A3: Missing-Fields Handshake — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in [wave-1c-A3-CONTEXT.md](wave-1c-A3-CONTEXT.md) — this log preserves the alternatives considered and the panel-level dissent.

**Date:** 2026-05-15
**Phase:** wave-1c-coach-tool-dispatch-rca (sub-iteration A3)
**Mode:** GSD discuss-phase + 4-panel expert brainstorm (per `feedback_expert_panel_pattern` engram memory + Julien's explicit ask at discuss-phase question-1 reply)
**Areas discussed:** Backend contract shape | Instruction placement | Persistence of user answers | Scope of A3

---

## Pre-discussion stance

State on entry:
- Wave 1c-A2.1 (PR #641 sha `37fbd889`) MERGED 2026-05-15T20:30:55Z; dev→staging PR #642 sha `c235e865` Railway SUCCESS 2026-05-15T20:39:46Z.
- Live probe at staging returned `message: ""`, `toolCalls: null`, `citationChips: null`, `tokensUsed: 16663` ([probe-evidence/probe-2026-05-15-A21-2240.json](probe-evidence/probe-2026-05-15-A21-2240.json)).
- WAVE1C_PAYLOAD log confirmed user message was now 104 chars + unaugmented — the structural RAG cut WORKS but Sonnet returns empty because the test profile lacks AVS / LPP / 3a fields.
- A3 proposal (must-have) was sketched in engram obs #88 but no contract / placement / persistence / scope decisions locked.

## Gray-area selection (user reply)

Julien selected ALL 4 proposed gray areas + added directive: « Pour toutes ces discussions, j'aimerais que tu y répondes avec un brainstorming avec des experts. »

→ Routed to `feedback_expert_panel_pattern`: spawn parallel domain specialists, require WebSearch, synthesize a perfect / logical / pragmatic / human compromise, decide myself, ship.

---

## Panel #1 — Backend contract shape

**Lead specialist:** `ai-engineer` (wshobson catalog)
**Internal 3 hats:** ai-engineering / backend-architect / python-pro
**Question:** How does the backend `get_*` tool signal « I need more data » back to the narrator agent loop?
**Tool uses:** 9 (WebSearch + read)
**Engram observation:** #89

| Option | Description | Selected |
|---|---|---|
| A — Typed exception | `raise MissingFieldsError(fields=[...])` caught at narrator loop, converted to structured tool_result | |
| B — Structured tool_result payload | Tool returns `{"status":"incomplete","missing_fields":[...],"hint_fr":"..."}` | ✓ |
| C — Anthropic `is_error: true` | Soft-error variant of B using the native Anthropic error flag | |

**Panel verdict:** **B**. Pydantic v2 `RootModel[Annotated[Union[CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked], Field(discriminator="status")]]`. Reasons archived in engram obs #89.

**Internal disagreement surfaced:** decorator-now vs. decorator-later. python-pro hat pushed for a `@coach_tool` decorator that auto-validates incomplete payloads; backend-architect pushed back (over-engineering for v1, 6 tools is small). Resolved per Karpathy #2 simplicity: ship plain Pydantic in A3, defer decorator to A3.1 once ≥3 tools migrated and a pattern is proven.

**Notable hat dissent on Anthropic ergonomics:** `is_error:true` (Option C) was initially attractive to ai-engineering hat for « Anthropic-native » framing but lost decisively when Yalçın 2026 + Anthropic « strict tool use » docs clarified that `is_error` is for transport-level failures and structured incomplete-status is its own pattern.

**Key WebSearch citations:**
- [Anthropic — How to implement tool use](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/implement-tool-use)
- [Anthropic — Tool use](https://platform.claude.com/docs/en/build-with-claude/tool-use)
- [Anthropic — Agent SDK user input / approvals](https://platform.claude.com/docs/en/agent-sdk/user-input)
- [Yalçın 2026 — When Claude Can't Ask: Building Interactive Tools for the Agent SDK](https://oneryalcin.medium.com/when-claude-cant-ask-building-interactive-tools-for-the-agent-sdk-64ccc89558fa)
- [Anthropic — Agent loop](https://platform.claude.com/docs/en/agent-sdk/agent-loop)
- [Anthropic — Handling stop reasons](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons)
- [Anthropic — Advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use)
- [Temporal — Basic Agentic Loop with Claude and Tool Calling](https://docs.temporal.io/ai-cookbook/agentic-loop-tool-call-claude-python)

**Post-panel path correction by orchestrator:** Panel #1 cited new file at `services/backend/app/services/coach/tools/_response.py` — that directory does NOT exist in the codebase. Verified actual existing pattern is under `services/backend/app/models/coach_tools/` (which holds `budget_snapshot.py`, `retirement_projection.py`, `cross_pillar.py`, `couple_optimization.py`). Locked in CONTEXT.md as `services/backend/app/models/coach_tools/_response.py`.

---

## Panel #2 — Instruction placement (where the handshake mandate lives)

**Lead specialist:** `prompt-engineer` (wshobson catalog)
**Internal 3 hats:** prompt-engineering / ai-engineering / context-manager
**Question:** Where does the « if missing_fields, ask user explicitly » instruction live so Sonnet 4.5 reliably executes the handshake?
**Tool uses:** 7 (WebSearch + read)
**Engram observation:** #90

| Option | Description | Selected |
|---|---|---|
| A — Static system-prompt addition | New FR paragraph in 45k-char system prompt, sister of Wave A MANDATE | |
| B — Per-tool `input_schema.description` annotation | Each tool's description gets a FR sentence + canonical `MISSING_FIELDS_INSTRUCTION_FR` substring | ✓ |
| C — Both (defense in depth) | Static MANDATE + per-tool annotation | |

**Panel verdict:** **B**. 28-token pointer added in TOP/BOTTOM MANDATE block referencing the per-tool consigne; canonical constant `MISSING_FIELDS_INSTRUCTION_FR` lives in `services/backend/app/services/coach/coach_tools.py` (NOT in invented `tool_registry.py`). Reasons archived in engram obs #90.

**Internal agreement:** all three hats converged on B once token-budget reality (45'879-char baseline + 2'167 already from Wave A1) + Liu 2024 lost-in-the-middle re-framed as a « distance from decision point » problem (not just TOP-vs-BOTTOM positioning).

**Key WebSearch citations:**
- Anthropic 2025 tool-description best-practices (cited in engram obs #90; tool defs are injected AFTER the system prompt per Claude Code reverse-engineering analyses).
- Liu 2024 lost-in-the-middle paper referenced via parent CONTEXT.

**Post-panel path correction by orchestrator:** Panel #2 referenced `services/backend/app/services/coach/tool_registry.py` — that file does NOT exist. Verified actual surface is `services/backend/app/services/coach/coach_tools.py` (1196+ lines with 28 `input_schema` definitions). Locked in CONTEXT.md.

---

## Panel #3 — Persistence of user answers (wiki write)

**Lead specialist:** `context-manager` (wshobson catalog)
**Internal 3 hats:** context-manager / backend-architect / ux-researcher
**Question:** When user replies « j'ai 42 ans, 8 années AVS, 320'000 LPP, 25'000 3a », where and how does that data persist?
**Tool uses:** 23 (WebSearch + Bash + Grep + Read — Panel #3 was the only panel to do extensive in-repo verification)
**Engram observation:** Full transcript in this DISCUSSION-LOG.md (panel returned content in-message, no separate engram obs).

| Option | Description | Selected |
|---|---|---|
| A — Ephemeral session memory only | Captured for duration of agent loop only; re-ask next session | |
| B — Wiki write only | Same-turn write to `CoachInsightRecord`, future invocations re-read | |
| C — Synchronous in-turn cache + same-turn wiki write | Both: turn-local dict caches for tool retry within turn, sync DB upsert for durability | ✓ (revised — synchronous, NOT async/queued) |

**Panel verdict:** **C synchronous in-turn** (NOT async/queued). Critical revision of the original framing: Panel #3 dropped the « background queue » framing from the prompt because `CoachInsightRecord` upsert is a single SQLAlchemy call (~5ms) and the write surface already exists. Same turn, no queue, no Redis. Reasons:
- Karpathy LLM Wiki direction (locked per `project_user_profile_wiki`) demands durable write.
- Race risk between wiki commit and same-turn tool retry → mitigated by turn-local cache as authoritative within the turn.
- UX cost of re-asking is high; Julien hates re-asks (multiple session memories).
- `services/backend/app/services/coach/profile_extractor.py` already implements regex+keyword extraction productively for 7 field families. Only gap = `_extract_avs_years`.

**Internal disagreements:**
- **backend-architect vs. context-manager** on whether to add a `provenance` JSON column migration to `CoachInsightRecord` in A3 or defer. Resolved: defer; v1 encodes provenance inline in `summary` string as `"320'000 CHF (source: handshake, raw: '…', captured: <ISO>)"`. Migration is a follow-up cleanup.
- **ux-researcher vs. backend-architect** on confidence handling. ux-researcher wanted a confirmation echo for every captured value. backend-architect pushed back (« don't re-ask values the AI just heard cleanly »). Resolved: confirmation echo ONLY for `confidence: low` captures (e.g. regex fired without AVS-anchor keyword).
- **All three agreed** Option A is dead (Karpathy-locked + UX-hostile) and Option B alone has a race risk inside the turn.

**Parsing strategy locked:** extend the existing `profile_extractor.py` regex+keyword extractor (NOT a structured second LLM call). Add `_extract_avs_years()` mirroring `_extract_lpp` at line 407. Cross-check against `age - 22` band for plausibility. LLM call is overkill for 4 numeric fields and adds ~600ms + non-determinism.

**Key WebSearch + repo citations:**
- [Karpathy LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [LLM Wiki v2 extension](https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2)
- [OpenAI Cookbook — Context Engineering for Personalization](https://developers.openai.com/cookbook/examples/agents_sdk/context_personalization)
- [Mem0 — universal memory layer](https://github.com/mem0ai/mem0)
- [ReMe — agent memory kit](https://github.com/agentscope-ai/ReMe)
- [MemX — local-first long-term memory](https://arxiv.org/html/2603.16171v1)
- [Cloudflare — Introducing Agent Memory](https://blog.cloudflare.com/introducing-agent-memory/)
- [Machine Learning Mastery — 7 Steps to Mastering Memory in Agentic AI Systems](https://machinelearningmastery.com/7-steps-to-mastering-memory-in-agentic-ai-systems/)
- Repo verification: `services/backend/app/services/coach/profile_extractor.py` (Fact dataclass + 7 field-family extractors), `services/backend/app/models/coach_insight.py:23` ((user_id, topic) index + upsert).

---

## Panel #4 — Scope of A3 (which tools)

**Lead specialist:** `architect-review` (wshobson catalog)
**Internal 3 hats:** architect-review / product-manager / qa-expert
**Question:** Which tools should A3's first PR wire the missing-fields handshake on?
**Tool uses:** 13 (WebSearch + read)
**Engram observation:** #92 (sparse stub; full reasoning retrieved via SendMessage continuation captured here verbatim)

| Option | Description | Selected |
|---|---|---|
| A — Minimal viable A3 (1 tool) | Wire handshake on `get_retirement_projection` only; A3.1/A3.2 for the other 5 | |
| B — Wave 1b parity (6 chip-emitters in one PR) | All 6 chip-emitting tools (`get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_3a_cap`, `get_avs_age_reference`, `get_couple_optimization`) | ✓ |
| C — Full narrator registry (26 tools) | Every narrator-eligible tool | |

**Panel verdict:** **B**. Decisive. Reasons archived in engram obs #92 (full reasoning retrieved via SendMessage continuation):

| Hat | Position | Key argument |
|---|---|---|
| architect-review | B | Single backend contract diff; 6 tool-schema diffs mechanical; anti-facade — don't ship a partial dispatcher that teaches the model to drift. |
| product-manager | B | Cleo parity requires all 6 chip-emitters functional for the G2 archetype × tool matrix. 1-tool ship doesn't move the product needle. |
| qa-expert | Initially A → converged B | A 6-tool batch can be tested via one extended Maestro flow file with 6 sub-scenarios — one Maestro run validates all 6. |

**Disagreement point:** qa-expert initially pushed for A on « blast radius » grounds. Architecture + Product overrode citing AgentDrift fallback-drift contamination risk (the killer architectural argument: partial tool coverage teaches Sonnet to redirect 3a queries to external sources because the empty-response path is locally cheaper — re-opening the regression Wave A2.1 just closed at the RAG layer). qa-expert agreed once the fixed verification surface (Wave B matrix tests the same 6 tools regardless of A3 scope) was made explicit.

**Side-question verdict (cosmetic A2.2 retriever guard):** **NO, do not fold into A3.** Ship as its own 3-line atomic PR `fix(wave-1c-A22): silence ChromaDB n_results=0 warning` against `dev` BEFORE A3 opens. Per `CLAUDE.md §3` Surgical Changes + `feedback_perimeter_5_gates` — bundling pollutes the A3 diff, makes panel review harder, and the atomic 3-line PR ships in 10 minutes with easy revert at `services/backend/app/services/rag/orchestrator.py:83`.

**Key WebSearch citations:**
- [Anthropic — Strict tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use) — Opus 4.6+ clarifies on missing params; Sonnet 4.5 needs explicit tool examples.
- [Anthropic — Handling stop reasons](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons) — direct match to obs #88's empty-response root cause.
- [Anthropic — Advanced tool use (Tool Use Examples)](https://www.anthropic.com/engineering/advanced-tool-use) — embed concrete handshake examples INSIDE tool definitions.
- [arxiv 2603.12564 — AgentDrift: Unsafe Recommendation Drift Under Tool Corruption](https://arxiv.org/html/2603.12564) — partial-coverage drift; THE architectural argument against Option A.
- [arxiv 2511.07585 — LLM Output Drift: Cross-Provider Validation for Financial Workflows](https://arxiv.org/html/2511.07585v1) — schema-drift risk when 6 tool Pydantic models diverge; mitigation = single shared envelope.
- [Galileo — Why multi-agent LLM systems fail](https://galileo.ai/blog/multi-agent-llm-systems-fail) — 41-86% prod failure rates with incomplete schemas.
- [openclaw issue #71880 — Claude empty terminal turns (stop=stop, content=[])](https://github.com/openclaw/openclaw/issues/71880) — direct match to MINT obs #88 probe.
- [LaunchDarkly — Percentage rollouts](https://launchdarkly.com/docs/home/releases/percentage-rollouts) — incremental rollout works for USER-segment gating, not tool-registry gating; argues against splitting tool wiring into 3 PRs.

---

## Synthesis — Locked decisions

See [wave-1c-A3-CONTEXT.md](wave-1c-A3-CONTEXT.md) `<decisions>` section. Mapping:

| Panel | Decision ID in CONTEXT.md |
|---|---|
| #1 backend contract | D-A3-01 |
| #2 instruction placement | D-A3-02 |
| #3 persistence | D-A3-03 |
| #4 scope | D-A3-04 + D-A3-08 (PR shape) |
| Server-side floor (added by orchestrator, anchored in `project_coach_forced_tool_invocation`) | D-A3-06 |
| Test floor (mirrors parent D-05) | D-A3-05 |
| financial_core reuse (CLAUDE.md triplet #3) | D-A3-07 |
| Branch / PR shape | D-A3-08 |
| 0-trust 5-gate (inherits parent D-10) | D-A3-09 |
| Design panel (inherits parent D-11, narrowed) | D-A3-10 |
| mem_save (inherits parent D-12) | D-A3-11 |

## Counter-arguments and data gaps

**Counter-arguments considered:**
- *« A3 scope should be minimal (1 tool MVP) to ship fast and iterate. »* — rejected per Panel #4 AgentDrift argument; partial coverage teaches the model to drift and re-opens the regression Wave A2.1 closed.
- *« Use a structured second LLM call for value extraction, not regex. »* — rejected per Panel #3 Karpathy-2 simplicity; existing regex extractor covers 6 of 7 field families and adds latency-free determinism.
- *« Put the handshake instruction in the system prompt for consistency with Wave A1 MANDATE. »* — rejected per Panel #2 lost-in-the-middle reframing as « distance from decision point », and token-budget pressure on the 45k-char baseline.
- *« Async/queued wiki write is safer for write durability. »* — rejected per Panel #3 because the upsert is single-SQL-call (~5ms) and the race risk inside the turn is the only real concern; turn-local cache solves it without infra cost.

**Data gaps acknowledged:**
- We have NO live probe yet of Sonnet 4.5's behaviour when handed a `status:"incomplete"` tool_result — all four panels reasoned from Anthropic 2025 docs + research papers + the Yalçın 2026 pattern, not from MINT-specific empirical evidence. Mitigation: D-A3-06 server-side floor catches the worst case (empty narrator response); A3 test floor includes a mocked-Anthropic fixture (D-A3-05 #2) to lock the expected behaviour; staging G1 probe will be the first real evidence.
- We have NOT verified that the existing `profile_extractor.py` covers 100% of the user reply patterns we expect (« 8 ans » without AVS keyword, « environ 320k » with magnitude letter, mixed comma/space thousand separator). Mitigation: confidence tagging + low-confidence confirmation echo (D-A3-03).
- We have NOT measured the token-cost impact of injecting `MISSING_FIELDS_INSTRUCTION_FR` into 6 tool descriptions. Panel #2 estimated ~330 tokens; actual will be measured in plan phase.
- The Maestro flow file path `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` is assumed to exist; if it doesn't, A3 creates `coach_handshake_6_tools.yaml` from scratch. Either way, planner verifies in plan phase.

## Deferred Ideas (preserved here for posterity, also in CONTEXT.md `<deferred>`)

- Open Banking / bank-data ingestion (future milestone — eliminates most handshake turns).
- `provenance` JSON column migration on `CoachInsightRecord` (follow-up cleanup).
- A3.2 — extend handshake to non-chip narrator tools (gate on Wave B G2 surfacing drift).
- LLM-based parser replacement for regex+keyword (Karpathy-2 simplicity wins for now).
- Multi-tool-eligible intent handling (« ma retraite à Genève » = retirement AND tax intents).
- Bank PDF upload + parse (future milestone).
