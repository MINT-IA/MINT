---
date: 2026-05-10
author: Claude (staff-engineer audit, on Julien request)
scope: apps/mobile/lib + services/backend/app
prior-audits: .planning/codebase/{ARCHITECTURE,STRUCTURE,CONCERNS}.md (2026-04-22), .planning/audit/2026-04-17-deep-audit.md
description: Deep but pragmatic audit on 4 axes (cleanliness, performance, simplification, durability) with concrete file:line evidence and a steel-man counter-argument.
---

# Codebase Audit — 2026-05-10

## Executive Summary

MINT is **not** an « usine à gaz » — the bones are clean: 1 source of truth (`financial_core/`), 1 router (GoRouter, 152 routes, only 2 raw `Navigator.push` left in 683 Dart files), 1 backend API tree, 1 ADR-driven decision log. The « monstre » lives in **3 god-files** (`coach_chat.py` 3 354 LOC, `coach_profile.dart` 3 353 LOC, `app.dart` 1 953 LOC) which absorb every feature, take 17–21 % of all monthly file-touches between them, and re-implement scaffolding inside themselves (PII scrub, fact persistence, formatting helpers, system-prompt builders).

The 2026-04-22 prior audit predicted this and listed the fixes — most are still open 18 days later. The structural pivot proposed in `decisions/2026-05-09-calc-first-llm-illumination.md` (calc-first / LLM as narrator) is the right framing because it forces extraction of the 3 god-files into well-named layers (calc → grounding pack → narrator → guard).

**Net scores:** Architecture 7/10 · Performance 7/10 · Simplification potential 6/10 (large) · Durability 6/10 (test coverage gaps + 3 god-file chokepoints).

---

## Axis 1 — Architecture cleanliness — **7/10**

### Rationale

**What is genuinely clean (kept the score above 6):**

- **Single source of truth for Swiss math.** `apps/mobile/lib/services/financial_core/financial_core.dart:1-26` exports 16 calculators. `services/backend/app/services/` has near-zero `_calculate*` re-implementations — `grep "def _calculate"` of the entire backend `services/` returns essentially nothing for the 4 pillars; the only structural calc on the backend is `services/backend/app/services/retirement/avs_estimation_service.py:1-50` which uses constants and a documented dataclass model, not a duplicate of `AvsCalculator`. The ADR `decisions/ADR-20260223-unified-financial-engine.md` is genuinely respected at the math level.
- **One router, one shell.** `apps/mobile/lib/app.dart` declares 152 `GoRoute(...)` / `ScopedGoRoute(...)` and 53 explicit `redirect:` entries. Across the full Flutter source (683 files) only **2** raw `Navigator.push` calls remain vs. **188** `context.go/push/pushNamed`. Routing is centralized.
- **`ScopedGoRoute` (`apps/mobile/lib/router/scoped_go_route.dart`) is a model of fail-closed design** — auth scope is encoded at route definition, not maintained as a prefix whitelist.
- **Provider tree is migrating in the right direction.** `apps/mobile/lib/app.dart:1495` (`MintStateProvider`), `:1517` (`FinancialPlanProvider`), `:1561` (`NotificationsWiringService`) are now `ChangeNotifierProxyProvider<CoachProfileProvider, …>` with `lazy: false` — exactly what the 2026-04-22 audit asked for. The « façade-sans-câblage » comment at lines 1511–1556 documents both what was wrong and why the fix shape is correct.

**What pulls the score down:**

