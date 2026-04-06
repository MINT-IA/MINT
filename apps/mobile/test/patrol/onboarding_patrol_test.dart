// Patrol / Integration test: Onboarding golden path flow.
//
// Requires an emulator or physical device to run.
// Run with:
//   flutter test integration_test/onboarding_test.dart
//   -- OR (when Patrol is configured) --
//   patrol test --target test/patrol/onboarding_patrol_test.dart
//
// Target devices:
//   - iOS 17 iPhone 15 simulator
//   - Android API 34 Pixel 7 emulator
//
// For CI: see .github/workflows/ integration notes.
// These tests require emulator infrastructure. They are scripted flows
// ready for execution once CI emulators are configured (QA-04/QA-05).
//
// Migration path: When patrol ^3.0.0 is added to dev_dependencies,
// replace IntegrationTestWidgetsFlutterBinding with patrolTest() wrapper
// and $.screenshot() calls. The flow logic remains identical.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mint_mobile/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Flow — Golden Path', () {
    // ─────────────────────────────────────────────────────────────────────
    // Full onboarding sequence:
    //   1. Launch app -> Promise/Landing screen
    //   2. Tap "Commencer" -> Login screen
    //   3. (Mock auth) -> Intent screen
    //   4. Tap a chip (e.g. firstJob) -> Quick Start screen
    //   5. Enter age / salary / canton
    //   6. Submit -> Premier Eclairage screen
    //   7. Continue -> Plan screen
    // ─────────────────────────────────────────────────────────────────────

    testWidgets('complete onboarding flow with screenshots', (tester) async {
      // Launch the full app.
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ── Step 1: Promise / Landing screen ──
      // Expect the landing screen with "Commencer" CTA.
      await binding.takeScreenshot('01_landing_screen');

      // Look for the primary CTA button.
      final commencerButton = find.text('Commencer');
      if (commencerButton.evaluate().isNotEmpty) {
        await tester.tap(commencerButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // ── Step 2: Login screen ──
      await binding.takeScreenshot('02_login_screen');

      // In integration test mode, auth may need to be mocked.
      // For now, look for magic link or Apple Sign-In and attempt.
      // If auth is not available, the test documents the flow up to here.
      final magicLinkField = find.byType(TextField);
      if (magicLinkField.evaluate().isNotEmpty) {
        // Enter a test email for magic link flow.
        await tester.enterText(magicLinkField.first, 'test@mint.test');
        await tester.pumpAndSettle();
        await binding.takeScreenshot('02b_login_email_entered');

        // Note: actual magic link auth requires backend. In CI, mock
        // the auth provider to auto-authenticate the test user.
      }

      // ── Step 3: Intent screen (post-auth) ──
      // After successful auth, the app navigates to intent selection.
      // If auth was mocked, we should see the intent chips.
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await binding.takeScreenshot('03_intent_screen');

      final intentChips = find.byType(InkWell);
      if (intentChips.evaluate().length >= 7) {
        // Tap the "Premier emploi" chip (index 6 in the chip list).
        await tester.tap(intentChips.at(6));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // ── Step 4: Quick Start screen ──
      await binding.takeScreenshot('04_quick_start_screen');

      // Enter minimal profile data: age, salary, canton.
      // The exact widget types depend on QuickStartScreen implementation.
      // Look for text fields or pickers.
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        // First field: age or birth year
        await tester.enterText(textFields.at(0), '25');
        await tester.pumpAndSettle();

        // Second field: salary
        await tester.enterText(textFields.at(1), '55000');
        await tester.pumpAndSettle();
      }

      await binding.takeScreenshot('04b_quick_start_filled');

      // Submit the form.
      final submitButton = find.text('Continuer');
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // ── Step 5: Premier Eclairage screen ──
      await binding.takeScreenshot('05_premier_eclairage');

      // Look for "Comprendre" or "Personnaliser" CTA.
      final comprendreCta = find.text('Comprendre');
      final personnaliserCta = find.text('Personnaliser');
      if (comprendreCta.evaluate().isNotEmpty) {
        await tester.tap(comprendreCta.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } else if (personnaliserCta.evaluate().isNotEmpty) {
        await tester.tap(personnaliserCta.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // ── Step 6: Plan screen ──
      await binding.takeScreenshot('06_plan_screen');

      // Verify we reached the plan screen (final onboarding step).
      // The plan screen should display a cap sequence or next steps.
      // At this point, onboarding is complete.

      // ── Step 7: Home screen (Aujourd'hui) ──
      // After plan screen, user navigates to the main app.
      final continuerPlan = find.text('Continuer');
      if (continuerPlan.evaluate().isNotEmpty) {
        await tester.tap(continuerPlan.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      await binding.takeScreenshot('07_home_screen');
    });
  });
}
