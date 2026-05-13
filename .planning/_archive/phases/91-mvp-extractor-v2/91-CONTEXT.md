# Phase 91: MVP-EXTRACTOR-V2 - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning
**Source:** discuss-phase 2026-05-09 (RESEARCH.md OQ-1..7 + DG-3 + open ops decisions resolved in single pass via accept-all)

<domain>
## Phase Boundary

Backend / LLM orchestration. Split the single coach LLM into 2 distinct roles:

- **Extractor** (fatter Sonnet 4.5, JSON-only, capture-focused): owns `save_fact` + `save_insight`-style fact capture. Runs BEFORE narrator. Reads user message + 6-turn history + profile snapshot. Returns Pydantic `ExtractorOutput(facts, intents)`. Non-fatal on failure (returns empty list, narrator runs anyway with regex floor only).
- **Narrator** (thin Haiku 4.5 first / Sonnet fallback, delivery-only): owns user-facing reply + tool routing. Reduced tool list (no `save_fact`, no `save_insight`). Trimmed system prompt (extraction directives REMOVED). Reads fresh consolidated profile + reasoning block + intents from extractor.

Resolves « LLM does extraction + narration poorly because they pull attention in opposite directions » (4-week production evidence, `profile_extractor.py:8-14` docstring + the regex extractor's existence). Unblocks Phase 94 (CITATION-GATE) and Phase 96 (CHAT-AS-VERB) which both depend on narrator being structurally constrained.

**OUT OF SCOPE:** CITATION-GATE parser (Phase 94), regex extractor removal (never — kept as floor), `StructuredReasoningService` rewrite, feature flag infra (assumed in place), multi-language extraction beyond FR+EN regex baseline.

</domain>

<decisions>
## Implementation Decisions

### Narrator Model Strategy
- **D-01:** Haiku-first with Stage 3 eval gate. Default narrator = `claude-haiku-4-5-20251001`. Gate: 50-fixture eval pack measures (a) ComplianceGuard pass-rate, (b) DoctrineChecks 6-check pass-rate, (c) banned-term lint pass-rate, (d) human Julien on-brand judgment. If Haiku <95% Sonnet pass-rate on (a)+(b)+(c) → fallback to `claude-sonnet-4-5-20250929` for narrator (cost +54% per turn). If pass → ship Haiku narrator (cost -2.5% per turn vs today). Gate is a discrete blocking task BEFORE Stage 4 staging soak (single-variable test, per D-06).

### Confirmation Gate UX (High-Stakes Keys)
- **D-02:** Option (b) — persist immediately, narrator surfaces « j'ai mis à jour ton canton — c'est correct ? » with undo. Faster path than option (a) pending-confirmation pattern. Trade-off: rare false-positive change visible to user vs always-double-turn confirmation tax. `_HIGH_STAKES_KEYS = {"canton", "commune", "householdType", "employmentStatus", "incomeGrossYearly"}` triggers the surface message ; tools `unfact` / `correct_fact` available to narrator for undo. Persistence happens BEFORE narrator runs (the narrator reads the fresh profile and announces the change).

### Extractor Scope
- **D-03:** Extractor absorbs intent classification — replaces keyword-based regex `_classify_user_intent` (`coach_chat.py:921-940`). Extractor system prompt's `intents` enum carries the load. Recall lift on unusual phrasings (« je crois que je dois trop d'argent à ma carte » → `debt`). Regex `_classify_user_intent` kept as fallback for extractor-failure path (returns empty list).
- **D-04:** Extractor runs on anonymous chat (no `_user`). Output cached in **request-scoped state** (Python dict on the request lifecycle), **never written to DB**. Persistence path remains gated on `body.persistence_consent=True` AND `_user is not None`. Adds ~$0.018 per anonymous turn ; improves anonymous coaching quality measurably (ABC funnel, Lauren-archetype « j'ai 80k à Genève » → coach has session-long context without account).
- **D-05:** `save_insight` stays narrator-side. Insight detection is narrative judgment (« she's worried about her debt »), not fact extraction (« she stated 50k debt »). Defer move-to-extractor to follow-up phase if narrator under-call symptom emerges post-Phase 91.

### Operational Gates
- **D-06:** Stage 3 narrator eval is a **discrete 1-day blocking task** BEFORE Stage 4 staging flip. Single-variable test (Haiku vs Sonnet on the same 50 fixtures). Eval fixtures sourced from PII-scrubbed production logs (handpicked 50 representative turns spanning compliance edges, banned-term proximity, French nuance, life-event diversity). Eval pass criteria: ≥95% Sonnet pass-rate on ComplianceGuard + DoctrineChecks + banned-term lint, plus Julien on-brand sign-off.
- **D-07:** Stage 0 telemetry baseline ON. ~1h grep over last 7 days production logs (`profile_extractor: persisted X fact(s)` log line at `coach_chat.py:2510`) to compute empirical « Sonnet under-calls save_fact » rate. Gives quantified lift estimate before Phase 91 ships ; mitigates DG-3 « is the production drift real ? » objection. Output: `tests/fixtures/extractor_baseline_2026-05.md` summary.
- **D-08:** Maestro G1 flow is **multi-fact** : `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` sends « j'ai 80k de salaire à Lausanne, je suis né en 1990 » in anonymous chat. Asserts post-message profile/in-memory state has `incomeGrossYearly=80000` AND `canton='VD'` AND `birthYear=1990`. Stronger gate than 1-fact ; also exercises the anonymous-chat path (D-04).
- **D-09:** Regex extractor lifecycle: **kept forever** as deterministic floor. No sunset planned post-Phase 91. Karpathy #2 (Simplicity First) — regex catches what LLM misses (typos, abbreviations, edge formats) for free, ~50 LOC of maintenance is cheap insurance. Future phases NEVER assume regex extractor is removable.

### Cache + History (Tech Detail)
- **D-10:** Cache backend = **Redis** via existing `app.core.rate_limit` Redis client. 30s TTL on `(user_id, sha256(sanitized_message))`. In-memory dict fallback if Redis env unset (degrades cache hit-rate, doesn't block functionality).
- **D-11:** Cache payload = **persisted facts** (post-`_coerce_fact_value` canonical values), NOT raw extractor output. No PII source_quote substrings in Redis. Same redaction precedent as `coach_chat.py:1603-1614`.
- **D-12:** Conversation history window = **6 turns both LLMs** (`safe_history[-6:]` per today). No asymmetry. Revisit only if Stage 4 staging soak shows extractor recall miss on multi-turn fact statements (e.g. « je vis à Lausanne » turn-1 + « j'ai 80k » turn-3 not joined).

### Claude's Discretion
- Exact Pydantic schema for `ExtractedFact` / `ExtractorOutput` field naming and validation rules (within the contract: `key`, `value`, `confidence`, `source_quote` ; `_SAVE_FACT_ALLOWED_KEYS` whitelist ; range guards via `_coerce_fact_value`).
- Exact extractor system prompt wording (RESEARCH §3 provides skeleton ; planner refines).
- Exact narrator system prompt diff (which lines of `_BASE_SYSTEM_PROMPT` to remove vs keep — RESEARCH §3 names 4 blocks ; planner finalizes).
- Retry message wording on JSON parse failure (« your previous output was not valid JSON ... »).
- Stage breakdown granularity within Stages 1-5 (RESEARCH §4 provides skeleton ; planner waves it).
- Eval fixture sampling methodology (50 hand-picked turns ; planner can deviate to 75-100 if signal noisy).
- Test fixtures specifics: which exact « happy-path / prose-mode / hallucinated-key / hallucinated-quote / low-conf / 0-fact » test cases to write (RESEARCH §4 Stage 1 T1.3 provides 7 ; planner finalizes).
- Logging verbosity (extractor success, retry, fail logging levels).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 91 anchors
- `.planning/phases/91-mvp-extractor-v2/RESEARCH.md` — full 848-line research artifact ; sections §3 (architecture), §4 (migration plan stages 0-5), §6 (counter-args + DG-1..6), §7 (validation architecture), §13 (assumptions A1-A10), §14 (open questions OQ-1..7 — all resolved here)
- `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` — milestone strategic frame, 5-gate exit contract, dependency graph, risks (#1-#6)
- `.planning/ROADMAP.md` §`### Phase 91: MVP-EXTRACTOR-V2` — Goal, Depends on (Phase 90), Requirements EXTR-01..07, Success Criteria 1-5

### Code touch points (READ-FIRST mandate per CLAUDE.md §7 #3 Surgical Changes)
- `services/backend/app/api/v1/endpoints/coach_chat.py` (2912 lines) — main pipeline. Specific sections:
  - L296-322 `_INJECTION_PATTERNS` (sanitize, reused by both LLMs)
  - L383-467 `_sanitize_conversation_history` (reused)
  - L469-510 `_sanitize_profile_context` (reused, verify whitelist covers `_SAVE_FACT_ALLOWED_KEYS` per A6)
  - L921-940 `_classify_user_intent` (regex fallback for D-03)
  - L955-969 `_has_concrete_facts` (skip-extractor heuristic per D-12 mitigation)
  - L1081-1103 `_SAVE_FACT_ALLOWED_KEYS` (canonical key whitelist — REUSE, do not duplicate)
  - L1142-1196 `_coerce_fact_value` (range guards — REUSE)
  - L1207-1208 model defaults (Sonnet 4.5 / Haiku 4.5)
  - L1219-1276 `_call_with_fallback` (extend for extractor mode per RESEARCH §3)
  - L1429-1556 `save_insight` handler (NARRATOR keeps this — D-05)
  - L1563-1634 `save_fact` handler (rename to `_persist_extracted_fact`, called from new `llm_extractor.py` per RESEARCH §6 Counter-arg #4)
  - L1603-1625 `_scrub_pii` + `is_safe_to_log` (extractor logging path uses same)
  - L1998-2274 `_run_agent_loop` (REUSE verbatim ; only `system_prompt` + `stripped_tools` change)
  - L2039 `stripped_tools = get_llm_tools()` → narrator path uses new `get_narrator_llm_tools()` per RESEARCH §10 Pattern 3
  - L2174-2190 `_REPROMPT_EMPTY_NARRATION` / `_REPROMPT_EMPTY_END_TURN` (monitor under D-12 / DG-5)
  - L2462-2532 regex extractor invocation site (D-09 floor — extend with LLM extractor STAGE 2 parallel-then-merge)
  - L2611-2619 « PROFIL UTILISATEUR » block (anti-hallucination anchor, REUSE for both LLMs)
  - L2713-2731 `_run_agent_loop` invocation (sequential after extractor pipeline per RESEARCH §6 Pitfall 2)
- `services/backend/app/services/coach/profile_extractor.py` (603 lines) — regex extractor, REUSE as STAGE 1 floor (D-09)
- `services/backend/app/services/coach/claude_coach_service.py` (961 lines) — system prompt builder. Specific sections:
  - L492-501 BIOGRAPHY-AWARENESS comment (P2 walkthrough fix 2026-05-07 — keep, narrator still needs)
  - L503-664 `_BASE_SYSTEM_PROMPT` body — refactor T0.1 per RESEARCH §4: extract « EXTRACTION DE PROFIL » L610-643 into `_EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM` ; legacy single-LLM path keeps it, narrator path drops it
  - L540-541 « TOUJOURS appeler save_insight » directive — REMOVE from narrator path
  - L632-643 4-layer extraction examples — REMOVE from narrator path
  - L667-674 `_LANGUAGE_NAMES` (i18n switch — KEEP, narrator output stays locale-correct per CLAUDE.md §1 #5)
  - L677-780 11-block prompt assembly — narrator path uses trimmed assembly per RESEARCH §10 Pattern 2
  - L705-713 `_BASE_SYSTEM_PROMPT.format(...)` site
- `services/backend/app/services/rag/llm_client.py` — `LLMClient.generate(...)` L182-272 REUSE (same retry policy, timeout, error envelope) ; only `model` + `system_prompt` change
- `services/backend/app/services/rag/orchestrator.py` — `_NoRagOrchestrator.query` L37-178 = the shape extractor uses (no RAG retrieval needed)
- `services/backend/app/services/coach/coach_tools.py` (1229 lines) — extend with `get_narrator_llm_tools()` per RESEARCH §10 Pattern 3 (excludes `save_fact` + `save_insight`)
- `services/backend/app/services/coach/structured_reasoning.py` — DO NOT TOUCH (out of scope per CLAUDE.md §7 #3)

### Project-level rules
- `/Users/julienbattaglia/Desktop/MINT.nosync/CLAUDE.md` §1 (banned terms LSFin), §1 #2 (accent_lint_fr), §1 #4 (i18n required), §1 #6 (0-trust protocol — Stage 4+5 require Maestro G1 + post-merge sim), §7 (Karpathy #2 Simplicity / #3 Surgical), §8 (Wiki schema — TLDR mandatory + counter-arguments)
- `tools/checks/banned_terms_arb.py` (narrator output continues to pass)
- `tools/checks/accent_lint_fr.py` (extractor system prompt + narrator system prompt both pass)
- `.planning/phases/90-mvp-design-lints-v1/VERIFICATION.md` — Phase 90 lint baselines (don't regress on touched files)

### Test infrastructure
- `services/backend/tests/test_profile_extractor.py` (25 tests) — anti-regression, ALL must still pass
- `services/backend/pyproject.toml` — pytest config
- `tools/simulator/flows/maestro-perfect-set/` — Maestro G1 flow library (D-08 adds `flow_extractor_captures_age_canton.yaml`)
- `tools/simulator/walker_audit_tap_render.sh` — Maestro flow runner per A7 (planner verifies argument shape)

### Decision precedents
- `decisions/ADR-20260419-autonomous-profile-tiered.md` — auto profile L1/L2/L3 routing
- `decisions/ADR-20260223-unified-financial-engine.md` — financial_core single source of truth (Phase 91 doesn't touch calculators, but narrator routing must defer numeric work to existing tool surface per CLAUDE.md §1 #4)
- `decisions/ADR-20260419-v2.8-kill-policy.md` — kill-policy template (Stage 3 eval failure → fallback Sonnet narrator, NOT phase kill)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (per RESEARCH §8 « Don't Hand-Roll »)
- **`LLMClient.generate(...)`** at `services/backend/app/services/rag/llm_client.py:182-272` — both extractor and narrator share this client class. Only `model` parameter and `system_prompt` change. Tenacity retries 429/5xx/connection ; 7-month battle-tested.
- **`_SAVE_FACT_ALLOWED_KEYS`** at `coach_chat.py:1081-1103` — canonical fact key whitelist. Single source of truth. Extractor's Pydantic `ExtractedFact.key` Literal enum mirrors this list.
- **`_coerce_fact_value`** at `coach_chat.py:1142-1196` — range guards (e.g. `birthYear` 1900-current+1, `canton ∈ 26 codes`). REUSE in extractor's persistence path verbatim.
- **`_sanitize_conversation_history`** at `coach_chat.py:383-467` — already PII-scrubbed and turn-capped. Extractor input passes through this.
- **`_sanitize_profile_context`** at `coach_chat.py:469-510` — strips control tokens. Extractor's profile snapshot input passes through this. (A6 verifies whitelist covers all `_SAVE_FACT_ALLOWED_KEYS`.)
- **« PROFIL UTILISATEUR » block builder** at `coach_chat.py:2611-2619` — anti-hallucination anchor for both LLMs.
- **`app.core.rate_limit` Redis client** — REUSE for D-10 cache backend (in-memory dict fallback if env-not-configured).
- **`_run_agent_loop`** at `coach_chat.py:1998-2274` — REUSE verbatim for narrator path. Only `system_prompt` + `stripped_tools` change.
- **JSON-fence parsing pattern** at `rag/orchestrator.py:339-356` (`_parse_vision_fields`) — REUSE for extractor JSON parse (handles raw JSON, ```json``` fences, ``` fences, per RESEARCH §6 Pitfall 1).
- **`is_safe_to_log` PII allowlist** at `app.services.privacy.fact_key_allowlist` (called at `coach_chat.py:1612-1614`) — REUSE in extractor logging path.

### Established Patterns
- **Feature flag rollout**: 5-stage migration plan (T0 pre-flight, T1 module, T2 wire, T3 model choice, T4 staging, T5 prod) is a standard MINT pattern from Phase 30.6 / Phase 31. `COACH_DUAL_LLM_ENABLED` lives in `app.core.config` per Phase 33 kill-flag pattern.
- **Pydantic v2 schemas everywhere**: project standard per CLAUDE.md §1. New `ExtractorOutput` follows the camelCase contract (input keys English, value coercion via `_coerce_fact_value`).
- **Persistence consent gate**: existing `body.persistence_consent` check at `coach_chat.py:2476-2483` controls regex extractor today ; LLM extractor inherits the same gate (no extraction without consent on authenticated path ; D-04 carves anonymous = run-but-don't-persist).
- **Sonnet/Haiku fallback chain**: existing `_call_with_fallback` at `coach_chat.py:1219-1276` extends to support « extractor mode » where fallback is Haiku (per A2 cost case if extractor stays Sonnet).
- **Async-aware Anthropic call**: existing `await self._client.messages.create(...)` in `LLMClient.generate` ; extractor + narrator BOTH async ; SEQUENTIAL not parallel (per RESEARCH §6 Pitfall 2 — narrator must read profile AFTER extractor persists).
- **Maestro G1 flow as gate**: phase exit blocked until `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` PASS on booted sim (D-08).

### Integration Points
- **`coach_chat.py` Step 1.4** at L2480-2540: extend with LLM extractor STAGE 2 (asyncio.gather with structured-reasoning at L2542). Behind flag `COACH_DUAL_LLM_ENABLED`.
- **`_run_agent_loop` invocation** at L2713-2731: stays the same call site ; the `system_prompt` and `stripped_tools` parameters fork on flag.
- **`save_fact` tool definition** at `coach_tools.py:492-595`: still EXISTS in registry, but `get_narrator_llm_tools()` excludes it (D-04 Pattern 3) ; legacy path keeps it visible.
- **`save_insight` tool**: stays in narrator's tool list (D-05).
- **Anonymous chat path** at `coach_chat.py:2517-2524`: extends to call extractor with in-memory persistence (request-scoped dict, no DB write per D-04).

</code_context>

<specifics>
## Specific Ideas

- **« Le narrateur LLM est mathématiquement incapable d'émettre un chiffre un-cited »** (milestone doctrine) — Phase 91 is the structural prereq. Phase 94 (CITATION-GATE) is the runtime parser. Phase 91 doesn't ship the parser, but its narrator with reduced tool list + trimmed system prompt is what makes the parser tractable.
- **« 2 prompts, 2 guardrails, 2 budgets »** (milestone §Phase 2) — symmetric architectural commitment. Token caps: extractor 12k input / 2k output ; narrator 4k input / 800 output. Guardrails: extractor = Pydantic schema + key whitelist + source_quote substring check ; narrator = ComplianceGuard + DoctrineChecks + HallucinationDetector + ARB language enforcement (all KEPT from today).
- **« j'ai 80k de salaire à Lausanne, je suis né en 1990 »** is the canonical Maestro G1 fixture. Multi-fact (D-08) ; exercises canton+income+birthYear extraction simultaneously. Used in eval fixtures + flow YAML + test_llm_extractor.py happy-path test.
- **Cost outcome hinges on Stage 3 eval (D-01 + D-06)**. Pass scenario: −2.5% per turn (Haiku narrator). Fail scenario: +54% per turn (Sonnet narrator). Plan must surface the gate explicitly to Julien before Stage 4 flip ; not a silent pass-through.
- **Compliance posture stays unchanged**: extractor JSON output is NOT user-facing → banned-terms lint N/A on extractor. Narrator output passes existing ComplianceGuard + DoctrineChecks. Net: no regression on LSFin / nLPD / accent / ARB parity. (Per RESEARCH §11 Security Domain.)
- **A8 production rate of « Sonnet under-calls save_fact »** is the critical assumption for Phase 91 cost-justification. D-07 (Stage 0 telemetry baseline) gives empirical lift estimate before commit. If baseline shows <10% under-call rate, Phase 91 cost case weakens — surface this to Julien at Stage 0 review.

</specifics>

<deferred>
## Deferred Ideas

- **CITATION-GATE post-process parser** — Phase 94 (depends on Phase 91 narrator with reduced tools). Phase 91 leaves stub test `tests/test_narrator_refuses_uncited_numbers.py` skip-marked.
- **DAG-INVALIDATION `inputs_hash` + `superseded_by` on projections** — Phase 95.
- **CHAT-AS-VERB intent bar on cards + 3-turn cap + chat-tab kill** — Phase 96.
- **`save_insight` ownership move to extractor** — defer to follow-up phase if narrator under-calls it post-Phase 91 (D-05).
- **Prompt registry pattern** (à la `prompt_registry.py` already in `services/coach/`) for both extractor and narrator system prompts — defer to follow-up phase (OQ-5). Phase 91 hardcodes prompts as module constants in `llm_extractor.py` and `claude_coach_service.py`.
- **Parallel extractor + narrator** (asyncio.gather both LLM calls instead of sequential) — defer ; revisit if narrator latency drives Phase 96 3-turn cap pain (RESEARCH §2 Alternatives Considered, REJECTED for Phase 91).
- **OpenAI structured-outputs as alternate extractor** (`response_format=json_schema`) — REJECTED (BYOK contract = single-provider Anthropic).
- **Replace `extract_profile_facts` regex extractor entirely** — NEVER (D-09 keeps as deterministic floor forever).
- **Multi-language extraction beyond FR+EN regex baseline** — out of scope (regex covers via `profile_extractor.py:208-220`).
- **Anthropic Sonnet 4.5 model registry refresh check** — discovery task at Stage 0 (`curl https://api.anthropic.com/v1/models`) ; if model deprecated by 2026-05-23 (RESEARCH validity window), planner re-locks model ID.
- **Per-token Anthropic pricing re-verification** — Stage 0 task. Re-fetch Anthropic console ; if pricing materially shifts (>20%), re-run §5 cost analysis before Stage 4 flip.

</deferred>

---

*Phase: 91-mvp-extractor-v2*
*Context gathered: 2026-05-09 via single-pass discuss-phase (RESEARCH-driven, accept-all-defaults)*
*Source decisions: 12 D-XX entries resolving OQ-1..7 + DG-3 + 4 ops decisions*
*Next: `/gsd-plan-phase 91` to produce PLAN.md with Stage 0-5 task DAG + 5-gate exit contract*
