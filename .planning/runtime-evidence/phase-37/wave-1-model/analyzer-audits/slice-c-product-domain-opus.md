All 81 tests green. I have what I need. This diff is a Flutter 3.41 API migration plus test dead-code cleanup, with no Swiss financial surface touched. Here is the audit.

---

Product/domain verdict: PASS

## Summary
Commit range `e266da836..HEAD` is a **Flutter 3.41.6 infrastructure/a11y migration plus dormant-test repair**. It contains **zero changes to Swiss financial logic, constants, thresholds, routing, ledger/DataQuest wiring, or user-facing compliance strings**. Every substantive change is an API rename or test cleanup, and I verified each against the installed SDK and by running the suites.

Verification performed:
- Flutter `3.41.6` / Dart `3.11.4` confirmed installed (`apps/mobile/pubspec.yaml` sdk `^3.6.0`).
- `SemanticsService.sendAnnouncement(FlutterView, String, TextDirection)` confirmed present at `semantics_service.dart:81`; call site passes `View.of(context)` (a `FlutterView`) — signature matches. Old `announce` is only deprecated, not removed, so this was a warning-cleanup migration, not a build-break fix (the removed code comment's "breaks the build under 3.27.4" framing was inaccurate, but harmless).
- `flagsCollection.isButton` / `.isLiveRegion` confirmed to return `bool` (`semantics.dart:6323`, `:418`) — test assertions are type-correct.
- All removed symbols (`_allowedLegalKeyPatterns`, `_normalApp`, unused `fact` var) confirmed to have **no remaining references** (no compile break).
- Ran `wcag_audit_test.dart` + `coach_live_region_test.dart` + `mint_trame_confiance_test.dart`: **81/81 pass**.

## P0 findings
None.

## P1 findings
None.

## P2 findings
- **`test/screens/calculator_prefill_writeback_test.dart:187-206`** — The refactored `simulateWriteBack` still tests a **reimplementation** of the `if (!_hasUserInteracted) return;` guard, not the real screen code path. The refactor is behavior-preserving and clean, but the test remains a tautology asserting its own local logic. Pre-existing weakness, not introduced here; worth replacing with a real widget-driven write-back assertion so the ledger write-back contract is actually exercised.
- **`test/architecture/route_doctrine_lint_test.dart`** — Removing `_allowedLegalKeyPatterns` is correct dead-code cleanup (ARB `raw-legal-reference` is already excluded by category in `scanFile`, pre-existing). No behavior change, but the compliance lint now permits raw legal citations in *any* ARB key, not only disclaimer/source keys. Not a regression from this diff, but the loosened guarantee is worth a comment so a future reviewer doesn't assume key-scoped enforcement still exists.
- **`lib/widgets/trust/mint_trame_confiance.dart`** (context, out of diff scope) — `_weakestAxis` retains the comment "Normalize to 0..1 (EnhancedConfidence stores 0..100)" while comparing raw 0..100 values. Harmless for a min-selection, but the stale comment invites future error. Untouched by this diff.

## Swiss domain review
- **AVS / LPP / 3a / tax / mortgage / insurance / succession:** **explicitly not affected.** No calculator inputs, rates, capacity ratios, coordination deductions, pillar constants, cantonal logic, or succession rules are added, removed, or altered. The only AVS mention is a hardcoded illustrative string `'3 480 CHF/mois … rente AVS estimee'` inside `wcag_audit_test.dart` (test fixture, not product output) — no correctness claim reaches a user.
- **Compliance language:** unchanged. No advice, ranking, guarantee, or product-recommendation strings introduced. The `MintTrameConfiance` D-08 "no `score` getter / no ranking surface" doctrine is preserved verbatim.

## Mint product logic review
Neutral-to-positive on the ledger → DataQuest → scenario → dossier spine. Nothing moves the spine forward functionally, but the change **restores CI/analyzer green on the confidence-rendering primitive (MTC)** and its a11y announcements, which is the surface that distinguishes known/estimated/missing facts to the user. The confidence-axis semantics (weakest-axis announcement, `.empty` missing-data CTA fallback for sparse axes) continue to function — verified by the passing `sparse weakest (< 40) triggers MTC.empty` and announce-dedup tests. No new facade-without-wiring risk: every migrated widget is exercised by a passing test.
