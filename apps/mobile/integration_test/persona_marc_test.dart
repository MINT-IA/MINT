import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Persona Marc (Debt) - Safe Mode', (WidgetTester tester) async {
    // 1. App Startup
    await TaxScalesLoader.load();
    await tester.pumpWidget(const MintApp());
    await tester.pumpAndSettle();

    // START
    await tester.tap(find.text("Démarrer mon diagnostic"));
    await tester.pumpAndSettle();

    // WIZARD FLOW (Marc - Debt)
    // Q1: Name
    await tester.enterText(find.byType(TextField), "Marc");
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle();

    // Q2-Q9 Skip through (Defaults ok)
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle(); // Year
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle(); // Canton
    await tester.tap(find.text("Célibataire"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Non"));
    await tester.pumpAndSettle(); // Children
    await tester.tap(find.text("Salarié"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "6000");
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle(); // Income
    await tester.tap(find.text("Locataire"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "1500");
    await tester.tap(find.text("Suivant"));
    await tester.pumpAndSettle(); // Rent

    // Q10: Debt (YES) -> CRITICAL
    await tester.tap(find.text("Oui"));
    await tester.pumpAndSettle();

    // Screenshot the acknowledgment or next step if relevant
    await binding.takeScreenshot('04_marc_debt_yes');

    // Finish Wizard (Skip rest)
    for (int i = 0; i < 15; i++) {
      if (find.text("Ton Plan Mint").evaluate().isNotEmpty) break;
      if (find.text("Non").evaluate().isNotEmpty)
        await tester.tap(find.text("Non").first);
      else if (find.text("Suivant").evaluate().isNotEmpty)
        await tester.tap(find.text("Suivant"));
      await tester.pumpAndSettle();
    }

    // REPORT
    await tester.pumpAndSettle();
    // Verify RED CARD "Rembourse tes dettes"
    expect(find.textContaining("Rembourse tes dettes"), findsOneWidget,
        reason: "Red Debt Card missing");
    await binding.takeScreenshot('05_report_marc_alert');

    // NAVIGATE TO TOOLS
    await tester.tap(find.text("EXPLORER"));
    await tester.pumpAndSettle();

    await tester
        .tap(find.textContaining("Outils")); // Or whatever tile leads to tools
    await tester.pumpAndSettle();

    // Verify Safe Mode Gate
    expect(find.text("Concentration Prioritaire"), findsOneWidget);
    await binding.takeScreenshot('06_safe_mode_gate');
  });
}
