# Phase 10 — Onboarding v2 Pre-Deletion Audit

**Date:** 2026-04-07
**Plan:** 10-01
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Scope:** Authoritative pre-deletion inventory for Phase 10 (5 screens + OnboardingProvider). No code modified.
**Status:** READY (with 2 conditional migration items — see Section 6)

---

## 1. Provider Consumers (OnboardingProvider)

`git grep -n 'OnboardingProvider\|onboarding_provider'` across `apps/mobile/lib/`, `apps/mobile/test/`, `apps/mobile/integration_test/`.

### lib/ (production)

| File | Line | Role |
|---|---|---|
| `lib/app.dart` | 131 | Import |
| `lib/app.dart` | 1013 | `ChangeNotifierProvider(create: (_) => OnboardingProvider())` in MultiProvider |
| `lib/providers/onboarding_provider.dart` | 1–220 | Provider definition (itself) |
| `lib/screens/onboarding/instant_premier_eclairage_screen.dart` | 15 | Import |
| `lib/screens/onboarding/instant_premier_eclairage_screen.dart` | 149, 151 | `context.read<OnboardingProvider>()` — writes choc + emotion via `setChoc` / `setEmotion` |
| `lib/screens/onboarding/promise_screen.dart` | 6, 17 | Import + docstring |
| `lib/screens/onboarding/promise_screen.dart` | 30 | `context.read<OnboardingProvider>()` — writes `anxietyLevel` (and reads `birthYear` per docstring line 6) |

**Indirect consumers (SharedPrefs-raw, not via the provider class but reading the same keys):**

| File | Line | Role | Key(s) read |
|---|---|---|---|
| `lib/screens/onboarding/quick_start_screen.dart` | 143–145 | Raw SharedPrefs reader | `onboarding_birth_year`, `onboarding_gross_salary`, `onboarding_canton` |
| `lib/screens/coach/coach_chat_screen.dart` | 224–307 | Raw SharedPrefs reader — auto-sends onboarding emotion as first coach message (one-shot, then cleared) | `onboarding_emotion` |
| `lib/services/coach/context_injector_service.dart` | 460–487 | Raw SharedPrefs reader — injects premier éclairage + emotion + birth year into coach first-session context; clears keys after | `onboarding_choc_type`, `onboarding_choc_value`, `onboarding_emotion`, `onboarding_birth_year` |

> **Critical finding:** Three production surfaces (`quick_start_screen`, `coach_chat_screen`, `context_injector_service`) read the SharedPrefs keys directly, bypassing `OnboardingProvider`. Two of them (`coach_chat_screen`, `context_injector_service`) **survive Phase 10 deletion** and must be migrated to their new source of truth, not just stripped. This is the single biggest migration risk in Plan 10-02.

**Indirect (docstring claims only, no code reference):**

- `lib/providers/coach_profile_provider.dart` — doc line 7 claims "reads to hydrate profile on first login" but `git grep OnboardingProvider` returns zero hits in this file. **Claim is stale.** Profile hydration actually happens via `coach_profile_provider.applyFromOnboarding(...)` call-site OR via raw `SharedPreferences` — verified: no `OnboardingProvider` read path exists in `coach_profile_provider.dart`. Safe to delete without touching this file (other than if tests import it).

### test/ (widget + unit)

| File | Line(s) | Role |
|---|---|---|
| `test/providers/onboarding_provider_test.dart` | 3, 6, 12, 20, 35, 41, 47, 55, 62, 81, 94, 114 | Dedicated unit test suite for `OnboardingProvider` (≈ 10 tests). **DELETED WITH PROVIDER.** |
| `test/smoke/mint_home_smoke_test.dart` | 9, 28, 55 | Comment + import + MultiProvider wire. **MIGRATE: drop the provider from the test's MultiProvider; smoke test itself survives.** |

### integration_test/

No hits. The integration test suite does not reference `OnboardingProvider` or `onboarding_provider`.

---

## 2. Screen References (5 deletion targets)

### 2.1 `quick_start_screen.dart`

