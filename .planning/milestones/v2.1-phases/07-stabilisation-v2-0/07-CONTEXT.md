# Phase 7: Stabilisation v2.0 - Context

**Gathered:** 2026-04-07 (auto-mode, assumptions-based)
**Status:** Ready for planning

<domain>
## Phase Boundary

v2.0 is provably wired end-to-end and ready for TestFlight. Every coach tool reaches the user, every façade-without-wiring blind spot is audited and resolved, CI is green, lints are clean.

**Strict scope guardrails:**
- **No new features.** v2.1 is stabilization only.
- **No architectural redesigns.** Surgical wiring fixes only.
- **No renames or refactors** unrelated to a specific STAB requirement.
- **No CI re-integration** of `golden_screenshots/` (intentionally excluded).

</domain>

<decisions>
## Implementation Decisions

### Coach Tool Wiring (STAB-01..04, STAB-11)

- **D-01:** Render path is the single source of truth. The renderer (`widget_renderer.dart`) decides what is user-visible. Any tool emitted by the orchestrator that hits a `SizedBox.shrink()` branch counts as a P0 bug. Fix at the renderer level (add `case`) AND at the orchestrator level (pass complete data).
- **D-02:** `route_to_screen` resolution: keep backend contract (`intent + confidence + context_message`) unchanged. Mobile-side, add an intent→route map (table-driven, lives in `chat_tool_dispatcher.dart` or a sibling). Renderer accepts either an explicit `route` or an `intent` and resolves to a tappable card.
- **D-03:** `generate_document` rendering: add `case 'generate_document'` to `widget_renderer.dart` returning a `DocumentGenerationCard` (reuse the existing component if one exists; otherwise add a minimal one — chip + label + tap → trigger).
- **D-04:** `generate_financial_plan` and `record_check_in`: expose both in the BYOK tool list emitted by `coach_orchestrator.dart` (currently only `route_to_screen` and `generate_document`). Modify `CoachLlmService.chat()` (`coach_llm_service.dart:321`) to re-expose `toolCalls` on its return value so the orchestrator can dispatch them. Renderer cases already exist.
- **D-05:** End-to-end test (STAB-11) lives at `apps/mobile/test/integration/coach_tool_choreography_test.dart` (new file). One test per tool. Each test exercises: tool call object → orchestrator handler → renderer → finder for the visible widget. No mocks of the renderer — test the real widget tree with `pumpWidget`.

### Façade-Sans-Câblage Audit (STAB-12..17)

