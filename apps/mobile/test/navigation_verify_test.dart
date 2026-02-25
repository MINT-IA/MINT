import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// Mock HttpOverrides to skip network calls for images
class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

// Helper to find navigation bar items
Finder findNavIcon(IconData icon) => find.byIcon(icon);

/// Pump multiple frames to let the app settle without pumpAndSettle
/// (pumpAndSettle never completes when infinite animations are active)
Future<void> _pumpFrames(WidgetTester tester, {int frames = 10}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  // Skipped in CI — full app integration test, timing-sensitive.
  testWidgets('Full Navigation Flow Verification', skip: true, (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    // Set Screen Size to Mobile (large enough to avoid overflow)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Pump App
    await tester.pumpWidget(const MintApp());
    await _pumpFrames(tester, frames: 20);

    // --- LANDING PAGE ---
    expect(find.text('Financial OS.'), findsOneWidget,
        reason: "Landing page loaded");

    // 2. Click "Démarrer" (MintPremiumButton uses GestureDetector)
    final targetFinder = find.text('Démarrer mon diagnostic');

    expect(targetFinder, findsOneWidget, reason: "Start button found");

    await tester.ensureVisible(targetFinder);
    await tester.tap(targetFinder);
    await _pumpFrames(tester, frames: 20);

    // --- DASHBOARD (CoachDashboardScreen) ---
    // We look for "Bonjour" header (from CoachDashboardScreen)
    expect(find.textContaining('Bonjour'), findsWidgets,
        reason: "Dashboard loaded");
    expect(find.text('Apprendre'), findsOneWidget, reason: "Bottom Nav visible");

    // 3. Navigate to APPRENDRE Tab (formerly EXPLORER)
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await _pumpFrames(tester, frames: 20);

    // --- EXPLORER TAB ---
    // Usually the text is "Maîtriser mon Budget" (may appear multiple times)
    final budgetFinder = find.text('Maîtriser mon Budget');
    if (budgetFinder.evaluate().isEmpty) {
      // Manually scroll if not visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await _pumpFrames(tester);
    }
    expect(budgetFinder, findsWidgets, reason: "Explorer Tab loaded");

    // 4. Click "Maîtriser mon Budget" -> Should NOT 404
    await tester.tap(find.text('Maîtriser mon Budget'));
    await _pumpFrames(tester, frames: 20);

    // --- BUDGET SCREEN ---
    // BudgetContainerScreen shows empty state initially
    expect(
        find.text('Votre Budget n\'est pas encore configuré'), findsOneWidget,
        reason: "Budget Route works");

    // 5. Go Back
    await tester.pageBack();
    await _pumpFrames(tester);

    // 6. Verify Back in Explorer
    expect(find.text('Maîtriser mon Budget'), findsOneWidget);

    // 7. Click "Simulateur Intérêts Composés" (in GridView)
    // It has title "Intérêts\nComposés", let's find by Icon to be safe
    await tester.tap(find.byIcon(Icons.trending_up));
    await _pumpFrames(tester, frames: 20);

    // --- SIMULATOR SCREEN ---
    // SimulatorCompoundScreen usually has a title "Intérêts Composés"
    // or we check that we left the explorer
    expect(find.text('EXPLORER'), findsNothing,
        reason: "Navigated away from Explorer");
    // Check for specific simulator widget text
    // e.g. "Capital Initial" or similar
    // Only checking for non-crash navigation for now.
  });
}