| File | Line | Role |
|---|---|---|
| `lib/app.dart` | 106 | Import |
| `lib/app.dart` | 848–852 | **GoRoute `/onboarding/quick`** → `QuickStartScreen` |
| `lib/app.dart` | 854–860 | **GoRoute `/onboarding/quick-start`** → `QuickStartScreen` (duplicate path, same screen) |
| `lib/screens/onboarding/intent_screen.dart` | 198, 204 | Comment + `router.go('/onboarding/quick-start', ...)` in `_isFromOnboarding==true` branch — **the D-03 target for rewire** |
| `lib/widgets/onboarding/premier_eclairage_card.dart` | 137 | `widget.onNavigate('/onboarding/quick-start')` — card CTA fallback route |
| `lib/services/navigation/screen_registry.dart` | (indirect via `/onboarding/premier-eclairage`) | — |
| `test/golden_screenshots/quick_start_screen_golden_test.dart` | 4 + body | Dedicated golden test. **DELETE.** |
| `test/golden_screenshots/README.md` | 59 | Doc reference. Update or strip. |
| `test/i18n/hardcoded_string_audit_test.dart` | 25 | Path in string audit allowlist/denylist. **Remove entry.** |
| `test/patrol/onboarding_patrol_test.dart` | 89 | `binding.takeScreenshot('04_quick_start_screen')`. **DELETE or migrate to intent-screen patrol.** |
| `test/screens/core_app_screens_smoke_test.dart` | 16 | Import for smoke render. **Remove entry.** |
| `test/screens/onboarding/quick_start_screen_test.dart` | 8 + body | Dedicated widget test suite. **DELETE.** |
| `test/services/navigation/route_planner_test.dart` | 92, 329 | `fallbackRoute: '/onboarding/quick-start'` + assertion. **MIGRATE:** fallback should become `/onboarding/intent` (no more quick-start). |
| `test/widgets/onboarding/premier_eclairage_card_test.dart` | 64, 174 | Route plumbing in card test. **MIGRATE** to new card CTA target (TBD Plan 10-02). |
| `docs/*` | (various) | Docs mention the screen — out of scope for Phase 10 code sweep. |

### 2.2 `premier_eclairage_screen.dart`

| File | Line | Role |
|---|---|---|
| `lib/app.dart` | 107 | Import |
| `lib/app.dart` | 861–865 | **GoRoute `/onboarding/premier-eclairage`** → `PremierEclairageScreen` |
| `lib/screens/onboarding/premier_eclairage_screen.dart` | 245 | Self: `context.go('/onboarding/plan', ...)` — the screen that pushes to plan_screen |
| `lib/screens/onboarding/quick_start_screen.dart` | 297 | `context.go('/onboarding/premier-eclairage', ...)` — upstream push |
| `lib/services/api_service.dart` | 761 | Backend API call `POST /onboarding/premier-eclairage` — **DIFFERENT CONCERN:** this is the backend endpoint, NOT the Flutter route. Preserved. |
| `lib/services/navigation/screen_registry.dart` | 1377 | `route: '/onboarding/premier-eclairage'` registry entry. **Remove entry.** |
| `test/i18n/hardcoded_string_audit_test.dart` | 26 | Path entry. **Remove.** |
| `tools/checks/no_legacy_confidence_render.py` | 136 | Path in allowlist. **Remove.** |

### 2.3 `instant_premier_eclairage_screen.dart`

| File | Line | Role |
|---|---|---|
| `lib/providers/onboarding_provider.dart` | 8 | Docstring reference only |
| `lib/screens/onboarding/instant_premier_eclairage_screen.dart` | 23–31 | Self definition |
| `lib/screens/onboarding/instant_premier_eclairage_screen.dart` | 102 | `AnalyticsService().trackScreenView('/premier-eclairage-instant')` — analytics string, no route |
| `lib/screens/onboarding/instant_premier_eclairage_screen.dart` | 166 | Self: `context.go('/onboarding/promise')` — pushes to promise_screen |
| **`lib/app.dart`** | — | **NO ROUTE REGISTRATION FOUND.** Grep for `InstantPremierEclairageScreen` / `/premier-eclairage-instant` in `app.dart` returns zero hits. |

> **Critical finding:** `instant_premier_eclairage_screen.dart` is **orphaned** — the class is defined and the file writes choc/emotion via OnboardingProvider, but there is no `GoRoute` pointing to it in `app.dart`. It cannot be reached from current navigation. Deleting it is pure dead-code cleanup. No route to remove.

