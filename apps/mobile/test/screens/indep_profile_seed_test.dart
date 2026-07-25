import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/independants/lpp_volontaire_screen.dart';
import 'package:mint_mobile/screens/independants/pillar_3a_indep_screen.dart';
import 'package:provider/provider.dart';

/// P2 (zéro donnée inventée) : les deux écrans indépendants doivent amorcer
/// leur revenu net (et l'âge / l'affiliation LPP) depuis le vrai [CoachProfile]
/// plutôt que depuis les fixtures statiques 100000 / 80000 / 40 / false.
///
/// Couvre aussi la course d'hydratation asynchrone : `loadFromWizard()` peuple
/// le profil APRÈS le montage de l'écran, donc le seed doit se déclencher via
/// notification du provider et non par une lecture unique au montage.

/// Fake immuable : injecte un profil (ou null) déjà présent au montage.
class _FakeCoachProfileProvider extends CoachProfileProvider {
  _FakeCoachProfileProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

/// Fake mutable : démarre sans profil puis l'hydrate (course asynchrone).
class _MutableFakeProvider extends CoachProfileProvider {
  CoachProfile? _p;
  @override
  CoachProfile? get profile => _p;
  void hydrate(CoachProfile p) {
    _p = p;
    notifyListeners();
  }
}

CoachProfile _indepProfile({
  required int birthYear,
  double? independentNet,
  Set<String> userProvidedFields = const {},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: 'VD',
    salaireBrutMensuel: 0,
    employmentStatus: 'independant',
    independentNetProfessionalIncomeAnnual: independentNet,
    userProvidedFields: userProvidedFields,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  CoachProfileProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final currentYear = DateTime.now().year;

  group('Pillar3aIndepScreen — P2 profile seed', () {
    testWidgets('seeds _revenuNet from independent net income', (tester) async {
      final profile = _indepProfile(
        birthYear: currentYear - 45,
        independentNet: 140000,
      );
      await _pump(tester, const Pillar3aIndepScreen(),
          _FakeCoachProfileProvider(profile));

      final state = tester.state(find.byType(Pillar3aIndepScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(140000, 0.01),
          reason: 'seeded from profile, not the static 100000 default');
    });

    testWidgets('keeps 100000 default when net income absent', (tester) async {
      final profile = _indepProfile(birthYear: currentYear - 45);
      await _pump(tester, const Pillar3aIndepScreen(),
          _FakeCoachProfileProvider(profile));

      final state = tester.state(find.byType(Pillar3aIndepScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(100000, 0.01),
          reason: 'no fabrication: absent field keeps editable default');
    });

    testWidgets('clamps net income above slider max (300000)', (tester) async {
      final profile = _indepProfile(
        birthYear: currentYear - 45,
        independentNet: 999999,
      );
      await _pump(tester, const Pillar3aIndepScreen(),
          _FakeCoachProfileProvider(profile));

      final state = tester.state(find.byType(Pillar3aIndepScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(300000, 0.01),
          reason: 'clamped to slider max to avoid an out-of-range assert');
    });

    testWidgets('seeds _affilieLpp=true from explicit pensionFundYes',
        (tester) async {
      final profile = _indepProfile(
        birthYear: currentYear - 45,
        independentNet: 90000,
        userProvidedFields: {'pensionFundYes'},
      );
      await _pump(tester, const Pillar3aIndepScreen(),
          _FakeCoachProfileProvider(profile));

      final state = tester.state(find.byType(Pillar3aIndepScreen)) as dynamic;
      expect(state.debugAffilieLpp, isTrue,
          reason: 'known affiliation truth used, not fabricated false');
    });

    testWidgets('keeps _affilieLpp=false default when affiliation unknown',
        (tester) async {
      final profile = _indepProfile(
        birthYear: currentYear - 45,
        independentNet: 90000,
      );
      await _pump(tester, const Pillar3aIndepScreen(),
          _FakeCoachProfileProvider(profile));

      final state = tester.state(find.byType(Pillar3aIndepScreen)) as dynamic;
      expect(state.debugAffilieLpp, isFalse,
          reason: 'unknown affiliation keeps editable default (no fabrication)');
    });

    testWidgets('seeds when profile hydrates AFTER mount (async load race)',
        (tester) async {
      final fake = _MutableFakeProvider();
      await _pump(tester, const Pillar3aIndepScreen(), fake);

      var state = tester.state(find.byType(Pillar3aIndepScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(100000, 0.01),
          reason: 'default while profile not yet hydrated');

      fake.hydrate(_indepProfile(
        birthYear: currentYear - 45,
        independentNet: 140000,
      ));
      await tester.pump();

      state = tester.state(find.byType(Pillar3aIndepScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(140000, 0.01),
          reason: 'seeds once profile hydrates via notifyListeners — not '
              'permanently stranded on the fabricated default');
    });

    testWidgets('keeps default and does not crash with no profile',
        (tester) async {
      await _pump(tester, const Pillar3aIndepScreen(),
          _FakeCoachProfileProvider(null));

      final state = tester.state(find.byType(Pillar3aIndepScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(100000, 0.01));
    });
  });

  group('LppVolontaireScreen — P2 profile seed', () {
    testWidgets('seeds _revenuNet and _age from profile', (tester) async {
      final profile = _indepProfile(
        birthYear: currentYear - 52, // ageOrNull → 52
        independentNet: 120000,
      );
      await _pump(tester, const LppVolontaireScreen(),
          _FakeCoachProfileProvider(profile));

      final state = tester.state(find.byType(LppVolontaireScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(120000, 0.01),
          reason: 'seeded from profile, not the static 80000 default');
      expect(state.debugAge, 52,
          reason: 'age seeded from ageOrNull, not the static 40 default');
    });

    testWidgets('keeps 80000 / 40 defaults when fields absent', (tester) async {
      // birthYear 0 → ageOrNull null; no independentNet.
      final profile = _indepProfile(birthYear: 0);
      await _pump(tester, const LppVolontaireScreen(),
          _FakeCoachProfileProvider(profile));

      final state = tester.state(find.byType(LppVolontaireScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(80000, 0.01),
          reason: 'no fabrication: absent net keeps default');
      expect(state.debugAge, 40,
          reason: 'no fabrication: null age keeps default, never invented');
    });

    testWidgets('clamps net (250000) and age (25..65) to control bounds',
        (tester) async {
      final profile = _indepProfile(
        birthYear: currentYear - 90, // age 90 → clamp to 65
        independentNet: 999999,
      );
      await _pump(tester, const LppVolontaireScreen(),
          _FakeCoachProfileProvider(profile));

      final state = tester.state(find.byType(LppVolontaireScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(250000, 0.01),
          reason: 'clamped to slider max');
      expect(state.debugAge, 65, reason: 'clamped to picker max');
    });

    testWidgets('seeds when profile hydrates AFTER mount (async load race)',
        (tester) async {
      final fake = _MutableFakeProvider();
      await _pump(tester, const LppVolontaireScreen(), fake);

      var state = tester.state(find.byType(LppVolontaireScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(80000, 0.01));
      expect(state.debugAge, 40);

      fake.hydrate(_indepProfile(
        birthYear: currentYear - 52,
        independentNet: 120000,
      ));
      await tester.pump();

      state = tester.state(find.byType(LppVolontaireScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(120000, 0.01),
          reason: 'seeds once profile hydrates — not stranded on default');
      expect(state.debugAge, 52);
    });

    testWidgets('keeps defaults and does not crash with no profile',
        (tester) async {
      await _pump(tester, const LppVolontaireScreen(),
          _FakeCoachProfileProvider(null));

      final state = tester.state(find.byType(LppVolontaireScreen)) as dynamic;
      expect(state.debugRevenuNet, closeTo(80000, 0.01));
      expect(state.debugAge, 40);
    });
  });
}
