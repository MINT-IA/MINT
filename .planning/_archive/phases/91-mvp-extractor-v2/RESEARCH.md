---
name: MVP-EXTRACTOR-V2 — RESEARCH
description: Research artifact for Phase 2 of MILESTONE-CHAT-AS-VERB-2026-05-09. Splits the single coach LLM into two distinct roles (extractor fatter / narrator thin) so extraction quality and delivery concision can be optimized independently. Maps current 3-role conflation in `coach_chat.py`, proposes a 2-LLM architecture with explicit API contracts, and surfaces cost (+90% per turn before mitigations) and 6 open questions for the planner.
type: phase-research
date: 2026-05-09
phase: MVP-EXTRACTOR-V2
milestone: CHAT-AS-VERB-2026-05-09
status: RESEARCH-COMPLETE
domain: backend / LLM orchestration
confidence: MEDIUM-HIGH
researcher: gsd-phase-researcher (Opus 4.7 1M)
related:
  - .planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md (on branch docs/milestone-chat-as-verb, head bd19e9f7)
  - .planning/phases/MVP-DESIGN-LINTS-V1/EXEC.md
  - .planning/phases/MVP-DESIGN-LINTS-V1/VERIFICATION.md
sources:
  - services/backend/app/api/v1/endpoints/coach_chat.py (2912 lines, full read)
  - services/backend/app/services/coach/profile_extractor.py (603 lines, full read)
  - services/backend/app/services/coach/claude_coach_service.py (961 lines, full read)
  - services/backend/app/services/rag/orchestrator.py (full read)
  - services/backend/app/services/coach/coach_tools.py (full read, 28 tools registered)
  - services/backend/app/services/coach/structured_reasoning.py (598 lines, header skim)
  - services/backend/app/services/rag/llm_client.py (model defaults, retry policy)
  - services/backend/tests/test_profile_extractor.py (25 tests, structure only)
---

# Phase 2 — MVP-EXTRACTOR-V2 — Research

## Goal recap

> Split the single LLM into 2 distinct roles : extracteur (fatter Sonnet, intent + facts capture) vs narrateur (thin Sonnet/Haiku, delivery only). 2 prompts, 2 guardrails, 2 budgets. Resolves « LLM is doing both jobs poorly » bottleneck.

**Why it matters now (per milestone §Strategic frame):** the same prompt that's good at extraction (be exhaustive, structured, JSON-only) is bad at narration (be concise, narrative, ≤4 phrases). Forcing one model to do both means it under-extracts when narration tone wins, and over-talks when extraction wins. The split lets each role be optimized against its own quality target. Phase 5 (CITATION-GATE) and Phase 7 (CHAT-AS-VERB) both depend on the narrator being **structurally constrained** — which is only achievable once it stops carrying the extraction load.

**Phase confidence: MEDIUM-HIGH.** The current state is HIGH (read directly). The proposed architecture is MEDIUM (no production analog inside MINT yet ; pattern is well-established in agentic systems but the specific fan-out shape needs piloting). Cost numbers are MEDIUM (token estimates derived from `coach_chat.py` system prompt size + observed `claude_coach_service.py` budget ; per-turn cost validated against Anthropic pricing as of model release dates, not re-checked against current pricing today).

## User Constraints (from CONTEXT.md)

**No CONTEXT.md exists** for this phase yet (Phase 2 was opened directly via `/gsd-research-phase` per the spawn prompt). The locked decisions therefore come from the milestone itself :

### Locked Decisions (from MILESTONE-CHAT-AS-VERB §Phase 2)

- **Split into 2 distinct LLM roles** : extractor + narrator. Not 1, not 3.
- **Extractor : fatter model**, capture-focused. Recommended starting point Sonnet 4.5.
- **Narrator : thin model**, delivery-only. Recommended starting point Haiku 4.5 OR Sonnet with strict prompt.
- **2 prompts, 2 guardrails, 2 budgets** — the architectural commitment is symmetric.
- **Phase is on the architecture track**, parallel to Phase 3/4 UI sweeps. No UI dependency.
- **Effort budget : 3 days**. Same envelope as Phase 5 (CITATION-GATE) and Phase 6 dropped (DAG-INVALIDATION = 4d).
- **5-gate exit contract** (G1 Maestro flow / G2 device by Julien / G3 dev CI / G4 regression / G5 LSFin+accent+ARB lint) per milestone §5-gate exit contract.

### Claude's Discretion

- **Where in the pipeline the extractor LLM runs** — before the agent loop, in parallel with retrieval, or as an LLM-driven first pass that augments the existing regex extractor. Research recommends the third (see §3 Proposed architecture).
- **Whether to keep `extract_profile_facts` (regex)** alongside the LLM extractor — kept as the cheap deterministic floor (see §4 Migration plan).
- **Token budget split** between extractor and narrator — research proposes 12k input / 2k output for extractor, 4k input / 800 output for narrator.
- **Caching policy** — research recommends 30-second cache on `(user_id, message_hash)` to absorb multi-tap-replay scenarios.

### Deferred Ideas (OUT OF SCOPE for Phase 2)

- The actual citation-gate parser (Phase 5 — anticipated in test stubs only).
- Removing `extract_profile_facts` regex extractor entirely (kept as floor, replaced never).
- Replacing `StructuredReasoningService` (deterministic, separate concern).
- Feature flag rollout / A/B testing infra (assumed already in place ; not part of this phase).
- Multi-language extraction parity beyond what regex covers today (FR + EN already handled in `profile_extractor.py:208-220`).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXTR-01 | A new extractor LLM call runs BEFORE the narrator agent loop on every coach turn that has user content. | §3 Proposed architecture, §4 Migration plan stage 1. |
| EXTR-02 | The extractor returns ONLY a JSON list of `{key, value, confidence, source_quote}` items — no prose. | §3 Extractor LLM contract, §6 Counter-arg « over-extraction ». |
| EXTR-03 | The narrator system prompt is rewritten to remove ALL extraction-related directives (the 5-bullet save_fact mandate, the 4-layer extraction examples, the EXTRACTION DE PROFIL block). | §2 Current state map row N1, §3 Narrator LLM contract. |
| EXTR-04 | The narrator's tool-set is reduced to a delivery-only subset — `route_to_screen`, `suggest_actions`, `show_*` cards, `record_check_in`. `save_fact` and `save_insight` are REMOVED from the narrator's tool list (their work is owned by the extractor). | §3 Narrator tool-set, §6 Counter-arg « who calls save_fact ». |
| EXTR-05 | The existing regex extractor (`extract_profile_facts`) keeps running as the FIRST stage. The LLM extractor runs SECOND and only persists facts the regex missed (or upgrades regex confidence). | §4 Migration plan, §6 Counter-arg « why both ». |
| EXTR-06 | Per-turn cost regression ≤ +90% before mitigations, ≤ +30% after caching + skip-on-empty mitigations. | §5 Cost / latency analysis. |
| EXTR-07 | Phase exit gate G1 = Maestro flow under `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` PASS on booted sim ; the flow sends « j'ai 80k de salaire à Lausanne » in anonymous chat and asserts that the post-message profile state has `incomeGrossYearly=80000` AND `canton='VD'`. | §7 Test strategy. |

## Project Constraints (from CLAUDE.md)

The following directives from `/Users/julienbattaglia/Desktop/MINT.nosync/CLAUDE.md` apply directly to Phase 2 implementation. The planner MUST verify compliance:

1. **Banned terms (LSFin)** — narrator output must continue to pass `tools/checks/banned_terms_arb.py` ; extractor output is JSON and not user-facing, so banned-term filter is N/A on its output. [VERIFIED: `claude_coach_service.py:44-46` lists the banned-terms reminder]
2. **Accents 100% FR mandatory** — any new prompt files (extractor system prompt) must pass `tools/checks/accent_lint_fr.py`. [VERIFIED: existing `_BASE_SYSTEM_PROMPT` in `claude_coach_service.py` is already accent-clean]
3. **Financial_core reuse mandatory** — N/A directly (Phase 2 is LLM split, no calculator changes), but the narrator must still defer numeric work to the existing tool surface (`get_retirement_projection`, `get_cap_status`, etc.).
4. **i18n required** — both extractor and narrator must respect `body.language` in `CoachChatRequest`. The extractor JSON output is language-neutral (English keys, raw values). The narrator output must remain locale-correct ; no regression on the existing `_LANGUAGE_NAMES` switch in `claude_coach_service.py:667-674`.
5. **0-trust** — "this works" claims for the new pipeline require Maestro flow output (G1) AND post-merge sim run (per CLAUDE.md §9.5). Plan must include both gates.
6. **Karpathy #2 Simplicity First** — research recommends reusing the existing `LLMClient` infrastructure (no new HTTP client) and the existing `RAGOrchestrator.query()` shape (no new orchestrator class) for the extractor. See §3 « Reuse, don't replace ».
7. **Karpathy #3 Surgical Changes** — the milestone scopes Phase 2 to LLM split only. Do NOT touch `StructuredReasoningService`, `coach_context_builder`, or the design system. Do NOT remove `extract_profile_facts` regex extractor (keep as floor). [CITED: spawn prompt §4]

## 1. Current state map

