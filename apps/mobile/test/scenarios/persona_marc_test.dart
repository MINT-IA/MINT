import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/advisor/advisor_wizard_screen_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test Persona: Marc (Dettes / Safe Mode)
void main() {
  testWidgets('Persona Marc (Debt) - Safe Mode V2',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2.0;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: AdvisorWizardScreenV2()));
    await tester.pumpAndSettle();

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

    // SECTION 4: PATRIMOINE
    await _answerChoice(tester, "Non");
    await _answerChoice(tester, "Retraite confortable");
    await _answerChoice(tester, "Prudent - Je dors mal si ça baisse de 10%");

    // VERIFICATION
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining("Ton Plan Mint"), findsWidgets);
    expect(find.textContaining("Marc"), findsWidgets);

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

  if (scrollable.evaluate().isNotEmpty) {
    try {
      await tester.scrollUntilVisible(target, 400.0,
          scrollable: scrollable, maxScrolls: 40);
      await tester.pumpAndSettle();
    } catch (e) {
      // Ignore
    }
  }

  final finalTarget = find.textContaining(exactText);
  if (finalTarget.evaluate().isEmpty) {
    fail("Choice '$exactText' not found.");
  }

  final inkWell =
      find.ancestor(of: finalTarget, matching: find.byType(InkWell));
  if (inkWell.evaluate().isNotEmpty) {
    await tester.tap(inkWell.first);
  } else {
    await tester.tap(finalTarget.first);
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
