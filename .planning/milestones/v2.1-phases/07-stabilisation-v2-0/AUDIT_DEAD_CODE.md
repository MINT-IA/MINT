# AUDIT_DEAD_CODE — Provider / Service consumer audit (STAB-13)

**Generated:** 2026-04-07
**Scope:**
- Every Provider registered in `apps/mobile/lib/app.dart` `MultiProvider`
- Every ChangeNotifier in `apps/mobile/lib/providers/` (whether registered or not)
- Every top-level public service class in `apps/mobile/lib/services/`
**Method:** `grep -rl "<Symbol>" apps/mobile/lib/ | grep -v _test.dart` (+ import-based audit for services). No code modified.
**Verdict legend:**
- **LIVE** — ≥1 non-test consumer reachable from current 3-tab + drawer shell
- **ORPHAN** — consumers exist but none reachable from the current shell
- **DEAD** — zero non-test consumers (or zero consumers at all)

---

## Part A — Providers registered in `app.dart` MultiProvider (lines 978-1014)

| # | Provider | Definition | Non-test consumer count | Verdict | Action |
|---|----------|-----------|-------------------------|---------|--------|
| 1 | AuthProvider | `providers/auth_provider.dart` | 11 | LIVE | KEEP |
| 2 | ProfileProvider | `providers/profile_provider.dart` | 79 | LIVE | KEEP |
| 3 | BudgetProvider | `providers/budget/` (subdir) | 7 | LIVE | KEEP |
| 4 | ByokProvider | `providers/byok_provider.dart` | 9 | LIVE | KEEP |
| 5 | DocumentProvider | `providers/document_provider.dart` | 6 | LIVE | KEEP |
| 6 | SubscriptionProvider | `providers/subscription_provider.dart` | 7 | LIVE | KEEP |
| 7 | HouseholdProvider | `providers/household_provider.dart` | 4 | LIVE | KEEP |
| 8 | CoachProfileProvider | `providers/coach_profile_provider.dart` | 73 | LIVE | KEEP |
| 9 | LocaleProvider | `providers/locale_provider.dart` | 3 | LIVE | KEEP |
| 10 | UserActivityProvider | `providers/user_activity_provider.dart` | 3 | LIVE | KEEP |
| 11 | SlmProvider | `providers/slm_provider.dart` | 5 | LIVE | KEEP |
| 12 | BiographyProvider | `providers/biography_provider.dart` | 6 | LIVE | KEEP |
| 13 | AnticipationProvider | `providers/anticipation_provider.dart` | 4 | LIVE | KEEP |
| 14 | ContextualCardProvider | `providers/contextual_card_provider.dart` | 3 | LIVE | KEEP |

All 14 providers registered in `app.dart` are LIVE.

---

## Part B — Providers NOT registered in `app.dart` MultiProvider (P0 findings)

The following providers exist in `apps/mobile/lib/providers/` and **are consumed from production screens** via `context.watch` / `context.read`, yet **are not registered in the production MultiProvider**. They are registered only inside test helpers (`test/test_helpers.dart`, `test/screens/coach/navigation_shell_test.dart`, `test/screens/core_app_screens_smoke_test.dart`, etc.). In production this raises `ProviderNotFoundException` at runtime — or relies on a try/catch swallow (see `widget_renderer.dart:500-502` and `budget_screen.dart:113`).

| # | Provider | Definition | Production consumers (screen files) | Registered in `app.dart`? | Verdict | Action |
|---|----------|-----------|--------------------------------------|---------------------------|---------|--------|
| B1 | **MintStateProvider** | `providers/mint_state_provider.dart:39` | `mint_home_screen.dart:124,638`, `main_navigation_shell.dart:214,265`, `budget_screen.dart:107`, `profile_screen.dart:755,859` | **NO** — absent from MultiProvider at `app.dart:979-1014` | **BROKEN (runtime crash risk)** | **WIRE** — add `ChangeNotifierProvider(create: (_) => MintStateProvider())` to `app.dart` MultiProvider, then audit each caller to decide whether the current try/catch fallback should remain. |
| B2 | **FinancialPlanProvider** | `providers/financial_plan_provider.dart:23` | `mint_home_screen.dart:298,332`, `widget_renderer.dart:455` (read in `_buildPlanPreviewCard`) | **NO** | **BROKEN (runtime crash risk)** | **WIRE** — add to `app.dart` MultiProvider. The coach tool `generate_financial_plan` (STAB-03) depends on this provider being in scope. |
| B3 | **CoachEntryPayloadProvider** | `providers/coach_entry_payload_provider.dart:14` | `plan_screen.dart:95`, `intent_screen.dart:254`, `main_navigation_shell.dart:147`, `mint_coach_tab.dart:32` | **NO** | **BROKEN (runtime crash risk)** | **WIRE** — add to `app.dart` MultiProvider. Used to hand payloads from onboarding to the coach tab. |
| B4 | **OnboardingProvider** | `providers/onboarding_provider.dart:65` | `promise_screen.dart:30`, `instant_chiffre_choc_screen.dart:149-151` | **NO** | **BROKEN (runtime crash risk)** | **WIRE** — add to `app.dart` MultiProvider. Sole writer for onboarding emotion + birthYear. |