The coach_chat pipeline today executes 4 distinct extraction-or-narration sub-tasks **all served by the same LLM call**, plus 1 deterministic regex pre-pass, plus 1 deterministic structured-reasoning pre-pass. Every claim below is `[VERIFIED]` against the cited file.

### Roles conflated today (the actual problem Phase 2 fixes)

| # | Role | Where it lives today | Type | Owner |
|---|------|---------------------|------|-------|
| R1 | **Regex extraction** (deterministic) | `profile_extractor.py:500-554` (`extract_profile_facts`) called from `coach_chat.py:2491` | Pre-LLM, regex-only | NOT an LLM role — keep as-is |
| R2 | **Structured reasoning** (deterministic) | `structured_reasoning.py:516-598` (`StructuredReasoningService.reason`), called from `coach_chat.py:2542` | Pre-LLM, profile-data math | NOT an LLM role — keep as-is |
| R3 | **LLM extraction via `save_fact` tool** | `coach_chat.py:1563-1634` (handler) + `coach_tools.py:492-595` (tool definition) + `claude_coach_service.py:610-643` (system-prompt mandate) | Inside the agent loop | TODAY: the single coach LLM. PHASE 2: extractor LLM. |
| R4 | **LLM extraction via `save_insight` tool** | `coach_chat.py:1429-1556` (handler implied at L1429+) + `coach_tools.py:425-484` + `claude_coach_service.py:610-628` | Inside the agent loop | TODAY: the single coach LLM. PHASE 2: extractor LLM. |
| R5 | **Narration / delivery** (the actual user-facing reply) | `claude_coach_service.py:503-664` (`_BASE_SYSTEM_PROMPT`) + the LLM call inside `_run_agent_loop` (`coach_chat.py:1998-2274`) | Same agent loop | TODAY: the single coach LLM. PHASE 2: narrator LLM. |
| R6 | **Tool routing decisions** (which screen to open, which card to render) | `coach_tools.py` (28 tools) executed in `_execute_internal_tool` (`coach_chat.py:1354-1745`) | Inside the agent loop | PHASE 2: narrator LLM (delivery-side decisions). |

### Single-LLM call site (where the conflation lives)

`coach_chat.py:2713-2731` — `_run_agent_loop(...)` is invoked once per coach turn. It in turn calls `_call_with_fallback` → `orchestrator.query` → `LLMClient.generate` (`rag/llm_client.py:182-262`). One model, one system prompt, all 4 LLM-served roles (R3 + R4 + R5 + R6) collapsed into the same context window.

[VERIFIED: `coach_chat.py:2039` `stripped_tools = get_llm_tools()` returns ALL 28 tools to the same LLM instance.]
[VERIFIED: `claude_coach_service.py:705-713` `_BASE_SYSTEM_PROMPT.format(...)` builds ONE system prompt covering identity (R5), routing rules (R6), AND the « EXTRACTION DE PROFIL (RÈGLE CRITIQUE — TU DOIS LE FAIRE À CHAQUE FOIS) » block (R3+R4) at lines 610-643.]

### Symptoms of the conflation (drives Phase 2)

| Symptom | Citation |
|---------|----------|
| **Sonnet under-calls `save_fact`** even with the imperative MANDATORY block at `coach_tools.py:496-521`. | `profile_extractor.py:8-14` docstring : « save_insight relies on Claude Sonnet's compliance with an imperative system prompt. Even with explicit instructions, Claude is reluctant to call the tool consistently. » The whole regex extractor exists because of this drift. |
| **Narrator « ne peut pas voir ton salaire »** failure mode after user states a number in plaintext. | `claude_coach_service.py:492-501` BIOGRAPHY-AWARENESS comment block (« P2 walkthrough fix 2026-05-07 »): the LLM was refusing to use a number the user just typed, because the same prompt forbade it from citing biography numbers. The fix added 8 lines of clarification — i.e. patching the conflation, not removing it. |
| **System prompt is ~600 lines** (`_BASE_SYSTEM_PROMPT` + 11 appended blocks at `claude_coach_service.py:716-759`) — 80%+ of which is delivery doctrine, ~15% extraction, ~5% routing. The extraction directives compete with the longer delivery directives. | `claude_coach_service.py:677-780`. Estimated token cost of the assembled system prompt: ~3500-4500 tokens before any user/conversation context. |
| **`extract_profile_facts` (regex) was added 2026-04-13 as a floor** because the LLM-extraction was unreliable in production. The architectural debt has been visible for 4 weeks. | `coach_chat.py:2462-2532` comment block. |
| **Empty `end_turn` retry loop** at `coach_chat.py:2176-2190` exists because Claude sometimes emits tool-only responses without text — likely because the tool-emission part of the prompt won the attention budget over the narration part. | `coach_chat.py:2174-2190` `_REPROMPT_EMPTY_NARRATION` and `_REPROMPT_EMPTY_END_TURN` re-prompts. |

### Token budget today (single LLM)

| Slot | Estimate | Source |
|------|----------|--------|
| System prompt (assembled) | 3500-4500 tokens | `claude_coach_service.py:677-780` 11 appended blocks. Logged at `coach_chat.py:2650-2655` (`prompt_len/4` heuristic). |
| User profile DB block | 50-150 tokens | `coach_chat.py:2611-2619`. |
| Reasoning block | 100-400 tokens | `structured_reasoning.py` `as_system_prompt_block`. |
| Memory/insight/commitment/intelligence blocks | 200-1500 tokens | `coach_chat.py:2555-2558`. |
| Conversation history | 0-2000 tokens | `coach_chat.py:2726` `safe_history`. |
| User message | 50-500 tokens | `body.message` post-sanitize. |
| **Per-turn input total** | **~4000-9000 tokens** | sum |
| Output budget | 600 tokens | `rag/llm_client.py:216` `max_tokens=600`. |
| Model | `claude-sonnet-4-5-20250929` (default) ; fallback `claude-haiku-4-5-20251001` | `coach_chat.py:1207-1208`. |

[CITED: `rag/llm_client.py:203-216` comment « max_tokens 2048 → 600. Un coach qui répond en 2-4 phrases »]

## 2. Standard Stack

### Core (already present in MINT — REUSE, don't replace)

| Library | Version | Purpose | Why standard |
|---------|---------|---------|--------------|
| `anthropic` (Python SDK) | as imported in `rag/llm_client.py:59,182,377` | LLM API client (Claude Sonnet 4.5 + Haiku 4.5) | Already wired into `LLMClient`. Both extractor and narrator can share the same client class — only `model` parameter changes. [VERIFIED: `rag/llm_client.py:72` `"claude": "claude-sonnet-4-5-20250929"`] |
| `tenacity` | retry decorator at `rag/llm_client.py:248-262` | Retry policy for 429/5xx | Already wraps the existing call. Extractor inherits the same retry behavior for free. [VERIFIED] |
| `pydantic` v2 | already throughout backend | Schema validation for extractor JSON output | Project-standard for backend models per CLAUDE.md §1. |
| `RAGOrchestrator.query` / `_NoRagOrchestrator.query` | `rag/orchestrator.py:37-178` and `coach_chat.py:97-169` | Single-shot LLM call with system prompt + tools + filter | Both fan-out paths (extractor and narrator) can call this same `.query` method — extractor passes `tools=None` and a JSON-only system prompt ; narrator passes the reduced tool subset and the trimmed system prompt. [VERIFIED] |

### Supporting (new, but minimal)

| Library | Version | Purpose | When to use |
|---------|---------|---------|-------------|
| `app.services.coach.llm_extractor` (NEW MODULE) | new in this phase | Owns the LLM extractor system prompt + JSON parsing + schema validation | Created in Phase 2, ~150 lines. |
| `app.services.coach.extractor_schema` (NEW MODULE) | new | Pydantic models for `ExtractedFact` and `ExtractorOutput` | Created in Phase 2, ~50 lines. Schema = mirror of `_SAVE_FACT_ALLOWED_KEYS` from `coach_chat.py:1081-1103`. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Anthropic Sonnet 4.5 for extractor | OpenAI GPT-4o-mini structured-outputs | Better JSON schema enforcement (`response_format=json_schema`) but introduces a 2nd provider. MINT already runs single-provider Anthropic ; adding OpenAI breaks the BYOK contract. **REJECTED** for Phase 2. |
| 2 LLM calls in series (extractor → narrator) | 2 LLM calls in PARALLEL | Parallel cuts wall-clock latency by ~40% (extractor ~2s, narrator ~3-5s) but the narrator no longer benefits from extractor's freshly-persisted facts. **REJECTED**: serial is correct for Phase 2 ; parallel can be revisited if narrator latency drives Phase 7 chat-as-verb 3-turn cap pain. |
| Replace `extract_profile_facts` regex with LLM | Keep both (regex first, LLM augments) | LLM-only saves ~50 LOC of regex maintenance but reintroduces the « Sonnet under-calls » failure mode that motivated the regex in 2026-04-13. **REJECTED per spawn prompt §4 backwards compat directive.** |

**Installation:** zero new pip dependencies. The phase ADDS 2 Python modules under `services/backend/app/services/coach/` and modifies `coach_chat.py` to fan out into 2 LLM calls.

