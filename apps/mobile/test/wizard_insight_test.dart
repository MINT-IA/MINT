import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/advisor/advisor_wizard_screen_v2.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

// Mock wrapper to provide MaterialApp and Theme
class TestWrapper extends StatelessWidget {
  final Widget child;
  const TestWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: MintColors.primary,
        scaffoldBackgroundColor: MintColors.background,
      ),
      home: child,
    );
  }
}

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
    print('STEP 1: Pump Widget');
    // 1. Pump Wizard Screen
    await tester.pumpWidget(const TestWrapper(child: AdvisorWizardScreenV2()));
    await tester.pumpAndSettle(); // Initial Load
    await tester.pumpAndSettle(); // Animation settle
    print('STEP 1: Done');

    // Helper to tap next securely
    Future<void> tapNext() async {
      final buttonFinder = find.widgetWithText(FilledButton, 'Suivant');
      await tester.tap(buttonFinder.last);
      await tester.pumpAndSettle();
    }

    print('STEP 2: Name');
    // Q1: Name
    await tester.enterText(find.byType(TextField).last, 'TestUser');
    await tapNext();

    print('STEP 3: Birth Year');
    // Q2: Birth Year
    await tester.enterText(find.byType(TextField).last, '1990'); // Age 36
    await tapNext();

    print('STEP 4: Canton');
    // Q3: Canton
    // 'VD' might be ambiguous. Use 'Vaud' if that's the label, or ensure visible.
    // The list helps. The data in WizardQuestionsV2 likely uses 'VD' as value but maybe full name as label?
    // Let's assume 'VD' is the text displayed.
    await tester.scrollUntilVisible(find.text('VD'), 500);
    await tester.tap(find.text('VD').last); // Use last to avoid duplicates
    await tester.pumpAndSettle();

    print('STEP 5: Civil Status');
    // Q4: Civil Status
    await tester.tap(find.text('Célibataire').last);
    await tester.pumpAndSettle();

    print('STEP 6: Children');
    // Q5: Children
    await tester.tap(find.text('Aucun').last);
    await tester.pumpAndSettle();

    print('STEP 7: Employment');
    // Q6: Employment
    await tester.tap(find.text('Salarié(e)').last);
    await tester.pumpAndSettle();

    print('STEP 8: Pay Frequency');
    // Q7: Pay Frequency (Budget Section starts)
    await tester.tap(find.text('Mensuel').last);
    await tester.pumpAndSettle();

    print('STEP 9: Income');
    // Q8: Net Income
    await tester.enterText(
        find.byType(TextField).last, '10000'); // 10k/month => 120k/year

    // Tap Next to finalize answer
    await tapNext();

    print('STEP 10: Check Insight');

    // CHECK: Does the Insight appear?
    expect(find.byKey(const ValueKey('tax_freedom')), findsOneWidget);
    expect(find.textContaining('Miroir Fiscal'), findsOneWidget);

    // Check Neighbor Comp (VD -> VS/FR saves money)
    expect(find.byKey(const ValueKey('neighbor_comp')), findsOneWidget);
    expect(find.textContaining('Le Voisin'), findsOneWidget);
  });
}
