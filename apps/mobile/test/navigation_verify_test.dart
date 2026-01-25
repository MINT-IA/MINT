import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/theme/colors.dart';
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

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  testWidgets('Full Navigation Flow Verification', (WidgetTester tester) async {
    // Set Screen Size to Mobile
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;

    // 1. Pump App
    await tester.pumpWidget(const MintApp());
    await tester.pumpAndSettle();

    // --- LANDING PAGE ---
    expect(find.text('Financial OS.'), findsOneWidget,
        reason: "Landing page loaded");

    // 2. Click "Démarrer"
    final buttonFinder =
        find.widgetWithText(InkWell, 'Démarrer mon diagnostic');

    // If text finding is flaky due to fonts, try finding by Icon
    final iconFinder = find.byIcon(Icons.arrow_forward_rounded);

    final targetFinder =
        buttonFinder.evaluate().isNotEmpty ? buttonFinder : iconFinder;

    expect(targetFinder, findsOneWidget, reason: "Start button found");

    await tester.ensureVisible(targetFinder);
    await tester.tap(targetFinder);
    await tester.pumpAndSettle();

    // --- DASHBOARD (NowTab) ---
    // We look for "Bonjour" or "MAINTENANT" header
    expect(find.textContaining('MAINTENANT'), findsOneWidget,
        reason: "Dashboard loaded");
    expect(find.text('EXPLORER'), findsOneWidget, reason: "Bottom Nav visible");

    // 3. Navigate to EXPLORER Tab
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();

    // --- EXPLORER TAB ---
    // Usually the text is "Maîtriser mon Budget"
    final budgetFinder = find.text('Maîtriser mon Budget');
    await tester.scrollUntilVisible(
        budgetFinder, 500); // Scroll down to find it
    expect(budgetFinder, findsOneWidget, reason: "Explorer Tab loaded");

    // 4. Click "Maîtriser mon Budget" -> Should NOT 404
    await tester.tap(find.text('Maîtriser mon Budget'));
    await tester.pumpAndSettle();

    // --- BUDGET SCREEN ---
    // BudgetContainerScreen shows empty state initially
    expect(
        find.text('Votre Budget n\'est pas encore configuré'), findsOneWidget,
        reason: "Budget Route works");

    // 5. Go Back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 6. Verify Back in Explorer
    expect(find.text('Maîtriser mon Budget'), findsOneWidget);

    // 7. Click "Simulateur Intérêts Composés" (in GridView)
    // It has title "Intérêts\nComposés", let's find by Icon to be safe
    await tester.tap(find.byIcon(Icons.trending_up));
    await tester.pumpAndSettle();

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
