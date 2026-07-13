import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/widgets/profile/financial_drawer.dart';
import 'package:mint_mobile/widgets/profile/futur_drawer_content.dart';
import 'package:mint_mobile/widgets/profile/hero_gap_card.dart';
import 'package:mint_mobile/widgets/profile/patrimoine_drawer_content.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyAvs = 2345.0;
const _spouseLegacyAvs = 1234.0;

CoachProfile _profile({
  double? avs,
  bool certificateTagged = false,
  CoachCivilStatus civilStatus = CoachCivilStatus.celibataire,
  ConjointProfile? spouse,
}) {
  const fieldPath = AvsOfficialPensionEvidence.selfFieldPath;
  return CoachProfile(
    firstName: 'Alex',
    birthYear: 1980,
    canton: 'VD',
    salaireBrutMensuel: 8000,
    etatCivil: civilStatus,
    conjoint: spouse,
    depenses: const DepensesProfile(
      loyer: 1800,
      assuranceMaladie: 450,
    ),
    prevoyance: PrevoyanceProfile(
      renteAVSEstimeeMensuelle: avs,
      avoirLppTotal: 300000,
      tauxConversion: 0.06,
      totalEpargne3a: 40000,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 30000,
      investissements: 50000,
    ),
    dataSources: certificateTagged
        ? const {fieldPath: ProfileDataSource.certificate}
        : const {},
    dataTimestamps:
        certificateTagged ? {fieldPath: DateTime.utc(2026, 7, 13)} : const {},
    userProvidedFields: const {
      'monthlyExpenses',
      'liquidSavingsAmount',
    },
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

ConjointProfile _spouse({double? avs}) => ConjointProfile(
      firstName: 'Sam',
      birthYear: 1982,
      salaireBrutMensuel: 6000,
      prevoyance: PrevoyanceProfile(
        renteAVSEstimeeMensuelle: avs,
        avoirLppTotal: 180000,
        tauxConversion: 0.06,
        totalEpargne3a: 20000,
      ),
    );

Widget _localized(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

class _ProfileProvider extends CoachProfileProvider {
  _ProfileProvider(this.value);

  final CoachProfile value;

  @override
  CoachProfile? get profile => value;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final contexts = <String, CoachProfile>{
    'missing': _profile(),
    'legacy non-null': _profile(avs: _legacyAvs),
    'certificate tag plus timestamp': _profile(
      avs: _legacyAvs,
      certificateTagged: true,
    ),
    'married with missing spouse pension': _profile(
      avs: _legacyAvs,
      civilStatus: CoachCivilStatus.marie,
      spouse: _spouse(),
    ),
    'cohabiting with self legacy pension': _profile(
      avs: _legacyAvs,
      civilStatus: CoachCivilStatus.concubinage,
      spouse: _spouse(avs: _spouseLegacyAvs),
    ),
  };

  group('FuturDrawerContent official-pension boundary', () {
    for (final entry in contexts.entries) {
      testWidgets('${entry.key} stays partial and preserves non-AVS sources',
          (tester) async {
        await tester.pumpWidget(_localized(
          FuturDrawerContent(profile: entry.value),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining("2'345"), findsNothing);
        expect(find.textContaining("1'234"), findsNothing);
        expect(find.textContaining('CHF 0/mois'), findsNothing);
        expect(find.text('Taux de remplacement'), findsNothing);
        expect(find.text('Total mensuel projeté'), findsNothing);
        expect(find.text('Total couple projeté'), findsNothing);
        expect(find.text('Rente LPP estimée'), findsOneWidget);
        expect(find.textContaining('Capital total'), findsOneWidget);
        expect(find.text('Demande ton calcul AVS officiel'), findsOneWidget);
      });
    }
  });

  group('PatrimoineDrawerContent official-pension boundary', () {
    for (final certificateTagged in [false, true]) {
      testWidgets(
          '${certificateTagged ? 'certificate-tagged' : 'legacy'} amount is hidden',
          (tester) async {
        await tester.pumpWidget(_localized(PatrimoineDrawerContent(
          profile: _profile(
            avs: _legacyAvs,
            certificateTagged: certificateTagged,
          ),
        )));
        await tester.pumpAndSettle();

        expect(find.textContaining("2'345"), findsNothing);
        expect(find.text('Rente estimée'), findsOneWidget);
        expect(find.text('Demande ton calcul AVS officiel'), findsOneWidget);
        expect(find.textContaining("300'000"), findsWidgets);
      });
    }
  });

  testWidgets('FinancialSummaryScreen never constructs an AVS-dependent gap',
      (tester) async {
    final provider = _ProfileProvider(_profile(avs: _legacyAvs));

    await tester.pumpWidget(
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: provider,
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: FinancialSummaryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HeroGapCard), findsOneWidget);
    expect(find.text('Demande ton calcul AVS officiel'), findsWidgets);
    final futureDrawer =
        tester.widgetList<FinancialDrawer>(find.byType(FinancialDrawer)).last;
    expect(futureDrawer.heroValue, '\u2014');
  });
}
