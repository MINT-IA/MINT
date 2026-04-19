---
phase: 28-pipeline-document
plan: 03
subsystem: mobile
tags: [flutter, visionkit, mlkit, document-scanner, image-labeling, i18n, native]
dependency_graph:
  requires:
    - phase: 28-01
      provides: backend understand_document() endpoint accepting raw bytes (no client change)
  provides:
    - NativeDocumentScanner.scan() returning normalized JPEG bytes (VisionKit iOS / ML Kit Doc Scanner Android)
    - LocalImageClassifier.shouldRejectAsNonFinancial() with 16-label block-list + 0.7 confidence threshold + fail-open semantics
    - Camera path on document_scan_screen now uses native scanner; ImagePicker removed from scope
    - i18n keys docScanRejectedNonFinancial + docScanScannerError in fr/en/de/es/it/pt
  affects:
    - Phase 28-04 (UI render_mode) — will polish the inline reject bubble that today reuses the existing _preValidationError surface
tech_stack:
  added:
    - flutter_doc_scanner ^0.0.13 (wraps VNDocumentCameraViewController iOS 13+ and com.google.android.gms:play-services-mlkit-document-scanner GA 2024)
    - google_mlkit_image_labeling ^0.14.2 (^0.14 required for google_mlkit_commons ^0.11 parity with text_recognition 0.15)
    - google_mlkit_commons ^0.11.0 (explicit dep for InputImage type)
    - com.google.android.gms:play-services-mlkit-document-scanner:16.0.0-beta1 (Android Gradle, pinned)
  patterns:
    - Native-first scanner with kIsWeb / Platform.isIOS|Android gate via isAvailable
    - Dependency-injected ImageLabelerPort so unit tests never hit the real ML Kit MethodChannel
    - Fail-open everywhere classifier touches (empty labels, exception, threshold miss → accept)
    - PDF magic-byte short-circuit to avoid wasted labeler calls on non-image inputs
key_files:
  created:
    - apps/mobile/lib/services/native_document_scanner.dart
    - apps/mobile/lib/services/local_image_classifier.dart
    - apps/mobile/test/services/local_image_classifier_test.dart
    - apps/mobile/test/screens/document_scan/document_scan_screen_test.dart
  modified:
    - apps/mobile/pubspec.yaml
    - apps/mobile/pubspec.lock
    - apps/mobile/ios/Runner/Info.plist
    - apps/mobile/android/app/build.gradle
    - apps/mobile/lib/screens/document_scan/document_scan_screen.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/lib/l10n/app_localizations.dart (regenerated)
    - apps/mobile/lib/l10n/app_localizations_*.dart x6 (regenerated)
key-decisions:
  - Picked flutter_doc_scanner over a custom MethodChannel — single Dart wrapper for both VisionKit and Android ML Kit Doc Scanner, MIT-licensed, last published 2025
  - Bumped google_mlkit_image_labeling from plan-suggested 0.13 to 0.14.2 due to a hard version conflict with google_mlkit_text_recognition 0.15 on shared google_mlkit_commons; pub solver flagged the incompatibility on first resolve
  - 16-label block-list (Food/Plate/Drink/Beverage/Selfie/Person/Cat/Dog/Pet/Landscape/Sky/Mountain/Sea/Beach/Plant/Flower/Tree/Cartoon/Meme/Sticker) — deliberately excluded "Screenshot" since banking screenshots are valid input
  - Confidence threshold 0.7, top-3 labels inspected (per RESEARCH §2)
  - Fail-open across the board — better to pay one wasted Vision call than to wrongly reject a legit LPP cert
  - Pre-reject hook injected at top of _processImageFile so it covers ALL image entrypoints (camera, gallery, paste-image), not just the camera button
  - Reject UX reuses existing _preValidationError surface for now; Phase 28-04 will polish the inline chat bubble + retry CTA
  - First scanned page only is processed today; multi-page queue deferred to 28-04 streaming flow (flutter_doc_scanner already returns N pages)
  - PDFs deliberately skip the labeler (image-only contract) via the %PDF magic-byte short-circuit
patterns-established:
  - Platform-capability gate (isAvailable) before any native scanner call → web/desktop graceful fallback to file picker
  - Port abstraction (ImageLabelerPort) over platform plugins so unit tests stay hermetic
requirements-completed: [DOC-03, DOC-07]
duration: 22 min
completed: 2026-04-14
---

# Phase 28 Plan 03: Native client scanner + local pre-reject — Summary

VisionKit on iOS and Google ML Kit Document Scanner on Android replace the old `ImagePicker` camera path; an offline `LocalImageClassifier` (Google ML Kit Image Labeling, 0.7 confidence, 16-label block-list, fail-open) short-circuits clearly non-financial photos before they hit Vision, saving ~3500 tokens + ~15s per pre-reject.

