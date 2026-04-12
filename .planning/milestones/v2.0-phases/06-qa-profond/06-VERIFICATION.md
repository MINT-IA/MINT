---
phase: 06-qa-profond
verified: 2026-04-06T20:42:25Z
status: gaps_found
score: 3/5 must-haves verified
gaps:
  - truth: "Golden Screenshots (pixel diff > 1.5% = red in CI) pass on both platforms"
    status: failed
    reason: "No custom GoldenFileComparator with 1.5% tolerance is configured. Flutter's default golden comparator requires exact pixel match (0% diff). The 1.5% threshold is documented only in README.md but never enforced in code. Also, test/golden_screenshots/ is NOT in any CI test shard -- the tests cannot be 'red in CI' if they never run in CI."
    artifacts:
      - path: "apps/mobile/test/golden_screenshots/golden_screenshot_test.dart"
        issue: "Uses matchesGoldenFile() with default exact comparator, not a 1.5%-tolerant GoldenFileComparator. setSurfaceSize() is absent -- phone size simulation only uses kGoldenDeviceSize constant, not two distinct phone sizes as required (iPhone SE 375x667 AND iPhone 15 393x852)."
      - path: ".github/workflows/ci.yml"
        issue: "test/golden_screenshots/ is not in any test_dirs shard. Golden screenshot tests never execute in CI pipeline."
    missing:
      - "Custom TolerantGoldenFileComparator class configured at test setup with threshold=0.015 (1.5%)"
      - "Add test/golden_screenshots/ to CI test shard (screens or dedicated golden shard)"
      - "Capture golden images at both iPhone SE (375x667) and iPhone 15 (393x852) using tester.binding.setSurfaceSize()"

  - truth: "Patrol integration tests (iOS 17 + Android API 34) pass on both platforms"
    status: failed
    reason: "Patrol tests are scripts-only and NOT integrated in CI. They require manual emulator execution. The CI workflow has no patrol step. QA-04 requires 'real navigation on emulator' and QA-05 requires runs at 'dev->staging' and 'staging->main' -- neither is configured. The plan explicitly deferred this ('when CI emulators are configured') but the SC treats it as a must-be-true condition."
    artifacts:
      - path: "apps/mobile/test/patrol/onboarding_patrol_test.dart"
        issue: "Test script exists but uses IntegrationTestWidgetsFlutterBinding (unit test mode), not actual emulator Patrol. Cannot pass on iOS 17 / Android API 34 without emulator CI setup."
      - path: "apps/mobile/test/patrol/document_patrol_test.dart"
        issue: "Same -- scripts ready but not wired to CI emulator pipeline."
      - path: ".github/workflows/ci.yml"
        issue: "No patrol step. test/patrol/ not in CI test_dirs."
    missing:
      - "CI workflow step or separate workflow triggering patrol tests on iOS 17 simulator (or document explicit manual gate policy in ROADMAP)"
      - "Add test/patrol/ to CI integration test stage or create .github/workflows/patrol.yml"

  - truth: "QA-09: DocumentFactory generates realistic Swiss test documents (SVG templates with persona-specific values, exportable as PDF)"
    status: failed
    reason: "DocumentFactory produces Map<String,dynamic> data only -- no SVG templates, no PDF export. The file explicitly comments: 'No real PDF/SVG generation — produces the DATA that would be extracted.' QA-09 requirement text says 'SVG templates with persona-specific values, exportable as PDF'. The plan intentionally reduced scope but did not update the requirement text or success criteria."
    artifacts:
      - path: "apps/mobile/test/fixtures/document_factory.dart"
        issue: "Data-only factory (Map<String,dynamic>). Satisfies deterministic test data need but NOT the SVG/PDF requirement as written."
    missing:
      - "SVG template generation for at least 1 document type (e.g., certificat_lpp) with persona-specific field injection, OR"
      - "Update QA-09 requirement text to reflect the data-factory approach (scope change must be recorded)"

  - truth: "WCAG 2.1 AA met on all new screens (contrast >= 4.5:1 for normal text)"
    status: partial
    reason: "Three MintColors fail strict 4.5:1 for normal text: error (#FF453A, ~3.41:1), info (#007AFF, ~4.02:1), success (#1A8A3A, ~4.43:1). Tests were adapted to use 3.0:1 threshold for these colors, documenting them as 'status accents / large text'. The WCAG AA SC requires >= 4.5:1 for normal text. If these colors appear as normal-weight text anywhere in new v2.0 screens, the screens do not meet WCAG AA. The test lowered the assertion rather than fixing the colors."
    artifacts:
      - path: "apps/mobile/test/accessibility/wcag_audit_test.dart"
        issue: "error, info, success colors tested at 3.0:1 threshold, not 4.5:1. success (#1A8A3A) threshold lowered to 4.3:1 -- still below 4.5:1 AA standard."
      - path: "apps/mobile/lib/theme/colors.dart"
        issue: "Colors themselves may need darkening to meet 4.5:1. Not verified against actual usage in Phase 1-5 screens."
    missing:
      - "Audit which new v2.0 screens actually render error/info/success text at normal weight -- if any do, colors must be darkened to >= 4.5:1"
      - "OR confirm via semantic analysis that all three colors are exclusively used as bold/large/icon contexts (not normal-weight text)"

  - truth: "New Phase 6 tests are part of the CI test run (QA-10: flutter test + pytest pass)"
    status: failed
    reason: "test/journeys/, test/accessibility/, test/i18n/, and test/golden_screenshots/ are not in any CI test shard. These 4 directories contain the bulk of Phase 6 QA work (~332 new tests by summary count) but will never run automatically. QA-10 requires 'flutter test + pytest pass' cross-cutting -- these tests cannot pass CI if they are never invoked."
    artifacts:
      - path: ".github/workflows/ci.yml"
        issue: "CI test_dirs shards are: test/services/, test/simulators/, test/financial_core/, test/domain/, test/b2b/, test/widgets/, test/models/, test/providers/, test/screens/, test/golden/, test/auth/, test/modules/. Missing: test/journeys/, test/accessibility/, test/i18n/, test/golden_screenshots/, test/patrol/."
    missing:
      - "Add test/journeys/ test/accessibility/ test/i18n/ to an existing CI shard (e.g., expand 'screens' shard or create new 'qa' shard)"
      - "test/golden_screenshots/ should run with --update-goldens on baseline PRs; add to screens shard for comparison runs"
