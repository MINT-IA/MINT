import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/arbitrage_bilan_screen.dart';
import 'package:mint_mobile/services/financial_core/generated/regulatory_constants.g.dart';

CoachProfile _profileWithRvcData({
  double tauxConversion = 0.05,
}) {
  return CoachProfile(
    firstName: 'Marc',
    birthYear: 1980,
    canton: 'VD',
    etatCivil: CoachCivilStatus.celibataire,
    salaireBrutMensuel: 9000,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 360000,
      totalEpargne3a: 0,
    ).copyWith(
      tauxConversion: tauxConversion,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

Widget _wrap(CoachProfile profile) {
  return ChangeNotifierProvider<CoachProfileProvider>(
    create: (_) => CoachProfileProvider()..updateProfile(profile),
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: ArbitrageBilanScreen(),
    ),
  );
}

void main() {
  testWidgets('RvC bilan omits the card when receipt is incomplete',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(_profileWithRvcData(tauxConversion: 0)));
    await tester.pumpAndSettle();

    expect(find.text('Rente vs Capital'), findsNothing);
    expect(
      find.byKey(const Key('rente_vs_capital_calculation_receipt')),
      findsNothing,
    );
  });

  testWidgets('RvC bilan card carries receipt metadata with visible figures',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(_profileWithRvcData()));
    await tester.pumpAndSettle();

    expect(find.textContaining('de potentiel identifié'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Rente vs Capital'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.textContaining('/mois'), findsWidgets);
    expect(find.textContaining('mobile_l1_arbitrage_engine'), findsOneWidget);
    expect(find.textContaining('rvc-arbitrage-engine-v1'), findsOneWidget);
    expect(
      find.textContaining(regulatoryConstantsVersionHash.substring(0, 12)),
      findsOneWidget,
    );
    expect(find.textContaining('CHF/mois'), findsOneWidget);
    expect(find.textContaining('Ce que ton capital rapporte'), findsOneWidget);
    expect(find.textContaining('LPP art. 14'), findsWidgets);
    expect(find.textContaining('LIFD art. 22'), findsWidgets);
    expect(find.textContaining('Confiance'), findsWidgets);
    expect(find.textContaining('Aucun champ requis manquant'), findsOneWidget);
  });
}