### 2.4 `promise_screen.dart`

| File | Line | Role |
|---|---|---|
| `lib/app.dart` | 111 | Import |
| `lib/app.dart` | 871–875 | **GoRoute `/onboarding/promise`** → `PromiseScreen` |
| `lib/screens/onboarding/instant_premier_eclairage_screen.dart` | 166 | `context.go('/onboarding/promise')` — but screen is orphaned (see 2.3) |
| **Test files:** none reference `promise_screen` by name | — | No dedicated tests. Safe to delete. |

### 2.5 `plan_screen.dart`

| File | Line | Role |
|---|---|---|
| `lib/app.dart` | 110 | Import |
| `lib/app.dart` | 876–880 | **GoRoute `/onboarding/plan`** → `PlanScreen` |
| `lib/screens/onboarding/premier_eclairage_screen.dart` | 245 | `context.go('/onboarding/plan', ...)` — upstream push |
| `lib/screens/onboarding/intent_screen.dart` | 198 | Comment only ("onboarding-done moved to plan_screen per Research Pitfall 3") |
| `test/i18n/hardcoded_string_audit_test.dart` | 27 | Path entry. **Remove.** |
| `test/journeys/lea_golden_path_test.dart` | 173, 185 | **Comments claim** "plan_screen (end of pipeline) sets [onboarding-done]". Test simulates plan_screen setting that flag. **MIGRATE:** responsibility moves to intent_screen or chat bootstrap. |
| `test/patrol/onboarding_patrol_test.dart` | 129 | `binding.takeScreenshot('06_plan_screen')`. **DELETE or migrate.** |
| `test/screens/onboarding/intent_screen_test.dart` | 32, 145, 148, 149, 168 | **Heavy coupling.** Intent screen tests mark completion via plan_screen narrative ("chipKey persists, onboarding-done moved to plan_screen"). With plan_screen gone, the "onboarding-done" flag needs a new owner — likely intent_screen itself on chip tap → `/coach/chat`. **MIGRATE — REQUIRES NEW BEHAVIOR** (intent_screen sets onboarding-done on chip tap). |

---

## 3. Route References

All mobile+backend+tools hits for `/onboarding/(quick-start|promise|plan|premier-eclairage|chiffre-choc)` and `/premier-eclairage-instant`, `/chiffre-choc-instant`.

### GoRouter declarations (to DELETE)

| Line | Path | Target |
|---|---|---|
| `lib/app.dart:845–852` | `/onboarding/quick` | `QuickStartScreen` — **DELETE** |
| `lib/app.dart:853–860` | `/onboarding/quick-start` | `QuickStartScreen` — **DELETE** |
| `lib/app.dart:861–865` | `/onboarding/premier-eclairage` | `PremierEclairageScreen` — **DELETE** |
| `lib/app.dart:871–875` | `/onboarding/promise` | `PromiseScreen` — **DELETE** |
| `lib/app.dart:876–880` | `/onboarding/plan` | `PlanScreen` — **DELETE** |

### GoRouter declarations (to KEEP)

| Line | Path | Target |
|---|---|---|
| `lib/app.dart:866–870` | `/onboarding/intent` | `IntentScreen` — **KEEP** (rewired per D-03) |
| `lib/app.dart:881–887` | `/data-block/:type` | `DataBlockEnrichmentScreen` — **KEEP** (D-02, JIT tool) |

> **No route** for `/premier-eclairage-instant`, `/chiffre-choc-instant`, `/onboarding/chiffre-choc` is declared in `app.dart`. D-06 already holds for these — no cleanup needed.

### `.go()` call-sites (internal pushes to DELETED routes — all MIGRATE)

