---
description: Phase 94 context — closed-world citation gate post-process parser. Narrator output rejected if any number / legal claim is emitted without a {{cite:<key>}} adjacent. Hard-cap retry=1, templated fallback. Closes the « ChatGPT clone » failure mode mechanically.
audience: gsd-phase-researcher, gsd-planner, executor
status: Ready for planning
date: 2026-05-10
mode: auto-decide (Claude product-leader call per Julien's "tu es l'expert" directive ; 7 gray areas locked)
---

# Phase 94: MVP-CITATION-GATE - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning
**Mode:** auto (Claude locked 7 gray areas A–G ; ROADMAP success criteria + calc-first ADR N1 + Phase 93.5 D-18 bundle contract are the spec anchor)

<domain>
## Phase Boundary

Post-process parser on narrator output (`coach_chat.py` response stage). Rejects narrator emission if ANY number, percentage, legal article, or regulatory constant is emitted without an adjacent `{{cite:<key>}}` placeholder. Substitutes placeholders with calculated values from the citation source registry. Retries the narrator ONCE on rejection with explicit reprompt; on second failure, returns templated « je n'ai pas cette donnée pour l'instant » with no number.

**Adopts:** Calc-first ADR N1 closed-world numeric vocabulary contract per `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` §N1. Consumes Phase 93.5's bundle `citation_allowlist` per D-18 (graceful fallback to a global registry when flag-OFF).

**Does NOT adopt:**
- Full GroundingPack JSON contract (Phase 95 territory — DAG-INVALIDATION emits the structured pack)
- NarrativeSleeve voice linter (Phase 96 — CHAT-AS-VERB)
- Backend calc-parity port (`backlog 999.4` — only triggered if CalcTrace requires server-side numbers)

**Out of scope (deferred):**
- Multi-turn citation continuity (citations carry across conversation history) — Phase 94 only gates a single narrator response
- Per-user citation provenance dashboard — Phase 96 territory
- Cross-language citation sources (FR-only registry in v1; DE/EN/IT/ES/PT later)

</domain>

<decisions>
## Implementation Decisions

### Citation Format & Detection (Gray Area A)

- **D-01:** Citation format is `{{cite:<key>}}` per calc-first ADR §N1 (NOT `[citation:source_id]` from the legacy ROADMAP wording — `{{cite:}}` is already used in Phase 93.5 bundle `citation_allowlist` annotations; uniformity wins). The ROADMAP wording will be patched in Phase 94 plan-01 to match. Examples: `{{cite:r3a_ceiling_2026}}`, `{{cite:user_avs_rente_low}}`, `{{cite:lifd_art_38_pillar3a_withdrawal}}`.
- **D-02:** Number detection regex — pure Python `re` module, no NLP lib. Pattern catches:
  - CHF/EUR/USD amounts: `\b\d{1,3}(?:[' ]\d{3})*(?:[.,]\d{1,2})?\s*(CHF|chf|EUR|eur|USD|usd|fr\.?|francs?)\b`
  - Percentages: `\b\d{1,3}(?:[.,]\d{1,2})?\s*%`
  - Legal article references: `\b(art\.?\s*\d+(?:\s*al\.?\s*\d+)?\s*(LIFD|LPP|LAVS|LCA|LPCC|OPP[23]?|OCC|LHID|CO))\b`
  - Time durations: `\b\d+\s*(ans?|mois|jours?|semaines?|années?|trimestres?)\b`
  - Regulatory constants by name: `(taux\s+de\s+conversion|plafond\s+3a|barème\s+LIFD|coefficient\s+\w+)`
- **D-03:** Detection is **whole-token aware** — must NOT trigger on the meta-quote / negation patterns introduced in Wave 4 (`93.5-w4`). Refactor the existing `_is_meta_negation` + `_is_meta_quoted` helpers from `tools/eval_narrator.py:250-296` into `app/services/coach/citation_parser.py` and **rename them to public API names `is_meta_negation` + `is_meta_quoted` (drop leading underscore)** — they are now consumed by both runtime `gate()` AND eval scorer + tests, so they cease to be private to the eval module. The eval module re-imports them and re-binds the underscore-prefixed names as backward-compat aliases. (Plan-checker iter 1 H2 fix — public API.)
- **D-04:** A number IS allowed without `{{cite:}}` ONLY when:
  - it appears in a meta-negation context (« aucun X n'est de 4% »)
  - it appears in a meta-quote (« le mythe du "10% garanti" »)
  - it is part of a legal article reference (`art. 38 LIFD` is itself the citation)
  - it appears inside an explicit `{{cite:...}}` placeholder body (e.g. timestamps in citation values)

### Citation Source Registry (Gray Area B — GATE-02)

- **D-05:** 4 source types per ROADMAP: `profile | reasoning | tool_call_id | adr | spec`. Each `{{cite:<key>}}` resolves to one of these source kinds at parse time:
  - `profile:<field>` — value from the user profile snapshot (e.g. `profile:income_gross_yearly`)
  - `reasoning:<calc>` — value from a deterministic calculation in `financial_core/` or `services/backend/app/services/`
  - `tool_call_id:<id>` — value emitted by a narrator tool call (the 6-tool registry from Phase 93.5 D-20)
  - `adr:<file>#<key>` — value defined in a project ADR (e.g. `adr:2026-05-09-calc-first#r3a_ceiling_2026`)
  - `spec:<file>#<key>` — value defined in a canonical spec (LIFD article values, FINMA constants, etc.)
- **D-06:** Citation registry storage — `services/backend/app/services/coach/citation_registry.py` (new). Pure Python module exposing a frozen dict `CITATION_REGISTRY: Mapping[str, CitationSource]` plus a `resolve(key: str, ctx: CoachContext) -> str | None` function that looks up the value at runtime. Phase 95 will replace this module with the `GroundingPack` JSON contract; Phase 94 keeps it minimal.
- **D-07:** Bundle integration per Phase 93.5 D-18 — when `COACH_BUNDLE_COMPILER_ENABLED=true`, the gate intersects the narrator's emitted `{{cite:<key>}}` set with the compiled bundle's `citation_allowlist`. Citations outside the allowlist are rejected (closed-world). When flag-OFF, the gate falls back to the global `CITATION_REGISTRY` (any registered key is accepted). This is the « graceful degradation » per D-18.

### Retry-or-Fallback Flow (Gray Area C — GATE-03)

- **D-08:** Hard-cap retries = 1. Per ROADMAP Risk #2 mitigation (« retry loop blows token budget »). Risk-pinned, not configurable.
- **D-09:** On first rejection, the narrator is reprompted with this exact text appended to the user message: `\n\nRAPPEL — Cite chaque chiffre via {{cite:<key>}} ou ne l'émets pas. Si tu n'as pas la source pour un chiffre, écris « je n'ai pas cette donnée » à la place.`
- **D-10:** On second failure, return the templated fallback verbatim: `Je n'ai pas cette donnée pour l'instant. Pour avancer ensemble, dis-moi un peu plus sur ta situation (canton, salaire, structure familiale) et je peux t'orienter vers ce qui s'applique chez toi.` — no fabricated number, life-event-router fallback tone.
- **D-11:** Gate insertion point — `coach_chat.py` after narrator response is collected, BEFORE the `_build_response` payload is sent to the client. Specifically, between the narrator-response capture (around `coach_chat.py:3170`-ish) and the final response build. The gate is a thin wrapper that calls `citation_parser.gate(response_text, ctx, citation_allowlist) -> GatedResponse`.

### Banned-Claim List (Gray Area D — GATE-04)

- **D-12:** Banned-claim list source — reuse the existing LSFin banned-terms set already wired in `services/backend/app/services/coach/bundles/compliance_narrator.py` (`_BANNED_TERMS_REMINDER` content) + `mint-swiss-compliance/SKILL.md` registry. Phase 94 ADDS the « affirmative claim with cited number » red flag: even a `{{cite:}}`-backed number that asserts a forecast as fact (« vous ferez 4% par an ») is rejected if the narrator wraps it in a deterministic verb (« vous ferez », « rapportera », « est garanti à »). Lint pattern: `(vous|tu)\s+(ferez|feras|aurez|auras|gagnerez|gagneras)\s+\d` triggers rejection EVEN WITH citation.
- **D-13:** A banned claim is rejected with the same retry-or-fallback flow as missing citations (D-09 / D-10). The reprompt text is adapted: `\n\nRAPPEL — Une projection est une scénario, pas une promesse. Reformule au conditionnel (« pourrait », « selon ce scénario », « si X reste constant »).`

### Eval Pack + Maestro Flow (Gray Area E)

- **D-14:** 50-fixture eval pack at `services/backend/tests/fixtures/citation_gate_eval_50.jsonl`. Each fixture has the same shape as `narrator_eval_50.jsonl` plus an `expected_gate_outcome: pass | rejected_uncited | rejected_banned_claim | fallback` field. Pack covers: 20 with valid citations, 10 with uncited numbers, 10 with banned claims, 10 with fallback paths.
- **D-15:** Eval thresholds per ROADMAP success criterion #3 — Sonnet narrator ≥95% gate-correct, Haiku narrator ≥90%. Gate-correct = (gate verdict matches expected_gate_outcome).
- **D-16:** Maestro flow — `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml`. Sends profile-empty user with chat « combien je gagne ? » and asserts the response does NOT contain a fabricated CHF number. Greenfield flow, builds on the existing Maestro setup (memory `reference_maestro_setup.md`).

### Performance & Wiring Budget (Gray Area F)

- **D-17:** Citation parser pure Python regex, no LLM call, no library load — target ≤50ms per response on a 200-token narrator output. Total turn budget remains ≤30s (existing performance budget per ROADMAP §Cross-cutting concerns).
- **D-18:** Sentry breadcrumbs introduced (mirroring Phase 93.5 telemetry hygiene): `coach.citation_gate.verdict={pass|rejected_uncited|rejected_banned_claim|fallback}`, `coach.citation_gate.retries={0|1}`, `coach.citation_gate.uncited_numbers_count=<n>`. Payload restricted to non-PII counts/labels — never user message content. Mirror the Wave 1 D-12 hygiene rule from Phase 93.5 (bundle compiler).

### Migration & Feature Flag (Gray Area G)

- **D-19:** New env-gated flag `COACH_CITATION_GATE_ENABLED: bool = False` in `app/core/config.py`, default OFF in prod, ON in staging during Stage 3 eval. Mirrors the Phase 91 `COACH_DUAL_LLM_ENABLED` and Phase 93.5 `COACH_BUNDLE_COMPILER_ENABLED` pattern.
- **D-20:** Two response paths preserved during rollout — flag-OFF: legacy bypass (no gate, current behavior), flag-ON: gate enforced. Tests parametrize over both paths. Flag flip-on plan documented in Plan 94-04 GO/NO-GO proposal (mirror 93.5-04-FLAG-FLIP-PROPOSAL.md template).
- **D-21:** Sunset plan — flag and bypass code path removed in Phase 96 OR after 4 weeks of staging soak with `coach.citation_gate.fallback` rate ≤2%, whichever comes later. The bypass is the safety net during rollout, NOT a permanent option.

### Claude's Discretion

NOT locked here — Claude decides at planning/execution time:

- Exact `CITATION_REGISTRY` contents (key list will iterate during Stage 3 eval as compiler bundles surface what they cite)
- Tokenizer choice for retry-once budget check (recommend reusing `count_tokens_cached` from Phase 93.5-04 Task 1)
- Whether the gate is a request-scoped middleware vs a coach_chat.py call-site wrapper (recommend wrapper for surgical Karpathy #3 minimalism)
- Per-fixture test file structure under `tests/test_citation_gate/` (one file per gate verdict type)
- Maestro flow's exact assertion format (relies on existing `flow_narrator_*.yaml` patterns)

### Folded Todos

None — Phase 94 is well-scoped from ROADMAP + calc-first ADR; no backlog items folded.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before producing artefacts.**

### Architectural blueprint
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` §N1 — closed-world numeric vocabulary contract, `{{cite:<key>}}` placeholders, post-processor + lint. Phase 94 IS this section.
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` §85 — Compliance pivot lock-in (CalcTrace + AI registry + LSFin disclaimer systemic) included in Phase 94.

### Code surfaces to modify or consume
- `services/backend/app/api/v1/endpoints/coach_chat.py` (≈line 3170, narrator response capture) — gate wrapper insertion point per D-11
- `services/backend/app/core/config.py` — add `COACH_CITATION_GATE_ENABLED` per D-19
- `services/backend/app/services/coach/bundles/__init__.py` — bundle path emits `citation_allowlist` consumed by gate per D-07 (Phase 93.5 D-18 contract)
- `services/backend/app/services/coach/bundles/compliance_narrator.py` — banned-terms reminder feeds D-12
- `services/backend/tools/eval_narrator.py` — `_is_meta_negation` + `_is_meta_quoted` helpers refactored into `citation_parser.py` and renamed to public `is_meta_negation` / `is_meta_quoted` per D-03 (iter 1 H2 fix) ; eval module re-imports + re-binds underscore aliases for backward compat

### Pattern precedents
- `.planning/phases/91-mvp-extractor-v2/91-CONTEXT.md` — `COACH_DUAL_LLM_ENABLED` flag pattern (precedent for D-19)
- `.planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-CONTEXT.md` D-15 / D-16 — flag + dual-path migration pattern
- `.planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-04-FLAG-FLIP-PROPOSAL.md` — proposal template for D-20 flag-flip GO/NO-GO

### Project doctrine
- `CLAUDE.md` §1 — financial_core/ source-of-truth (citation values resolve through it; Phase 94 does NOT re-implement calculations)
- `CLAUDE.md` §3 — MCP tools `check_banned_terms` complement D-12 lint
- `CLAUDE.md` §5 NEVER #5/#8/#9 — banned terms, no-promise LSFin doctrine, projection ≠ promesse
- `CLAUDE.md` §9 0-Trust — gate verdict claims must cite deterministic test output (eval pack + Maestro flow)
- `rules.md` — banned LSFin terms list (consumed by D-12)

### Eval + telemetry
- `services/backend/tests/fixtures/narrator_eval_50.jsonl` — Wave 4 of Phase 93.5 added `intents:` field; precedent for the new `expected_gate_outcome:` field per D-14
- `services/backend/tools/eval_narrator.py` — Phase 93.5-04 Task 1 added `--prompt-builder` flag; Phase 94 adds `--gate={on,off}` flag for parametric eval
- `tools/simulator/flows/maestro-perfect-set/` — existing flow location for D-16

### Memory triggers
- `feedback_anthropic_key_on_railway.md` — never list "Anthropic key missing" as suspect when triaging coach issues
- `feedback_zero_trust_protocol.md` — banned « shipped/ready/works » without deterministic citation
- `feedback_design_panel_before_push.md` — compliance-narrator changes require 4-person panel review (carries from Phase 93.5)
- `reference_maestro_setup.md` — Maestro flows location + walker invocation for D-16

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Bundle compiler `citation_allowlist`**: Phase 93.5 already shipped — `services/backend/app/services/coach/bundle_compiler.py:compile_bundles` returns `CompiledBundle.citation_allowlist`. Phase 94 gate consumes this directly per D-07.
- **`is_meta_negation` + `is_meta_quoted`** (public — iter 1 H2 rename): Phase 93.5 Wave 4 added these as `_is_meta_*` to `tools/eval_narrator.py`. Phase 94 refactors them into `citation_parser.py` AND drops the leading underscore (now public API). Used both at eval time AND at runtime. Single source of truth.
- **`COACH_BUNDLE_COMPILER_ENABLED` precedent**: `app/core/config.py` already has the env-gated bool pattern (Phase 93.5 Wave 1). `COACH_CITATION_GATE_ENABLED` mirrors it.
- **`count_tokens_cached`**: `tools/fixtures/.token_count_cache.json` Phase 93.5-04 Task 1 added an Anthropic count_tokens cache. Reused for retry-budget check.
- **`build_narrator_system_prompt_from_bundles` kwargs-only signature** (Phase 93.5 D-16): the gate's reprompt string is APPENDED to the user message before the retry call — no signature change to the prompt builder.

### Established Patterns
- **Two-path coexistence**: Phase 91 (`COACH_DUAL_LLM_ENABLED`) + Phase 93.5 (`COACH_BUNDLE_COMPILER_ENABLED`) established the env-flag dual-path migration pattern. Phase 94 follows verbatim per D-19/D-20.
- **Sentry breadcrumb hygiene**: payload limited to non-PII counts/labels per Phase 93.5 Wave 1 D-12. Mirror exactly in D-18.
- **GSD plan structure**: 4-wave layout (scaffold → compiler+wiring → fattening/eval → flag-flip) inherited from Phase 93.5 D-17. Phase 94 likely fits 3-wave (scaffold → wiring → eval+proposal) given smaller scope (3d budget vs 6d of 93.5).
- **Stage 3 eval gate**: 50-fixture jsonl + `eval_narrator.py` extension flag + 95%/90% thresholds — same shape as Phase 91 + Phase 93.5-04.

### Integration Points
- **Gate wrapper entrypoint**: `citation_parser.gate(response_text, ctx, citation_allowlist) -> GatedResponse` returning `(verdict, gated_text, retry_needed: bool, reprompt_addendum: str | None)`. Pure function, no I/O.
- **`coach_chat.py` request handler**: after narrator response capture, branch on `settings.COACH_CITATION_GATE_ENABLED` → if ON, call `gate(...)` ; if `retry_needed`, call narrator again with appended reprompt ; on second failure, return D-10 fallback. If OFF, return narrator response unchanged.
- **Phase 95 hard-dependency**: `inputs_hash` propagation to `citation_allowlist` keys in `GroundingPack` ensures stale citations get rejected. Phase 94 emits a stub `inputs_hash` field on `GatedResponse` that Phase 95 will populate. No change to Phase 94's gate logic — just the schema field.

</code_context>

<specifics>
## Specific Ideas

- **Calc-first ADR §N1 IS the spec**, not a suggestion. Read it cover-to-cover before writing code.
- **Citation format consolidation**: `{{cite:<key>}}` everywhere — Phase 93.5 bundle citation_allowlists already use this format. Aligning Phase 94 gate parser eliminates a translation layer.
- **The narrator's reprompt MUST be French**, even when the user is in another language — the system prompt is FR by default, the reprompt text appends to the same FR system prompt context. Future multi-language work (Phase 99+) will translate the reprompt; for now FR-only is the conservative default.
- **The gate's verdict is structurally separated from compliance** — `ComplianceGuard` (existing, in `compliance_guard.py`) handles banned LSFin terms ; `citation_parser.gate` handles uncited numbers + banned-claim verbs. Both run independently on the same response. A response can pass compliance and fail citation, or vice versa.
- **No retry on banned-claim with citation** — D-13 says reprompt at the conditional, NOT removal of the citation. The narrator KEEPS the citation, REFRAMES the assertion ("vous ferez" → "vous pourriez faire selon ce scénario").
- **Performance**: regex compile happens at module import time (one-shot), parser instances are stateless. ≤50ms target per response.

</specifics>

<deferred>
## Deferred Ideas

- **Multi-turn citation continuity** (citations carry across conversation history) — Phase 96 (CHAT-AS-VERB) territory; turn-cap context propagation will integrate.
- **Per-user citation provenance dashboard** — Phase 96 or beyond; user-facing UX.
- **Cross-language citation registry** (DE/EN/IT/ES/PT keys) — Phase 99+.
- **Citation source registry as JSON contract `GroundingPack`** — Phase 95 (DAG-INVALIDATION) ; D-06's pure-Python module is a Phase 94 stub that Phase 95 replaces.
- **Backend calc-parity (`backlog 999.4`)** — only triggered if Phase 94 §3 CalcTrace requires server-side numbers. Conditional, post-TestFlight.
- **`mint-wiring-verifier` full agent (`backlog 999.3`)** — conditional on ≥3 façade-revert incidents post-Phase 94 close ; not a Phase 94 deliverable.
- **Audit Proposal B (compliance-narrator-auditor leaf-worker subagent)** — runtime multi-agent topology ; deferred to Phase 97-98 post-TestFlight per Phase 93.5 CONTEXT deferred section.

### Reviewed Todos (not folded)
None — Phase 94 inherits scope from ROADMAP + calc-first ADR §N1, not from the todo backlog.

</deferred>

---

*Phase: 94-mvp-citation-gate*
*Context gathered: 2026-05-10 via auto mode (Claude product-leader call)*
*7 gray areas locked (A–G) ; 21 D-XX decisions ; ready for /gsd-plan-phase 94 --auto*
