# Wave 1c: Coach Tool-Dispatch RCA — Context

> **Statut : CLOS 2026-07-29** — le HANDOFF pointait « after PR #631 », mergée depuis longtemps ; la doctrine forced-tool-invocation et les gates money-trust ont repris la surface. Réconciliation plans 2026-07-29.

**Gathered:** 2026-05-15
**Status:** Ready for planning
**Source:** Derived from `HANDOFF.md` (post-bisection smoking gun) + `captured_staging_payload_hydrated.json` + `bisect_results.json` + `experiment_results.json` (deterministic ground truth). Non-roadmap perimeter (slug-based phase dir).

<domain>
## Phase Boundary

**This phase delivers** the doctrine-level fix that makes the coach narrator actually INVOKE `tool_use` blocks instead of emitting `{{cite:tool_<name>}}` placeholders as bare prose patterns, plus the runtime gate that REJECTS placeholder-without-invocation responses, plus the regression-test floor that prevents the bug from re-emerging, plus the WAVE1C instrumentation teardown.

**Out of scope:**
- Wave 1b "SHIPPED" flip (gated on post-fix live G2 sim probe; happens AFTER this phase closes).
- Bisect.py regex updates (bisect.py's drop transforms didn't match staging system-prompt markers; bisection ran 5 no-op drops; this is now irrelevant because the smoking gun was found WITHOUT a successful drop — see `## Smoking gun discovered in the bisect output` in HANDOFF.md).
- Orphan Railway env var cleanup (`COACH_TOOL_SERVER_SIDE_BUDGET_STATUS` and 4 siblings) — separate cleanup, optional.
- Profile PATCH 422 fix during register-seed flow — not blocking.
- Phase 94.2 narrator-prompt iter 2 (intent-driven key grouping) — gated on prod-flip reactivation.

</domain>

<decisions>
## Implementation Decisions (LOCKED)

### Root cause (deterministic, from bisect+payload)

- **D-01.** The bug is doctrine-level: `services/backend/app/services/coach/citation_grammar.py:146` (the Wave 1b plan-03 fragment) teaches the LLM the citation **FORMAT** via `"L'outil get_budget_status renvoie un surplus mensuel de … "` example, but never MANDATES that the LLM must call the tool via `tool_use` BEFORE emitting `{{cite:tool_<name>}}` placeholders. Sonnet 4.5 mimics the FORMAT pattern in prose, refuses (`stop_reason=end_turn`), never emits `tool_use`. Evidence: `bisect_results.json` shows the LLM citing `{cite:tool_retirement_projection}` and `{cite:tool_budget_status}` AS PROSE across multiple bisect variants — it knows the tool by name yet declines to call it.

- **D-02.** Tool advertisement is correct (`captured_staging_payload_hydrated.json` → 3 narrator-relevant tools including `get_retirement_projection`), `tool_choice: {"type": "auto"}` is fine (`experiment_results.json` proved Sonnet picks `tool_use` under `auto` for a minimal prompt). The 26-tool registry filter via `LifeEventRouterBundle` is fine. These three layers are NOT part of the fix.

### Fix architecture (3 surfaces)

- **D-03.** Surface 1 — `services/backend/app/services/coach/citation_grammar.py` doctrine rewrite:
  - Add a MANDATE paragraph at the TOP of `get_grammar()` output (before any FORMAT example), stating in French: tool invocation via `tool_use` is REQUIRED before emitting any `{{cite:tool_<name>}}` placeholder; 1 citation = 1 prior `tool_use`; no exceptions.
  - Reorder existing FORMAT examples to come AFTER the mandate (so the LLM reads "you MUST invoke first" before it reads "here's how to cite the result").
  - Add an explicit WRONG-vs-RIGHT example pair (WRONG = `{cite:tool_retirement_projection}` in prose without tool_use; RIGHT = `tool_use(get_retirement_projection) → tool_result → "{cite:tool_retirement_projection}"`).
  - LSFin compliance: no banned terms (« garanti », « optimal », « meilleur », « certain », etc.). Use « doit », « obligatoire », « préalable ».
  - Accent compliance: 100% FR accents (`tools/checks/accent_lint_fr.py`).

