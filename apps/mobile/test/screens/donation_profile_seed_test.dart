import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:provider/provider.dart';

/// P2 (zéro donnée inventée) : donation_screen amorce la SITUATION réelle du
/// donateur (âge, canton, nombre d'enfants, fortune nette) depuis le
/// [CoachProfile] au lieu des fixtures 55 / VD / 2 / 800000. Les paramètres du
/// scénario (montant du don, lien, type, valeur du bien donné, régime) restent
/// des hypothèses éditables et ne sont PAS amorcés.

class _FakeCoachProfileProvider extends CoachProfileProvider {
  _FakeCoachProfileProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

class _MutableFakeProvider extends CoachProfileProvider {
  CoachProfile? _p;
  @override
  CoachProfile? get profile => _p;
  void hydrate(CoachProfile p) {
    _p = p;
    notifyListeners();
  }
}

CoachProfile _donorProfile({
  required int birthYear,
  String canton = 'GE',
  int nombreEnfants = 0,
  double epargneLiquide = 0,
  double dette = 0,
  // P2 « gate dur » : le seed du canton et de la fortune n'a lieu que si leur
  // provenance est réelle (clé userProvidedFields), jamais valeur≠défaut. Les
  // cas « champs présents » fournissent donc les clés ; les cas « champs
  // absents » passent `provided: {}`.
  Set<String> provided = const {'canton', 'liquidSavings'},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: 0,
    nombreEnfants: nombreEnfants,
    patrimoine: PatrimoineProfile(epargneLiquide: epargneLiquide),
    dettes: DetteProfile(autresDettes: dette),
    userProvidedFields: provided,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(WidgetTester tester, CoachProfileProvider provider) async {
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
        home: DonationScreen(),
      ),
    ),
  );
  await tester.pump();
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(DonationScreen)) as dynamic;

void main() {
  final currentYear = DateTime.now().year;

  testWidgets('seeds age / canton / nbEnfants / fortune nette from profile',
      (tester) async {
    final profile = _donorProfile(
      birthYear: currentYear - 62, // age 62
      canton: 'GE',
      nombreEnfants: 3,
      epargneLiquide: 1200000,
      dette: 200000, // net = 1_000_000
    );
    await _pump(tester, _FakeCoachProfileProvider(profile));

    final s = _state(tester);
    expect(s.debugDonateurAge, 62, reason: 'age seeded, not the static 55');
    expect(s.debugCanton, 'GE', reason: 'canton seeded, not the static VD');
    expect(s.debugNbEnfants, 3, reason: 'children seeded, not the static 2');
    expect(s.debugFortuneTotale, closeTo(1000000, 0.01),
        reason: 'NET wealth (assets - debts), not the static 800000');
  });

  testWidgets('keeps static defaults when profile fields absent/empty',
      (tester) async {
    // birthYear 0 → ageOrNull null; nbEnfants 0 (ambigu) not seeded; net 0.
    // provided: {} → aucune provenance → canton/fortune gardent leurs défauts.
    final profile =
        _donorProfile(birthYear: 0, canton: 'unknown', provided: {});
    await _pump(tester, _FakeCoachProfileProvider(profile));

    final s = _state(tester);
    expect(s.debugDonateurAge, 55, reason: 'null age keeps default');
    expect(s.debugCanton, 'VD', reason: 'unknown canton keeps default');
    expect(s.debugNbEnfants, 2, reason: 'ambiguous 0 keeps default (no fab)');
    expect(s.debugFortuneTotale, closeTo(800000, 0.01),
        reason: 'net wealth 0 keeps default');
  });

  testWidgets('clamps fortune above max (5000000)', (tester) async {
    final profile = _donorProfile(
      birthYear: currentYear - 62,
      epargneLiquide: 9000000,
    );
    await _pump(tester, _FakeCoachProfileProvider(profile));
    expect(_state(tester).debugFortuneTotale, closeTo(5000000, 0.01));
  });

  testWidgets('does not crash and keeps defaults with no profile',
      (tester) async {
    await _pump(tester, _FakeCoachProfileProvider(null));
    final s = _state(tester);
    expect(s.debugDonateurAge, 55);
    expect(s.debugFortuneTotale, closeTo(800000, 0.01));
  });

  testWidgets('seeds when profile hydrates AFTER mount (async load race)',
      (tester) async {
    final fake = _MutableFakeProvider();
    await _pump(tester, fake);
    expect(_state(tester).debugDonateurAge, 55,
        reason: 'default while profile not yet hydrated');

    fake.hydrate(_donorProfile(
      birthYear: currentYear - 62,
      canton: 'GE',
      epargneLiquide: 500000,
    ));
    await tester.pump();

    final s = _state(tester);
    expect(s.debugDonateurAge, 62,
        reason: 'seeds once profile hydrates — not stranded on default');
    expect(s.debugCanton, 'GE');
    expect(s.debugFortuneTotale, closeTo(500000, 0.01));
  });

  testWidgets('does NOT overwrite a user fortune edit made before hydration',
      (tester) async {
    final fake = _MutableFakeProvider();
    await _pump(tester, fake);

    // User edits the fortune field during the race (profile still null).
    // The fortune MintAmountField is the last one in the succession section;
    // find it by its seeded default value 800000.
    final fields = tester
        .widgetList<MintAmountField>(find.byType(MintAmountField))
        .toList();
    final fortuneField =
        fields.firstWhere((f) => (f.value - 800000).abs() < 0.01);
    fortuneField.onChanged(1500000);
    await tester.pump();
    expect(_state(tester).debugFortuneTotale, closeTo(1500000, 0.01));

    // Profile hydrates late with a different net wealth + a fresh canton.
    fake.hydrate(_donorProfile(
      birthYear: currentYear - 62,
      canton: 'GE',
      epargneLiquide: 500000,
    ));
    await tester.pump();

    final s = _state(tester);
    expect(s.debugFortuneTotale, closeTo(1500000, 0.01),
        reason: 'user fortune edit preserved, not clobbered by late hydration');
    expect(s.debugCanton, 'GE',
        reason: 'the untouched canton still seeds from the profile');
  });
}
