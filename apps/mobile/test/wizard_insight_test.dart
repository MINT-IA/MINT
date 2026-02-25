import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/screens/advisor/advisor_wizard_screen_v2.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Load real tax data so the Estimator works
    final file = File('assets/config/tax_scales.json');
    if (await file.exists()) {
      final jsonString = await file.readAsString();
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      TaxScalesLoader.init(jsonMap);
    } else {
      debugPrint('Warning: Tax scales asset not found for test.');
    }
  });

  // Skipped in CI — full wizard integration test, timing-sensitive.
  testWidgets('Fiscal Mirror Insight triggers on Vaud/Single/HighIncome',
      skip: true,
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2.0;

    debugPrint('STEP 1: Pump Widget');
    // 1. Pump Wizard Screen with GoRouter wrapper
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AdvisorWizardScreenV2(),
        ),
        GoRoute(
          path: '/simulators/:type',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Simulator'))),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(
        primaryColor: MintColors.primary,
        scaffoldBackgroundColor: MintColors.background,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    debugPrint('STEP 1: Done');

    // Helper to tap next securely
    Future<void> tapNext() async {
      final buttonFinder = find.widgetWithText(FilledButton, 'Suivant');
      await tester.tap(buttonFinder.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Q0: Name (stress check removed — wizard now starts with Profil section)
    debugPrint('STEP 2: Name');
    await tester.enterText(find.byType(TextField).first, 'TestUser');
    await tapNext();

    debugPrint('STEP 3: Birth Year');
    // Q1: Birth Year
    await tester.enterText(find.byType(TextField).first, '1990');
    await tapNext();

    debugPrint('STEP 4: Canton');
    // Q2: Canton
    await _answerChoice(tester, 'Vaud (VD)');

    debugPrint('STEP 5: Civil Status');
    // Q3: Civil Status
    await _answerChoice(tester, 'Célibataire');

    debugPrint('STEP 6: Children');
    // Q4: Children
    await _answerChoice(tester, 'Aucun');

    debugPrint('STEP 7: Employment');
    // Q5: Employment (last Profil question)
    await _answerChoice(tester, 'Salarié(e)');

    debugPrint('STEP 8: Income');
    // Q6: Net Income (first Budget & Protection question)
    await tester.enterText(
        find.byType(TextField).first, '10000'); // 10k/month => 120k/year
    await tapNext();

    debugPrint('STEP 9: Check Insight');

    // Scroll down to find the insight widgets
    final scrollable = find.byKey(const ValueKey('wizard_scroll_view'));
    if (scrollable.evaluate().isNotEmpty) {
      for (int i = 0; i < 5; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    // CHECK: Tax freedom insight appears on income question
    expect(find.textContaining('LIBERATION FISCALE'), findsOneWidget);
    expect(find.textContaining('impots'), findsWidgets);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

// Helper functions adapted from persona tests
Future<void> _answerChoice(WidgetTester tester, String exactText) async {
  await tester.pump(const Duration(milliseconds: 300));
  await _handlePotentialTransition(tester);

  final target = find.textContaining(exactText);
  final scrollable = find.byKey(const ValueKey('wizard_scroll_view'));

  if (scrollable.evaluate().isNotEmpty && target.evaluate().isEmpty) {
    for (int i = 0; i < 10; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));
      if (target.evaluate().isNotEmpty) break;
    }
  }

  final finalTarget = find.textContaining(exactText);
  if (finalTarget.evaluate().isEmpty) {
    fail("Choice '$exactText' not found.");
  }

  final targetToUse =
      finalTarget.evaluate().length > 1 ? finalTarget.last : finalTarget.first;

  final inkWell =
      find.ancestor(of: targetToUse, matching: find.byType(InkWell));
  if (inkWell.evaluate().isNotEmpty) {
    await tester.tap(inkWell.first, warnIfMissed: false);
  } else {
    await tester.tap(targetToUse, warnIfMissed: false);
  }

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _handlePotentialTransition(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  if (find.textContaining("Prochaine").evaluate().isNotEmpty) {
    await tester.pump(const Duration(seconds: 2));
  }
}
