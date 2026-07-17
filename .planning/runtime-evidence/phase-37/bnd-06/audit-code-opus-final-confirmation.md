## MINT External Auditor — Code Audit

**Scope:** diff `e7ef9a3cd..HEAD` on `codex/mint-product-usability-plan-20260712` (515 lines, within 4000 budget). Two production changes plus test/harness hardening for the G1 BND-06 financial-plan staleness runtime proof.

### Verification performed

**Production change 1 — `landing_screen.dart:86`** `home_route` → `landing_route`
- Confirmed the old id is now only in `aujourdhui_screen.dart:50` (production home) and the test. Grep for `home_route` across `lib/` shows no other consumer relied on `LandingScreen` carrying it.
- Routing is consistent: `app.dart:433` maps `/` → `LandingScreen` (landing_route); `/home` (`app.dart:486`) gates to `AujourdhuiScreen` (home_route). The Maestro barrier (launch→`landing_route`, then `openLink mint:///home`→`home_route`) matches real routing and correctly disambiguates the startup screen from home. `home_route_semantics_test.dart` updated to lock both invariants.

**Production change 2 — `financial_plan_setup_card.dart:186-190`** amount-parse fallback
- Adds `double.tryParse(normalizedAmount.replaceAll(',', '.'))` only when localized parse returns null. This is the "accept persisted plan amount format" fix: `initState` seeds the field via `initialAmount.toString()` ("54321.0"), which `NumberFormat.decimalPattern('fr')` rejects. Fallback is reached only on localized-parse failure. Correct.

**Facade-without-wiring check — PASS**
- `financialPlanSetupEnabled` is `bool.fromEnvironment('MINT_TEST_FINANCIAL_PLAN_SETUP', defaultValue: false)` (`feature_flags.dart:77`), fail-closed and deliberately absent from `applyFromMap`, so the backend cannot activate the unfinished path.
- The flag genuinely gates behavior: `app.dart:1927`/`2131`, `widget_renderer.dart:74`, `aujourdhui_screen.dart:93/127`.
- Every Maestro/Patrol id referenced (`financial_plan_setup_retirement_horizon/continue/review/confirmation/confirm`) exists in `financial_plan_setup_card.dart:706/786/851/903/1133`, and the no-LPP branch correctly hides `_retirement_scope`/`_return_assumption` (card:718), matching the Python gate assertions that those ids are absent from the reader/flow. Wiring is real (horizon checkbox toggles `_horizonAcknowledged`, card:710-712).

**Privacy/compliance:** unchanged posture. Patrol/orchestrator changes remain synthetic-data-only; sanitizer + `verify_retained_artifacts` guards intact; `MINT_META_TEST_OPT_IN_*` metadata honestly discloses the test flag.

### Findings

**P0:** none.

**P1:** none.

**P2 (non-blocking):**
1. `financial_plan_setup_card.dart:190` — the `replaceAll(',', '.')` fallback could misread a thousands-grouping comma as a decimal in a grouping-comma locale *if* the localized parse unexpectedly fails first. Low likelihood (fallback is null-path only) and mitigated by prior stripping of spaces/apostrophes; worth a comment noting it is a persisted-format ("54321.0") escape hatch, not a general input parser.
2. `patrol_bnd06_financial_plan_process_death.sh:797` — the "production install" stage builds the exact archive with `--dart-define=MINT_TEST_FINANCIAL_PLAN_SETUP=true`, so the installed binary is not the shipping default. This is honestly labeled in `mode`/`test_compile_time_opt_in` metadata and gated to `exact_archive_production_entrypoint_debug_build_only`, so it is disclosure-adequate — noting only that the proof exercises a test-flagged build, not the default-off configuration.

### Verdict

**PASS** — Both production changes are correct and fully wired; the feature stays fail-closed and non-server-drivable; routing and semantic ids are consistent; tests exercise real code paths (no facade). P2 items are cosmetic/documentation-level and non-blocking.