- **D-06:** All 6 audit reports live under the phase directory (`.planning/phases/07-stabilisation-v2-0/AUDIT_*.md`) and are committed. Format = markdown table with columns appropriate to each audit (PASS/FAIL/MISSING + evidence path + fix action).
- **D-07:** STAB-12 (coach surface audit) — enumerate every tool definition in `services/backend/app/services/coach/coach_tools.py` AND every `case` in `apps/mobile/lib/widgets/coach/widget_renderer.dart`. For each, verify the 5-stage chain: definition → orchestrator dispatch → renderer case → bubble display → user-visible. Cross-product table.
- **D-08:** STAB-13 (provider/service consumer audit) — script: `grep -rl "ProviderName" apps/mobile/lib/ | grep -v _test.dart` for every Provider in `app.dart`. Same for every public class in `lib/services/`. Zero hits = dead. All-test hits = orphan. Output table per finding with verdict: DELETE / WIRE / KEEP-WITH-RATIONALE.
- **D-09:** STAB-14 (route reachability audit) — enumerate every `path:` in `app.dart` GoRouter config. For each, grep `context.go|context.push|context.pushNamed|context.pushReplacement` for that path or named route across `lib/`. Zero hits = orphan. Verdict: WIRE-ENTRY / DELETE / KEEP-DEEP-LINK-ONLY.
- **D-10:** STAB-15 (contract drift audit) — for every Pydantic schema in `services/backend/app/schemas/` that's returned by an endpoint hit by mobile, find the corresponding Dart model. Diff the field lists. Any field present in backend but absent in mobile = silent drop. Verdict: ADD-TO-MOBILE / REMOVE-FROM-BACKEND / DOCUMENT-WHY-IGNORED. The `route_to_screen` bug is exactly this category.
- **D-11:** STAB-16 (try/except audit) — `grep -n "try:" services/backend/app/` and `grep -n "try {" apps/mobile/lib/`. For each hit, read the except/catch block. Any handler that returns null/empty/false on a non-best-effort path is a finding. Verdict: RETHROW / SURFACE-TO-USER / DOCUMENT-BEST-EFFORT.
- **D-12:** STAB-17 (tap-to-render audit) — manual walkthrough on the latest dev build. For each tab (Aujourd'hui, Coach, Explorer) plus ProfileDrawer, document every interactive element with: location (file:line), expected outcome, actual outcome, verdict (PASS/FAIL). This is the **last gate** before TestFlight. Run AFTER STAB-01..16 are fixed.
- **D-13:** Audit findings produce fix tasks **inside Phase 7**. Anything that genuinely cannot be fixed in v2.1 (because it requires a feature decision or architectural change) is documented with explicit accept + ADR placeholder + GSD todo for v3.0.

### Phase 1 Test Refresh (STAB-05..07)

- **D-14:** STAB-05 fix: re-read the current `login_screen.dart`, identify the actual current widgets (magic-link button, email field, etc.), and rewrite `auth_screens_smoke_test.dart` to assert on what's there. Do NOT add tests for the deleted password flow.
- **D-15:** STAB-06 fix: re-read the current `intent_screen.dart` and `plan_screen.dart` to confirm where `setOnboardingCompleted` actually fires. Update the test to assert at the correct screen boundary. If the test name no longer matches its purpose, rename it.
- **D-16:** STAB-07 fix: capture `GoRouter.of(context)` and any provider reads BEFORE `await` at `intent_screen.dart:195`. Standard pattern: `final router = GoRouter.of(context); final foo = context.read<FooProvider>(); await someAsync(); if (!mounted) return; router.go('/...');`.

### Lint & Hygiene (STAB-08..09)

- **D-17:** STAB-08: run `ruff check services/backend/ --output-format=concise` and fix all 43 errors mechanically. No behavioral changes — pure hygiene. Commit in one atomic commit.
- **D-18:** STAB-09: run `flutter analyze` and triage. Production code (`lib/`) warnings = MUST FIX. Test files (`test/`) infos = nice-to-have, fix only the trivial ones. The IntentScreen async-gap (STAB-07) is the highest-priority production warning.

### CI Green (STAB-10)

- **D-19:** After STAB-01..09 are merged to dev, push a no-op commit (or the last fix commit) and watch CI. Any red job is a Phase 7 task. The screens shard MUST go green — STAB-05 and STAB-06 unblock it. `golden_screenshots/` stays excluded (intentional).

### Plan Decomposition Hint for `gsd-planner`

- **D-20:** Recommended plan decomposition (planner has discretion):
  - **07-01 — Façade audit (parallelizable)**: STAB-12..16 (the 5 mechanical audits). 5 audit reports written. NO fixes yet.
  - **07-02 — Coach tool wiring**: STAB-01..04 + STAB-11. Drives all 4 tools to user-visible state with E2E test.
  - **07-03 — Phase 1 test refresh**: STAB-05..07.
  - **07-04 — Audit fix sweep**: every BROKEN/MISSING from 07-01 fixed or accepted with ADR.
  - **07-05 — Lint & hygiene**: STAB-08..09.
  - **07-06 — CI green + tap-to-render gate**: STAB-10 + STAB-17. Manual walkthrough is THE last gate before TestFlight.
- **D-21:** Order rationale: audit FIRST so we know the full surface area; then wire coach tools and refresh tests in parallel; then fix audit findings; then lint sweep; then CI green and manual walkthrough as final gate.

### Claude's Discretion

- Exact wording of the intent→route mapping table
- Layout/styling of `DocumentGenerationCard` (reuse closest existing component)
- Whether STAB-13/14/15/16 produce 4 separate scripts or one combined audit script
- Audit table column ordering
- Whether to fix backend ruff in one commit or per-file (recommend: one commit)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `CLAUDE.md` — full project context (constants, compliance, dev rules)
- `.planning/PROJECT.md` — current milestone goals
- `.planning/REQUIREMENTS.md` — STAB-01..STAB-17 detailed requirements
- `.planning/ROADMAP.md` §"Phase 7: Stabilisation v2.0" — success criteria

### Coach tool wiring (STAB-01..04, STAB-11, STAB-12)
- `services/backend/app/services/coach/coach_tools.py` — backend tool definitions
- `apps/mobile/lib/services/coach/coach_orchestrator.dart` — mobile orchestrator (lines ~476, ~639, ~644)
- `apps/mobile/lib/services/coach/chat_tool_dispatcher.dart` — tool dispatch (line ~82)
- `apps/mobile/lib/services/coach_llm_service.dart` — BYOK LLM service (line ~321)
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` — render switch (lines ~49, ~70, ~96, ~450)
- `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` — bubble surface (line ~107)

### Phase 1 test refresh (STAB-05..07)
- `apps/mobile/lib/screens/auth/login_screen.dart` — current magic-link UI (source of truth for STAB-05)
- `apps/mobile/test/screens/auth_screens_smoke_test.dart` — broken test
- `apps/mobile/lib/screens/onboarding/intent_screen.dart` — async-gap at line 195 (STAB-07)
- `apps/mobile/lib/screens/onboarding/plan_screen.dart` — current setOnboardingCompleted location
- `apps/mobile/test/screens/onboarding/intent_screen_test.dart` — broken test

### Façade audit anchors (STAB-13..15)
- `apps/mobile/lib/app.dart` — Provider registrations + GoRouter routes (audit input)
- `apps/mobile/lib/services/` — services to audit consumers of
- `services/backend/app/schemas/` — Pydantic contracts to diff against mobile models
- `apps/mobile/lib/models/` — mobile model targets

### Methodology
- `MEMORY.md` → `feedback_facade_sans_cablage.md` — the recurring failure mode this phase pays down
- `MEMORY.md` → `feedback_audit_methodology.md` — 12-point production-grade audit checklist
- `MEMORY.md` → `feedback_audit_multi_pass.md` — 7-pass audit methodology
- `MEMORY.md` → `feedback_audit_inter_layer_contracts.md` — inter-layer contract checks (STAB-15 directly)
- `MEMORY.md` → `feedback_audit_read_error_paths.md` — try/except discipline (STAB-16 directly)
- `MEMORY.md` → `feedback_no_regressions.md` — regression discipline
- `MEMORY.md` → `feedback_never_commit_without_audit.md` — pipeline = code → audit → fix → commit

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `widget_renderer.dart:70` and `:450` — render cases for `generate_financial_plan` and `record_check_in` already exist; only the orchestrator wiring is missing.
- `coach_orchestrator.dart:644` — `[GENERATE_DOCUMENT:…]` marker already emitted; only the renderer case is missing.
- `chat_tool_dispatcher.dart` — has dispatch infra; the `intent` path is acknowledged as not-yet-supported (explicit comment).
- Existing integration test scaffolding in `apps/mobile/test/integration/` (Phase 6 onboarding tests) — pattern to copy for STAB-11.
- `coach_tools.py` — clean tool definition shape; backend side is the SOT for new tool fields.

### Established Patterns
- Mobile orchestrator emits inline markers (`[ROUTE_TO_SCREEN:…]`, `[GENERATE_DOCUMENT:…]`) which the renderer parses. STAB-01/02 fix should keep this pattern, not reinvent transport.
- BYOK tool list is hardcoded in the orchestrator. Adding new tools = list edit + ensure the LLM service propagates `toolCalls` back.
- `flutter analyze` is currently 87 issues, mostly test/style. STAB-09 targets `lib/` only.
- Backend tests are 5018 passing (per audit). Don't break that with ruff fixes.

### Integration Points
- The 4 coach tools land in `CoachMessageBubble` via `widget_renderer.dart`. That single switch is the choke point for all coach UX.
- `app.dart` MultiProvider + GoRouter is the choke point for STAB-13/14 audits.
- CI screens shard runs `flutter test test/screens/`. STAB-05 and STAB-06 are blockers; STAB-09 is hygiene on top.

</code_context>

<specifics>
## Specific Ideas

- Audit reports should be **mechanical and grep-driven** wherever possible. Only STAB-17 (tap-to-render) is manual. The point is to find blind spots agents can't reason about.
- Every BROKEN finding should be small enough to fix in one commit. If a finding requires a design discussion, it's a v3.0 todo, not a Phase 7 fix.
- The user ("façade sans câblage" warning) is the Why for STAB-12..17. Keep that motivation visible in commit messages: `fix(coach): wire route_to_screen end-to-end (façade audit)` rather than a generic `fix: bug`.

</specifics>

<deferred>
## Deferred Ideas

- Coach tool architecture refactor (collapse marker-based transport into structured `toolCalls`) — out of scope; surgical fixes only.
- Re-integrating `golden_screenshots/` into CI with cross-platform tolerance — needs separate spike, v3.0.
- Cleaning test/style lints in `test/` — lower ROI than production code lints; v3.0 if at all.
- Replacing `flutter analyze` with stricter `analysis_options.yaml` — out of scope.
- TestFlight build itself — happens AFTER Phase 7 verification, not during.

</deferred>

---
*Phase: 07-stabilisation-v2-0*
*Context gathered: 2026-04-07 (auto-mode)*
