import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Persona Lea (Starter) - Full Golden Path',
      (WidgetTester tester) async {
    // 1. App Startup
    await TaxScalesLoader.load(); // Preload assets if needed
    await tester.pumpWidget(const MintApp());
    await tester.pumpAndSettle();

    // Verify Welcome Screen
    expect(find.text("MINT"), findsOneWidget, reason: "App Title missing");

    // START DIAGNOSTIC
    await tester.tap(find.text("Démarrer mon diagnostic"));
    await tester.pumpAndSettle();

    // WIZARD FLOW
    // Q1: Name
    await tester.enterText(find.byType(TextField), "Léa");
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle();

    // Q2: Birth Year (2002)
    final slider = find.byType(Slider);
    if (slider.evaluate().isNotEmpty) {
      // Drag slider if possible, or just skip relying on default for now to be safe
      // Default is often middle range. Let's assume default is OK or try to move it.
    }
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle();

    // Q3: Canton (VD)
    await tester.tap(find.text("Suivant")); // Default is often VD or first
    await tester.pumpAndSettle();

    // Q4: Civil Status (Single)
    await tester.tap(find.text("Célibataire"));
    await tester.pumpAndSettle(); // Auto-advance?

    // Q5: Children (0)
    await tester.tap(find.text("Non"));
    await tester.pumpAndSettle();

    // Q6: Job (Employee)
    await tester.tap(find.text("Salarié"));
    await tester.pumpAndSettle();

    // SECTION TRANSITION: PROFIL -> BUDGET
    // Expect Circle Transition - Wait for animation
    await tester.pump(const Duration(seconds: 2));
    // Screenshot Transition
    try {
      await binding.takeScreenshot('01_circle_transition_budget');
    } catch (e) {
      debugPrint('Screenshot failed: $e');
    }

    // Q7: Net Income (3800)
    await tester.enterText(find.byType(TextField), "3800");
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle();

    // Q8: Housing (Tenant)
    await tester.tap(find.text("Locataire"));
    await tester.pumpAndSettle();

    // Q9: Housing Cost (1200)
    await tester.enterText(find.byType(TextField), "1200");
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle();

    // Q10: Debt (No)
    await tester.tap(find.text("Non"));
    await tester.pumpAndSettle();

    // Q11: Emergency Fund (No, <3m)
    await tester.tap(find.textContaining("Moins de 3 mois"));
    await tester.pumpAndSettle();

    // Q12: Savings (200)
    await tester.enterText(find.byType(TextField), "200");
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle();

    // SECTION TRANSITION
    await tester.pump(const Duration(seconds: 2));

    // Q13: LPP (Yes)
    await tester.tap(find.text("Oui"));
    await tester.pumpAndSettle();

    // Q14: 3a (No)
    await tester.tap(find.text("Non"));
    await tester.pumpAndSettle();

    // Skip/Fast Forward (Assume defaults/No for rest)
    // Q15...
    // Simply loop taps on "Non" or "Suivant" until Report
    // This handles variable question count
    for (int i = 0; i < 10; i++) {
      if (find.text("Ton Plan Mint").evaluate().isNotEmpty) break;

      if (find.text("Non").evaluate().isNotEmpty) {
        await tester.tap(find.text("Non").first);
      } else if (find.text("Suivant").evaluate().isNotEmpty) {
        await tester.tap(find.text("Suivant"));
      } else if (find.text("Je ne sais pas").evaluate().isNotEmpty) {
        await tester.tap(find.text("Je ne sais pas"));
      }
      await tester.pumpAndSettle();
    }

    // REPORT
    expect(find.text("Ton Plan Mint"), findsOneWidget);
    await binding.takeScreenshot('02_report_lea_top');

    // Verify Emergency Fund Action
    expect(find.textContaining("fonds d'urgence"), findsOneWidget);

    // Scroll down
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03_report_lea_bottom');
  });
}
