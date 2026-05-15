---
description: Wave 1c sub-iteration A3 — missing-fields handshake. Locks 4 decisions (backend contract / instruction placement / persistence / scope) for the iteration that makes the narrator EXPLICITLY ask the user for missing profile fields instead of returning empty after Wave 1c-A2.1 closed the RAG-cut bypass. Sibling of wave-1c-A-PLAN.md / A1 / A2 / A2.1.
---

# Wave 1c-A3: Missing-Fields Handshake — Context

**Gathered:** 2026-05-15
**Status:** Ready for planning
**Parent phase:** [wave-1c-CONTEXT.md](wave-1c-CONTEXT.md)
**Predecessor:** wave-1c-A2.1 (PR #641 sha `37fbd889`, MERGED 2026-05-15T20:30:55Z, dev→staging PR #642 sha `c235e865` SUCCESS 2026-05-15T20:39:46Z)
**Source of decisions:** 4 expert panels run 2026-05-15 21:00-21:05 CEST (engram obs #89 ai-engineer, #90 prompt-engineer, #91 context-manager via in-message return, #92 architect-review extended via SendMessage transcript). All 4 panels used WebSearch; rationale archived in companion [wave-1c-A3-DISCUSSION-LOG.md](wave-1c-A3-DISCUSSION-LOG.md).

<domain>
## Phase Boundary

**This sub-iteration delivers** the « missing-fields handshake » contract that prevents Sonnet 4.5 from returning empty messages when the user profile lacks the fields required to invoke a `get_*` financial tool. Concretely, when the narrator wants to call `get_retirement_projection` but the user has no `age` / `avs_contribution_years` / `lpp_balance` / `pillar3a_balance`, the tool returns a structured `status: "incomplete"` payload with `missing_fields` + `hint_fr`, the narrator system-prompt forces an explicit French question to the user, the user's answer is parsed and persisted to `CoachInsightRecord` AND re-injected into the tool call within the same turn so the narrator emits a real `tool_use` block instead of `message: ""`.

**Out of scope:**
- Wave 1c-A / A1 / A2 / A2.1 surfaces (already merged; this iteration BUILDS ON the clean unaugmented user message that A2.1 produces).
- Wave 1c-B regression-test floor (5 artifacts per parent D-05). Wave B is the consumer; it remains blocked until A3 stabilises tool_use emission.
- Wave 1c-C teardown (instrumentation revert, Railway env var deletion). Sequenced AFTER A3 G2 green.
- Cosmetic A2.2 retriever guard (`if n_results > 0:` at `services/backend/app/services/rag/orchestrator.py`) — ships as its own 3-line PR BEFORE A3 opens (per Panel #4 side question verdict — keeps A3 diff focused).
- Phase 94.2 narrator-prompt iter 2 (intent-driven key grouping). Gated on prod-flip reactivation.
- Open Banking / bank-data ingestion that would pre-fill many of these fields automatically. Out of scope for A3; will reduce A3's surface in a future milestone.

</domain>

<decisions>
## Implementation Decisions (LOCKED)

### D-A3-01. Backend contract = structured tool_result with status discriminator

**From Panel #1 (ai-engineer + backend-architect + python-pro hats, engram obs #89, Anthropic docs + Yalçın 2026 cited).**

- New Pydantic v2 RootModel `CoachToolResponse` defined as `RootModel[Annotated[Union[CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked], Field(discriminator="status")]]`.
- `status: Literal["ok", "incomplete", "policy_blocked"]` is the discriminator. Tool implementations RETURN one of the three variants — NEVER raise a typed exception, NEVER set `is_error: true` on the Anthropic tool_result.
- Rejected alternatives:
  - **Option A (typed exception)** — leaks Python control flow into a narrator semantic contract; scales poorly per-tool; opaque Sentry breadcrumbs. REJECTED.
  - **Option C (`is_error: true`)** — data-gaps are not tool failures; conflating corrupts Sentry error telemetry; trains the narrator into apologetic register (« je n'arrive pas à... ») instead of the coaching register MINT needs. REJECTED.
- `CoachToolIncomplete` payload (Pydantic v2):
  - `status: Literal["incomplete"]`
  - `missing_fields: list[str]` — canonical profile field names (e.g. `age`, `avs_contribution_years`, `lpp_balance`, `pillar3a_balance`), camelCase per FastAPI Pydantic v2 convention. **Cap at 3 per response** (conversational handshake, not form dump).
  - `hint_fr: str` — short French clause the narrator can read to ground its question (e.g. `« Pour calculer ta rente AVS, j'ai besoin de ton âge et de tes années de cotisation AVS. »`). LSFin-clean (no « garanti / optimal / meilleur / certain / assuré / sans risque / parfait »). 100% French accents.
- `CoachToolOk` keeps the existing per-tool payload shape (`apps/mobile/lib/services/financial_core/` parity preserved). NO behavioural change for the happy path.
- `CoachToolPolicyBlocked` reserved for future LSFin / FINMA gates; not wired in A3 but defined now so we don't migrate twice.
- New shared file: `services/backend/app/models/coach_tools/_response.py` (sibling to existing `budget_snapshot.py`, `retirement_projection.py`, `cross_pillar.py`, `couple_optimization.py` under `models/coach_tools/`). NOT `services/backend/app/services/coach/tools/_response.py` (that path does not exist in the codebase — Panel #1's stated path was invented; the verified existing pattern is under `models/coach_tools/`).
- Narrator wire site: `services/backend/app/api/v1/endpoints/coach_chat.py:_run_narrator_with_gate` (~line 4230 per parent CONTEXT). JSON-encode `CoachToolResponse` into the `tool_result.content` block. **Phase 94 byte-identity preserved** — `_citation_gate` is untouched because `status:"incomplete"` produces NO citations and the gate's input shape is unchanged.
- Server-side floor: if narrator returns `message: ""` AFTER receiving a `status:"incomplete"` tool_result, deterministically synthesize a French fallback question from `hint_fr` BEFORE returning the response to Flutter. Don't trust the model alone (Panel #1 risk #1 + obs #88 trust-collapse pattern).
- Sentry breadcrumb: category `coach.tool.incomplete`, payload `{tool_name, missing_fields, user_id_hashed, fallback_used: bool}`. Sister to existing `coach.tool.<name>` breadcrumb.

### D-A3-02. Instruction placement = per-tool `input_schema.description`, NOT system prompt

**From Panel #2 (prompt-engineer + ai-engineer + context-manager hats, engram obs #90, Anthropic 2025 docs + Indie Hackers Claude Code reverse-engineering + Liu 2024 cited).**

- The « if you cannot fill required inputs, ask the user explicitly via your text turn — do NOT invoke with filler values, do NOT redirect to an external resource » instruction is planted in **each tool's `input_schema.description`** (or the parent tool `description` field of the Anthropic tools array), NOT as a 4th MANDATE copy in the 45'879-char system prompt.
- Canonical constant defined in `services/backend/app/services/coach/coach_tools.py` (the actual tool-array file — Panel #2's stated `tool_registry.py` does not exist; the verified surface is `coach_tools.py`):
  ```python
  MISSING_FIELDS_INSTRUCTION_FR = (
      "Champs profil requis : {required_fields_csv}. Si un champ manque, "
      "ne devine pas, ne redirige pas vers une ressource externe : pose la "
      "question explicitement à l'utilisateur dans ta réponse texte et "
      "renvoie un statut « incomplete » au prochain tour."
  )
  ```
- Per-tool registration `.format(required_fields_csv=...)` listing the canonical fields for that tool. Single source of truth — drift-resistant.
- A short pointer (~28 tokens) is added inside the existing TOP+BOTTOM MANDATE block at `services/backend/app/services/coach/citation_grammar.py`: « Pour chaque outil, lis le champ `description` : il liste les champs profil requis et la procédure si un champ manque. »
- Rejected alternatives:
  - **Option A (system-prompt only)** — Wave A1 (TOP+67%+99% MANDATE triplication) STILL didn't fix the structural issue; position alone is not enough when the instruction is semantically detached from the tool_use decision point. Plus token-budget pressure on the 45k-char baseline. REJECTED.
  - **Option C (both)** — most tokens, contradiction-risk between two stale copies, marginal gain over B once B is well-injected. REJECTED.
- Lint test: `services/backend/tests/test_coach_tools/test_missing_fields_instruction_present.py` asserts every chip-emitting tool's `description` contains the canonical substring. Hard-fail if drift.
- Token cost estimate: ~28 tokens (pointer in MANDATE) + ~50 tokens × 6 tools = ~330 tokens added vs. ~2000+ tokens for Option C. Stays within RESEARCH §A4 grammar budget.
- The instruction text MUST also include a concrete **Anthropic Tool Use Example** (per Anthropic 2025 « Advanced tool use » blog, also cited by Panel #4): show a literal blank-profile → narrator-asks → user-replies → tool_use-emits sequence in the tool description. Sonnet 4.5 picks this up far more reliably than abstract instructions.

### D-A3-03. Persistence = same-turn synchronous cache + same-turn wiki write to `CoachInsightRecord`

**From Panel #3 (context-manager + backend-architect + ux-researcher hats, full reasoning in DISCUSSION-LOG.md, Karpathy LLM Wiki gist + Mem0 + OpenAI Cookbook cited).**

- Reuse existing `services/backend/app/services/coach/profile_extractor.py` regex+keyword extractor (`extract_profile_facts(user_message)` → `facts_to_insight_rows()` → bulk upsert `CoachInsightRecord`). NO new endpoint, NO new service-layer module.
- Add ONE function `_extract_avs_years()` to `profile_extractor.py` (mirrors existing `_extract_lpp` at line 407). The other field families (`age`, `lpp_balance`, `pillar3a_balance`, etc.) are already covered by the existing extractor.
- Flow inside the agent loop (`coach_chat.py`):
  1. Tool returns `status: "incomplete"` with `missing_fields`.
  2. Narrator asks user the question (D-A3-02 instruction enforces this; D-A3-01 server-side floor catches if it doesn't).
  3. User replies in the next turn with values.
  4. `extract_profile_facts(user_message, current_profile)` parses into a `list[Fact]`.
  5. Parsed values stuffed into the **turn-local agent state dict** under key `pending_profile_updates`. The tool dispatcher reads from this dict BEFORE re-checking the DB. **No race window** because cache and DB write happen in the same Python turn.
  6. Same turn, BEFORE returning the narrator's final reply, upsert each Fact into `CoachInsightRecord` via the existing `save_insight` code path at `coach_chat.py:2443-2470`. SQLAlchemy session is already open — single transaction.
- Rejected alternatives:
  - **Option A (ephemeral only)** — re-asks across sessions; Karpathy direction violated; Cleo proactive-coaching value-prop dead. REJECTED.
  - **Option B (wiki write only)** — race risk between wiki commit and same-turn tool retry. The synchronous cache is the safety net inside the turn. REJECTED in favour of C.
  - **Async / queued wiki write** — Panel #3 explicitly drops the "background queue" framing from the original prompt because `CoachInsightRecord` upsert is a single SQLAlchemy call (~5ms) and there is no reason to defer it. The "C" we ship is synchronous-in-turn.
- Topic key namespacing: structured-handshake writes use prefix `profile.<canonical_field>` (e.g. `profile.pillar3aBalance`) to avoid collision with the existing free-form coach-saved insights (e.g. `topic="3a"`). Migration adding a `provenance` JSON column to `CoachInsightRecord` is out-of-scope for A3 — for v1 we encode provenance inline in the `summary` text as `"320'000 CHF (source: handshake, raw: '…', captured: <ISO timestamp>)"`.
- Confidence tagging: when the regex fires but the AVS-anchor keyword is not present (e.g. user replies « 8 ans » without specifying « AVS »), `Fact.confidence = low`. The narrator on first capture issues a **confirmation echo** for low-confidence facts only: « J'ai noté 8 années de cotisations AVS — c'est bien ça ? ». No echo for high-confidence captures (don't re-ask values the AI just heard cleanly).
- Cross-language consistency: profile fields stored in `CoachInsightRecord.summary` keep the value in CHF and YYYY format regardless of which UI locale (fr/en/de/es/it/pt) the user types in. The 6 ARB files only carry display text, not stored values.

### D-A3-04. Scope = all 6 Wave 1b chip-emitting tools in ONE PR

**From Panel #4 (architect-review + product-manager + qa-expert hats, full reasoning in DISCUSSION-LOG.md, AgentDrift arxiv 2603.12564 + Galileo + LaunchDarkly cited).**

- A3 PR wires the missing-fields handshake on all 6 Wave 1b chip-emitting tools in one merge:
  1. `get_budget_status`
  2. `get_retirement_projection`
  3. `get_cross_pillar_analysis`
  4. `get_3a_cap`
  5. `get_avs_age_reference`
  6. `get_couple_optimization`
- Rejected alternatives:
  - **Option A (1 tool MVP — `get_retirement_projection` only)** — partial coverage causes Sonnet to learn the cheaper fallback (« consulte ahv-iv.ch ») for the 5 unhandled chip-emitters → contaminates the Wave 1c-A2.1 doctrine fix we just shipped. AgentDrift arxiv 2603.12564 + Galileo failure analysis (41-86% prod failure rates with partial schemas) explicitly warn against this. Architectural NO. REJECTED.
  - **Option C (all 26 narrator tools)** — ~20 of the 26 are read/retrieval tools that don't take user-profile fields; handshake is a no-op for them. Massive diff, near-zero value, delays A3 by 2-3 days. REJECTED.
- Sequencing:
  - **A3 (this PR)** — backend contract (D-A3-01) + per-tool descriptions (D-A3-02) + persistence wiring (D-A3-03) + 6 tool migrations + 6 unit tests + 1 extended Maestro flow. ~6 dev days.
  - **A3.1 (cleanup)** — post-A3 G2-green; fold any lint/log noise reductions surfaced by panel review. Does NOT include A2.2 (which ships as its own pre-A3 PR).
  - **A3.2 (optional, defer)** — extend handshake to non-chip narrator tools ONLY if Wave B G2 surfaces fallback-drift on those surfaces. Otherwise drop.
- PR commit structure: 1 contract commit + 6 tool-specific commits, each independently reviewable to mitigate panel rubber-stamp risk (Panel #4 risk #3). Squash on merge to `dev` per `CLAUDE.md §4 DEV RULES`.

### D-A3-05. Test floor for A3 (5 mandatory artifacts before merge)

Mirrors parent D-05 pattern, scoped to A3 surfaces:

1. `services/backend/tests/test_coach_chat/test_missing_fields_handshake.py` — for each of the 6 chip-emitting tools: fixture (blank profile, tool-eligible question) → assert tool returns `status:"incomplete"`; fixture (complete profile) → assert tool returns `status:"ok"` with payload; fixture (partial profile, 1 field missing) → assert `missing_fields == ["<the one field>"]`.
2. `services/backend/tests/test_coach_chat/test_narrator_asks_on_incomplete.py` — mock Anthropic, fixture per tool: assistant turn after `status:"incomplete"` tool_result contains the canonical handshake question pattern in French; AND `stop_reason == "end_turn"` with non-empty text (no empty-message regression vs. obs #88).
3. `services/backend/tests/test_coach_tools/test_missing_fields_instruction_present.py` — lint test: every chip-emitting tool's `input_schema.description` contains the canonical `MISSING_FIELDS_INSTRUCTION_FR` substring (D-A3-02 drift guard).
4. `services/backend/tests/test_coach_chat/test_handshake_persistence.py` — fixture: tool returns incomplete; mock user reply with 4 values; assert `CoachInsightRecord` upsert happens in the same turn; assert tool retry within the turn uses the cached values; assert no DB query for the user's profile between cache write and tool retry.
5. `tools/simulator/flows/maestro-perfect-set/coach_handshake_6_tools.yaml` — extends `wave_1b_citation_chip_smoke.yaml` with 6 sub-scenarios (one per chip-emitter): blank-profile user → narrator-asks → Maestro types reply → narrator emits real `tool_use` + chip on retry. Precondition: `runFlow: auth/login.yaml`.

### D-A3-06. Server-side floor on empty narrator response

Belt-and-braces backup: if the narrator returns `message: ""` AFTER receiving a `status:"incomplete"` tool_result (i.e. the Sonnet instruction-following failure mode that observation #88 documented), the agent loop deterministically synthesizes a French question from the tool's `hint_fr` field BEFORE returning the response to Flutter. Logged as `coach.tool.incomplete.fallback_used: true` in the Sentry breadcrumb. This is what `project_coach_forced_tool_invocation` memory mandates — never serve trust-collapsing empty content to the user.

### D-A3-07. financial_core / source-of-truth reuse (NON-NEGOTIABLE)

Per `CLAUDE.md` triplet #3 + canonical_refs below: when a tool's `status:"ok"` happy path computes a number, the computation MUST delegate to `apps/mobile/lib/services/financial_core/` for the Flutter side (`AvsCalculator`, `LppCalculator.projectToRetirement()`, `TaxCalculator.capitalWithdrawalTax()`, `ConfidenceScorer.EnhancedConfidence`) and to the mirror `services/backend/app/services/` constants for backend computation. A3 does NOT reinvent or shortcut calculator logic; it only wires the handshake when calculator inputs are absent. EnhancedConfidence is mandatory on every numeric projection in the `CoachToolOk` payload.

### D-A3-08. Branch + PR shape

- Branch: `feature/wave-1c-A3-missing-fields-handshake` from `dev` per `CLAUDE.md §4 DEV RULES`. Never direct on `main` / `staging`. Always `--rebase` on pull.
- PR target: `dev`. Conventional commit format `feat(wave-1c-A3): <surface>` (e.g. `feat(wave-1c-A3): CoachToolResponse Pydantic envelope`).
- A2.2 retriever guard PR opens FIRST as a 3-line atomic `fix(wave-1c-A22): silence ChromaDB n_results=0 warning` against `dev`. Merge before A3 opens to keep the A3 diff focused. Per Panel #4 side-question verdict + `CLAUDE.md §3 Surgical Changes`.

### D-A3-09. 0-trust 5-gate exit (inherits parent D-10)

Phase A3 may only be claimed « WORKS » after all 5 gates green WITH deterministic citations in the same commit message or HTML evidence report:

- **G1** — Sim/staging Maestro walker (`coach_handshake_6_tools.yaml`) shows for each of the 6 chip-emitters: blank profile → narrator French question → Maestro typing user reply → narrator emits real `tool_use` + chip on retry. Cite `idb ui describe-all` snapshot OR Maestro JUnit XML.
- **G2** — Julien runs the flow on a sim, sees chips render on all 6, confirms in chat (« ok » or screenshot).
- **G3** — dev CI green sha cited (`gh pr checks` output).
- **G4** — `pytest -q` exit 0 + `flutter test` exit 0 cited.
- **G5** — `tools/checks/banned_terms_python.py services/backend/app/services/coach/coach_tools.py services/backend/app/api/v1/endpoints/coach_chat.py services/backend/app/services/coach/profile_extractor.py` exit 0 + `tools/checks/accent_lint_fr.py` exit 0 + `validate_arb_parity()` exit 0 (if any ARB key is added for the confirmation-echo Snackbar, which is currently NOT planned). Plus lefthook gates from `CLAUDE.md §4` (memory-retention-gate, wiki-lint, banned-terms-arb-gate, arb-parity-gate).

PR opened ≠ shipped. Tests green ≠ feature working. Per `CLAUDE.md §9.5`.

### D-A3-10. Design panel pre-push (inherits parent D-11, narrowed to A3 surfaces)

Backend-only diff + French narrator-copy edit on tool descriptions → pre-push panel composition: `security-auditor` (LSFin banned-terms scan on `MISSING_FIELDS_INSTRUCTION_FR` template, all 6 per-tool `hint_fr` strings, and the server-side floor fallback) + `qa-expert` (regression coverage opinion on the 5-artifact test floor) + `ai-engineer` (Pydantic v2 contract review) + `prompt-engineer` (per-tool description rewrite review) + `architect-review` (financial_core reuse + anti-facade verification per D-A3-07). NO Flutter panel needed (no screen change). NO `accessibility-expert` (no a11y surface). Verdict BLOCK by any 1+ agent = do NOT `/ship`.

### D-A3-11. mem_save discipline (inherits parent D-12)

`mem_save` after each meaningful sub-checkpoint with `topic_key: coach:tool_use:missing_fields_handshake:wave_a3:<sub-area>` and `prior_finding_refs` including engram obs ids 88, 89, 90, 91 (in-message return), 92, plus this CONTEXT.md's commit sha once landed.

### Claude's Discretion

- Exact French wording of each per-tool `hint_fr` (LSFin-clean + accent-perfect). Default recommended templates:
  - `get_retirement_projection.hint_fr` → « Pour calculer ta rente AVS et LPP, j'ai besoin de ton âge, de tes années de cotisation AVS et de tes soldes LPP / 3a. »
  - `get_3a_cap.hint_fr` → « Pour estimer ton plafond 3a, j'ai besoin de ton âge et de ton statut d'emploi (salarié / indépendant). »
  - `get_avs_age_reference.hint_fr` → « Pour situer ton âge de référence AVS, j'ai besoin de ton âge et de ton genre. »
  - others to be drafted in plan phase.
- Whether the per-turn server-side floor (D-A3-06) lives in `_run_narrator_with_gate` directly or in a sibling helper `_synthesize_handshake_fallback`. Recommended sibling helper for testability.
- Whether the AVS-anchor confidence test uses a closed list of keywords (`AVS`, `cotisation`, `1er pilier`) or a small LLM call. Recommended closed list (Karpathy-2 simplicity; LLM call is overkill for 6 keywords).
- Whether to add a `provenance` JSON column migration to `CoachInsightRecord` in A3 or defer to a follow-up cleanup. Recommended defer — v1 encodes provenance inline in `summary`.
- Maestro flow: one combined `coach_handshake_6_tools.yaml` vs. 6 separate files. Recommended one combined per qa-expert hat in Panel #4 (one Maestro run validates all 6).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Parent phase context
- [wave-1c-CONTEXT.md](wave-1c-CONTEXT.md) — full parent context (root-cause RCA, D-01 doctrine, D-10 5-gate, D-11 panel pattern, D-12 mem_save discipline).
- [wave-1c-A2-PLAN.md](wave-1c-A2-PLAN.md) — orchestration-layer RAG cut (predecessor merged).
- [wave-1c-A-PLAN.md](wave-1c-A-PLAN.md), [wave-1c-A1-PLAN.md](wave-1c-A1-PLAN.md) — earlier doctrine attempts.

### Live probe evidence (deterministic ground truth)
- [probe-evidence/probe-2026-05-15-A21-2240.json](probe-evidence/probe-2026-05-15-A21-2240.json) — the empty response after A2.1 ship (`message: ""`, `toolCalls: null`, `citationChips: null`, `tokensUsed: 16663`). This is THE bug A3 fixes.
- [probe-evidence/payload-2026-05-15-A2-2219.jsonl](probe-evidence/payload-2026-05-15-A2-2219.jsonl) — the clean 104-char user message proving A2.1 structural fix works.

### Code surfaces to modify or wire against (verified to exist 2026-05-15)
- `services/backend/app/services/coach/coach_tools.py` — the 26-tool registry with 28 `input_schema` definitions (the actual file Panel #2 called `tool_registry.py`). Site of D-A3-02 instruction injection + canonical `MISSING_FIELDS_INSTRUCTION_FR` constant.
- `services/backend/app/models/coach_tools/{budget_snapshot,retirement_projection,cross_pillar,couple_optimization}.py` — existing tool Pydantic models. Site of D-A3-01 contract migration. Sibling new file: `_response.py` for shared `CoachToolResponse` envelope.
- `services/backend/app/models/coach_insight.py:23` — `CoachInsightRecord` with `(user_id, topic)` index + upsert semantics. Persistence target for D-A3-03.
- `services/backend/app/services/coach/profile_extractor.py` — `Fact` dataclass + `extract_profile_facts` + `facts_to_insight_rows` (existing). Site of `_extract_avs_years` addition + reuse for D-A3-03.
- `services/backend/app/api/v1/endpoints/coach_chat.py` — agent loop:
  - `:_build_insight_memory_block` ~line 1100 (re-read after upsert).
  - `:save_insight` handler ~lines 2443-2470 (existing wiki write surface).
  - `:_run_narrator_with_gate` ~line 4230 (wire site for D-A3-01 tool_result + D-A3-06 server-side floor).
- `services/backend/app/services/coach/citation_grammar.py` — pointer line added to TOP/BOTTOM MANDATE block per D-A3-02.

### Anthropic + research docs
- [Anthropic — Tool use](https://platform.claude.com/docs/en/build-with-claude/tool-use) — Anthropic SDK tool_result contract reference.
- [Anthropic — Implement tool use](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/implement-tool-use) — structured JSON content in tool_result.
- [Anthropic — Strict tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use) — Opus 4.6+ clarification semantics, Sonnet 4.5 sits between.
- [Anthropic — Handling stop reasons](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons) — `end_turn` with empty content root cause.
- [Anthropic — Advanced tool use (Tool Use Examples)](https://www.anthropic.com/engineering/advanced-tool-use) — embed handshake example INSIDE tool description (cited by Panel #2 + Panel #4).
- [Anthropic — Agent SDK user input / approvals](https://platform.claude.com/docs/en/agent-sdk/user-input) — clarification-on-missing-fields pattern.
- [Yalçın 2026 — When Claude Can't Ask: Building Interactive Tools for the Agent SDK](https://oneryalcin.medium.com/when-claude-cant-ask-building-interactive-tools-for-the-agent-sdk-64ccc89558fa) — discriminated-union tool_result pattern, cited by Panel #1.
- [arxiv 2603.12564 — AgentDrift: Unsafe Recommendation Drift Under Tool Corruption](https://arxiv.org/html/2603.12564) — partial-coverage fallback drift, cited by Panel #4 (justifies all-6 scope, not 1-tool MVP).
- [Galileo — Why multi-agent LLM systems fail](https://galileo.ai/blog/multi-agent-llm-systems-fail) — 41-86% prod failure rates with incomplete schemas, cited by Panel #4.
- [Karpathy — LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) + [LLM Wiki v2](https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2) — direction lock for D-A3-03 (per memory `project_user_profile_wiki`).
- [OpenAI Cookbook — Context Engineering for Personalization](https://developers.openai.com/cookbook/examples/agents_sdk/context_personalization) — distill durable facts into structured memory before persisting, cited by Panel #3.
- [Mem0](https://github.com/mem0ai/mem0) + [ReMe](https://github.com/agentscope-ai/ReMe) + [MemX arxiv 2603.16171](https://arxiv.org/html/2603.16171v1) + [Cloudflare Agent Memory](https://blog.cloudflare.com/introducing-agent-memory/) — 2026 convergent agent-memory patterns (write fact-level, key by stable topic ID, upsert dedup). MINT's `CoachInsightRecord` already implements this shape.

### Project doctrine
- `CLAUDE.md §1` — financial_core reuse + LSFin banned terms + accent-FR + i18n.
- `CLAUDE.md §3.5` — routing rules + design panel composition.
- `CLAUDE.md §4` — DEV RULES (branch naming, conventional commits, lefthook gates).
- `CLAUDE.md §9` — 0-TRUST PROTOCOL (D-A3-09 inherits).
- Engram memory `project_coach_forced_tool_invocation` — trust-collapse tripwire pattern (this iteration IS that pattern applied at the missing-data boundary).
- Engram memory `project_user_profile_wiki` — Karpathy direction lock for D-A3-03.
- Engram memory `feedback_pre_push_checklist` — caller-grep + canonical regen + full test before push.
- Engram memory `feedback_perimeter_5_gates` — 5-gate exit contract.
- Engram memory `feedback_expert_panel_pattern` — panel pattern used to produce THIS context.

### Engram observations (use `prior_finding_refs` when saving findings)
- obs id 81 — RAG-context root cause (Wave A2 surface discovery).
- obs id 87 — Wave A2 shipped (orchestration-layer cut).
- obs id 88 — Wave A2.1 ship + A3 must-have proposal (THE source of this context).
- obs id 89 — Panel #1 decision (backend contract = structured tool_result discriminator).
- obs id 90 — Panel #2 decision (instruction in tool description, not system prompt).
- obs id 91 (in-message return from context-manager agent; full transcript in DISCUSSION-LOG.md) — Panel #3 decision (synchronous in-turn cache + same-turn wiki write).
- obs id 92 — Panel #4 decision (6 chip-emitters in one PR).
- (NEW, save when this CONTEXT is committed) — A3 CONTEXT landed; topic key `coach:tool_use:missing_fields_handshake:wave_a3:context_landed` with `supersedes` for any older « next-steps from A2.1 » projection notes.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (verified 2026-05-15)
- `services/backend/app/services/coach/profile_extractor.py` — `Fact` dataclass + `extract_profile_facts` (free-text French → structured rows) + `facts_to_insight_rows`. Already covers age / salary / canton / family / LPP / 3a / debt. Only gap = `avs_contribution_years` (add `_extract_avs_years`).
- `services/backend/app/models/coach_insight.py` — `CoachInsightRecord` with `(user_id, topic)` index + upsert semantics. The "wiki page" for a user is `WHERE user_id = X`.
- `services/backend/app/services/coach/coach_tools.py` — 26-tool Anthropic tools array (the actual file; Panel #2's `tool_registry.py` does not exist). All `input_schema` additions land here.
- `services/backend/app/models/coach_tools/{budget_snapshot,retirement_projection,cross_pillar,couple_optimization}.py` — existing per-tool Pydantic models. Site of `CoachToolResponse` migration.
- `services/backend/app/api/v1/endpoints/coach_chat.py:2443-2470` — `save_insight` existing wiki-write code path. Reused, not replaced.
- `services/backend/app/api/v1/endpoints/coach_chat.py:_run_narrator_with_gate` ~line 4230 — agent loop entry. Phase 94 `_citation_gate` byte-identity preserved (status:"incomplete" produces no citations).
- `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` (if exists) — Maestro extended with 6 sub-scenarios; otherwise create `coach_handshake_6_tools.yaml`.
- `apps/mobile/lib/services/financial_core/` — Dart source-of-truth calculators (CLAUDE.md triplet #3 mandatory reuse).

### Established Patterns
- Pydantic v2 RootModel + discriminated union is MINT-standard for status-bearing payloads.
- `Fact` dataclass + `confidence: Literal["low", "medium", "high"]` is the existing confidence model for profile extraction.
- `coach.<surface>.<event>` Sentry breadcrumb category convention (e.g. `coach.tool.<name>`, `coach.citation_gate`, this iteration adds `coach.tool.incomplete`).
- Conventional commits per `CLAUDE.md §4`. Lefthook gates: memory-retention, wiki-lint, banned-terms-arb, arb-parity. `LEFTHOOK_BYPASS=1` only with explicit reason — never `--no-verify`.

### Integration Points
- D-A3-01 `CoachToolResponse` → narrator `_run_narrator_with_gate` JSON-encodes into tool_result.content.
- D-A3-02 `MISSING_FIELDS_INSTRUCTION_FR` → injected into every chip-emitting tool's `description` field at registration time in `coach_tools.py`.
- D-A3-03 turn-local cache → `coach_chat.py` agent-loop state dict + same-turn `save_insight` call.
- D-A3-06 server-side floor → `_run_narrator_with_gate` empty-message branch synthesizes from `hint_fr`.
- D-A3-07 happy-path computations → `apps/mobile/lib/services/financial_core/` + backend mirror constants under `services/backend/app/services/`.

</code_context>

<specifics>
## Specific Ideas

- **Canonical handshake question pattern (FR)**, surface in narrator system-prompt POINTER block:
  - « Pour répondre, j'ai besoin de [field1], [field2] et [field3]. Tu peux me les partager ? »
  - LSFin-clean. 100% French accents. Phrase used in `coach.tool.incomplete.fallback_used` server-side synthesis (D-A3-06).
- **Confirmation echo (FR)** for low-confidence handshake captures (D-A3-03):
  - « J'ai noté [valeur] pour [field] — c'est bien ça ? »
- **Sentry tripwire alarm (operational, post-deploy)**: rule `stop_reason==end_turn AND content==[] AND last_tool_result.status==incomplete AND fallback_used==false` → page on-call. Sister to parent CONTEXT's tripwire on placeholder-without-tool_use.
- **Live probe expected shape post-A3** (`curl https://mint-staging.up.railway.app/api/v1/coach/chat ...` against a blank-profile staging user asking « Quelle sera ma rente AVS à 65 ans ? »):
  - First turn: `message: « Pour calculer ta rente AVS, j'ai besoin de ton âge, ... »`, `toolCalls: [{name: "get_retirement_projection", input: {...}}]`, `citationChips: null` (no citation on incomplete-status tool result).
  - Second turn (user types `« j'ai 42 ans, 8 années AVS, 320'000 LPP, 25'000 3a »`): `message: « Sur la base de tes valeurs, ta rente projetée est de … {{cite:tool_retirement_projection}} »`, `toolCalls: [{name: "get_retirement_projection", input: {age: 42, avs_contribution_years: 8, lpp_balance: 320000, pillar3a_balance: 25000}}]`, `citationChips: [{toolName: "get_retirement_projection", ...}]`.
- **PR titles** (conventional commits): preferred
  - `fix(wave-1c-A22): silence ChromaDB n_results=0 warning` (separate 3-line pre-A3 PR)
  - `feat(wave-1c-A3): missing-fields handshake on 6 chip-emitters` (the main A3 PR)

</specifics>

<deferred>
## Deferred Ideas

- **Open Banking / bank-data ingestion** that would pre-fill `lpp_balance` / `pillar3a_balance` / `avs_contribution_years` automatically, eliminating most handshake turns. Belongs in a future milestone post-Wave 1c. Memory: `project_byok_scope`.
- **`provenance` JSON column migration on `CoachInsightRecord`** — encode `{source, captured_at, raw_quote, confidence}` as a structured column instead of inline in `summary`. Defer to a follow-up cleanup; v1 inlines.
- **A3.2 — extend handshake to non-chip narrator tools** (`get_canton_tax_table`, `retrieve_memories`, `search_wiki`, etc.). Optional; ship only if Wave B G2 surfaces fallback-drift on those surfaces.
- **LLM-based parser for free-text FR values** — replace regex+keyword with a structured tool-use call for value extraction. Defer; Karpathy-2 simplicity wins for the 4 numeric fields A3 cares about.
- **Multi-tool-eligible intent handling** (« ma retraite à Genève » → retirement AND tax intents) — out of scope for A3; flagged in Panel #4 risk #2 as a follow-up if Maestro coverage surfaces it.
- **Bank PDF upload + parse** (salary slip, LPP attestation) — future milestone; not the A3 ask path.
- **Wave 1c-A3 status flip on `wave-1b-VERIFICATION-REPORT.html`** — Wave 1b PENDING G2 → SHIPPED flips after A3 G2 green + live chip-render probe; happens via manual edit by Julien once Claude provides probe evidence, NOT as part of A3's own plan.

</deferred>

---

*Phase: wave-1c-coach-tool-dispatch-rca (sub-iteration A3)*
*Context gathered: 2026-05-15 via 4 expert panels (engram obs #89, #90, #91 in-message, #92)*
*0-trust note: every claim above is anchored to a file path verified 2026-05-15, an engram observation, a panel-cited URL, or a deterministic command output. No « shipped » / « ready » / « works » claims. PR not opened; plan not written; nothing merged.*