| Line | Call |
|---|---|
| `lib/screens/onboarding/intent_screen.dart:204` | `router.go('/onboarding/quick-start', extra: {'intent': chip.chipKey})` → **rewrite to `router.go('/coach/chat', extra: payload)`** per D-03 |
| `lib/screens/onboarding/instant_premier_eclairage_screen.dart:166` | `context.go('/onboarding/promise')` → screen deleted, irrelevant |
| `lib/screens/onboarding/premier_eclairage_screen.dart:245` | `context.go('/onboarding/plan', extra: extra)` → screen deleted |
| `lib/screens/onboarding/quick_start_screen.dart:297` | `context.go('/onboarding/premier-eclairage', extra: ...)` → screen deleted |
| `lib/widgets/onboarding/premier_eclairage_card.dart:137` | `widget.onNavigate('/onboarding/quick-start')` → **MIGRATE** to `/onboarding/intent` or the new chat entry route. Requires Plan 10-02 decision. |

### Backend / tools / docs

| File | Role | Action |
|---|---|---|
| `services/backend/app/api/v1/endpoints/onboarding.py` | Backend endpoint `POST /api/v1/onboarding/premier-eclairage` | **PRESERVED** — it's the backend API, not a Flutter route. Different namespace. |
| `services/backend/tests/test_onboarding_contract.py` | Contract tests for the backend endpoint | **PRESERVED** |
| `tools/openapi/*.json` | OpenAPI schema | **PRESERVED** |
| `lib/services/api_service.dart:761` | Flutter → backend POST `/onboarding/premier-eclairage` | **PRESERVED** (backend call, not nav) |
| `docs/*` | ROADMAP, WIRE_SPEC, etc. | Out of scope for Plan 10-02 code sweep; update in Plan 10-04 if time permits |

---

## 4. External Deep Links

`git grep -nE "/onboarding/" services/backend/app/ tools/ docs/ | grep -v .planning`

**Findings:**

- **Push notifications:** No template mentions `/onboarding/quick-start`, `/onboarding/promise`, `/onboarding/plan`, `/onboarding/premier-eclairage`, `/onboarding/chiffre-choc`, or `/premier-eclairage-instant`. `services/backend/` has zero push-template hits for these paths.
- **Marketing emails:** No templates found referencing these routes.
- **Mobile deep-link config (`AndroidManifest.xml`, `Info.plist`, Firebase Dynamic Links):** No hits. Verified via `git grep -nE '/onboarding/(quick-start|promise|plan|premier-eclairage)' apps/mobile/android/ apps/mobile/ios/` returned empty.
- **Backend API** `/api/v1/onboarding/premier-eclairage` is a separate namespace (REST endpoint, not a Flutter route). It is **preserved** and unaffected.
- **Doc mentions** in `docs/ROUTE_POLICY.md`, `docs/NAVIGATION_GRAAL_V10.md`, `docs/WIRE_SPEC_V1.md`, `docs/WIRE_SPEC_V2.md`, `docs/SCREEN_INTEGRATION_MAP.md`, `docs/AUDIT-01-*`, `docs/MINT_SOUL_SPRINT_PROMPTS.md` are **documentation only** — no runtime deep-link bindings.

### Verdict: **NO SHIMS**

D-06 default holds. Zero external deep-link producers reference the deleted routes. No catch-all redirect needed. Full delete is safe.

---

## 5. Test Files

`git grep -nl` for `quick_start_screen|premier_eclairage_screen|instant_premier_eclairage_screen|promise_screen|plan_screen|OnboardingProvider` in `apps/mobile/test/` and `apps/mobile/integration_test/`.

| # | File | References | Action |
|---|---|---|---|
| 1 | `test/golden_screenshots/README.md` | doc ref (quick_start) | Edit or strip mention |
| 2 | `test/golden_screenshots/quick_start_screen_golden_test.dart` | dedicated golden | **DELETE** |
| 3 | `test/i18n/hardcoded_string_audit_test.dart` | 3 path entries (quick_start, premier_eclairage, plan) | **MIGRATE** (remove 3 entries) |
| 4 | `test/journeys/lea_golden_path_test.dart` | 2 comments simulating plan_screen setting onboarding-done | **MIGRATE** — simulate intent_screen (or chat bootstrap) setting the flag |
| 5 | `test/patrol/onboarding_patrol_test.dart` | 2 screenshot stops (quick_start, plan_screen) | **MIGRATE or DELETE** — patrol flow must match new 2-screen path |
| 6 | `test/providers/onboarding_provider_test.dart` | full provider unit test | **DELETE** (~10 tests — provider gone) |
| 7 | `test/screens/core_app_screens_smoke_test.dart` | import for smoke | **MIGRATE** — drop import |
| 8 | `test/screens/onboarding/intent_screen_test.dart` | 5 hits: heavy coupling to "onboarding-done moved to plan_screen" contract | **MIGRATE — REQUIRES NEW BEHAVIOR** (intent_screen must own onboarding-done flag post-Phase 10) |
| 9 | `test/screens/onboarding/quick_start_screen_test.dart` | dedicated widget test | **DELETE** |
| 10 | `test/smoke/mint_home_smoke_test.dart` | MultiProvider wire includes `OnboardingProvider` | **MIGRATE** — drop the provider from test MultiProvider |