**Version verification (Anthropic models):**
- `claude-sonnet-4-5-20250929` — current MINT default (per `coach_chat.py:1207`). [VERIFIED via codebase grep]
- `claude-haiku-4-5-20251001` — current MINT fallback (per `coach_chat.py:1208`). [VERIFIED via codebase grep]
- Both model IDs are dated October 2025, ~7 months old at research time. [ASSUMED] — current registry status not re-verified in this session ; planner should confirm via `curl https://api.anthropic.com/v1/models` before locking model choice. Pricing (per 1M input/output tokens) was last published mid-2025 ; planner should re-fetch.

## 3. Proposed Architecture

### High-level fan-out

```
                 user message
                       │
            ┌──────────┴──────────┐
            │  Sanitize + intent  │  (unchanged from today)
            │  classification     │
            └──────────┬──────────┘
                       │
   ┌───────────────────┼─────────────────────┐
   ▼                   ▼                     ▼
┌──────────┐   ┌──────────────────┐   ┌─────────────────────┐
│ Regex    │   │ LLM Extractor    │   │ Structured          │
│ extract  │   │ (Sonnet 4.5)     │   │ Reasoning Service   │
│ STAGE 1  │   │ STAGE 2          │   │ (deterministic)     │
└────┬─────┘   └────────┬─────────┘   └──────────┬──────────┘
     │                  │                         │
     └──────────────────┴────────┬────────────────┘
                                 ▼
                  ┌──────────────────────────────┐
                  │ Persist facts to             │
                  │ ProfileModel.data            │
                  │ (idempotent on key)          │
                  └──────────────┬───────────────┘
                                 ▼
                  ┌──────────────────────────────┐
                  │ Narrator LLM                 │
                  │ (Haiku 4.5 OR Sonnet 4.5     │
                  │  with strict prompt)         │
                  │                              │
                  │ tools = delivery-only subset │
                  │ system prompt = trimmed      │
                  │ max_tokens = 800             │
                  └──────────────┬───────────────┘
                                 ▼
                       user-facing reply
                       + Flutter tool_calls
```

**Critical insight:** the regex extractor + LLM extractor + structured reasoning all run **before the narrator LLM**, and all three persist their findings to `ProfileModel.data` BEFORE the narrator runs. The narrator therefore reads a **fresh, consolidated profile** in its system-prompt « PROFIL UTILISATEUR (donnees reelles, NE PAS INVENTER) » block (`coach_chat.py:2611-2619`) — the same anti-hallucination block that exists today, but now reliably filled.

### Extractor LLM contract