**Evidence for non-registration:** `grep -rn "=> MintStateProvider|=> FinancialPlanProvider|=> CoachEntryPayloadProvider|=> OnboardingProvider" apps/mobile/lib/` returns **zero** matches (all matches are in `apps/mobile/test/`).

This is the single biggest "façade sans câblage" finding of Phase 7: the production app has 4 providers wired only in tests. Tests pass, production crashes. These 4 rows MUST be fixed in plan 07-04.

---

## Part C — Services in `apps/mobile/lib/services/` (import-based audit)

Method: for each top-level `services/*.dart` file, count non-test files that `import 'services/<name>.dart'` (excluding the file itself). Subdirectory services (`services/coach/`, `services/navigation/`, `services/financial_core/`, etc.) are LIVE by construction and summarized at the end. Only findings with ≤2 non-test consumers are listed; LIVE rows with ≥3 consumers are omitted (see Summary §D for counts).

### C.1 — DEAD services (0 non-test consumers AND 0 test consumers)

| Service | Definition | nontest/total | Verdict | Action |
|---------|-----------|---------------|---------|--------|
| `backend_coach_service.dart` | `services/backend_coach_service.dart` | 0/0 | **DEAD** | DELETE |
| `cap_step_title_resolver.dart` | `services/cap_step_title_resolver.dart` | 0/0 | **DEAD** | DELETE |
| `enhanced_confidence_scorer.dart` | `services/enhanced_confidence_scorer.dart` | 0/0 | **DEAD** | DELETE (note: the active confidence scorer lives in `services/financial_core/confidence_scorer.dart` per CLAUDE.md §2; this standalone file is a leftover) |
| `onboarding_analytics_helper.dart` | `services/onboarding_analytics_helper.dart` | 0/0 | **DEAD** | DELETE |

### C.2 — DEAD-IN-PRODUCTION services (0 non-test consumers, only tested or self-referenced)

| Service | Definition | nontest/total | Verdict | Action |
|---------|-----------|---------------|---------|--------|
| `affiliate_service.dart` | `services/affiliate_service.dart` | 0/1 | **DEAD-IN-PROD** | DELETE or WIRE (if affiliate feature is planned — not in v2.1 scope, so DELETE) |
| `annual_refresh_service.dart` | `services/annual_refresh_service.dart` | 0/1 | **DEAD-IN-PROD** | DELETE or WIRE (annual refresh is a vision feature, v3.0) |
| `check_in_amount_parser.dart` | `services/check_in_amount_parser.dart` | 0/1 | **DEAD-IN-PROD** | WIRE — should be used by `record_check_in` tool flow (STAB-04 fix) OR DELETE if parsing is inlined elsewhere |
| `circle_scoring_service.dart` | `services/circle_scoring_service.dart` | 0/1 | **DEAD-IN-PROD** | DELETE |
| `financial_health_score_service.dart` | `services/financial_health_score_service.dart` | 0/1 | **DEAD-IN-PROD** | DELETE or WIRE — note: confirm this is not the FRI score source before deleting |
| `ocr_sanitizer.dart` | `services/ocr_sanitizer.dart` | 0/1 | **DEAD-IN-PROD** | WIRE into document scan pipeline OR DELETE |
| `pulse_hero_engine.dart` | `services/pulse_hero_engine.dart` | 0/1 | **DEAD-IN-PROD** | DELETE (Pulse feature is not in current shell) |
| `recommendations_service.dart` | `services/recommendations_service.dart` | 0/1 | **DEAD-IN-PROD** | DELETE |
| `retirement_budget_service.dart` | `services/retirement_budget_service.dart` | 0/1 | **DEAD-IN-PROD** | DELETE — overlaps with `retirement_projection_service.dart` (LIVE, 11 consumers) |
| `scenario_narrator_service.dart` | `services/scenario_narrator_service.dart` | 0/1 | **DEAD-IN-PROD** | DELETE |
| `timeline_service.dart` | `services/timeline_service.dart` | 0/1 | **DEAD-IN-PROD** | DELETE |
| `fiscal_intelligence_service.dart` | `services/fiscal_intelligence_service.dart` | 0/2 | **DEAD-IN-PROD** | DELETE — note: `fiscal_service.dart` is LIVE (6 consumers), this is a separate unused file |
| `wizard_conditions_service.dart` | `services/wizard_conditions_service.dart` | 0/2 | **DEAD-IN-PROD** | DELETE — note: `wizard_service.dart` (2 consumers) + `secure_wizard_store.dart` (1 consumer) are wired |

