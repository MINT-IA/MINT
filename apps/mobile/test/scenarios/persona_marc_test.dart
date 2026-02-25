import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/screens/advisor/advisor_wizard_screen_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test Persona: Marc (Dettes / Safe Mode)
/// Skipped in CI — full wizard integration test, timing-sensitive.
void main() {
  testWidgets('Persona Marc (Debt) - Safe Mode V2',
      skip: true,
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
    // Pump multiple frames to allow GoRouter + async _loadSavedProgress to complete
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // SECTION 0: STRESS CHECK
    await _answerChoice(tester, "Réduire mes dettes");

    // SECTION 1: PROFIL
    await _answerText(tester, "Marc");
    await _answerNumber(tester, "1990");
    await _answerChoice(tester, "Genève");
    await _answerChoice(tester, "Célibataire");
    await _answerChoice(tester, "Aucun");
    await _answerChoice(tester, "Salarié(e)");

    // SECTION 2: BUDGET & PROTECTION
    await _answerChoice(tester, "Mensuel");
    await _answerNumber(tester, "6000");
    await _answerChoice(tester, "Locataire");
    await _answerNumber(tester, "1800");
    await _answerChoice(tester, "Oui");
    await _answerChoice(tester, "Non, < 3 mois");
    await _answerNumber(tester, "0");

    // SECTION 3: PRÉVOYANCE
    await _answerChoice(tester, "Avec LPP (salarié)");
    await _answerNumber(tester, "0");
    await _answerChoice(tester, "Non");
    await _answerChoice(tester, "Je ne sais pas");
    await _answerNumber(tester, "10"); // q_avs_contribution_years (asked because avs_gaps != 'no')

    // SECTION 4: PATRIMOINE
    // q_has_investments is SKIPPED (Marc has consumer debt)
    await _answerChoice(tester, "Non");
    await _answerChoice(tester, "Retraite confortable");
    await _answerChoice(tester, "Prudent - Je dors mal si ça baisse de 10%");

    // VERIFICATION
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining("Ton Plan Mint"), findsWidgets);
    expect(find.textContaining("Marc"), findsWidgets);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

Future<void> _answerText(WidgetTester tester, String text) async {
  await tester.pump(const Duration(milliseconds: 300));
  await _handlePotentialTransition(tester);
  final input = find.byType(TextField);
  expect(input, findsOneWidget);
  await tester.enterText(input, text);
  await tester.pump();
  await tester.tap(find.text("Suivant"), warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _answerNumber(WidgetTester tester, String number) async {
  await tester.pump(const Duration(milliseconds: 300));
  await _handlePotentialTransition(tester);
  final input = find.byType(TextField);
  expect(input, findsOneWidget);
  await tester.enterText(input, number);
  await tester.pump();
  await tester.tap(find.text("Suivant"), warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _answerChoice(WidgetTester tester, String exactText) async {
  await tester.pump(const Duration(milliseconds: 300));
  await _handlePotentialTransition(tester);

  final target = find.textContaining(exactText);
  final scrollable = find.byKey(const ValueKey('wizard_scroll_view'));

  // Manually scroll to find the target
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
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _handlePotentialTransition(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  if (find.textContaining("Prochaine étape").evaluate().isNotEmpty) {
    await tester.pump(const Duration(seconds: 2));
  }
}