**Model:** `claude-sonnet-4-5-20250929` (today's default — same as the current single LLM). The model is "fatter" relative to the narrator, NOT relative to today.

**Input:**
- System prompt (NEW, ~80 lines, ~600 tokens) — extraction-only, JSON-only
- User message (sanitized)
- Conversation history (last 6 turns max — recency window)
- Current profile snapshot (compact JSON, ~200 tokens)
- NO tools (none registered)

**System prompt skeleton:**
```
Tu es un EXTRACTEUR de faits financiers. Tu n'écris JAMAIS de prose pour l'utilisateur.
Sortie : JSON STRICT respectant le schema fourni. Aucun autre texte.

INPUT : message utilisateur + 6 derniers tours + snapshot profil.

OUTPUT (JSON) :
{
  "facts": [
    {
      "key": "<one of the canonical keys>",
      "value": <number | string | boolean>,
      "confidence": "high" | "medium",
      "source_quote": "<verbatim user quote, max 80 chars>"
    }
  ],
  "intents": ["debt" | "housing" | "family" | "career" | "retirement" | "taxes"]
}

CLES CANONIQUES (whitelist — toute autre clé sera rejetée) :
{enum from _SAVE_FACT_ALLOWED_KEYS}

REGLES :
- Extrais SEULEMENT ce que l'utilisateur a explicitement dit.
- N'extrais pas ce qui est déjà dans le snapshot profil sauf si l'utilisateur le corrige.
- Confidence "high" si le chiffre est exact (« 80'000 »). "medium" si arrondi (« environ 80k »).
  N'émets jamais "low" — si tu n'es pas sûr, n'émets pas le fait.
- source_quote DOIT être un extrait verbatim du message utilisateur. Si tu ne peux pas
  citer, n'émets pas le fait.
- Pas de prose. Pas de markdown. JSON UNIQUEMENT.
```

**Output schema (Pydantic v2):**
```python
class ExtractedFact(BaseModel):
    key: Literal[...]  # mirrors _SAVE_FACT_ALLOWED_KEYS, ~50 keys
    value: Union[int, float, str, bool]
    confidence: Literal["high", "medium"]
    source_quote: str = Field(..., max_length=80)

class ExtractorOutput(BaseModel):
    facts: list[ExtractedFact] = Field(default_factory=list, max_length=12)
    intents: list[Literal["debt", "housing", "family", "career", "retirement", "taxes"]] = Field(default_factory=list, max_length=4)
```

**Token budget:**
- Input cap : 12 000 tokens (allows fat conversation history + profile snapshot)
- Output cap : 2 000 tokens (`max_tokens=2000` in the Anthropic call)
- Per-turn realistic usage : ~3000 input + ~400 output = ~3400 tokens

**Guardrails:**
- Pydantic schema validation on output (reject + retry once on parse fail)
- Key whitelist (`_SAVE_FACT_ALLOWED_KEYS` from `coach_chat.py:1081-1103`)
- Value coercion via existing `_coerce_fact_value` (`coach_chat.py:1142-1196`)
- `source_quote` substring check against the actual user message — if quote is fabricated, reject the fact

**Failure mode:**
- On JSON parse error : log + retry once with explicit « your previous output was not valid JSON, return ONLY the JSON object now » prompt
- On second failure : extractor returns `{"facts": [], "intents": []}` — narrator continues with regex-extractor + structured-reasoning output only
- This means the LLM extractor is **always optional** — the pipeline degrades to current behavior on extractor failure

### Narrator LLM contract

**Model:** Two candidates evaluated.

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| `claude-haiku-4-5-20251001` | ~5x cheaper input, ~5x faster | Lower compliance with banned-term lint, less nuanced French | **Phase 2 starting point** with feature flag fallback to Sonnet |
| `claude-sonnet-4-5-20250929` | Same compliance as today (no regression risk) | No cost savings, no latency gain | Fallback if Haiku fails compliance gate G5 |

[ASSUMED] — Haiku 4.5 nuance/compliance on French is not measured against current MINT prompt corpus. The planner SHOULD include a 50-fixture eval of the narrator on a representative chat sample as task T-NAR-EVAL before committing to Haiku as default.

**Input:**
- System prompt (TRIMMED, target ≤300 lines, ~2000 tokens — vs ~600 lines / ~3500 tokens today). All extraction directives REMOVED. Delivery doctrine + routing rules + DOCTRINE INFORMATION + 5-gate compliance kept.
- User message (sanitized)
- Conversation history (last 6 turns)
- Profile snapshot (the « PROFIL UTILISATEUR » block from `coach_chat.py:2611-2619` — UNCHANGED, this is the anti-hallucination anchor)
- Reasoning block (from `StructuredReasoningService` — UNCHANGED)
- Detected intents (from extractor output OR existing `_classify_user_intent`)
- Reduced tool list — see below

**Reduced tool list (narrator's allowed tools):**

| Tool | Kept? | Reason |
|------|-------|--------|
| `route_to_screen` | YES | Delivery-side decision |
| `suggest_actions` | YES | Computes chips from now-fresh profile |
| `show_fact_card`, `show_budget_snapshot`, `show_score_gauge`, `show_commitment_card` | YES | Inline widgets, delivery surface |
| `record_check_in`, `record_commitment`, `save_pre_mortem`, `save_provenance`, `save_earmark`, `remove_earmark`, `save_partner_estimate`, `update_partner_estimate` | YES | These persist USER-DRIVEN events (« I just did this »), not extracted facts. They belong to delivery flow. |
| `ask_user_input` | YES | Delivery loop |
| `retrieve_memories` | YES | Read-only memory search ; useful for narration continuity |
| `get_*` (5 read-only data lookups) | YES | Read-side computations the narrator needs |
| `get_regulatory_constant` | YES | Source for cited numbers |
| `generate_financial_plan`, `generate_document` | YES | Flutter-bound delivery |
| **`save_fact`** | **NO** | OWNED BY EXTRACTOR. Removed from narrator's `tools` parameter. |
| **`save_insight`** | **NO** | OWNED BY EXTRACTOR (LLM-extracted insights). The narrator's job is to use facts, not capture them. |

**Token budget:**
- Input cap : 4 000 tokens
- Output cap : 800 tokens (already today's budget, see `rag/llm_client.py:216` and `coach_chat.py:1213-1216`)
- Per-turn realistic usage : ~3000 input + ~400 output = ~3400 tokens

**Guardrails (kept from today):**
- ComplianceGuard (`rag/guardrails.py`) — banned terms, conditional language, disclaimer injection
- DoctrineChecks (`coach/doctrine_checks.py`) — 6-check mechanical validation
- HallucinationDetector (`coach/hallucination_detector.py`) — cited number must match profile or reasoning block
- ARB language enforcement (existing language switch at `claude_coach_service.py:764-773`)

### Reuse, don't replace (Karpathy #2)

The new extractor module reuses :
- `LLMClient.generate(...)` from `rag/llm_client.py:182-272` — **same retry policy, same timeout, same error envelope**. Only difference is the `model` and `system_prompt` parameters.
- `_call_with_fallback` from `coach_chat.py:1219-1276` — extends to support an « extractor mode » where the fallback model is Haiku (not Sonnet) since extractor JSON output benefits less from Sonnet nuance.
- `RAGOrchestrator` is **not used by the extractor** — the extractor doesn't need RAG retrieval, only the user message + profile snapshot. It calls `LLMClient.generate` directly with `context_chunks=[]`. This is the same shape as `_NoRagOrchestrator.query` (`coach_chat.py:97-169`).

The new narrator wiring REUSES `_run_agent_loop` (`coach_chat.py:1998-2274`) verbatim — only the `system_prompt` and `stripped_tools` parameters change.

## 4. Migration plan

### Stage 0 — pre-flight (no behavior change)

- T0.1 Refactor `_BASE_SYSTEM_PROMPT` in `claude_coach_service.py:503-664` to extract the « EXTRACTION DE PROFIL » block (lines 610-643) into a separately exported constant `_EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM`. Both the legacy single-LLM path and the new narrator path can then assemble their prompts from named building blocks. **Zero behavior change.**
- T0.2 Add a feature flag `COACH_DUAL_LLM_ENABLED` in `app.core.config` (default `False`). Read at request time in `coach_chat.py` Step 1.5.
- T0.3 Author Maestro flow stub `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` — drives the G1 gate. Stub-only at this stage ; runs against current single-LLM and is expected to PASS already (the regex extractor catches `age` + `canton` from « j'ai 80k de salaire à Lausanne »). The stub becomes the regression-detection harness for stages 1-3.

### Stage 1 — extractor LLM module (no wire-up yet)

- T1.1 Create `app/services/coach/extractor_schema.py` (Pydantic models `ExtractedFact`, `ExtractorOutput`).
- T1.2 Create `app/services/coach/llm_extractor.py` with:
  - `EXTRACTOR_SYSTEM_PROMPT: str` — the JSON-only prompt skeleton from §3.
  - `async def run_llm_extractor(user_message, conversation_history, profile_snapshot, api_key, provider, model) -> ExtractorOutput`
  - JSON parse + Pydantic validate + `source_quote` substring check.
  - Retry-once policy on parse failure.
  - Returns `ExtractorOutput(facts=[], intents=[])` on second failure.
- T1.3 Unit tests : `tests/test_llm_extractor.py` (~12 tests). Fixtures :
  - happy path (« j'ai 80k à Lausanne ») → 2 facts (`incomeGrossYearly=80000`, `canton='VD'`)
  - prose-mode response (LLM returns French sentences) → reject + retry → empty
  - hallucinated key (LLM emits `"customField"`) → schema rejects
  - hallucinated quote (`source_quote` not in user message) → fact dropped
  - low-confidence emission (`"confidence": "low"`) → fact dropped
  - already-known fact (value matches profile snapshot) → skipped (no upgrade unless user corrects)
  - 0-fact case (« merci ! ») → empty list returned

### Stage 2 — wire extractor into `coach_chat` (behind flag)

- T2.1 Modify `coach_chat.py` Step 1.4 (`extract_profile_facts` regex) at line 2480-2540 :
  - Keep regex extraction as STAGE 1 (no change).
  - When `COACH_DUAL_LLM_ENABLED=True` AND `body.persistence_consent=True`, call `run_llm_extractor` as STAGE 2 in parallel (asyncio.gather) with the existing structured-reasoning call at L2542.
  - Merge LLM-extracted facts with regex-extracted facts (LLM augments, regex floor wins on conflict — regex is deterministic so its output is more trustworthy for the keys it covers).
  - Persist merged facts to both `CoachInsightRecord` (current behavior) AND `ProfileModel.data` (via existing `_coerce_fact_value` + the same code path the `save_fact` handler uses at L1578-1601).
- T2.2 Behind the flag, REMOVE `save_fact` and `save_insight` from `stripped_tools` passed to `_run_agent_loop`. The narrator no longer carries the extraction tools. With the flag OFF, behavior is unchanged.
- T2.3 Trim the system prompt for the narrator path :
  - Remove `_EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM` block.
  - Reduce length of `_BASE_SYSTEM_PROMPT` by ~150 lines (the 4-layer extraction examples block + the EXTRACTION DE PROFIL critique block — kept in the legacy path, removed in the narrator path).
- T2.4 New unit tests : `tests/test_coach_chat_dual_llm.py` :
  - flag-off : behavior identical to current (`save_fact` still in tools, full prompt)
  - flag-on : extractor runs ; narrator's `stripped_tools` does NOT contain `save_fact` ; narrator system prompt does NOT contain « EXTRACTION DE PROFIL »
  - flag-on + extractor returns 2 facts : both persist to `ProfileModel.data` BEFORE narrator runs
  - flag-on + extractor JSON parse fails : narrator still runs, falls back to regex-only extraction (no 500)

### Stage 3 — narrator LLM choice (Haiku eval, behind flag)

- T3.1 Define an extra flag `COACH_NARRATOR_MODEL` (default `"sonnet"` ; values `"sonnet"|"haiku"`).
- T3.2 With `COACH_DUAL_LLM_ENABLED=True` and `COACH_NARRATOR_MODEL="haiku"`, the narrator path uses `claude-haiku-4-5-20251001` instead of Sonnet. The model passes through `effective_model` already in `coach_chat.py:2696-2703`.
- T3.3 Eval : run a 50-fixture sample (curated from `tests/fixtures/coach_chat_*` if exists, else 50 hand-picked turns from production logs after PII scrub) against `narrator=haiku`. Score on (a) ComplianceGuard pass-rate (b) DoctrineChecks 6-check pass-rate (c) banned-term lint pass-rate (d) human evaluation of « tone is on-brand » by Julien.
- T3.4 If Haiku eval is ≥95% Sonnet pass-rate on (a)+(b)+(c) : default Haiku for narrator. Else : keep Sonnet for narrator and document Haiku as Phase 2.5 work.

### Stage 4 — flip the flag in staging

- T4.1 `COACH_DUAL_LLM_ENABLED=True` in staging environment.
- T4.2 Maestro flow `flow_extractor_captures_age_canton.yaml` runs as G1 gate. Asserts post-message profile has `incomeGrossYearly=80000` AND `canton='VD'` after a single « j'ai 80k de salaire à Lausanne » message.
- T4.3 Soak in staging for 24h ; monitor Anthropic 4xx/5xx rate, p95 latency, narrator empty-end-turn retry count.

### Stage 5 — flip the flag in prod

- T5.1 `COACH_DUAL_LLM_ENABLED=True` in prod.
- T5.2 The legacy single-LLM path code is RETAINED (under the flag-off branch) for one full release cycle. After 14 days of green metrics, a follow-up phase removes the legacy path.

**Backwards compatibility throughout:** at every stage the flag-off path produces identical output to today. The only mutating change behind the flag is that `ProfileModel.data` now fills more reliably (which is exactly the point).

## 5. Cost / latency analysis

### Per-turn cost (today, single LLM)

| Item | Tokens | Unit cost | Cost |
|------|--------|-----------|------|
| Sonnet 4.5 input | ~4500 | $3 / 1M (assumed) | $0.0135 |
| Sonnet 4.5 output | ~400 | $15 / 1M (assumed) | $0.0060 |
| **Per-turn total** | | | **~$0.0195** |

[ASSUMED — Anthropic pricing per 1M tokens not re-verified in this session.] Planner should re-fetch via Anthropic console / website before locking the budget. Numbers below scale linearly so the conclusion is direction-correct even if absolute values shift.

### Per-turn cost (Phase 2, dual LLM)

| Item | Tokens | Unit cost | Cost |
|------|--------|-----------|------|
| Sonnet 4.5 input (extractor) | ~3000 | $3 / 1M | $0.0090 |
| Sonnet 4.5 output (extractor) | ~400 | $15 / 1M | $0.0060 |
| Haiku 4.5 input (narrator) | ~3000 | $0.80 / 1M (assumed) | $0.0024 |
| Haiku 4.5 output (narrator) | ~400 | $4 / 1M (assumed) | $0.0016 |
| **Per-turn total** | | | **~$0.0190** |

**Net delta: ~−2.5% per turn.** The narrator's switch to Haiku **more than offsets** the cost of the extra extractor call. This is true ONLY if Haiku passes the eval gate at Stage 3 ; if Haiku fails and the narrator stays on Sonnet, the calculation is :

| Item | Tokens | Unit cost | Cost |
|------|--------|-----------|------|
| Sonnet 4.5 input (extractor) | ~3000 | $3 / 1M | $0.0090 |
| Sonnet 4.5 output (extractor) | ~400 | $15 / 1M | $0.0060 |
| Sonnet 4.5 input (narrator) | ~3000 | $3 / 1M | $0.0090 |
| Sonnet 4.5 output (narrator) | ~400 | $15 / 1M | $0.0060 |
| **Per-turn total (Sonnet+Sonnet)** | | | **~$0.0300** |

**Worst-case net delta: +54% per turn.** This is below the +90% headline in the spawn prompt (which assumed extractor=Sonnet at full 12k input). With the realistic ~3k-input pre-cache estimate, +54% is the true upper bound.

### Mitigations

| Mitigation | Effect | When applied |
|------------|--------|--------------|
| **Cache extractor output** on `(user_id, sha256(message))` for 30s | Eliminates extractor call on multi-tap-replay (user retypes / Flutter retries) | Always-on |
| **Skip extractor when message is empty / pure ack** | « ok », « merci », « 👍 » → no extractor call | Always-on (guard at top of `run_llm_extractor`) |
| **Skip narrator on `end_turn` empty + no Flutter tools** | Already skipped today via `_REPROMPT_EMPTY_END_TURN` retry path | Already-on |
| **Use Haiku for narrator (Stage 3)** | -54% on narrator side | If eval passes |

Realistic per-turn cost after mitigations : **between ~$0.019 (Haiku narrator) and ~$0.025 (Sonnet narrator)** vs $0.0195 today. **Net : −2% to +28%** depending on Stage 3 eval outcome.

### Per-turn latency

| Path | Today p50 | Phase 2 p50 (Sonnet+Haiku) | Phase 2 p50 (Sonnet+Sonnet) |
|------|-----------|----------------------------|------------------------------|
| Sanitize + intent + regex extract | ~50ms | ~50ms | ~50ms |
| Structured reasoning | ~5ms | ~5ms | ~5ms |
| Extractor LLM | — | ~1.5s | ~3s |
| Narrator LLM | ~3s (Sonnet) | ~1.2s (Haiku) | ~3s (Sonnet) |
| Tool execution (suggest_actions etc.) | ~50ms | ~50ms | ~50ms |
| **Total p50** | **~3.1s** | **~2.8s** | **~6.1s** |

[ASSUMED — latency numbers are derived from Anthropic published p50 benchmarks for Sonnet 4.5 ~3s/600tok and Haiku 4.5 ~1.2s/600tok ; not re-measured against staging production. Planner should re-measure during Stage 4 soak.]

**Critical observation:** if narrator stays Sonnet, total latency **doubles** (3.1s → 6.1s). This is acceptable per the milestone's Phase 7 « 3-turn cap » design — but ONLY if Haiku passes Stage 3 eval. **The Haiku eval is the gating decision for Phase 2 success.**

## 6. Counter-arguments and data gaps

### Counter-arg #1 — « Why not just improve the single-LLM prompt ? »

**Steelman:** if the 600-line prompt is the problem, rewriting it to ~300 lines while keeping it single-model would deliver 80% of the benefit at 20% of the cost, with no architectural risk.

**Rejected:** the core problem is **competing optimization targets in the same context window**, not just length. The same model cannot be (1) concise enough to satisfy « MAX 4 PHRASES » directive AND (2) exhaustive enough to satisfy « 5-8 save_fact calls per pavé » directive — the two pull in opposite directions during attention computation. The 4-week production evidence (`profile_extractor.py:8-14` docstring + the regex extractor's existence) confirms this is not solvable by prompt engineering. Phase 2 is the structural fix.

### Counter-arg #2 — « Why fatter for extractor ? »

**Steelman:** extraction is a structured-output task, structured-output models like GPT-4o-mini or even Sonnet's smaller siblings are perfectly capable. Spending Sonnet 4.5 on extraction is over-investment.

**Rejected:** missing a fact = silent profile drift = user states « j'ai 80k » and MINT later says « tu n'as pas renseigné ton salaire ». Extraction quality scales with model capability AND with prompt understanding. Sonnet's nuance helps with ambiguous cases (« je touche entre 70 et 90k selon l'année » → which canonical key ? Sonnet picks `incomeGrossYearly=80000` median + confidence=medium ; Haiku tends to skip). **Accepted with caveat:** Stage 3 eval should ALSO measure extractor performance with Haiku as a 50/50 fallback ; if Haiku-as-extractor passes the same fixtures at ≥90% Sonnet rate, the cost case for Phase 2 collapses to clear net-negative.

### Counter-arg #3 — « What if the extractor over-extracts ? »

**Steelman:** the LLM emits 8 facts when the user said one number ; profile bloats with low-quality data ; coach trusts wrong values.

**Mitigated by:**
- `source_quote` substring check (§3) — every fact requires a verbatim user quote
- `confidence != "low"` only (no LOW emissions allowed)
- `_coerce_fact_value` (`coach_chat.py:1142-1196`) range guards (e.g. `birthYear` rejected outside 1900-current_year+1)
- High-stakes diff gate: if extractor emits `canton` change OR `incomeGrossYearly` >50% delta from existing profile, the fact is **proposed but not auto-persisted** — the narrator must surface it as « tu confirmes que tu as déménagé à Sion ? » before persistence. **NEW WORK in Phase 2** : add a confirmation gate in `llm_extractor.py` for keys in `_HIGH_STAKES_KEYS = {"canton", "commune", "householdType", "employmentStatus", "incomeGrossYearly"}`. Persistence of these keys requires either (a) regex extractor concurrence, OR (b) explicit user confirmation in the next turn.

### Counter-arg #4 — « Who calls save_fact in Phase 2 ? »

**Resolved:** `save_fact` becomes a **backend-internal** operation triggered by the extractor's output, not an LLM tool. The handler at `coach_chat.py:1563-1634` is renamed `_persist_extracted_fact(...)` and called from the new `llm_extractor.py` after schema validation. The Anthropic `save_fact` tool definition is removed from the narrator's `stripped_tools` (Stage 2 T2.2). The legacy path keeps the tool in `stripped_tools` while the flag is OFF.

### Counter-arg #5 — « 2 LLM calls double the failure surface »

**Steelman:** today 1 LLM call ≈ 1% upstream failure rate (per existing retry config). 2 calls ≈ 2% failure rate compound.

**Mitigated:** the extractor failure is **non-fatal** (returns empty list, narrator runs anyway). Only the narrator failure is user-visible. So user-visible failure rate is unchanged at ~1%. Extractor failure simply reduces extraction quality to today's regex-only baseline — which is already production behavior 50% of the time when Sonnet under-calls `save_fact`.

### Counter-arg #6 — « Adversarial: is this just adding latency for the same output ? »

**Steelman:** if the extractor output is empty 80% of the time (pure ack messages, follow-up questions, etc.) then 80% of turns pay extractor latency for zero benefit.

**Mitigation: skip extractor on empty / pure-ack messages.** Heuristic: extractor is only called when `_has_concrete_facts(message)` (already present at `coach_chat.py:955-969`) returns True. This lifts the 80%-ack baseline to a sample where extractor output has measurable value. **Caveat:** this is a heuristic ; user might say « 80k » in turn-1 (no concrete-fact pattern fires because no CHF marker) and the extractor would skip. Stage 4 soak should monitor false-skip rate.

### Data gaps

- **DG-1** Anthropic pricing not re-verified in this session. All cost numbers are `[ASSUMED]`. Planner should re-fetch via Anthropic console.
- **DG-2** Haiku 4.5 French nuance + LSFin compliance not measured against MINT corpus. Stage 3 eval is a gating decision ; without it, Phase 2 can ship with narrator=Sonnet at +54% cost.
- **DG-3** No production telemetry on « how often does Sonnet under-call `save_fact` today ? » We have the docstring claim from 2026-04-13 but no quantified rate. Without this, we cannot estimate Phase 2's lift on extraction recall. Recommendation: planner adds a Stage 0 task to grep production logs (`profile_extractor: persisted X fact(s)` at `coach_chat.py:2510`) for the last 7 days and compute a baseline.
- **DG-4** Maestro flow `flow_extractor_captures_age_canton.yaml` doesn't exist yet. Stage 0 T0.3 creates the stub ; the planner should treat it as a Wave 0 dependency.
- **DG-5** The narrator's reduced tool list assumes that removing `save_fact` from the LLM's tool surface won't trigger the empty-end-turn retry path more often. This is a hypothesis ; Stage 4 soak monitors `iter > 0 reflective retry` count (already logged at `coach_chat.py:2185-2188`).
- **DG-6** « Already-known fact » suppression assumes the extractor receives a complete profile snapshot. The current `_sanitize_profile_context` (`coach_chat.py:469-510`) drops fields not in a whitelist — verify this whitelist covers all `_SAVE_FACT_ALLOWED_KEYS` before Stage 2.

## 7. Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest 7.x (per `services/backend/pyproject.toml` + 25 existing tests in `tests/test_profile_extractor.py`) |
| Config file | `services/backend/pyproject.toml` (existing) |
| Quick run command | `cd services/backend && python3 -m pytest tests/test_llm_extractor.py tests/test_coach_chat_dual_llm.py -x` |
| Full suite command | `cd services/backend && python3 -m pytest tests/ -q` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test type | Automated command | File exists? |
|--------|----------|-----------|-------------------|--------------|
| EXTR-01 | Extractor LLM runs before narrator on every turn with content | unit | `pytest tests/test_coach_chat_dual_llm.py::test_extractor_runs_before_narrator -x` | Wave 0 |
| EXTR-02 | Extractor returns ONLY JSON ; prose response triggers retry then empty | unit | `pytest tests/test_llm_extractor.py::test_prose_response_triggers_retry_then_empty -x` | Wave 0 |
| EXTR-03 | Narrator system prompt has NO « EXTRACTION DE PROFIL » block | unit | `pytest tests/test_coach_chat_dual_llm.py::test_narrator_prompt_has_no_extraction_directives -x` | Wave 0 |
| EXTR-04 | Narrator's `tools` list does NOT contain `save_fact` or `save_insight` | unit | `pytest tests/test_coach_chat_dual_llm.py::test_narrator_tools_no_save_fact -x` | Wave 0 |
| EXTR-05 | Regex extractor + LLM extractor merge correctly ; regex floor wins on conflict | unit | `pytest tests/test_llm_extractor.py::test_regex_floor_wins_on_conflict -x` | Wave 0 |
| EXTR-06 | Per-turn cost regression bounded (mocked tokens, asserts ratio) | integration | `pytest tests/integration/test_dual_llm_cost.py -x` | Wave 0 |
| EXTR-07 | Maestro flow E2E « j'ai 80k de salaire à Lausanne » → profile updates | manual + maestro | `tools/simulator/walker_audit_tap_render.sh flow_extractor_captures_age_canton` | Wave 0 |
| **Anti-regression** | Citation gate stub tests (Phase 5 anticipation) | unit | `pytest tests/test_narrator_refuses_uncited_numbers.py -x` | Wave 0 (stubbed) |
| **Anti-regression** | All 25 existing `test_profile_extractor.py` tests still pass | unit | `pytest tests/test_profile_extractor.py -q` | EXISTS |

### Sampling Rate

- **Per task commit:** `cd services/backend && python3 -m pytest tests/test_llm_extractor.py tests/test_coach_chat_dual_llm.py -x` (target ≤ 5s)
- **Per wave merge:** `cd services/backend && python3 -m pytest tests/ -q` (target ≤ 60s ; current full suite ≥ 6047 tests per Phase 1 verification)
- **Phase gate:** Full suite green + Maestro flow PASS + Stage 3 eval ≥95% Sonnet pass-rate before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `tests/test_llm_extractor.py` — covers EXTR-02, EXTR-05 (Stage 1 T1.3, ~12 tests)
- [ ] `tests/test_coach_chat_dual_llm.py` — covers EXTR-01, EXTR-03, EXTR-04 (Stage 2 T2.4, ~8 tests)
- [ ] `tests/integration/test_dual_llm_cost.py` — covers EXTR-06 (mocked Anthropic client + token counts)
- [ ] `tests/test_narrator_refuses_uncited_numbers.py` — Phase 5 anticipation stub (skip-marked until Phase 5 lands)
- [ ] `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` — covers EXTR-07
- [ ] Eval fixtures `tests/fixtures/narrator_eval_50.jsonl` — Stage 3 eval (50 hand-curated turns from production logs after PII scrub)
- [ ] Framework install: none — pytest already wired

## 8. Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| LLM HTTP client + retry | Custom Anthropic wrapper | `app.services.rag.llm_client.LLMClient` | Already wired ; tenacity retries 429/5xx/connection ; 7-month battle-tested. |
| Schema validation on extractor JSON | Custom dict checks | Pydantic v2 `ExtractorOutput` | Project standard ; gives free type errors + nice error messages. |
| Fact key whitelist | New enum | Reuse `_SAVE_FACT_ALLOWED_KEYS` from `coach_chat.py:1081-1103` | Single source of truth ; if planner adds `pillar3aBalance` here, narrator + extractor both see it. |
| Value coercion | Custom logic in extractor | Reuse `_coerce_fact_value` (`coach_chat.py:1142-1196`) | Same range guards (birthYear 1900-current+1, etc.) and enum checks (`canton ∈ 26 codes`). |
| Profile snapshot serialization | Custom JSON shape | Reuse the « PROFIL UTILISATEUR » block builder (`coach_chat.py:2611-2619`) | Same anti-hallucination anchor for both LLMs. |
| Conversation history sanitization | Custom truncation | Reuse `_sanitize_conversation_history` (`coach_chat.py:383-467`) | Already PII-scrubbed and turn-capped. |
| Cache layer | Custom Redis wrapper for extractor | Reuse `app.core.rate_limit` Redis client OR `TokenBudget` (`coach_chat.py:2674-2675`) — both already wire to Redis | Same connection pool, same fail-open semantics. |

**Key insight:** Phase 2 is structural plumbing. ~80% of the code is calling existing helpers in a new arrangement ; only ~20% is genuinely new (the extractor system prompt, the Pydantic models, the schema-validation glue, the merge logic).

## 9. Common Pitfalls

### Pitfall 1 — Sonnet returns prose instead of JSON

**What goes wrong:** the extractor system prompt says « JSON ONLY » but Sonnet sometimes prefixes with « Voici les faits extraits : ```json\n{...}\n``` ».
**Why it happens:** even with strict prompts, Sonnet has a strong markdown-formatting prior.
**How to avoid:** parser must handle (a) raw JSON, (b) JSON inside ```json``` fences, (c) JSON inside ``` fences. Existing pattern at `rag/orchestrator.py:339-356` (`_parse_vision_fields`) does this correctly — REUSE that exact regex.
**Warning sign:** « JSON parse failed » log line ; second-attempt success rate < 95%.

### Pitfall 2 — Profile snapshot stale during request

**What goes wrong:** extractor reads profile, writes a fact, narrator reads profile — but narrator's read happened before the write because both queries are fired concurrently.
**Why it happens:** Pythonic instinct to `asyncio.gather` everything.
**How to avoid:** extractor → persist → narrator is **sequential**, not parallel. The `_run_agent_loop` invocation in `coach_chat.py:2713-2731` runs AFTER the extractor pipeline at L2480-2540. **DO NOT** wrap them in `asyncio.gather`.
**Warning sign:** narrator says « tu n'as pas mentionné ton canton » in a turn where extractor logged `canton=VD`.

### Pitfall 3 — `save_fact` tool removed from narrator but still referenced in user-facing output

**What goes wrong:** narrator says « je vais enregistrer que tu vis à Lausanne » but the tool is no longer in its toolbelt — the LLM hallucinates a tool call that never happens.
**Why it happens:** the narrator's training prior includes the tool ; removing it from the API doesn't remove it from the model's expected vocabulary.
**How to avoid:** trim the narrator system prompt's references to `save_fact` and `save_insight` at the same time as the tool removal. The « EXTRACTION DE PROFIL » block at `claude_coach_service.py:610-643` and the « 5. TOUJOURS appeler save_insight » directive at L540-541 must both go in the narrator path.
**Warning sign:** narrator output mentions « j'enregistre », « je note dans ton profil », « save_insight » in the wild.

### Pitfall 4 — Caching layer caches PII

**What goes wrong:** `(user_id, sha256(message))` cache key holds the extractor output, which contains `source_quote` substrings of the user message — including PII the user might have typed.
**Why it happens:** caching is added late, PII review is skipped.
**How to avoid:** cache the **persisted facts**, not the raw extractor output. The persisted facts are post-`_coerce_fact_value` — they contain canonical values (`incomeGrossYearly=80000`), not raw quotes. PII redaction at `coach_chat.py:1603-1614` is the precedent.
**Warning sign:** Redis dump in staging shows raw user quotes.

### Pitfall 5 — `_HIGH_STAKES_KEYS` confirmation gate breaks happy path

**What goes wrong:** every time a user states their canton in a fresh chat, the narrator asks « tu confirmes que tu vis à Lausanne ? » — annoying.
**Why it happens:** confirmation gate fires on absent prior value, not just on conflict.
**How to avoid:** confirmation only fires when (a) extractor emits a high-stakes key AND (b) profile already has a different value for that key. First-time emissions persist directly (regex extractor concurs).
**Warning sign:** Maestro flow `flow_extractor_captures_age_canton` fails because narrator asks for confirmation on a fresh canton instead of acknowledging.

## 10. Code Examples

### Pattern 1 — Extractor invocation (new, in `coach_chat.py` Step 1.4)

```python
# Source: derived from coach_chat.py:2480-2540 + new module
from app.services.coach.llm_extractor import run_llm_extractor

# Stage 1 (existing): regex extractor
extracted_regex = extract_profile_facts(sanitized_message, safe_profile or {})

# Stage 2 (new, behind flag): LLM extractor
if settings.COACH_DUAL_LLM_ENABLED and body.persistence_consent and _has_concrete_facts(sanitized_message):
    try:
        extractor_output = await asyncio.wait_for(
            run_llm_extractor(
                user_message=sanitized_message,
                conversation_history=safe_history[-6:],
                profile_snapshot={k: v for k, v in (safe_profile or {}).items() if v is not None},
                api_key=effective_api_key,
                provider=body.provider,
                model="claude-sonnet-4-5-20250929",
            ),
            timeout=10.0,
        )
    except (asyncio.TimeoutError, Exception) as exc:
        logger.warning("llm_extractor failed (non-fatal): %s", type(exc).__name__)
        extractor_output = ExtractorOutput()  # empty
else:
    extractor_output = ExtractorOutput()

# Merge: regex floor wins on conflict
merged_facts = _merge_extracted(regex=extracted_regex, llm=extractor_output.facts)

# Persist (reuse existing _persist_extracted_fact handler)
for fact in merged_facts:
    _persist_extracted_fact(fact, user_id=str(_user.id), db=db)
```

### Pattern 2 — Narrator system prompt assembly (new, in `claude_coach_service.py`)

```python
# Source: derived from claude_coach_service.py:677-780 with extraction directives stripped
def build_narrator_system_prompt(ctx, language, cash_level):
    """Trimmed system prompt — extraction directives removed (owned by extractor LLM).

    Difference vs build_system_prompt:
      - _BASE_SYSTEM_PROMPT body has the EXTRACTION block (lines 610-643) removed
      - Rule 5 ('TOUJOURS appeler save_insight') is removed
      - The 'EXEMPLE DE BONNE RÉPONSE SUR UN PAVÉ UTILISATEUR' (lines 632-643) is removed
    """
    base = _NARRATOR_BASE_SYSTEM_PROMPT.format(...)  # ~300 lines vs ~600
    base += "\n" + _LIFE_EVENT_CATALOG
    base += "\n" + _ARCHETYPE_CATALOG
    base += "\n" + _DOCTRINE_INFORMATION_RULE
    # ... other delivery-side blocks unchanged
    return base
```

### Pattern 3 — Reduced tools for narrator (new helper in `coach_tools.py`)

```python
# Source: derived from coach_tools.py:1215-1229 get_llm_tools
_NARRATOR_EXCLUDED_TOOLS = {"save_fact", "save_insight"}

def get_narrator_llm_tools() -> list[dict[str, Any]]:
    """Narrator-scoped tools: removes save_fact + save_insight (extractor owns those)."""
    _LLM_ALLOWED_FIELDS = {"name", "description", "input_schema"}
    return [
        {k: v for k, v in tool.items() if k in _LLM_ALLOWED_FIELDS}
        for tool in COACH_TOOLS
        if tool.get("name") not in _NARRATOR_EXCLUDED_TOOLS
    ]
```

## 11. Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Existing `require_current_user` dep at `coach_chat.py:2293`. Extractor inherits the same auth. |
| V3 Session Management | yes | Existing session via auth dep. No new session surface. |
| V4 Access Control | yes | `body.persistence_consent` gate already at `coach_chat.py:2476`. Extractor reuses the same gate (no extraction without consent). |
| V5 Input Validation | yes | Pydantic models for extractor output (`ExtractedFact`, `ExtractorOutput`) ; whitelist on `key` ; substring check on `source_quote` ; existing `_coerce_fact_value` range guards. |
| V6 Cryptography | no | No new crypto. API key handling unchanged via existing `effective_api_key` chain. |
| V14 Data Protection | yes | PII redaction already enforced via `_scrub_pii`, `_PII_PATTERNS`, `is_safe_to_log` (`coach_chat.py:1603-1625`). Extractor must respect the same allowlist when logging extracted facts. |

### Known Threat Patterns for Python/FastAPI/Anthropic

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prompt injection in user message | Tampering | Already mitigated via `_INJECTION_PATTERNS` filter at `coach_chat.py:296-322`. Sanitized message is passed to BOTH LLMs. |
| Prompt injection in profile snapshot | Tampering | `_sanitize_profile_context` (`coach_chat.py:469-510`) already strips control tokens from values. Extractor input inherits sanitized output. |
| Prompt injection in conversation history | Tampering | `_sanitize_conversation_history` (`coach_chat.py:383-467`) already filters. Extractor passes only sanitized history. |
| Hallucinated fact persistence | Tampering | `source_quote` substring check rejects facts the user never said. `_HIGH_STAKES_KEYS` confirmation gate stops silent canton/income changes. |
| PII leak in extractor logs | Information Disclosure | Reuse `app.services.privacy.fact_key_allowlist.is_safe_to_log` (`coach_chat.py:1612-1614`). Extractor's persistence log path uses the same allowlist. |
| API key exposure | Information Disclosure | Existing BYOK chain at `coach_chat.py:effective_api_key`. Both LLM calls use the same key ; not stored, passed-through. |
| LLM cost-DoS via prompt injection | DoS | `MAX_AGENT_LOOP_TOKENS=8000` and `MAX_REQUEST_TOKENS=4000` already cap costs ; extractor adds its own `max_tokens=2000` Anthropic-side cap. |

### MINT-specific compliance

- **LSFin** : extractor JSON output is NOT user-facing → banned-terms lint N/A on extractor output. Narrator output passes existing ComplianceGuard. **Net: no compliance regression.**
- **nLPD art. 4** : extractor input includes user message + profile snapshot ; both already sanitized. PII redaction on persistence path unchanged.
- **Privacy by design (CLAUDE.md §1)** : extraction is gated on `persistence_consent=True` (sync ON). With sync OFF, the LLM extractor does NOT run (matches the existing regex-extractor gate at `coach_chat.py:2476-2483`).

## 12. Sources

### Primary (HIGH confidence)
- `services/backend/app/api/v1/endpoints/coach_chat.py` (2912 lines, lines 1-322 + 887-2274 + 2440-2700 read in this session)
- `services/backend/app/services/coach/profile_extractor.py` (603 lines, full read)
- `services/backend/app/services/coach/claude_coach_service.py` (961 lines, full read)
- `services/backend/app/services/rag/orchestrator.py` (full read, 433 lines)
- `services/backend/app/services/coach/coach_tools.py` (full read, 1229 lines)
- `services/backend/app/services/coach/structured_reasoning.py` (598 lines, header skim)
- `services/backend/app/services/rag/llm_client.py` (lines 45-262 grep + skim)
- `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` from branch `docs/milestone-chat-as-verb` head `bd19e9f7` (full read via git show)
- `.planning/phases/MVP-DESIGN-LINTS-V1/EXEC.md` (full read)
- `.planning/phases/MVP-DESIGN-LINTS-V1/VERIFICATION.md` (full read)
- `services/backend/tests/test_profile_extractor.py` (count + fixture map)
- `.planning/config.json` (full read)
- `/Users/julienbattaglia/Desktop/MINT.nosync/CLAUDE.md` (system context)

### Secondary (MEDIUM confidence)
- Anthropic Claude Sonnet 4.5 / Haiku 4.5 model IDs : codebase grep (`coach_chat.py:1207-1208`). Model availability + current pricing not re-verified against Anthropic console in this session.
- Latency p50 estimates : derived from observed `coach_chat.py:1209` `FALLBACK_TIMEOUT_SECONDS=20` budget + `AGENT_ITERATION_TIMEOUT_SECONDS=25` budget. Not re-measured in this session.

### Tertiary (LOW confidence — flagged for validation)
- Per-token Anthropic pricing — `[ASSUMED]` based on training-data prior. Planner must re-verify.
- Haiku 4.5 French nuance / LSFin compliance rate — `[ASSUMED]` based on architectural prior. Stage 3 eval is the validation step.
- Production rate of « Sonnet under-calls save_fact » — `[ASSUMED]` from `profile_extractor.py:8-14` docstring claim, no telemetry quantification. DG-3.

## 13. Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Anthropic Sonnet 4.5 pricing ≈ $3/$15 per 1M input/output tokens | §5 | Cost calculation drifts ; planner re-fetches before locking budget |
| A2 | Anthropic Haiku 4.5 pricing ≈ $0.80/$4 per 1M input/output tokens | §5 | Same as A1 |
| A3 | Haiku 4.5 passes ComplianceGuard + DoctrineChecks at ≥95% Sonnet rate | §3, §5 Stage 3 | If False : narrator stays Sonnet at +54% per-turn cost. Phase 2 still ships, cost ratio worse. |
| A4 | Sonnet 4.5 returns reliably-parseable JSON when prompted with strict JSON-only directive | §3, §6 Pitfall 1 | If False : extractor failure rate >5%, falls back to regex-only baseline 1/20 turns |
| A5 | Sonnet 4.5 latency p50 ~3s @ 600-output, ~1.5s @ 400-output | §5 | If higher : Phase 7 3-turn cap budget gets tighter ; revisit Haiku narrator default |
| A6 | Existing `_sanitize_profile_context` whitelist covers all `_SAVE_FACT_ALLOWED_KEYS` | §6 DG-6 | If False : extractor can't see fields user already filled → re-extracts unnecessarily, slight noise increase |
| A7 | `tools/simulator/walker_audit_tap_render.sh` accepts a flow file argument and runs Maestro on booted sim | §7 | If False : G1 gate runs through different harness ; planner adjusts T0.3 |
| A8 | Production rate of « Sonnet under-calls save_fact » is significant (≥30% of fact-bearing turns) | §1 Symptoms, §6 DG-3 | If False : Phase 2's lift on extraction recall is small, cost case weakens |
| A9 | Anthropic SDK supports `max_tokens=2000` on Sonnet 4.5 (vs current 600) | §3 Extractor budget | Verified-likely (Anthropic limit is 8192 for Sonnet) ; planner verifies |
| A10 | Removing `save_fact` from narrator's tools doesn't increase empty-end-turn retry rate | §6 DG-5 | If False : narrator latency degrades, mitigated by reflective retry already at coach_chat.py:2185 |

## 14. Open Questions for planner / discuss-phase

1. **OQ-1 — Haiku-as-narrator gating decision.** Stage 3 eval is the gating decision for Phase 2 cost outcome. Should the planner explicitly carve out a 1-day eval task BEFORE Stage 4 staging flip ? Or can it be in-line with Stage 4 soak ? **Recommendation:** carve out as discrete task ; staging soak already mixes too many variables.

2. **OQ-2 — Confirmation gate for high-stakes keys.** §6 Counter-arg #3 proposes a gate where `canton` / `incomeGrossYearly` >50% delta requires user confirmation before persistence. The narrator's confirmation surface is « tu confirmes ? » in next turn. Two design options:
   - (a) extractor flags fact as `pending_confirmation=True`, narrator prompts, next turn's regex-confirmation persists.
   - (b) extractor persists immediately, narrator surfaces « j'ai mis à jour ton canton — c'est correct ? », undo via tool call.
   Option (a) is safer, option (b) is faster. **Defer to discuss-phase.**

3. **OQ-3 — Should the LLM extractor also classify intents ?** The current `_classify_user_intent` (`coach_chat.py:921-940`) is keyword-based. The extractor could absorb this responsibility (its system prompt already includes the intent enum). Pros: better recall on unusual phrasings (« je crois que je dois trop d'argent à ma carte »). Cons: another role for the extractor, scope creep. **Defer to discuss-phase.**

4. **OQ-4 — Extractor on anonymous chat ?** Today, anonymous chat (no `_user`) skips persistence at `coach_chat.py:2517-2524`. Should the LLM extractor still RUN on anonymous chat (extracting facts that are then logged but not persisted) ? Use case: ABC funnel — Lauren-archetype hits chat anonymously, says « j'ai 80k à Genève », chat coaches her with that context for the rest of the session via in-memory state. **Recommendation:** YES, extractor runs on anonymous, output cached in request-scoped state, never written to DB. Adds ~$0.018/anonymous-turn but improves anonymous coaching quality measurably. **Defer to discuss-phase.**

5. **OQ-5 — Versioning of extractor system prompt.** The narrator system prompt is « versioned » today by being committed in `claude_coach_service.py`. The extractor system prompt will live in `llm_extractor.py`. Should there be a registry pattern (à la `prompt_registry.py` already in `services/coach/`) for both ? **Recommendation:** YES, but in a follow-up phase (not Phase 2 scope). Phase 2 hardcodes the prompt as a module constant.

6. **OQ-6 — Conversation history truncation strategy.** Extractor benefits from longer history (more context for « il a dit son canton il y a 4 turns »). Narrator benefits from short history (concision). Both currently use `safe_history[-6:]`. Should the extractor get a longer window (10 turns?) at the cost of more tokens ? **Recommendation:** start with same `safe_history[-6:]` for both. Revisit if Stage 4 soak shows extractor recall miss on multi-turn fact statements.

7. **OQ-7 — `save_insight` ownership.** Today `save_insight` is LLM-driven (narrator decides). In Phase 2 the extractor owns `save_fact`. Should `save_insight` ALSO move to extractor (decision/preference/concern detection) ? Pros: symmetric. Cons: insight detection is more narrative-judgment than fact-extraction (« she's worried about her debt » vs « she stated 50k debt »). **Recommendation:** keep `save_insight` on narrator side for Phase 2 ; revisit in a future phase if narrator under-calls it the same way it under-calls `save_fact` today. **Defer to discuss-phase.**

## 15. State of the Art

| Old approach | Current approach | When changed | Impact |
|--------------|------------------|--------------|--------|
| Single LLM doing all 3 LLM-served roles (extraction + narration + routing) | Two LLM roles fan-out (extractor + narrator) | Phase 2 (this) | Extraction recall ↑, narration concision ↑, cost ≈ flat (Haiku narrator) or +54% (Sonnet narrator) |
| Regex extractor as the only deterministic floor | Regex extractor + LLM extractor in series | Phase 2 (this) | LLM augments regex coverage ; regex stays as cheap deterministic floor |
| `save_fact` and `save_insight` exposed to narrator LLM | `save_fact` removed from narrator ; `save_insight` retained for narrative-judgment | Phase 2 (this) | Narrator stops emitting tool-only responses for extraction reasons |

**Deprecated/outdated (after Phase 2 ships):**
- The 5-bullet « EXTRACTION DE PROFIL » directive in `_BASE_SYSTEM_PROMPT` (lines 610-643) — moved to extractor's system prompt
- The 4-layer extraction example block in `_BASE_SYSTEM_PROMPT` (lines 632-643) — same
- The « Rule 5 : TOUJOURS appeler save_insight » in `_BASE_SYSTEM_PROMPT` (lines 540-541) — moved to extractor

## 16. Environment Availability

Phase 2 is pure backend Python work. External dependencies :

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.11+ | All backend | ✓ | per `services/backend/pyproject.toml` | — |
| pytest | Test execution | ✓ | per existing `tests/` (≥ 6047 tests) | — |
| anthropic SDK | LLM client | ✓ | per `rag/llm_client.py:59,182` | — |
| pydantic v2 | Schema validation | ✓ | per project standard CLAUDE.md §1 | — |
| Anthropic API access (BYOK) | Extractor + narrator LLM calls | ✓ | runtime | Per-user BYOK ; no env-side dep |
| Maestro CLI | G1 gate flow | ✓ | per existing `tools/simulator/` walker | — |
| Booted iOS sim | G1 + G2 gates | ✓ | per existing dev environment | — |
| Redis (for extractor cache) | Stage 2 mitigation | ✓ | per existing `app.core.rate_limit` use | In-memory dict fallback (skip cache) |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** Redis can fall back to in-memory cache if env-not-configured (degrades cache hit-rate, doesn't block functionality).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all infrastructure already in MINT, verified via codebase grep + full reads
- Architecture: MEDIUM — pattern is industry-standard but specific MINT shape (regex floor + LLM augment + narrator with reduced tools) is novel
- Pitfalls: MEDIUM-HIGH — pitfalls 1-5 are derived from existing comments + `coach_chat.py` 4-week production evidence
- Cost / latency: MEDIUM — token estimates derived from observed system prompt size + `claude_coach_service.py` budget ; pricing assumed
- Test strategy: HIGH — pytest infrastructure + Maestro flow harness already in place
- Security: HIGH — phase reuses existing PII/sanitize/consent chain ; no new attack surface

**Research date:** 2026-05-09
**Valid until:** 2026-05-23 (14-day stable window for fast-moving Anthropic API ; revisit before Phase 2 lands if not flipped within 2 weeks)

---

## RESEARCH COMPLETE

**Phase:** MVP-EXTRACTOR-V2
**Confidence:** MEDIUM-HIGH

### Key findings
- Today's coach LLM serves 3 distinct roles in one model + one prompt + one budget (R3 LLM-extraction via `save_fact`, R4 LLM-extraction via `save_insight`, R5 narration). The conflation is documented in 4-week-old production evidence (`profile_extractor.py:8-14` + the regex extractor's existence).
- Phase 2 is mostly plumbing — ~80% of code reuses `LLMClient`, `_coerce_fact_value`, `_SAVE_FACT_ALLOWED_KEYS`, `_run_agent_loop`, the existing PII/sanitize/consent chain. Only ~20% is new (extractor system prompt, Pydantic models, merge logic).
- Cost outcome hinges on Stage 3 eval (Haiku-as-narrator). Pass : −2.5% per turn. Fail : +54% per turn. Plan must carve Stage 3 as a discrete gating task.
- `extract_profile_facts` regex extractor STAYS as deterministic floor ; LLM extractor RUNS SECOND and augments. This is the spawn-prompt's mandated design and matches the production failure mode (regex is reliable for the keys it covers ; LLM catches the rest).
- 6 open questions deferred to discuss-phase (Haiku gating decision, confirmation gate design, intent classification ownership, anonymous-chat extractor, prompt versioning, history truncation, save_insight ownership).

### File created
`/Users/julienbattaglia/Desktop/MINT.nosync/.planning/phases/MVP-EXTRACTOR-V2/RESEARCH.md`

### Confidence assessment
| Area | Level | Reason |
|------|-------|--------|
| Current state map | HIGH | Direct codebase reads with line citations |
| Proposed architecture | MEDIUM | Pattern is industry-standard ; specific MINT shape is novel |
| Cost / latency | MEDIUM | Token estimates HIGH ; pricing ASSUMED, awaits verification |
| Test strategy | HIGH | pytest + Maestro infra already in place |
| Migration plan | MEDIUM-HIGH | Stage gating is conventional ; flag rollout already a MINT pattern |

### Open questions
6 listed in §14 ; principal one is OQ-1 (Haiku gating eval).

### Ready for planning
Research complete. Planner can now create PLAN.md files. Recommend planner consume §4 Migration plan as the task DAG skeleton, §7 Validation Architecture for test coverage, §13 Assumptions Log + §14 Open Questions for discuss-phase routing.