## Performance

- **Duration:** 22 min
- **Started:** 2026-04-14T18:00:00Z
- **Completed:** 2026-04-14T18:22:00Z
- **Tasks:** 3
- **Files created:** 4
- **Files modified:** 13 (pubspec + lock, native config, scan screen, 6 ARB + 7 generated l10n)

## Accomplishments

- Native scanner service (`NativeDocumentScanner`) with VisionKit + ML Kit GA 2024 wrapped behind a single Dart API and a `isAvailable` capability gate
- Local image classifier (`LocalImageClassifier`) with port-based DI, PDF magic-byte short-circuit, fail-open semantics, and a 16-label block-list at confidence 0.7
- Scan screen rewired: ImagePicker removed from `lib/screens/document_scan/`, camera button now opens VisionKit/ML Kit Doc Scanner, pre-reject runs before any backend call
- 6 ARBs updated + `flutter gen-l10n` regenerated (fr/en/de/es/it/pt) for `docScanRejectedNonFinancial` and `docScanScannerError`
- 8 new tests (6 classifier unit + 2 widget) all green; `flutter analyze` 0 new issues

## Task Commits

1. **Task 1: Native scanner service + native config** — `dcf23b52` (feat)
2. **Task 2 RED: failing tests for LocalImageClassifier** — `458f5bc2` (test)
3. **Task 2 GREEN: LocalImageClassifier impl** — `df92104c` (feat)
4. **Task 3: Wire scan screen to native scanner + classifier + i18n** — `10be2799` (feat)

_Plan metadata commit follows this SUMMARY._

## Files Created/Modified

- `apps/mobile/lib/services/native_document_scanner.dart` — Wrapper over `flutter_doc_scanner` exposing `scan(maxPages:5) → ScannedPages?` with multi-shape result normalization (String / List<String> / Map[pageImages|Uri|pdfUri]) and `DocumentScannerException` mapping; cancellation returns `null`, not error.
- `apps/mobile/lib/services/local_image_classifier.dart` — `RejectDecision { reject, reason, confidence }` + `ImageLabelerPort` interface; default factory wires the real ML Kit `ImageLabeler` over a temp file. Fail-open on PDF, web, empty bytes, exception, threshold miss.
- `apps/mobile/lib/screens/document_scan/document_scan_screen.dart` — `_onCameraPressed` now uses `NativeDocumentScanner.scan`; new `_materializeBytesAsXFile` helper preserves the downstream XFile-based pipeline; pre-reject pass at top of `_processImageFile`.
- `apps/mobile/pubspec.yaml` — `flutter_doc_scanner: ^0.0.13`, `google_mlkit_image_labeling: ^0.14.2`, `google_mlkit_commons: ^0.11.0`.
- `apps/mobile/ios/Runner/Info.plist` — `NSCameraUsageDescription` refined to plan wording ("MINT utilise l'appareil photo pour scanner tes documents financiers, jamais sans ton accord.").
- `apps/mobile/android/app/build.gradle` — explicit `play-services-mlkit-document-scanner:16.0.0-beta1` dep block; `minSdk = 24` already meets ML Kit ≥21.
- ARB files (6) — added `docScanRejectedNonFinancial` and `docScanScannerError` with descriptions.
- `apps/mobile/test/services/local_image_classifier_test.dart` — 6 tests via `_FakeLabeler` (food reject, document accept, below-threshold, empty, PDF short-circuit, exception fail-open).
- `apps/mobile/test/screens/document_scan/document_scan_screen_test.dart` — 2 widget tests (screen builds without exception, i18n keys resolve in fr).

## Decisions Made

See frontmatter `key-decisions`. Highlights:

- **Library choice**: `flutter_doc_scanner` over a hand-rolled `MethodChannel` — the package wraps both native SDKs cleanly and is actively maintained (2025).
- **Version bump (Rule 3 deviation)**: `google_mlkit_image_labeling 0.13 → 0.14.2` to satisfy `google_mlkit_commons ^0.11` shared with `google_mlkit_text_recognition 0.15`. Pub's solver suggested the bump on first resolve.
- **Block-list shape**: 16 labels covering food/people/pets/landscape/plant/cartoon. "Screenshot" deliberately excluded because banking-app screenshots are valid input (route to backend `narrative` mode).
- **Threshold + top-N**: 0.7 confidence on top 3 labels, per RESEARCH §2.
- **Fail-open everywhere**: classifier exception, empty labels, threshold miss, web, PDF — all return `RejectDecision.accept`. Doctrine: never wrongly reject a legit document; the cost of one wasted Vision call is negligible compared to the friction of a false negative.
- **UX surface for reject**: reused the existing `_preValidationError` warning card so the wiring lands now without blocking on the polished bubble UI from 28-04.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `google_mlkit_image_labeling ^0.13.0` incompatible with `google_mlkit_text_recognition ^0.15.0`**
- **Found during:** Task 1, on first `flutter pub get`
- **Issue:** 0.13 depends on `google_mlkit_commons ^0.9.0` while 0.15 of text_recognition depends on `^0.11.0`; pub solver refused to resolve.
- **Fix:** Bumped to `google_mlkit_image_labeling: ^0.14.2` per pub solver suggestion (0.14 line targets `commons ^0.11`).
- **Files modified:** `apps/mobile/pubspec.yaml`
- **Verification:** `flutter pub get` completed cleanly; analyzer + tests green.
- **Committed in:** `dcf23b52` (Task 1)