---

# Phase 6: QA Profond Verification Report

**Phase Goal:** All v2.0 capabilities are validated across 9 personas, hostile scenarios, accessibility standards, and multilingual accuracy before release
**Verified:** 2026-04-06T20:42:25Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | All 9 personas complete golden path tests with >= 1 error recovery scenario each | VERIFIED | 8 new test files (marc, sophie, thomas, anna, pierre, julia, laurent, nadia) exist with 260-281 lines each. All have Group 5 "error recovery" section (grep -c returns 2 per file = header comment + group declaration). Lea (Phase 1) has embedded error recovery: age=0 rejection + negative salary handling in Group 1. |
| 2 | Golden Screenshots (pixel diff > 1.5% = red in CI) and Patrol tests pass on both platforms | FAILED | golden_screenshot_test.dart has 9 matchesGoldenFile() calls but no custom GoldenFileComparator with 1.5% tolerance. Flutter default = exact match. test/golden_screenshots/ absent from CI shards. Patrol tests are scripts only, not CI-integrated. |
| 3 | ComplianceGuard 100% coverage on all new output channels with zero banned terms and zero PII | VERIFIED | compliance_channel_coverage_test.dart (26 Flutter tests) validates all 4 channels: alert (ComplianceGuard.validateAlert per AlertTemplate), narrative biography (AnonymizedBiographySummary PII absence), coach opener (5-priority paths), confidence > 0 for 9 personas. Backend test (11 tests) validates BIOGRAPHY_AWARENESS, PII absence, conditional language. |
| 4 | WCAG 2.1 AA met on all new screens (contrast >= 4.5:1, tap >= 44pt, font scaling 200%) | PARTIAL | Tap targets and font scaling: VERIFIED. Contrast: PARTIAL -- textPrimary, textSecondary, button pairs meet 4.5:1. Three status colors (error, info, success) tested at 3.0:1 threshold, not 4.5:1. success color at 4.43:1 is 0.07 below AA threshold. |
| 5 | All new user-facing strings in 6 ARB files via AppLocalizations -- zero hardcoded strings, DE+IT terminology >= 85% | VERIFIED | hardcoded_string_audit_test.dart (26 tests) scans 10 Phase 1-5 files for literal French strings in Text() calls and validates 6-language key parity. de_it_terminology_test.dart (13 tests) validates DE (Vorsorge/BVG/AHV) and IT (pensione/pilastro/cassa pensione) at >= 85% coverage with French leakage detection. |

**Score:** 3/5 truths fully verified (SC 2 failed, SC 4 partial, SC 5 verified with note on QA-09 scope deviation)

### Deferred Items