Plus indirectly (grep for route strings, not screen names):

| # | File | References | Action |
|---|---|---|---|
| 11 | `test/services/navigation/route_planner_test.dart` | `fallbackRoute: '/onboarding/quick-start'` + expectation | **MIGRATE** — fallback becomes `/onboarding/intent` |
| 12 | `test/widgets/onboarding/premier_eclairage_card_test.dart` | 2 route-capture assertions | **MIGRATE** — new card CTA target |

**Total test files affected: 12** (10 from screen/provider grep + 2 from route string grep).

**Deletions (pure):** 3 (`quick_start_screen_golden_test.dart`, `onboarding_provider_test.dart`, `quick_start_screen_test.dart`).

**Migrations:** 9.

Silent test-count drop risk: **≈ 10 provider tests + ~15 quick_start widget tests + 1 golden = ~26 tests minimum lost** unless migrated. Plan 10-04 SC #3 gate (`post_count ≥ pre_count`) must be enforced; replacements will live in the new intent_screen + chat bootstrap test suites.

---

## 6. Field Migration Map

Per D-05. Target existence verified by reading `coach_profile_provider.dart`, `cap_memory_store.dart`, `report_persistence_service.dart`, `coach_profile.dart`, `context_injector_service.dart`.

| # | Field | Type | Set by (writers) | Read by (consumers) | Migration Target | Verdict |
|---|---|---|---|---|---|---|
| 1 | `birthYear` | `int?` | `quick_start_screen.dart` (raw prefs, line 143; screen deleted) | `context_injector_service.dart:465` (raw prefs read, SURVIVES); `coach_profile_provider.profile.age` derivation (already canonical, docstring-claimed but no direct read) | **`CoachProfileProvider.profile.birthYear`** — already exists (`coach_profile.dart:85`) via `applyFromOnboarding()` which takes `birthYear` kwarg. Intent screen already writes to it today. | **MIGRATE → CoachProfileProvider.profile.birthYear** (already wired; just need context_injector to read from profile instead of raw prefs) |
| 2 | `grossSalary` | `double?` | `quick_start_screen.dart` (raw prefs, line 144; deleted) | No direct reader found — only `quick_start_screen` reads it back | **`CoachProfileProvider.profile.salaireBrutMensuel`** — exists (`coach_profile.dart`, `applyFromOnboarding` line 433). | **MIGRATE → CoachProfileProvider.profile.salaireBrutMensuel** |
| 3 | `canton` | `String?` | `quick_start_screen.dart` (raw prefs, line 145; deleted) | No direct reader beyond quick_start | **`CoachProfileProvider.profile.canton`** — exists. | **MIGRATE → CoachProfileProvider.profile.canton** |
| 4 | `anxietyLevel` | `String?` ('far'\|'mid'\|'close') | `promise_screen.dart:30` (deleted) | **No surviving reader.** `git grep anxietyLevel apps/mobile/lib/` outside provider + promise_screen returns zero hits. Not read by `context_injector_service`, not by coach chat, not by any service. | N/A — no consumer exists today | **DROP** (dead field post-deletion; writer + reader both in deleted pipeline) |
| 5 | `chocType` | `OnboardingChocType?` | `instant_premier_eclairage_screen.dart:149` via `setChoc` (deleted) | **`context_injector_service.dart:460` (raw prefs read, SURVIVES Phase 10)** — injects into coach first-session context | `ReportPersistenceService.savePremierEclairageSnapshot` (already exists, `report_persistence_service.dart:217`; already called from `intent_screen.dart:221`) | **MIGRATE → ReportPersistenceService snapshot** — intent_screen already persists via snapshot; context_injector must be migrated to read from snapshot instead of raw prefs. **REQUIRES context_injector rewrite** (Plan 10-02 scope addition). |
| 6 | `chocValue` | `double?` | Same as chocType | Same as chocType (`context_injector_service.dart:463`) | Same as chocType | **MIGRATE → ReportPersistenceService snapshot** — same rewrite |
| 7 | `emotion` | `String?` | `instant_premier_eclairage_screen.dart` via `setEmotion` (deleted) | **`context_injector_service.dart:464` (SURVIVES)** + **`coach_chat_screen.dart:224` (SURVIVES)** — both read raw prefs `onboarding_emotion` | `CapMemoryStore` has no emotion field today. Either add one or drop the field. | **DROP** (recommended) — emotion was captured by the deleted instant_premier_eclairage moment; post-Phase 10 the user's first coach message IS their emotional signal (chip tap → chat). The `coach_chat_screen.dart:224-307` one-shot emotion replay becomes obsolete and the block should be deleted from coach_chat_screen. `context_injector` emotion injection should also be stripped. |