### C.3 — ORPHAN candidates (1-2 non-test consumers, verify reachability)

These have ≤2 production consumers — borderline cases the fix sweep (07-04) should quickly confirm reachable from the 3-tab + drawer shell. If only consumers are archived or legacy screens (see AUDIT_ORPHAN_ROUTES.md), promote to ORPHAN and delete.

| Service | nontest | Status |
|---------|---------|--------|
| `apple_sign_in_service.dart` | 1 | LIKELY LIVE (auth flow) — verify |
| `arbitrage_summary_service.dart` | 1 | verify |
| `bank_import_service.dart` | 1 | LIKELY ORPHAN (bLink is sandbox-only per PROJECT.md) — verify |
| `benchmark_service.dart` | 1 | verify |
| `cantonal_benchmark_service.dart` | 1 | verify |
| `contract_benchmark_service.dart` | 1 | verify |
| `cross_validation_service.dart` | 1 | verify |
| `donation_service.dart` | 1 | LIKELY LIVE (life event) |
| `educational_insert_service.dart` | 1 | verify |
| `financial_report_service.dart` | 1 | verify — used by report? |
| `first_job_service.dart` | 2 | LIVE (life event) |
| `glossary_service.dart` | 1 | verify |
| `household_service.dart` | 1 | verify |
| `housing_sale_service.dart` | 1 | LIVE (life event) |
| `job_comparison_service.dart` | 1 | LIVE (route `/simulator/job-comparison`) |
| `life_events_service.dart` | 1 | LIVE |
| `notification_scheduler_service.dart` | 1 | verify |
| `plan_generation_service.dart` | 1 | LIVE — called from `widget_renderer.dart:_buildPlanPreviewCard` |
| `secure_wizard_store.dart` | 1 | verify |
| `smart_onboarding_draft_service.dart` | 1 | verify |

---

## D — Summary

| Category | Count |
|----------|-------|
| Providers in `app.dart` MultiProvider | 14 (all LIVE) |
| Providers CONSUMED by production screens but NOT registered in `app.dart` | **4 (P0 BROKEN)** |
| Total top-level services in `services/` | ~105 |
| DEAD services (0 consumers) | 4 |
| DEAD-IN-PRODUCTION services (tests-only) | 13 |
| ORPHAN candidates (≤2 non-test consumers, need verification) | ~20 |
| LIVE services (≥3 non-test consumers) | ~68 |

**Fix tasks for plan 07-04:**
1. (P0) Register `MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider` in `app.dart` MultiProvider.
2. (P1) Delete the 4 DEAD services (C.1).
3. (P1) Delete the 13 DEAD-IN-PRODUCTION services (C.2) unless the fix sweep decides to wire them instead (e.g. `check_in_amount_parser` for STAB-04, `ocr_sanitizer` for scan).
4. (P2) Verify the ORPHAN candidates (C.3) against AUDIT_ORPHAN_ROUTES.md and delete unreachable ones.

**Scope caveat:** Service subdirectories (`services/coach/`, `services/navigation/`, `services/financial_core/`, `services/agent/`, `services/anticipation/`, `services/biography/`, `services/benchmark/`, `services/confidence/`, `services/contextual/`, `services/document_parser/`, `services/dach/`, `services/expert/`, `services/factory/`, `services/gamification/`, `services/institutional/`, `services/lifecycle/`, `services/llm/`, `services/memory/`, `services/modules/`, `services/nudge/`, `services/openfinance/`, `services/precision/`, `services/recap/`, `services/report/`, `services/sequence/`, `services/simulators/`, `services/slm/`, `services/voice/`, `services/b2b/`, `services/advisor/`) are NOT enumerated class-by-class here. They are structurally wired through their barrel/entry files (e.g. `financial_core.dart`). A per-class audit of those subdirectories is deferred to plan 07-04 if any specific subsystem shows symptoms during fixes.
