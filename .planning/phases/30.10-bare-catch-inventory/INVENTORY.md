# Bare catch inventory — Phase 36 FIX-05 foundation

**Généré :** 2026-04-24 · **Scope :** `apps/mobile/lib/**/*.dart` · **Total :** 342 catches

## Breakdown

| Dimension | Count |
|-----------|------:|
| **Total bare catches** | 342 |
| P0 (core flows) | **201** |
| P1 (best-effort / UX) | **141** |
| P2 (test mocks) | 0 *(scan limited to `lib/`, tests exempted by path)* |
| **Body: empty (silent fail)** | **19** |
| Body: logged only | 106 |
| Body: rethrow | 8 |
| Body: other (partial handling) | 209 |

**Backend :** 0 bare `except:` patterns (déjà propre, GUARD-02 backend pass).

## P0 hot-path classification

Files flagged P0 by path heuristic (auth / coach / mint_state / document_scan / scan / budget / profile / household / api_service / session / persistence / orchestrat / context_injector / narrative / biography / coach_memory).

### Top P0 offenders (≥5 catches)

| # | File | P0 |
|--:|------|---:|
| 1 | `lib/providers/auth_provider.dart` | 21 |
| 2 | `lib/screens/coach/coach_chat_screen.dart` | 18 |
| 3 | `lib/services/coach_narrative_service.dart` | 15 |
| 4 | `lib/screens/document_scan/document_scan_screen.dart` | 12 |
| 5 | `lib/services/coach/coach_orchestrator.dart` | 12 |
| 6 | `lib/services/mint_state_engine.dart` | 12 |
| 7 | `lib/services/report_persistence_service.dart` | 9 |
| 8 | `lib/services/coach/context_injector_service.dart` | 7 |
| 9 | `lib/providers/coach_profile_provider.dart` | 6 |
| 10 | `lib/services/anonymous_session_service.dart` | 6 |
| 11 | `lib/providers/biography_provider.dart` | 5 |
| 12 | `lib/providers/household_provider.dart` | 5 |
| 13 | `lib/screens/budget/budget_screen.dart` | 5 |
| 14 | `lib/screens/coach/retirement_dashboard_screen.dart` | 5 |
| 15 | `lib/services/memory/coach_memory_service.dart` | 5 |

**P0 total top-15 : 143 catches** (71% of P0 total).

## Priority zone : silent failures (19 empty catch bodies)

Ces 19 catches avalent l'exception sans log, sans rethrow, sans Sentry. Ils cachent des bugs. **Priorité P0 absolue pour migration**, même dans les zones classées P1 (une erreur silencieuse dans un simulateur casse quand même l'écran).

### P0 silent-fail (6 — fix first PR)

| File | Line | Context (inferred from file role) |
|------|-----:|-----------------------------------|
| `lib/providers/auth_provider.dart` | 123 | Auth initialization / token refresh |
| `lib/providers/auth_provider.dart` | 207 | Auth state restoration |
| `lib/screens/budget/budget_screen.dart` | 135 | Budget state load |
| `lib/screens/coach/optimisation_decaissement_screen.dart` | 46 | Coach decaissement calc |
| `lib/screens/coach/retirement_dashboard_screen.dart` | 322 | Retirement projection |
| `lib/services/anonymous_session_service.dart` | 66 | Anonymous session init |

### P1 silent-fail (13 — fix batched per FIX-05 plan)

| File | Line |
|------|-----:|
| `lib/screens/arbitrage/rente_vs_capital_screen.dart` | 134 |
| `lib/screens/consumer_credit_screen.dart` | 61 |
| `lib/screens/coverage_check_screen.dart` | 87 |
| `lib/screens/deces_proche_screen.dart` | 63 |
| `lib/screens/gender_gap_screen.dart` | 70 |
| `lib/screens/pillar_3a_deep/real_return_screen.dart` | 70 |
| `lib/screens/pillar_3a_deep/retroactive_3a_screen.dart` | 75 |
| `lib/screens/pillar_3a_deep/retroactive_3a_screen.dart` | 98 |
| `lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart` | 69 |
| `lib/screens/simulator_3a_screen.dart` | 83 |
| `lib/screens/simulator_compound_screen.dart` | 60 |
| `lib/services/document_service.dart` | 1316 |
| `lib/services/local_image_classifier.dart` | 108 |

## Migration strategy (Phase 36 FIX-05)

### Wave order

1. **Wave 1 (P0 silent-fail, 6 catches)** — surgical, adds Sentry.captureException + rethrow on core-flow silent bugs. Low risk, high signal.
2. **Wave 2 (P1 silent-fail, 13 catches)** — simulator/education screens. Similar surgical pattern.
3. **Wave 3+ (P0 non-silent, 195 catches)** — batch 20/PR per file, replace `catch (e)` → `catch (e, st)` with typed handling or `Sentry.captureException(e, stackTrace: st)` + rethrow/graceful fallback.
4. **Wave N (P1 non-silent, 128 catches)** — same pattern, lower priority.

### Enforcement

Phase 34 GUARD-02 (`no_bare_catch.py`) must run on PRs (scope-to-PR, not `--all-files`) BEFORE starting Wave 3 to prevent agents re-introducing bare catches during migration. This is the dependency called out in Phase 36 ROADMAP ("GUARD-02 bare-catch ban must be ACTIVE before Phase 36 FIX-05").

### Success criteria (ROADMAP §36)

- P0 + P1 catches → 0
- P2 test catches exempted (scan didn't find any in `lib/`, clean)
- Each wave ships with regression test per [REQUIREMENTS.md FIX-09](../../REQUIREMENTS.md)

## Data

Machine-readable inventory: `catches.json` (342 entries with `{file, line, var, has_stack, empty, logged, rethrow, class}`).

## Notes

- Path-based heuristic misclassifies rarely (e.g., `timeline_provider` flagged P1, but it's P0 for onboarding completion). Human review should over-classify P1 → P0 on suspicion during migration, never under-classify.
- `document_service.dart:1316` silent-fail in P1 zone is suspicious — DocumentService is on the scan/P0 path. May need P0 reclassification.
- Backend already clean (0 `except:`), so Phase 36 FIX-05 is mobile-only effort.
