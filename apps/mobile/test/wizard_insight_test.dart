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
      print('Warning: Tax scales asset not found for test.');
    }
  });

  testWidgets('Fiscal Mirror Insight triggers on Vaud/Single/HighIncome',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2.0;

    print('STEP 1: Pump Widget');
    // 1. Pump Wizard Screen with GoRouter wrapper
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AdvisorWizardScreenV2(),
        ),
        // Add placeholder routes for any navigation attempts
        GoRoute(
          path: '/simulators/:type',
          builder: (context, state) => const Scaffold(body: Center(child: Text('Simulator'))),
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
    await tester.pumpAndSettle(); // Initial Load
    await tester.pumpAndSettle(); // Animation settle
    print('STEP 1: Done');

    // Helper to tap next securely
    Future<void> tapNext() async {
      final buttonFinder = find.widgetWithText(FilledButton, 'Suivant');
      await tester.tap(buttonFinder.last);
      await tester.pumpAndSettle();
    }

    print('STEP 1b: Stress Check');
    // Q0: Financial Stress Check (choice) - Use the helper from persona tests
    await _answerChoice(tester, 'Optimiser mes impôts');

    print('STEP 2: Name');
    // Q1: Name
    await tester.enterText(find.byType(TextField).first, 'TestUser');
    await tapNext();

    print('STEP 3: Birth Year');
    // Q2: Birth Year
    await tester.enterText(find.byType(TextField).first, '1990'); // Age 36
    await tapNext();

    print('STEP 4: Canton');
    // Q3: Canton (choice type with labels like "Vaud (VD)")
    await _answerChoice(tester, 'Vaud (VD)');

    print('STEP 5: Civil Status');
    // Q4: Civil Status
    await _answerChoice(tester, 'Célibataire');

    print('STEP 6: Children');
    // Q5: Children (after this, section transitions to Budget & Protection)
    await _answerChoice(tester, 'Aucun');

    print('STEP 7: Employment');
    // Q6: Employment (now in Budget & Protection section)
    await _answerChoice(tester, 'Salarié(e)');

    print('STEP 8: Pay Frequency');
    // Q7: Pay Frequency
    await _answerChoice(tester, 'Mensuel');

    print('STEP 9: Income');
    // Q8: Net Income
    await tester.enterText(
        find.byType(TextField).first, '10000'); // 10k/month => 120k/year

    // Tap Next to finalize answer
    await tapNext();

    print('STEP 10: Check Insight');

    // Scroll down to find the insight widgets (they appear below the question)
    final scrollable = find.byKey(const ValueKey('wizard_scroll_view'));
    if (scrollable.evaluate().isNotEmpty) {
      for (int i = 0; i < 5; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
    }

    // CHECK: Does the Insight appear?
    expect(find.byKey(const ValueKey('tax_freedom')), findsOneWidget);
    expect(find.textContaining('INSIGHT FISCAL'), findsOneWidget);

    // Check Neighbor Comp (VD -> VS/FR saves money)
    expect(find.byKey(const ValueKey('neighbor_comp')), findsOneWidget);
    expect(find.textContaining('OPTIMISATION LOCALE'), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

// Helper functions adapted from persona tests
Future<void> _answerChoice(WidgetTester tester, String exactText) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  await _handlePotentialTransition(tester);

  final target = find.textContaining(exactText);
  final scrollable = find.byKey(const ValueKey('wizard_scroll_view'));

  // Scroll down to make the question options visible (they may be after the educational insert)
  if (scrollable.evaluate().isNotEmpty && target.evaluate().isEmpty) {
    for (int i = 0; i < 10; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      if (target.evaluate().isNotEmpty) break;
    }
  }

  final finalTarget = find.textContaining(exactText);
  if (finalTarget.evaluate().isEmpty) {
    fail("Choice '$exactText' not found.");
  }

  // If there are multiple matches (e.g., in educational insert + question), tap the last one
  final targetToUse = finalTarget.evaluate().length > 1 ? finalTarget.last : finalTarget.first;

  final inkWell =
      find.ancestor(of: targetToUse, matching: find.byType(InkWell));
  if (inkWell.evaluate().isNotEmpty) {
    await tester.tap(inkWell.first, warnIfMissed: false);
  } else {
    await tester.tap(targetToUse, warnIfMissed: false);
  }

  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 1000));
}

Future<void> _handlePotentialTransition(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  if (find.textContaining("Prochaine étape").evaluate().isNotEmpty) {
    await tester.pumpAndSettle(const Duration(seconds: 6));
  }
}
