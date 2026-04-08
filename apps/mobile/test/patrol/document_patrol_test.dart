// Patrol / Integration test: Document capture and enrichment flow.
//
// Requires an emulator or physical device to run.
// Run with:
//   flutter test integration_test/document_test.dart
//   -- OR (when Patrol is configured) --
//   patrol test --target test/patrol/document_patrol_test.dart
//
// Target devices:
//   - iOS 17 iPhone 15 simulator
//   - Android API 34 Pixel 7 emulator
//
// For CI: see .github/workflows/ integration notes.
// These tests require emulator infrastructure and camera mocking.
// They are scripted flows ready for execution once CI emulators
// are configured (QA-04/QA-05).
//
// Camera mocking: On iOS simulators, the camera is not available.
// Use image_picker test utilities or mock the camera channel to
// provide a pre-captured test document image.
//
// Migration path: When patrol ^3.0.0 is added to dev_dependencies,
// replace IntegrationTestWidgetsFlutterBinding with patrolTest() wrapper
// and $.screenshot() calls. The flow logic remains identical.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mint_mobile/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Document Capture Flow', () {
    setUp(() {
      // Mock the camera/image_picker channel to return a test document image.
      // This prevents the test from hanging on camera permission dialogs.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/image_picker'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'pickImage' ||
              methodCall.method == 'pickMultiImage') {
            // Return null to simulate user cancelling camera.
            // In a real CI setup, return a path to a test fixture image.
            return null;
          }
          return null;
        },
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // Document capture sequence:
    //   1. Navigate to document capture (from home or profile)
    //   2. Select capture method (camera or gallery)
    //   3. (Mock camera) -> Review screen with extracted data
    //   4. Confirm extraction -> Profile enrichment
    //   5. View impact screen (updated premier eclairage)
    // ─────────────────────────────────────────────────────────────────────

    // Patrol integration test: requires emulator / real binding. Under the
    // widget-test binding, app.main() throws LateInitializationError before
    // the first frame. Tracked under QA-04/QA-05 (emulator CI infra).
    // Investigation note (2026-04-08 pre-dev-merge sweep):
    // .planning/phases/12-l1.6c-ton-ux-ship-gate/12-PATROL-DEFERRED.md
    testWidgets('document capture and enrichment with screenshots', skip: true,
        (tester) async {
      // Launch the full app.
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ── Step 1: Navigate to document capture ──
      // Assume user is already authenticated (from onboarding test or mock).
      // Look for document capture entry point.
      await binding.takeScreenshot('doc_01_home_before_capture');

      // Try to find a document capture button or FAB.
      // The entry point may be in the profile drawer or a contextual action.
      final addDocButton = find.byIcon(Icons.add_a_photo);
      final uploadButton = find.byIcon(Icons.upload_file);
      final captureButton = find.text('Scanner un document');

      if (captureButton.evaluate().isNotEmpty) {
        await tester.tap(captureButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } else if (addDocButton.evaluate().isNotEmpty) {
        await tester.tap(addDocButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } else if (uploadButton.evaluate().isNotEmpty) {
        await tester.tap(uploadButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // ── Step 2: Document capture screen ──
      await binding.takeScreenshot('doc_02_capture_screen');

      // Select capture method. Look for camera or gallery options.
      final cameraOption = find.text('Photo');
      final galleryOption = find.text('Galerie');
      final takePhotoOption = find.byIcon(Icons.camera_alt);

      if (cameraOption.evaluate().isNotEmpty) {
        await tester.tap(cameraOption.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } else if (takePhotoOption.evaluate().isNotEmpty) {
        await tester.tap(takePhotoOption.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } else if (galleryOption.evaluate().isNotEmpty) {
        await tester.tap(galleryOption.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // ── Step 3: Review screen (mock camera returned null) ──
      // With mocked camera returning null, the app should handle gracefully.
      // In a real test with a fixture image, we'd see extracted fields.
      await binding.takeScreenshot('doc_03_after_capture_attempt');

      // If extraction succeeded (with fixture image), we'd see a review screen.
      // Look for confirmation actions.
      final confirmButton = find.text('Confirmer');
      final validateButton = find.text('Valider');

      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await binding.takeScreenshot('doc_04_confirmation');
      } else if (validateButton.evaluate().isNotEmpty) {
        await tester.tap(validateButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await binding.takeScreenshot('doc_04_confirmation');
      }

      // ── Step 4: Profile enrichment ──
      // After confirmation, the extracted data enriches the profile.
      // The app may show an enrichment animation or summary.
      await binding.takeScreenshot('doc_05_enrichment');

      // ── Step 5: Impact screen ──
      // After enrichment, an updated insight may be shown.
      // Look for premier eclairage or impact indicators.
      final impactIndicators = find.textContaining('CHF');
      if (impactIndicators.evaluate().isNotEmpty) {
        await binding.takeScreenshot('doc_06_impact_screen');
      }

      // Navigate back to home to verify the profile was enriched.
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      await binding.takeScreenshot('doc_07_home_after_enrichment');
    });
  });
}