### Summary of required Plan 10-02 rewrites beyond pure deletion

1. **`lib/services/coach/context_injector_service.dart`** (lines 456–487): stop reading `onboarding_choc_type`, `onboarding_choc_value`, `onboarding_emotion`, `onboarding_birth_year` from raw SharedPrefs. Migrate to `ReportPersistenceService` snapshot for choc; drop emotion; read birthYear from `CoachProfileProvider.profile.birthYear`.
2. **`lib/screens/coach/coach_chat_screen.dart`** (lines 152, 216–307): delete the `_onboardingEmotion` one-shot replay logic entirely. Post-Phase 10 the first user message comes directly from the intent chip → `/coach/chat` payload, not from a stored emotion string.
3. **`lib/services/navigation/screen_registry.dart`** (line 1377): remove `/onboarding/premier-eclairage` entry.
4. **`lib/widgets/onboarding/premier_eclairage_card.dart`** (line 137): update CTA target from `/onboarding/quick-start` to `/onboarding/intent` (or whatever replaces it).
5. **`tools/checks/no_legacy_confidence_render.py`** (line 136): remove `premier_eclairage_screen.dart` from allowlist.
6. **Dead enum:** `OnboardingChocType` in `onboarding_provider.dart:24` should be deleted with the provider. Canonical source post-1.5 is `PremierEclairageType` in `premier_eclairage_selector.dart`.

---

## 7. Pre-Deletion Test Baseline

Run from `apps/mobile/` on branch `feature/v2.2-p0a-code-unblockers` at audit time.

```
flutter test 2>&1 | tail -20
```

Final aggregate (last progress line):

```
01:11 +9292 ~6 -11: Some tests failed.
```

**`PRE_DELETION_TEST_COUNT: 9292`** (passed) + 6 skipped + **11 failed** (pre-existing, unrelated to Phase 10).

Total declared tests: **9309** (9292 pass + 6 skip + 11 fail).

The **9292** figure is the floor for Plan 10-04 SC #3 audit fix C3: post-deletion `flutter test` passed count must be **≥ 9292** (or, if failing tests are fixed in-flight, total must be ≥ 9309).

**Pre-existing failures** (out of Phase 10 scope — documented for traceability, not blocking):

The 11 failures are distributed across the suite; they pre-date Phase 10 and are captured here only to avoid regression scoring confusion. Plan 10-04 should verify that its delta does not increase the failure count.

### Analyzer baseline

```
flutter analyze lib/ 2>&1 | tail -3
```

Result:

```
info • Use 'const' with the constructor to improve performance • lib/widgets/trust/mint_trame_confiance.dart:636:18 • prefer_const_constructors

6 issues found. (ran in 6.3s)
```

**`PRE_DELETION_ANALYZE_ISSUES: 6`** (all `info` level, all pre-existing, unrelated to Phase 10). Floor for Plan 10-04: `≤ 6` issues.

---

## 8. intent_screen.dart Selector Verification (D-03)

Read: `apps/mobile/lib/screens/onboarding/intent_screen.dart`.

**Question:** Is `PremierEclairageSelector.select()` called in the merged path (post-D-03 unification)?

