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

    // --- DASHBOARD (RetirementDashboardScreen) ---
    // We look for "Bonjour" header (from RetirementDashboardScreen)
    expect(find.textContaining('Bonjour'), findsWidgets,
        reason: "Dashboard loaded");
    expect(find.text('Mint'), findsOneWidget, reason: "Bottom Nav visible");

    // 3. Navigate to Mint Tab (coach)
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await _pumpFrames(tester, frames: 20);

    // --- MINT TAB (Coach) ---
    // Coach screen renders with greeting or empty state
    expect(find.byType(Scaffold), findsWidgets, reason: "Mint Tab loaded");

    // 4. Tap Moi tab
    await tester.tap(find.text('Moi'));
    await _pumpFrames(tester, frames: 20);

    expect(find.byType(Scaffold), findsWidgets,
        reason: "Moi Tab loaded");
  });
}