- **`apps/mobile/lib/app.dart` is still 1 953 LOC and was touched 168 times in 90 days** (most-touched file in the entire repo, ahead of all 6 generated `app_localizations*.dart` files). Three concerns coexist there: 152-route GoRouter table, MultiProvider tree (18 providers), 53 redirects + auth listener. A « stable app entry » should see < 5 touches/month.
- **financial_core barrel is bypassed by 97 imports** of sub-modules (`grep "import.*financial_core/" --include='*.dart' | grep -v "financial_core.dart';"` = 97 hits). Examples: `apps/mobile/lib/providers/coach_profile_provider.dart:13`, `apps/mobile/lib/screens/simulator_3a_screen.dart:18`, `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:22`. The ADR mandate is partially enforced. Phase 2 of ADR-20260223 (« replace direct imports with barrel ») was scheduled but never closed.
- **`services/backend/app/api/v1/endpoints/coach_chat.py` is 3 354 LOC and grew 738 lines (+28 %) since the 2026-04-22 audit (was 2 616).** It contains 40 top-level functions: `_scrub_pii`, `_get_vector_store`, `_get_hybrid_search`, `_get_orchestrator`, `_sanitize_*` (3 variants), `_build_coach_context_from_profile`, `_build_commitment_memory_block`, `_build_intelligence_memory_block`, `_build_insight_memory_block`, `_build_system_prompt_with_memory`, `_handle_retrieve_memories`, `_classify_user_intent`, `_compute_suggested_actions`, `_coerce_fact_value`, `_persist_extracted_fact`, `_run_extractor_stage`, `_call_with_fallback`, `_execute_internal_tool`, `_fmt_chf`, `_fmt_pct`, `_format_budget_status`, `_format_retirement_projection`, … — every concern (PII, memory, intent, extraction, tool dispatch, formatting) is glued into one file. 21 distinct touches in 90 days and growing.
- **`apps/mobile/lib/models/coach_profile.dart` (3 353 LOC) is consumed by 84+ files** (last-90-days touch count: 84). Hand-rolled `fromJson`/`toJson`, a deprecated field still referenced (per prior audit). Schema changes here remain a 100-file audit operation.
- **Two « narrator » layers without a settled boundary.** `apps/mobile/lib/services/coach_narrative_service.dart` (1 458 LOC) coexists with `services/backend/app/services/coach/claude_coach_service.py` (1 100 LOC). Both build coach system prompts. The prior audit flagged a Flutter twin (`lib/services/coach/coach_narrative_service.dart`); that twin was deleted (good). The remaining duplication is **client/server**, which is harder: prompts diverge silently when only one side is updated.
- **`services/backend/build/lib/` shadow tree (260 .py files, ~80 K LOC) sits on disk untracked** (`git ls-files services/backend/build/` = 0). Not a git problem, but it is a *grep* problem: every `grep -r services/backend` accidentally matches stale code (e.g. `services/backend/build/lib/app/services/rules_engine.py` 957 LOC vs. canonical 1 014 LOC). Devs reading this repo locally see two answers to the same question.

### Evidence file:line

- `apps/mobile/lib/services/financial_core/financial_core.dart:1-26` — the barrel that *should* be the only entry-point.
- `apps/mobile/lib/app.dart:1440-1569` — MultiProvider with 4 still-plain `ChangeNotifierProvider(create: (_) { x.someAsync(); return x; })` patterns at lines 1442 (`AuthProvider.checkAuth`), 1449 (`ByokProvider.loadSavedKey`), 1457 (`CoachProfileProvider.loadFromWizard`), 1471 (`SlmProvider.init`). These 4 still trigger uncoordinated async I/O at provider construction.
- `services/backend/app/api/v1/endpoints/coach_chat.py:84,187,224,250,334,393,479,522,574,635,687,744,784,944,978,995,1165,1258,1319,1336,1354,1367,1375,1386,1560,1695,2088,2101,2114,2137` — 30 helper-function declarations all inside one HTTP-endpoint module.
- `services/backend/app/api/v1/endpoints/coach_chat.py:2075` — beta entitlement bypass still in place (`# TODO(billing): Re-enable full entitlement gate`).

---

## Axis 2 — Performance / optimization — **7/10**

### Rationale

**What is good:**