**2. [Rule 2 — Missing] Explicit `google_mlkit_commons ^0.11` dep**
- **Found during:** Task 2 GREEN phase
- **Issue:** `LocalImageClassifier` imports `InputImage` from `google_mlkit_commons` which was only pulled transitively → analyzer warning `depend_on_referenced_packages`.
- **Fix:** Added `google_mlkit_commons: ^0.11.0` as a direct dependency.
- **Verification:** `flutter analyze` clean.
- **Committed in:** `df92104c` (Task 2 GREEN)

**3. [Rule 1 — Bug] Test widget tree had unnecessary `const` keywords on non-const-callable constructor**
- **Found during:** Task 3 final analyze
- **Issue:** Initial test file paired `const MaterialApp(...)` with non-const `localizationsDelegates` → `unnecessary_const` lint.
- **Fix:** Removed the redundant inner `const` keywords on `localizationsDelegates` and `home`.
- **Verification:** `flutter analyze test/screens/document_scan/` → 0 issues.
- **Committed in:** `10be2799` (Task 3)

---

**Total deviations:** 3 auto-fixed (1 blocking, 1 missing critical, 1 bug)
**Impact on plan:** None — all three were pure-mechanical fixes (version solver, dep declaration, lint). No scope creep, no behavioural change vs. the plan spec.

## Issues Encountered

- The plan referenced `flutter_doc_scanner` as the iOS/Android wrapper; there is no published `^0.0.13` minor that breaks API parity, so the version constraint matched the package's latest stable channel and resolved without issue once the ML Kit version conflict (deviation #1) was fixed.

## Authentication Gates

None — entirely client-side work, no backend or service auth touched.

## User Setup Required

None — no external service configuration. The two new native dependencies install transparently on next `flutter pub get` / `pod install` / Gradle sync. CI builds will pull the Android `mlkit-document-scanner` AAR automatically.

## Known Stubs

None.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: native_permission | apps/mobile/ios/Runner/Info.plist | `NSCameraUsageDescription` wording updated. No new permission, no new entitlement. |
| threat_flag: temp_file | apps/mobile/lib/services/local_image_classifier.dart | Writes user image bytes to `getTemporaryDirectory()` for ML Kit to consume, then deletes via `try { await file.delete(); } catch (_) {}`. Same trust tier as existing OCR temp-file pattern in `document_scan_screen._cleanupTempFile`. |

## Next Phase Readiness

- Phase 28-04 (UI render_mode polish) can now layer the Wise-style chat bubble + bottom sheet on top of the wiring landed here. The reject path already routes through the canonical i18n key.
- The first-page-only behaviour in `_onCameraPressed` is intentional: streaming + multi-page queue is part of 28-04 (along with the SSE event handlers from 28-02).
- No regressions to the existing OCR fallback or PDF preflight paths — they branch off `_handlePdfImport` / `_processOcrText` which were untouched.

## Self-Check: PASSED

Verified files exist:
- FOUND: apps/mobile/lib/services/native_document_scanner.dart
- FOUND: apps/mobile/lib/services/local_image_classifier.dart
- FOUND: apps/mobile/test/services/local_image_classifier_test.dart
- FOUND: apps/mobile/test/screens/document_scan/document_scan_screen_test.dart

Verified commits exist:
- FOUND: dcf23b52 (Task 1 — native scanner)
- FOUND: 458f5bc2 (Task 2 RED)
- FOUND: df92104c (Task 2 GREEN — classifier)
- FOUND: 10be2799 (Task 3 — wiring + i18n)

Verified ImagePicker scope removal:
- `grep -r ImagePicker apps/mobile/lib/screens/document_scan/` → 0 hits

Verified test suite:
- 8/8 tests pass (`local_image_classifier_test.dart` + `document_scan_screen_test.dart`)
- `flutter analyze` on touched files → 0 new issues

---
*Phase: 28-pipeline-document*
*Completed: 2026-04-14*
