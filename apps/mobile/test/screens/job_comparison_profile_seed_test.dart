import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:provider/provider.dart';

/// SALVAGE-01-03 (def-04): job_comparison_screen must seed its "current job"
/// side from the real CoachProfile (age via ageOrNull, annual gross, prevoyance
/// avoir/conversion-rate) instead of the static fixtures
/// 35 / 85000 / 5.2 / 120000. When a field is absent it must keep its default;
/// when no profile / null age it must not crash.

/// Test double: lets the test inject an arbitrary profile (or null) without
/// touching SharedPreferences-backed persistence in `updateProfile`.
class _FakeCoachProfileProvider extends CoachProfileProvider {
  _FakeCoachProfileProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

CoachProfile _profileWith({
  required int birthYear,
  required double salaireBrutMensuel,
  double? avoirLppTotal,
  double? tauxConversionSuroblig,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: 'VD',
    salaireBrutMensuel: salaireBrutMensuel,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLppTotal,
      tauxConversionSuroblig: tauxConversionSuroblig,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65),
      label: 'Retraite',
    ),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CoachProfileProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: JobComparisonScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Reads back the seeded current-job inputs via the @visibleForTesting getters.
({int age, double salaireBrut, double avoir, double taux}) _read(
  WidgetTester tester,
) {
  final state = tester.state(find.byType(JobComparisonScreen)) as dynamic;
  return (
    age: state.debugAge as int,
    salaireBrut: state.debugCurrentSalaireBrut as double,
    avoir: state.debugCurrentAvoirVieillesse as double,
    taux: state.debugCurrentTauxConversion as double,
  );
}

void main() {
  final currentYear = DateTime.now().year;

  testWidgets(
    'seeds age / annual gross / avoir / taux from a profile with prevoyance',
    (tester) async {
      final profile = _profileWith(
        birthYear: currentYear - 42, // ageOrNull → 42
        salaireBrutMensuel: 9000, // → annual 108000 (×12, no bonus)
        avoirLppTotal: 250000,
        tauxConversionSuroblig: 0.058, // → 5.8%
      );
      await _pumpScreen(tester, _FakeCoachProfileProvider(profile));

      final s = _read(tester);
      expect(s.age, 42, reason: 'age seeded from ageOrNull, not 35');
      expect(s.salaireBrut, closeTo(108000, 0.01),
          reason: 'annual gross seeded from profile, not 85000');
      expect(s.avoir, closeTo(250000, 0.01),
          reason: 'avoir seeded from prevoyance.avoirLppTotal, not 120000');
      expect(s.taux, closeTo(5.8, 0.001),
          reason: 'taux seeded from tauxConversionSuroblig*100, not 5.2');
    },
  );

  testWidgets(
    'keeps avoir 120000 and taux 5.2 defaults when prevoyance fields absent',
    (tester) async {
      final profile = _profileWith(
        birthYear: currentYear - 30,
        salaireBrutMensuel: 7000, // → annual 84000
        // avoirLppTotal: null, tauxConversionSuroblig: null
      );
      await _pumpScreen(tester, _FakeCoachProfileProvider(profile));

      final s = _read(tester);
      expect(s.age, 30);
      expect(s.salaireBrut, closeTo(84000, 0.01));
      expect(s.avoir, closeTo(120000, 0.01),
          reason: 'avoir keeps static default when prevoyance avoir absent');
      expect(s.taux, closeTo(5.2, 0.001),
          reason: 'taux keeps static default when conversion rate absent');
    },
  );

  testWidgets('keeps ALL defaults and does not crash when no profile',
      (tester) async {
    await _pumpScreen(tester, _FakeCoachProfileProvider(null));

    final s = _read(tester);
    expect(s.age, 35);
    expect(s.salaireBrut, closeTo(85000, 0.01));
    expect(s.avoir, closeTo(120000, 0.01));
    expect(s.taux, closeTo(5.2, 0.001));
  });

  testWidgets('keeps default age when profile age is null (no fabrication)',
      (tester) async {
    // birthYear 0 → ageOrNull returns null (sentinel); must NOT fabricate.
    final profile = _profileWith(
      birthYear: 0,
      salaireBrutMensuel: 8000, // annual 96000 still seeds salary
    );
    await _pumpScreen(tester, _FakeCoachProfileProvider(profile));

    final s = _read(tester);
    expect(s.age, 35, reason: 'null age keeps default, never fabricated');
    expect(s.salaireBrut, closeTo(96000, 0.01));
  });
}