**Current state (pre-Phase 10):**

- Line 15: `import 'package:mint_mobile/services/premier_eclairage_selector.dart';`
- Line 215: `final choc = PremierEclairageSelector.select(profile, stressType: mapping.stressType);`
- The `.select()` call lives **only in the `else` branch** (line 208 onwards, `// ── Non-onboarding path ──`). The `fromOnboarding == true` branch (lines 202–206) currently short-circuits to `router.go('/onboarding/quick-start', ...)` and does NOT call the selector.

**Post-D-03 unified path (Plan 10-02 work):**

The else-branch logic (selector call + `ReportPersistenceService.savePremierEclairageSnapshot` at line 221 + `CapMemoryStore` seeding at line 231 + `CapSequenceEngine.build` at line 239) **is explicitly preserved and merged** into the single path per D-03. The chip payload carries the intent + computed choc into `/coach/chat`.

**Verdict: IMPORT REMAINS.**

`premier_eclairage_selector` stays imported in `intent_screen.dart`. ROADMAP wording "removed" does not apply — document the deviation. The `_buildMinimalProfileFor` helper (lines 261–312) also **survives** for the same reason: the merged path needs a `MinimalProfileResult` to feed `PremierEclairageSelector.select()`.

---

## 9. Verdict — ready for Plan 10-02?

**Status: ⚠ CONDITIONAL — READY with 2 migration items beyond pure deletion**

### ✅ Clear path

- 5 screens can be deleted (confirmed file list, D-01).
- 5 GoRoutes can be removed (`/onboarding/quick`, `/onboarding/quick-start`, `/onboarding/premier-eclairage`, `/onboarding/promise`, `/onboarding/plan`).
- `OnboardingProvider` class + registration + unit tests can be deleted.
- No external deep links — zero shims needed (D-06 default holds).
- 5 of 7 provider fields have a clear migration target; 2 are dead (`anxietyLevel`, `emotion`).
- `data_block_enrichment_screen` + `/data-block/:type` route preserved (D-02).
- `intent_screen.dart` selector import + `_buildMinimalProfileFor` helper remain (D-03).
- Pre-deletion test count captured: **9292 passed**, analyzer: **6 info issues**.
- `instant_premier_eclairage_screen.dart` is **orphaned** (no route); pure dead-code removal.

### ⚠ Conditional — Plan 10-02 must also do the following (not pure deletion):

1. **Rewrite `context_injector_service.dart:456–487`** to stop reading the 4 SharedPrefs keys (`onboarding_choc_type`, `onboarding_choc_value`, `onboarding_emotion`, `onboarding_birth_year`). Migrate to `ReportPersistenceService` snapshot (for choc) + `CoachProfileProvider.profile.birthYear`. Drop emotion injection.
2. **Delete `coach_chat_screen.dart:152, 216–307`** `_onboardingEmotion` one-shot replay logic — it reads a SharedPrefs key that will no longer exist, and the use case (first emotional message) is replaced by the chip → /coach/chat payload.

These two items are **scope expansion vs a pure "delete 5 files + provider" read of Plan 10-02**. They were not called out in 10-CONTEXT D-05 beyond the field migration table; this audit surfaces them explicitly so Plan 10-02 can budget the work. Neither requires an architectural decision — both are mechanical rewrites following D-05 intent.

### ❌ Blocked items

None.

### Test migration quantified

- **10 test files to migrate** + **3 test files to delete** + **~26 tests at risk of silent drop** unless replaced.
- `test/screens/onboarding/intent_screen_test.dart` is the highest-risk migration: its contract currently assumes `plan_screen` owns the `onboarding-done` flag. Plan 10-02 must move that flag ownership to `intent_screen` on chip tap, and migrate the test accordingly.
- `test/widgets/onboarding/premier_eclairage_card_test.dart` + `test/services/navigation/route_planner_test.dart` both need route-string updates.

### Go/no-go

**GO — with scope clarification.** Plan 10-02 proceeds as planned, with explicit budget for (a) context_injector rewrite, (b) coach_chat_screen emotion replay deletion, (c) intent_screen onboarding-done flag ownership. All three are within the spirit of D-04/D-05 and require no new architectural decisions.