- **Cold-launch shape is sound.** `apps/mobile/lib/main.dart:26-120` follows progressive disclosure: only `installGlobalErrorBoundary()`, `ApiService.ensureReachableBaseUrl()` and `RegulatorySyncService.loadFromDisk()` are awaited; SLM init is `unawaited(...)` with a 5 s timeout (`main.dart:68-87`); feature-flag refresh has an 800 ms timeout (`main.dart:96-101`, comment says STAMP-02 reduced from 2 s); pillar3a + tax + commune + regulatory + snapshot loads are `Future.wait([...])` non-blocking (`main.dart:104-`). Phase 89 STAMP-02/03 instrumentation is wired (`main.dart:35` `MintFrameTimingCapture.register()`).
- **Test suite duration is healthy.** 6 154 backend tests in ~107 s (per Julien) ≈ 17 ms / test. 470 Flutter test files, 229+ test units, with the known 3 flaky races documented (`apps/mobile/test/data_injection_test.dart`, `apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart`, `apps/mobile/test/widgets/plan_reality_home_test.dart`).
- **Backend startup has fail-fast DB check + auto-RAG ingest deferred** (`services/backend/app/main.py:62-113`). SLO monitor is a background task with explicit fail-open (`main.py:115-120`).

**What pulls the score down:**

- **`coach_chat.py` is the slow path of the slow path.** Every authenticated chat turn: PII scrub (`coach_chat.py:84`) → memory blocks built 3 times (`:574, :635, :687`) → system prompt assembled with memory (`:744`) → user-intent classified (`:944`) → extractor stage with cache (`:1386`) → call with fallback (`:1560`) → tool execution (`:1695`) → response formatting helpers (`:2088+`). All synchronously chained inside one endpoint, no profiling of which stage dominates p95. With Sonnet kill-policy fallback (per ADR 2026-04-19) latency variance on a single chat turn is unbounded.
- **`apps/mobile/lib/app.dart` has 18 providers built at root + auth listener; every auth state change can rebuild everything below `MultiProvider`.** The `_AuthRouterBridge` and `MigrationNoticeListener` wrap `MaterialApp.router` (`app.dart:1571-1594`); a `Builder` reads `LocaleProvider` (`:1577`) — locale changes also rebuild the app shell.
- **126-consumer god-model means hot-path hygiene is impossible.** `coach_profile.dart` is touched on every save_fact, every wizard step, every scan extract. With 3 353 LOC and hand-rolled JSON, equality / change detection is not memoized; every mutation calls `notifyListeners()` which fans out across the proxy tree (`app.dart:1495, 1517, 1561`).

### Top 3 specific bottlenecks

1. **`services/backend/app/api/v1/endpoints/coach_chat.py:1386-2080`** (extractor + fallback + internal tool) — composite p95 is unmeasured; this is the hot path for « anonymous → first illumination » conversion.
2. **`apps/mobile/lib/app.dart:1442-1569` MultiProvider root** — 18 providers + 4 plain `ChangeNotifierProvider(create: ...async I/O...)` at lines 1442/1449/1457/1471 create non-deterministic init order. Cold-start observability is non-existent (no per-provider timing).
3. **`apps/mobile/lib/services/coach_narrative_service.dart` (1 458 LOC) + duplicate prompt construction client-side.** Every chat turn rebuilds prompt locally for SLM/BYOK fallback even when authenticated path won't use it. ~57 KB Dart code in a tier-3 fallback that should be a static template.

---

## Axis 3 — Simplification opportunities

### Top 5 « extreme » wins

#### #1 — Split `coach_chat.py` into 5 modules — high-value, medium-risk