- **D-04.** Surface 2 — `services/backend/app/api/v1/endpoints/coach_chat.py` runtime enforcement gate:
  - New function `_enforce_tool_use_for_citations(answer_text: str, tool_calls: list) -> EnforcementVerdict` (location: sibling to `_citation_gate`; module decision = Claude's Discretion below, but recommendation = same file unless it pushes the file over a reasonable LOC cap).
  - Logic: parse `{{cite:tool_<name>}}` placeholders from `answer_text`; for each placeholder `<name>`, assert at least one matching `tool_use` block in `tool_calls` with `name == "get_<name>"` (or equivalent canonical mapping). On mismatch → REJECT with structured reason `tool_use_missing_for_citation:<name>`.
  - Wire into `_run_narrator_with_gate` alongside `_citation_gate` (approx `coach_chat.py:~4230`). REJECT path triggers re-prompt with the MANDATE inlined into the system prompt for the retry.
  - Sentry breadcrumb on REJECT: category `coach.citation.tool_use_missing`, payload `{placeholder_name, retry_count, narrator_tool_count}`. Sister to existing `coach.citation_gate`. Used to measure rate post-deploy.
  - Re-prompt must include the WRONG-vs-RIGHT example from D-03 verbatim. Cap retries at 1 (per existing `_run_narrator_with_gate` retry budget) — if 2nd attempt still mismatches, fall through to TEXT FALLBACK using the existing `_citation_gate` fallback machinery (do NOT crash, do NOT serve placeholder-as-prose to the user).

- **D-05.** Surface 3 — regression test floor (5 artifacts per qa-expert engram obs id 69, mandatory before fix PR merges):
  1. `services/backend/tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py` — 6 force-keyword fixtures, mock Anthropic, assert `stop_reason == "tool_use"` + correct tool name.
  2. `services/backend/tests/bundles/test_compile_yields_chip_emitter.py` — parameterized 3 messages, assert `compile_bundles(intents).allowed_tools ∩ CHIP_EMITTERS` is non-empty.
  3. `services/backend/tests/test_coach_citation/test_g2_archetype_matrix.py` — 8 archetypes × 6 tools (swiss_native, expat_eu, expat_us FATCA, cross_border, independent_no_lpp, retiree, young_professional, expat_high_income). Reuse Wave 1a parity fixture rig.
  4. `services/backend/tests/test_coach_citation/test_tool_use_mandate.py` (NEW) — fixture: prompt with `{{cite:tool_X}}` produces `tool_use:X` in response stack; fixture: gate REJECTS when LLM emits placeholder without prior `tool_use`; fixture: re-prompt restores correct behavior on retry; fixture: 2-retry exhaustion falls through to TEXT FALLBACK without crash.
  5. `tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml` — assert chips for ALL 6 tools (`get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_3a_cap`, `get_avs_age_reference`, `get_couple_optimization`). Precondition: `runFlow: auth/login.yaml`.

### Wave 1c instrumentation teardown (after fix lands + G2 verification)

- **D-06.** Teardown is in scope of this phase as a final wave (autonomous, blocked-on-fix-live):
  1. Delete Railway env var: `railway variable delete --service MINT --environment staging WAVE1C_INSTRUMENT_ENABLED` then `railway redeploy --service MINT --yes`.
  2. Revert PR #628 instrumentation block: `services/backend/app/services/rag/llm_client.py:232-258` (the wrong call site, kept for legacy path only).
  3. Revert PR #631 instrumentation block: `services/backend/app/services/llm/router.py:_call_anthropic` (the correct narrator call site).
  4. Delete the `claude-wave1c-bisect-*@example.com` staging accounts (or leave — not flagged as real users).

- **D-07.** Wave 1b status flip is OUT of scope for this phase's plans but tracked as a downstream consumer: after a live G2 probe returns `citationChips: [{toolName: ...}, ...]` non-null from staging, `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` flips `PENDING G2 — RUNTIME GAP` → `SHIPPED`. That flip happens via a manual edit-and-commit by Julien after Claude provides the probe evidence in chat, NOT as part of this phase's plans.

### Engineering & ops discipline (LOCKED)

- **D-08.** Branch naming: continue on existing `feature/wave-1c-smoking-gun` for the citation-grammar fix + runtime gate (Wave A). Separate branches for regression tests (Wave B) and teardown (Wave C) — keeps each PR diff focused and reviewable.

- **D-09.** PR shape & ordering:
  - PR Wave A — fix (grammar + gate + Sentry) targets `dev`. Tests in same PR if total LOC ≤ ~150; else split tests into Wave B PR.
  - PR Wave B — regression test floor PR (the 5 artifacts). Lands AFTER Wave A is merged + staging redeploy + 1 live probe confirms `tool_use` emission. Tests are the safety net that prevents regression.
  - PR Wave C — teardown PR (revert instrumentation, delete env var). Lands AFTER Wave B's tests are green AND a clean G2 probe has been captured.

- **D-10.** 0-trust protocol applies (CLAUDE.md §9). The phase claims « WORKS » only after:
  - G1: Sim/staging walker shows narrator response with `tool_use` block AND citation chips in response payload (cite `idb` snapshot OR `curl` JSON in the verification report).
  - G2: Julien runs the flow on a sim, sees chips render, confirms in chat (« ok » or screenshot).
  - G3: dev CI green sha cited (`gh pr checks` output).
  - G4: full `pytest -q` exit 0 + `flutter test` exit 0 cited.
  - G5: `accent_lint_fr.py` + `banned_terms_python.py` + `validate_arb_parity()` exit 0 cited.
  - PR-opened ≠ shipped. Tests-green ≠ feature-working.

- **D-11.** Design panel pre-push: backend-only fix, BUT the prompt-fragment edit affects user-facing French narrator copy → requires `security-auditor` (LSFin banned-terms scan) + `qa-expert` (regression coverage opinion) + `ai-engineer` + `prompt-engineer` (prompt rewrite review). NO Flutter panel needed (no screen change).

- **D-12.** `mem_save` after each wave with `topic_key: coach:citation:tool_use_mandate:<wave>` + `prior_finding_refs` to engram obs ids 65, 66, 74, 75 (Wave 1b/1c audit trail).

### Claude's Discretion

- Exact French wording of the MANDATE paragraph (must be LSFin-clean + accent-perfect; recommended: « AVANT d'émettre tout placeholder `{{cite:tool_<name>}}` dans ta réponse, tu DOIS d'abord invoquer l'outil correspondant via le mécanisme `tool_use`. UNE citation = UN appel `tool_use` préalable. Aucune exception. »).
- Whether `_enforce_tool_use_for_citations` lives in `coach_chat.py` or in a new `services/backend/app/services/coach/citation_tool_use_gate.py` module — split if the parent file exceeds a reasonable LOC cap after the addition.
- Exact retry-prompt phrasing for the rejection re-prompt (must inline the WRONG-vs-RIGHT example + the mandate, keep token cost < ~150 added tokens).
- Whether to add a third regression fixture inside `test_tool_use_mandate.py` for the PARTIAL case (LLM emits some chips via tool_use but ALSO emits 1 prose placeholder without tool_use) — recommended yes.
- Whether to ship Sentry breadcrumb addition in Wave A or Wave B — recommended Wave A (so the alarm is live before regression tests confirm green).
- Whether the post-fix probe runs via `curl` + JSON parse (machine-checkable) or via Maestro flow against sim build — recommended both (curl confirms backend; Maestro confirms full-stack chip render).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (planner, checker, executor) MUST read these before planning or implementing.**

### Smoking-gun evidence (deterministic ground truth)
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/HANDOFF.md` — full RCA narrative + smoking gun + fix shape; START HERE.
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json` — the actual staging request that suppresses tool_use (system_len=44,416; tools=3; tool_choice=auto).
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/bisect_results.json` — 5 drop variants × `end_turn` outcome; LLM cites tools by name in prose.
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/experiment_results.json` — H2 (`tool_choice=auto` suppression) falsified; minimal prompt → Sonnet emits `tool_use`.
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/tools.json` — 26-tool registry dump (narrator-relevant subset is 3).

### Code surfaces to modify or wire against
- `services/backend/app/services/coach/citation_grammar.py:86-89` — Wave 1b refusal escape hatch (audit; may need adjustment to defer to new gate).
- `services/backend/app/services/coach/citation_grammar.py:146` — current FORMAT-teaching fragment (target of D-03 rewrite).
- `services/backend/app/api/v1/endpoints/coach_chat.py:1000-1090` — `_build_system_prompt_with_memory` (may need re-prompt path for retry).
- `services/backend/app/api/v1/endpoints/coach_chat.py:~4230` — `_run_narrator_with_gate` wire site for D-04 new gate.
- `services/backend/app/api/v1/endpoints/coach_chat.py:944-963` — `_classify_user_intent` (referenced by Phase 94.2 hypothesis; out of scope here but adjacent).
- `services/backend/app/services/coach/claude_coach_service.py:660` — legacy doctrine line; verify no conflict with new MANDATE.
- `services/backend/app/services/rag/llm_client.py:232-258` — PR #628 instrumentation block (target of D-06 revert).
- `services/backend/app/services/llm/router.py` — PR #631 instrumentation in `_call_anthropic` (target of D-06 revert).

### Adjacent Wave 1b status doc
- `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` — current Wave 1b status (`PENDING G2 — RUNTIME GAP`); downstream flip after this phase.

### Project doctrine
- `CLAUDE.md §9` — 0-TRUST PROTOCOL (citation discipline).
- `CLAUDE.md §3.5` — routing rules + design panel pattern.
- Engram memory `project_coach_forced_tool_invocation` — trust-collapse tripwire pattern (this phase IS that pattern).
- Engram memory `feedback_pre_push_checklist` — caller-grep + canonical regen + full test before push.
- Engram memory `feedback_perimeter_5_gates` — 5-gate exit contract.

### Engram observations (use `prior_finding_refs` when saving findings)
- obs id 65 — Wave 1b UAT pivot to G2 closure.
- obs id 66 — Wave 1b G2 Run #2 — 3 blockers (2 fixed, 1 = this phase).
- obs id 74 (`obs-bcb0b41d70a52ae4`) — H2 falsification (`tool_choice` not the suppressor).
- obs id 75 (`obs-bab7b74851fff6a9`) — handoff doc (the source of this CONTEXT).
- (NEW, save when planning starts) — smoking-gun discovery (citation grammar teaches FORMAT not INVOCATION); should `supersedes` obs 74's "context bloat" hypothesis.

</canonical_refs>

<specifics>
## Specific Ideas (from HANDOFF.md `## Update 2026-05-15 17:38 CEST`)

- **MANDATE paragraph (target text):** « AVANT d'émettre tout placeholder `{{cite:tool_<name>}}` dans ta réponse, tu DOIS d'abord invoquer l'outil correspondant via le mécanisme `tool_use`. UNE citation = UN appel `tool_use` préalable. Aucune exception. »
- **WRONG example to embed in grammar:** prose `« Ta projection de rente AVS sera de {cite:tool_retirement_projection} »` without prior `tool_use(get_retirement_projection)` block.
- **RIGHT example to embed in grammar:** `tool_use(get_retirement_projection) → tool_result(...) → « Ta projection de rente AVS est de 24'960 CHF/an {cite:tool_retirement_projection} »`.
- **Gate REJECT structured reason:** `tool_use_missing_for_citation:<placeholder_name>`.
- **Sentry breadcrumb category:** `coach.citation.tool_use_missing` (sister to `coach.citation_gate`).
- **Sentry alarm rule (operational tripwire post-deploy):** `stop_reason==end_turn AND prose matches /\{cite:tool_/ AND narrator_tool_count == 0` → page.
- **Live probe expected shape (post-fix):** `curl https://mint-staging.up.railway.app/api/v1/coach/chat ...` → response with `citationChips: [{toolName: "get_retirement_projection", ...}, ...]` non-null AND no bare `{cite:tool_...}` strings in `message`.

</specifics>

<deferred>
## Deferred Ideas

- Phase 94.2 narrator-prompt iter 2 (intent-driven key grouping per `_classify_user_intent`). Reactivated when prod-flip path becomes critical path again. Out of scope here.
- Orphan Railway env vars (`COACH_TOOL_SERVER_SIDE_BUDGET_STATUS`, `_CAP_STATUS`, `_COUPLE_OPTIMIZATION`, `_CROSS_PILLAR_ANALYSIS`, `_RETIREMENT_PROJECTION`) cleanup. Optional, separate cleanup.
- Profile PATCH 422 fix in register-seed flow (`services/backend/app/schemas/profile.py:ProfileUpdate` field-name reconciliation). Not blocking — budget seed alone is sufficient for `get_budget_status` probes.
- bisect.py regex updates so its `drop_*` transforms match real staging system-prompt format. Irrelevant for this phase (smoking gun already found without successful drops); keep `bisect.py` in the phase dir as an audit artifact.
- Wave 1b "SHIPPED" status flip — happens after this phase's Wave A merge + G2 probe; not a deliverable here.

</deferred>

---

*Phase: wave-1c-coach-tool-dispatch-rca*
*Context derived: 2026-05-15 from HANDOFF.md (post-bisection smoking gun) + captured payload + bisection evidence + 3-agent RCA experiment*
*0-trust note: every claim above is anchored to a file path or a deterministic command output. No « shipped » / « ready » claims in this CONTEXT.*