None -- Phase 6 is the final milestone phase. All gaps require closure before release.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/journeys/marc_golden_path_test.dart` | Marc persona test (swiss_native, retirement) | VERIFIED | 269 lines, marcAge=58, IntentRouter + MinimalProfileService calls, Group 5 error recovery |
| `test/journeys/sophie_golden_path_test.dart` | Sophie persona test (expat_eu, housingPurchase) | VERIFIED | 269 lines, sophieAge=35, error recovery: empty canton |
| `test/journeys/thomas_golden_path_test.dart` | Thomas persona test (independent_with_lpp, selfEmployment) | VERIFIED | 264 lines, thomasAge=42 |
| `test/journeys/anna_golden_path_test.dart` | Anna persona test (cross_border, newJob) | VERIFIED | 258 lines, annaAge=30 |
| `test/journeys/pierre_golden_path_test.dart` | Pierre persona test (returning_swiss, cantonMove) | VERIFIED | 263 lines, pierreAge=50 |
| `test/journeys/julia_golden_path_test.dart` | Julia persona test (expat_us, marriage) | VERIFIED | 265 lines, juliaAge=38, error recovery: nonExistentChipKey |
| `test/journeys/laurent_golden_path_test.dart` | Laurent persona test (independent_no_lpp, debtCrisis) | VERIFIED | 260 lines, laurentAge=45, error recovery: negative salary |
| `test/journeys/nadia_golden_path_test.dart` | Nadia persona test (expat_non_eu, birth) | VERIFIED | 281 lines, nadiaAge=28, SwissRegion.italiana |
| `test/fixtures/document_factory.dart` | Deterministic document data generator for 4 Swiss doc types | PARTIAL | 192 lines. Has lppCertificate(), salaryCertificate(), attestation3a(), insurancePolicy() returning Map<String,dynamic>. Missing: SVG templates + PDF export as required by QA-09. |
| `test/golden_screenshots/golden_screenshot_test.dart` | Golden screenshot widget tests | PARTIAL | Exists, 9 matchesGoldenFile() calls, but no custom 1.5% tolerant comparator, setSurfaceSize() absent from test file (only in helper). |
| `test/golden_screenshots/README.md` | Golden update protocol documentation | VERIFIED | 1.5% threshold policy documented, update protocol defined |
| `test/patrol/onboarding_patrol_test.dart` | Patrol navigation test for onboarding flow | PARTIAL | Script exists, IntegrationTestWidgetsFlutterBinding, iOS17/Android API 34 noted in comments. Not CI-integrated. |
| `test/patrol/document_patrol_test.dart` | Patrol navigation test for document capture flow | PARTIAL | Script exists with takeScreenshot() calls. Not CI-integrated. |
| `test/services/coach/compliance_channel_coverage_test.dart` | ComplianceGuard coverage for all 4 output channels | VERIFIED | 26 tests: AlertTemplate loop, AnonymizedBiographySummary PII absence, CoachOpenerService channels, 9-persona replacementRate confidence |
| `services/backend/tests/test_compliance_channel_coverage.py` | Backend compliance coverage for coach prompt | VERIFIED | 11 tests: BIOGRAPHY_AWARENESS presence, PII placeholder absence, conditional language, jamais citer |
| `test/services/coach/de_it_terminology_test.dart` | DE+IT financial terminology accuracy tests | VERIFIED | 13 tests: DE Vorsorge/BVG terms, IT pensione/pilastro terms, French leakage detection, 85% coverage threshold |
| `test/accessibility/wcag_audit_test.dart` | WCAG 2.1 AA accessibility audit tests | PARTIAL | 29 tests, contrastRatio() helper, 18 color pairs. Normal text pairs verified at 4.5:1. Status colors (error, info, success) only tested at 3.0:1. |
| `test/accessibility/font_scaling_test.dart` | Font scaling 200% overflow tests | VERIFIED | 7 tests, TextScaler.linear(2.0), FlutterError capture for overflow |
| `test/i18n/hardcoded_string_audit_test.dart` | Hardcoded string detection + i18n coverage | VERIFIED | 26 tests: regex scan of 10 Phase 1-5 files, 6-language ARB key parity, financial key non-empty validation |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `test/journeys/*_golden_path_test.dart` | IntentRouter, MinimalProfileService, ChiffreChocSelector | service-level calls | WIRED | grep confirms IntentRouter.forChipKey and MinimalProfileService.compute called in all persona tests |
| `golden_screenshot_test.dart` | MintHomeScreen, IntentScreen, PremierEclairageCard, PrivacyControlScreen | pumpWidget + matchesGoldenFile | PARTIAL | matchesGoldenFile present (9 calls). Phone size simulation via kGoldenDeviceSize constant in helper but setSurfaceSize() not confirmed in test file itself. 1.5% threshold NOT enforced in comparator. |
| `compliance_channel_coverage_test.dart` | ComplianceGuard.validate, ComplianceGuard.validateAlert | adversarial inputs across all channels | WIRED | AlertTemplate.values loop, validateAlert() called, AnonymizedBiographySummary.build() called |
| `wcag_audit_test.dart` | MintColors, PremierEclairageCard, AnticipationSignalCard | contrastRatio calculations + widget pump | PARTIAL | contrastRatio() verified 22 occurrences, tap target tests present. Status color thresholds reduced below SC requirement. |
| `hardcoded_string_audit_test.dart` | app_fr.arb, app_de.arb, 6 ARB files | dart:io JSON loading | WIRED | grep confirms app_fr.arb, app_de.arb references in test file (20 matches total) |

### Data-Flow Trace (Level 4)

Not applicable -- Phase 6 delivers test files only (no new user-facing data-rendering components). All artifacts are test infrastructure, not runtime components with data flows.

### Behavioral Spot-Checks

Step 7b: Skipped for test files (no runnable entry points in test suites without Flutter test runner). Test results are attested by SUMMARY.md commit hashes (dabce5ae, ea77d300, 78f70a98, 31eaaeb6, e2639d8f, ff783d8e, 9ee62624, 292c2c28) -- all summaries report 0 failures.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| QA-01 | 06-01-PLAN.md | 9 personas each complete golden path integration tests | SATISFIED | 8 new persona files + existing Lea = 9 total personas with golden path tests |
| QA-02 | 06-01-PLAN.md | Each persona includes >= 1 error recovery scenario | SATISFIED | All 8 new personas have Group 5 error recovery. Lea has age=0/negative salary edge cases in Group 1. |
| QA-03 | 06-02-PLAN.md | Golden Screenshots pixel diff > 1.5% = red in CI | BLOCKED | No GoldenFileComparator with 1.5% tolerance. test/golden_screenshots/ not in CI shards. Threshold is documentation-only. |
| QA-04 | 06-02-PLAN.md | Patrol tests on iOS 17 + Android API 34 emulators | BLOCKED | Scripts exist (onboarding_patrol_test.dart, document_patrol_test.dart) but no CI emulator integration. Not executable without emulator infrastructure. |
| QA-05 | 06-02-PLAN.md | Patrol runs at dev->staging and staging->main | BLOCKED | No CI workflow step for patrol. test/patrol/ not in CI test_dirs. |
| QA-06 | 06-03-PLAN.md | ComplianceGuard 100%, zero banned terms, zero PII, confidence > 0 | SATISFIED | compliance_channel_coverage_test.dart validates all 4 channels with adversarial inputs. |
| QA-07 | 06-03-PLAN.md | DE + IT financial terminology accuracy >= 85% | SATISFIED | de_it_terminology_test.dart validates at 85% threshold for both languages (IT at 75% for retirement terms due to valid alternate terms). |
| QA-08 | 06-04-PLAN.md | WCAG 2.1 AA on all new screens | PARTIAL | Tap targets (44pt) and font scaling (200%) VERIFIED. Contrast: normal text pairs at 4.5:1 VERIFIED. Status accent colors (error/info/success) only at 3.0:1 -- below SC requirement for normal text. |
| QA-09 | 06-01-PLAN.md | DocumentFactory with SVG templates exportable as PDF | BLOCKED | DocumentFactory is data-only (Map<String,dynamic>). No SVG templates, no PDF export. Requirement text not updated to reflect scope reduction. |
| QA-10 | 06-03-PLAN.md | Cross-cutting: ComplianceGuard, flutter analyze 0 errors, flutter test + pytest pass | PARTIAL | ComplianceGuard tests: SATISFIED. flutter analyze 0: attested by summaries. flutter test: PARTIAL -- test/journeys/, test/accessibility/, test/i18n/ not in CI shards. |
| COMP-01 | 06-03-PLAN.md | ComplianceGuard validates ALL new output channels | SATISFIED | All 4 channels tested: alerts (Phase 4), narrative refs (Phase 3), coach openers (Phase 5), extraction insights (Phase 2). |
| COMP-05 | 06-04-PLAN.md | All new user-facing strings in 6 ARB files via AppLocalizations | SATISFIED | hardcoded_string_audit_test.dart scans 10 Phase 1-5 files with regex, ARB key parity across 6 languages verified. |

**Orphaned requirements (Phase 6 in REQUIREMENTS.md but unclaimed by plans):** None -- all Phase 6 requirements are claimed by at least one plan.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/golden_screenshots/golden_screenshot_test.dart` | 10 | `// See README.md for update protocol and 1.5% threshold policy.` -- threshold documented, not enforced | BLOCKER | QA-03 SC cannot be satisfied without a GoldenFileComparator that enforces 1.5% tolerance |
| `test/accessibility/wcag_audit_test.dart` | 131 | `greaterThanOrEqualTo(4.3)` for success color (4.43:1 actual) | WARNING | SC requires 4.5:1 for normal text. Test passes at 4.3 threshold, masking a real WCAG gap. |
| `apps/mobile/test/fixtures/document_factory.dart` | 5 | `// No real PDF/SVG generation` comment explicitly acknowledges scope deviation from QA-09 | BLOCKER | QA-09 requirement specifies SVG + PDF; requirement text not updated to match implementation. |
| `.github/workflows/ci.yml` | 145-151 | test/journeys/, test/accessibility/, test/i18n/, test/golden_screenshots/ absent from all test_dirs shards | BLOCKER | New Phase 6 tests never run in CI -- QA-10 cannot be satisfied. |

### Human Verification Required

#### 1. WCAG Status Color Usage Audit

**Test:** Review every new Phase 1-5 screen (intent_screen, quick_start_screen, chiffre_choc_screen, plan_screen, privacy_control_screen, anticipation_signal_card, contextual card widgets, MintHomeScreen) for text rendered using MintColors.error, MintColors.info, or MintColors.success at normal font weight.
**Expected:** These colors should only appear as bold text, large text (>= 18pt regular or 14pt bold), or icons/decorative elements -- never as normal-weight body text.
**Why human:** Requires visual inspection of rendered screens + checking font weight at each usage point. Cannot be determined from static code analysis without tracing every TextStyle chain.

#### 2. Patrol Integration Tests Execution

**Test:** On an iOS 17 iPhone 15 simulator and Android API 34 Pixel 7 emulator, run `flutter test integration_test/` or `patrol test --target test/patrol/onboarding_patrol_test.dart` to verify the complete onboarding and document capture flows navigate without crash.
**Expected:** All 7 onboarding steps and 7 document capture steps complete with screenshots captured at each step.
**Why human:** Requires physical simulator/emulator setup. Cannot run in unit test mode. CI infrastructure for emulators not yet configured.

### Gaps Summary

**5 gaps block full goal achievement:**

1. **QA-03 threshold not enforced (BLOCKER):** The 1.5% pixel diff policy is in README but no custom `GoldenFileComparator` with `threshold=0.015` is configured. Flutter's built-in comparator is exact-match only. Additionally, the golden screenshot test directory is excluded from all CI shards -- these tests are invisible to the pipeline.

2. **QA-04/05 Patrol not CI-integrated (BLOCKER):** The patrol test scripts are complete but remain manual artifacts. Neither the iOS 17 nor Android API 34 platforms are tested in CI. The SC requires passing "on both platforms" -- this cannot be verified without emulator CI infrastructure or a documented manual gate policy accepted by the team.

3. **QA-09 DocumentFactory scope deviation (BLOCKER):** The requirement specifies SVG templates exportable as PDF. The implementation is a pure data factory (Map<String,dynamic>). The requirement text was not updated to reflect the scope change, creating a mismatch between REQUIREMENTS.md and the codebase.

4. **WCAG status colors at 3.0:1 (WARNING):** error (#FF453A ~3.41:1), info (#007AFF ~4.02:1), and success (#1A8A3A ~4.43:1) fail strict 4.5:1 WCAG AA for normal text. Tests were adjusted to pass at 3.0:1 (large text threshold), masking real compliance risk if these colors are used as normal-weight text in new screens.

5. **New Phase 6 tests excluded from CI (BLOCKER):** test/journeys/, test/accessibility/, test/i18n/, and test/golden_screenshots/ contain ~332 new tests but are absent from all CI test_dirs shards. QA-10 (cross-cutting flutter test pass) cannot be satisfied while these directories are invisible to CI.

**Root cause commonality:** Gaps 1, 2, and 5 all share the same root cause: CI integration was deferred. A single CI shard addition + GoldenFileComparator implementation would close gaps 1, 3 (partial), and 5 together.

---

_Verified: 2026-04-06T20:42:25Z_
_Verifier: Claude (gsd-verifier)_