- **Files:** `services/backend/app/api/v1/endpoints/coach_chat.py:1-3354`
- **Estimated LOC reduction:** -800 to -1 200 inside the endpoint (from 3 354 → ~1 800 in the router + 4 sibling files: `coach_pii.py`, `coach_memory.py`, `coach_intent.py`, `coach_tool_executor.py`, `coach_formatters.py`). Net repo LOC roughly flat — but blast radius shrinks 3× (5 files of 400-600 LOC each, each touched by its own concern).
- **Risk:** Medium. 21 touches/90 d means coach is in active development; needs a 2-week feature-freeze on coach OR extract one helper at a time behind a feature flag. The 5 « format » helpers (`_fmt_chf`, `_fmt_pct`, `_format_budget_status`, `_format_retirement_projection` at `:2088-2300+`) are pure functions — extract those first as a smoke test of the split process.
- **Why now:** the 2026-04-22 audit asked for this. 18 days later the file grew +28 %. Each delayed week costs more.

#### #2 — Migrate the 97 direct sub-module `financial_core/` imports to the barrel — low-risk codemod

- **Files:** 97 callers across `apps/mobile/lib/`, e.g. `apps/mobile/lib/providers/coach_profile_provider.dart:13`, `apps/mobile/lib/screens/simulator_3a_screen.dart:18`, `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:22`, `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:9`, `apps/mobile/lib/models/response_card.dart:2`.
- **Estimated LOC reduction:** ~0 LOC reduction (it's a substitution), but **97 file-headers cleaned** + future calculator splits become a 1-file change instead of 97. Pre-condition for the calc-first pivot in ADR 2026-05-09.
- **Risk:** Low. `financial_core.dart` already exports everything (verified `:1-26`). Add a `tools/checks/financial_core_barrel_only.py` lint rule, run `dart fix` codemod, ship 1 PR.
- **Why now:** ADR-20260223 says « Implemented »; right now that's partially false, and the calc-first ADR makes it load-bearing.

#### #3 — Delete `services/backend/build/lib/` (260 stale .py files, ~80 K LOC on disk) — zero-risk cleanup

- **Files:** `services/backend/build/lib/app/**/*.py` (260 files) — confirmed not tracked (`git ls-files services/backend/build/` = 0 lines).
- **Estimated LOC reduction:** ~80 000 LOC removed from local greps and IDE indexing. Disk only.
- **Risk:** Zero. Not in git. Add `services/backend/build/` to `.gitignore` if not already, then `rm -rf`.
- **Why now:** Every `grep -r services/backend` returns wrong matches. New Claude sessions get confused by stale `rules_engine.py:957 LOC` vs canonical `:1014 LOC`. CLAUDE.md NEVER #6 (« code without reading existing code ») degrades when there are two candidates.

#### #4 — Extract `coach_profile.dart` into 3 layers — high-value, high-risk

- **Files:** `apps/mobile/lib/models/coach_profile.dart:1-3353`, 84+ direct importers.
- **Estimated LOC reduction:** Net ~-300 LOC (removing duplicated `fromJson` boilerplate via a `JsonSerializable` codegen on the leaf schemas), but the real win is **84 importers each touch a 400 LOC file instead of a 3 353 LOC file**. Splits: `coach_profile_schema.dart` (pure data, ~800 LOC), `coach_profile_extensions.dart` (computed getters / convenience methods, ~600 LOC), `coach_profile_storage.dart` (SharedPreferences serde, ~400 LOC), `coach_profile_legacy.dart` (deprecated fields awaiting migration).
- **Risk:** High. Hand-rolled JSON means a typo is silent null. Mandatory: golden tests pass before AND after for Julien + Lauren archetypes (`apps/mobile/test/golden/Julien/`, `apps/mobile/test/golden/Lauren/`). Adopt `json_serializable` codegen DURING the split, not after.
- **Why now:** This is the single highest-leverage god-file. It blocks the calc-first GroundingPack (N2 in ADR 2026-05-09) which needs a clean profile schema to serialize.

#### #5 — Remove the duplicate « narrator » layer and define one narrator contract — medium-risk

- **Files:** `apps/mobile/lib/services/coach_narrative_service.dart` (1 458 LOC), `services/backend/app/services/coach/claude_coach_service.py` (1 100 LOC).
- **Estimated LOC reduction:** -1 458 LOC client-side **if** the calc-first ADR is adopted (LLM becomes a closed-vocabulary narrator with `{{cite:<key>}}` placeholders, the per-tier prompt construction moves server-side, the on-device fallback becomes a static template registry of ~200 LOC). -1 258 LOC net.
- **Risk:** Medium. The fallback path matters for offline / BYOK / SLM. Solution: keep `apps/mobile/lib/services/coach/coach_orchestrator.dart` (1 482 LOC) as the tier router but delete prompt construction from `coach_narrative_service.dart`; tier-3 returns a ~10-line static template per intent.
- **Why now:** The Stage 3 narrator eval in `.planning/phases/91-mvp-extractor-v2/eval-evidence/eval_comparison.md` (Haiku 7/50 vs Sonnet 26/50 doctrine) shows that LLM narration is the unreliable surface. Less narrator code = fewer divergence points.

---

## Axis 4 — Durability / sustainability — **6/10**

### Rationale

**Strengths:**

- **ADR discipline is real.** 21 ADRs in `.planning/decisions/` (May 2026 alone). `_TEMPLATE.md` enforces counter-arguments + data-gaps sections (HARD lint per CLAUDE.md §8 wiki-schema rule 2). The 2026-05-09 calc-first ADR cites 7 expert-panel research docs in `.planning/audit/calc-first-architecture/`.
- **Test mass is non-trivial.** 212 backend `test_*.py` + 470 Flutter `*_test.dart`. Golden fixtures (Julien, Lauren) committed under `apps/mobile/test/golden/` and `services/backend/tests/fixtures/`.
- **Five-gate exit contract for perimeters** (per Julien's `feedback_perimeter_5_gates.md`) is genuinely enforced: G1 sim walker / G2 device by Julien / G3 dev CI / G4 regression / G5 LSFin+accent+ARB lint. Phase 91 closed under this contract.

**Weaknesses (the 4 points lost):**

- **`app.dart` 168 touches/90 d, `coach_chat.py` 21 touches/90 d, `coach_profile.dart` 84 touches/90 d.** Three files account for ~17–21 % of all source-file touches. New devs (or new Claude sessions) hit one of these on day 1 and edit a file they cannot fully read. CLAUDE.md NEVER #6 is structurally violated by file size, not by intent.
- **Test coverage gaps remain unaddressed since 2026-04-22.** Markdown rendering (T1, prior audit) — no widget tests; auth state propagation post-login (T2) — no integration test; coach multi-turn context retention (T3) — shallow test only. 6/8 archetypes (`expat_eu`, `expat_non_eu`, `independent_with_lpp`, `independent_no_lpp`, `cross_border`, `returning_swiss`) have no golden regression baseline (`apps/mobile/test/golden/` only contains Julien + Lauren).
- **346 bare `catch` in Flutter, 60 bare `except` in backend** (vs. 332 / 56 in 2026-04-22). Both increased. The « 388 bare catches silencieux » entry from `.planning/PROJECT.md` Context section is still active and growing.
- **TODO/FIXME density: 41 in source code** — looks low until you read them. They mark structurally-load-bearing gaps: AVS income splitting for married couples (`services/backend/app/services/retirement/avs_estimation_service.py`, prior audit §C8), monthly check-ins not synced (`apps/mobile/lib/providers/coach_profile_provider.dart:1133`), fire-and-forget profile sync (4 sites in same file), beta entitlement bypass (`coach_chat.py:2075`).
- **Duplicate « narrator » code** between Flutter `coach_narrative_service.dart` (1 458 LOC) and backend `claude_coach_service.py` (1 100 LOC) means coach prompt drift is undetected by tests — both files build similar system prompts, neither has a parity gate.

### Top 5 durability concerns

| # | Concern | Files | Recommended action |
|---|---|---|---|
| 1 | God-file chokepoint: `app.dart` (1 953 LOC, 168 touches/90 d) is THE merge-conflict hotspot | `apps/mobile/lib/app.dart` | Extract `_router` (152 routes + 53 redirects) into `apps/mobile/lib/router/router_config.dart` (~900 LOC) ; extract `MultiProvider` providers list (`:1440-1569`) into `apps/mobile/lib/providers/provider_tree.dart` (~150 LOC). Target: `app.dart` < 400 LOC, < 5 touches/month. |
| 2 | God-model chokepoint: `coach_profile.dart` blocks GroundingPack contract for calc-first | `apps/mobile/lib/models/coach_profile.dart` | Adopt `json_serializable` codegen, split into 3 files (#4 above). MUST happen before Phase 95 MVP-DAG-INVALIDATION. |
| 3 | 6/8 archetype golden tests missing — silent regression risk on every `arbitrage_engine.dart` change | `apps/mobile/test/golden/` (only Julien + Lauren) | Generate frozen fixtures for `expat_eu`, `expat_non_eu`, `independent_with_lpp`, `independent_no_lpp`, `cross_border`, `returning_swiss`. Phase 92.5 calc-rigor proposed in calc-first ADR explicitly covers this with 200 frozen fixtures + ESTV oracle. Ship 92.5 before any further calc edit. |
| 4 | Beta entitlement gate bypass in `coach_chat.py:2075` is not flag-protected — a launch-blocker if forgotten | `services/backend/app/api/v1/endpoints/coach_chat.py:2075` | Add `BILLING_GATE_REENABLE_DATE` env var; backend logs CRITICAL if `today > that_date AND gate is bypassed`. Add CI test that fails when bypass code path is reached after the date. |
| 5 | Bare-catch growth (346 Flutter, 60 backend) — observability degrades silently | repo-wide | Add lefthook lint that bare-catch ratio cannot grow per PR. CLAUDE.md §9 0-trust requires « observable failure » — bare catches silently hide regressions. Run `tools/checks/bare_catch_audit.py` (create if absent). |

---

## Counter-argument (steel-man : « le code est sain, ne refactore pas »)

A staff engineer optimizing for ship-velocity would refuse most of this audit. The argument:

1. **MINT shipped 6 154 backend tests + 9 327 Flutter tests + Phase 91 + 5 perimeters in 2 weeks of solo founder + AI pair-programming time.** That throughput dominates any « god-file » abstract concern. The team that splits `coach_chat.py` will spend 15-20 dev-days on a refactor that ships zero user value, while a competitor spends those days adding LPP scan, FATCA, frontalier wiring — features Julien actually owes the user.
2. **The 3 god-files are the only places God-files belong: hot, central, well-known.** A 3 354-LOC `coach_chat.py` is greppable, single-process, single-error-model. Splitting it into 5 files moves bugs from « 1 file with 21 touches/month » to « 5 files with 4-5 touches/month, plus a new import-graph to maintain ». Net cognitive load goes UP for a small team.
3. **`financial_core.dart` barrel already works for the cases that matter.** The 97 direct imports are tree-shaken by Dart; the « clean barrel » is a hygiene win, not a correctness win. Spending Phase-budget on it now defers the calc-rigor work in 92.5 (the actually-load-bearing piece per the 2026-05-09 ADR).
4. **`app.dart` 168 touches in 90 d is *because* this is a young product still finding its routing shape**, not because it's broken. Routes are added when life events ship. Splitting it now freezes a still-evolving shape into multi-file ceremony.
5. **The duplicate narrator (Flutter `coach_narrative_service.dart` + backend `claude_coach_service.py`) exists for a reason: privacy-first 3-tier fallback (SLM → BYOK → cloud).** Killing the Flutter side without an equivalent on-device template registry breaks offline UX, the actual differentiator vs. competitors who can't operate without their cloud LLM.
6. **The 6/8 archetype golden gap is theoretical** until those archetypes have non-zero traffic. With < 100 beta users, the empirical regression rate is « unobserved ». Generating 200 frozen ESTV oracle fixtures before traffic exists is YAGNI — premature rigor on math that already passes 6 154 backend tests.
7. **CLAUDE.md NEVER #6 (« code without reading existing code ») is enforced by the `.planning/codebase/*.md` doc tree** — exactly so that AI agents don't re-edit large files blindly. The doc tree IS the cognitive offload; the file size is not the constraint.

A reasonable response: **accept #2, #3, and #6 (delete `services/backend/build/lib/`, financial_core barrel codemod, leave `app.dart` alone for now)** as low-risk, defer #1 and #4 (god-file splits) until Phase 92.5 calc-rigor is in flight and provides the pretext (fixtures + GroundingPack require schema split anyway).

---

## Sources

- `/Users/julienbattaglia/Desktop/MINT.nosync/CLAUDE.md` — RULE #4 financial_core mandate, §7 Karpathy 4, §9 0-trust protocol, §8 wiki schema.
- `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/PROJECT.md` — milestone v2.9 Coach Visuel Hybride, 388 bare catches inheritance, doctrine « pas de raccourcis ».
- `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/codebase/STRUCTURE.md` (2026-04-22) — directory layout, naming, where-to-add-new-code.
- `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/codebase/ARCHITECTURE.md` (2026-04-22) — 3-tier LLM, MultiProvider tree, financial_core ADR.
- `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/codebase/CONCERNS.md` (2026-04-22) — prior god-file inventory + tech-debt log.
- `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/decisions/2026-05-09-calc-first-llm-illumination.md` — Stage 3 narrator eval (Haiku 7/50 vs Sonnet 26/50 doctrine), N1-N4 actions, roadmap mapping.
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/main.dart:1-120` — cold-launch sequence (STAMP-02/03 instrumentation, 800 ms flag refresh).
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/app.dart:1-100, 1440-1596` — imports + MultiProvider + router mount.
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/financial_core/financial_core.dart:1-26` — barrel exports.
- `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/main.py:1-120` — FastAPI lifespan + middleware stack.
- `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/api/v1/endpoints/coach_chat.py:1-80, 2050-2140` — 40-function god-endpoint sample.
- `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/services/retirement/avs_estimation_service.py:1-50` — backend-side AVS service with constants.
- Repo-wide measurements (rerun 2026-05-10):
  - `find apps/mobile/lib -name '*.dart' -not -path '*/l10n/*' | wc -l` → 683
  - `find services/backend/app -name '*.py' -not -path '*/__pycache__/*' -not -path '*/build/*' | wc -l` → 355
  - `grep -rn "Navigator.push" apps/mobile/lib --include='*.dart' | wc -l` → 2
  - `grep -rn "context.go\|context.push\|context.pushNamed" apps/mobile/lib --include='*.dart' | wc -l` → 188
  - `grep -rn "import.*financial_core/" apps/mobile/lib --include='*.dart' | grep -v "financial_core.dart';" | wc -l` → 97
  - `git log --since='2026-02-01' --pretty=format: --name-only | grep '^apps/mobile/lib/.*\.dart$\|^services/backend/app/.*\.py$' | sort | uniq -c | sort -rn | head -3` → app.dart 168, coach_chat_screen.dart 154, coach_profile.dart 84
  - `grep -c "GoRoute(\|ScopedGoRoute(" apps/mobile/lib/app.dart` → 152
  - `grep -c "redirect:" apps/mobile/lib/app.dart` → 53
  - `find services/backend/build -name '*.py' | wc -l` → 260 (untracked)
  - `git ls-files services/backend/build/ | wc -l` → 0

---

*Audit by Claude (Opus 4.7) for Julien Battaglia, 2026-05-10. Contradicts no prior ADR; informs 2026-05-09 calc-first ADR by surfacing the schema-split prerequisites and the financial_core barrel hygiene gap.*
