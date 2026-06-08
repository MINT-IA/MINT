import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart';

void main() {
  testWidgets('3a lever copy frames tax impact as an estimate', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale('fr'),
        home: Scaffold(
          body: MintScene3aLevier(
            netMonthly: 6000,
            cantonCode: 'VD',
            isRange: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('retombe sur ton compte'), findsNothing);
    expect(find.textContaining('peut réduire ton impôt'), findsNothing);
    expect(find.textContaining('économie fiscale estimée'), findsNothing);
    expect(
        find.textContaining('diminuer ton revenu imposable'), findsOneWidget);
    expect(find.textContaining('impact fiscal indicatif'), findsOneWidget);
    expect(find.textContaining("CHF\u00a07'258"), findsOneWidget);
  });
}
