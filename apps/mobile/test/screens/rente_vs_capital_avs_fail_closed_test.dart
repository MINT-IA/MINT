import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

CoachProfile _profile({required bool certificateTagged}) {
  const fieldPath = AvsOfficialPensionEvidence.selfFieldPath;
  return CoachProfile(
    birthYear: 1976,
    canton: 'VD',
    salaireBrutMensuel: 9000,
    prevoyance: const PrevoyanceProfile(
      renteAVSEstimeeMensuelle: 2345,
      avoirLppTotal: 350000,
      tauxConversion: 0.06,
    ),
    dataSources: certificateTagged
        ? const {fieldPath: ProfileDataSource.certificate}
        : const {},
    dataTimestamps:
        certificateTagged ? {fieldPath: DateTime.utc(2026, 7, 13)} : const {},
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2041),
      label: 'Retraite',
    ),
  );
}

Widget _app(CoachProfile profile) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: _ProfileProvider(profile),
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: RenteVsCapitalScreen(),
    ),
  );
}

class _ProfileProvider extends CoachProfileProvider {
  _ProfileProvider(this.value);

  final CoachProfile value;

  @override
  CoachProfile? get profile => value;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rente-vs-capital source cannot consume the legacy AVS pension', () {
    final source = File(
      'lib/screens/arbitrage/rente_vs_capital_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('renteAVSEstimeeMensuelle')));
  });

  for (final certificateTagged in [false, true]) {
    testWidgets(
        'rente-vs-capital hides ${certificateTagged ? 'certificate-tagged' : 'legacy'} AVS amount but keeps LPP comparison',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 8000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(_profile(
        certificateTagged: certificateTagged,
      )));
      await tester.pump();

      expect(
        find.textContaining('AVS estimée', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining("2'345", findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('Rente', findRichText: true), findsWidgets);
      expect(find.textContaining('Capital', findRichText: true), findsWidgets);
      expect(find.textContaining('Mixte', findRichText: true), findsWidgets);
    });
  }
}
