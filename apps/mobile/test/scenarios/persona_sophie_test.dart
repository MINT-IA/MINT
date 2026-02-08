import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/screens/advisor/advisor_wizard_screen_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test Persona: Sophie (Wealth / Optimization)
void main() {
  testWidgets('Persona Sophie (Wealth) - Vaud Fiscal & Concubin Legal V2',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2.0;
    SharedPreferences.setMockInitialValues({});

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AdvisorWizardScreenV2(),
        ),
        GoRoute(
          path: '/report',
          builder: (context, state) => Scaffold(
            body: Center(child: Text('Ton Plan Mint - Report: ${state.extra}')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    // SECTION 0: STRESS CHECK
    await _answerChoice(tester, "Optimiser mes impôts");

    // SECTION 1: PROFIL
    await _answerText(tester, "Sophie");
    await _answerNumber(tester, "1980");
    await _answerChoice(tester, "Vaud (VD)");
    await _answerChoice(tester, "Concubinage");
    await _answerChoice(tester, "2 enfants");
    await _answerChoice(tester, "Salarié(e)");

    // SECTION 2: BUDGET & PROTECTION
    await _answerChoice(tester, "Mensuel");
    await _answerNumber(tester, "12000");
    await _answerChoice(tester, "Propriétaire");
    await _answerNumber(tester, "2500");
    await _answerChoice(tester, "Non");
    await _answerChoice(tester, "Oui, 3-6 mois");
    await _answerNumber(tester, "2000");

    // SECTION 3: PRÉVOYANCE
    await _answerChoice(tester, "Avec LPP (salarié)");
    await _answerNumber(tester, "50000");
    await _answerChoice(tester, "Oui");
    await _answerChoice(tester, "2 comptes");
    await _answerChoice(tester, "Fintech (VIAC, Finpension...)");
    await _answerNumber(tester, "7056");
    await _answerChoice(tester, "Non, tout complet");

    // SECTION 4: PATRIMOINE
    await _answerChoice(tester, "Oui");
    await _answerChoice(tester, "Non");
    await _answerChoice(tester, "Retraite confortable");
    await _answerChoice(tester, "Dynamique - Je vise le long terme");

    // VERIFICATION
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining("Ton Plan Mint"), findsWidgets);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

Future<void> _answerText(WidgetTester tester, String text) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  await _handlePotentialTransition(tester);
  final input = find.byType(TextField);
  expect(input, findsOneWidget);
  await tester.enterText(input, text);
  await tester.pump();
  await tester.tap(find.text("Suivant"), warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _answerNumber(WidgetTester tester, String number) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  await _handlePotentialTransition(tester);
  final input = find.byType(TextField);
  expect(input, findsOneWidget);
  await tester.enterText(input, number);
  await tester.pump();
  await tester.tap(find.text("Suivant"), warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _answerChoice(WidgetTester tester, String exactText) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  await _handlePotentialTransition(tester);

  final target = find.textContaining(exactText);
  final scrollable = find.byKey(const ValueKey('wizard_scroll_view'));

  // Manually scroll to find the target (SingleChildScrollView doesn't work with scrollUntilVisible)
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
