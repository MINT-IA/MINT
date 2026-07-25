import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
import 'package:mint_mobile/services/donation_service.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for donation_screen.
///
/// Every assertion is on the RENDERED figure (a keyed CHF Text) or the rendered
/// [SituationGateCard], never on an internal bool: a refactor that keeps the
/// number but swaps the flag is still caught. Each test goes RED if the gate is
/// removed.

// ── Figure keys (mirror donation_screen.dart) ──
const _taxCard = Key('donationTaxCard');
const _reserveFigure = Key('donationReserveFigure');

// ── Swiss CHF formatter (mirrors donation_screen._chfFmt) ──
String _chf(double value) {
  final intVal = value.round();
  final isNeg = intVal < 0;
  final str = intVal.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write("'");
    buf.write(str[i]);
  }
  return 'CHF ${isNeg ? '-' : ''}$buf';
}

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

class _MutableProvider extends CoachProfileProvider {
  CoachProfile? _p;
  @override
  CoachProfile? get profile => _p;
  void hydrate(CoachProfile p) {
    _p = p;
    notifyListeners();
  }
}

CoachProfile _profile({
  int birthYear = 1965,
  String canton = 'GE',
  int nombreEnfants = 0,
  double epargneLiquide = 0,
  double dette = 0,
  Set<String> provided = const {},
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

Future<void> _tapCalculer(WidgetTester tester) async {
  final btn = find.byType(FilledButton);
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

Future<void> _touchNbEnfants(WidgetTester tester, int v) async {
  final picker = tester
      .widgetList<MintPickerTile>(find.byType(MintPickerTile))
      .firstWhere((p) => p.maxValue == 6);
  picker.onChanged(v);
  await tester.pump();
}

Future<void> _touchFortune(WidgetTester tester, double v) async {
  final field = tester
      .widgetList<MintAmountField>(find.byType(MintAmountField))
      .firstWhere((f) => f.min == 0 && f.max == 5000000);
  field.onChanged(v);
  await tester.pump();
}

Future<void> _touchCanton(WidgetTester tester, String c) async {
  final dd = tester.widget<DropdownButton<String>>(
    find.byType(DropdownButton<String>),
  );
  dd.onChanged!(c);
  await tester.pump();
}

Future<void> _touchRegime(WidgetTester tester, String regime) async {
  final gd = tester.widget<GestureDetector>(
    find.byKey(ValueKey('donationRegime_$regime')),
  );
  gd.onTap!();
  await tester.pump();
}

void main() {
  // ── 1. No profile → tap → both figures gone, two gate cards ──
  testWidgets('no profile: both outputs gated, two gate cards list facts',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _tapCalculer(tester);

    expect(find.byKey(_taxCard), findsNothing,
        reason: 'tax figure must not compute on a fabricated canton');
    expect(find.byKey(_reserveFigure), findsNothing,
        reason: 'réserve figure must not compute on fabricated facts');

    final gateCards =
        tester.widgetList<SituationGateCard>(find.byType(SituationGateCard));
    expect(gateCards.length, 2, reason: 'one gate per gated output');
    final allMissing =
        gateCards.expand((c) => c.gate.missing.map((f) => f.key)).toSet();
    expect(allMissing, containsAll(<String>['canton', 'nbEnfants', 'fortune', 'regime']));
  });

  // ── 2. Canton-only profile → tax unlocks, réserve still gated ──
  testWidgets('canton-only: tax computes, réserve still gated on 3 facts',
      (tester) async {
    await _pump(
      tester,
      _FakeProvider(_profile(canton: 'GE', provided: {'canton'})),
    );
    await _tapCalculer(tester);

    expect(find.byKey(_taxCard), findsOneWidget,
        reason: 'tax gates on canton only, which is confirmed');
    expect(find.byKey(_reserveFigure), findsNothing,
        reason: 'réserve still needs nbEnfants + fortune + régime');

    final gate =
        tester.widget<SituationGateCard>(find.byType(SituationGateCard));
    expect(gate.gate.missing.map((f) => f.key),
        containsAll(<String>['nbEnfants', 'fortune', 'regime']));
  });

  // ── 3. Complete → both figures; réserve equals the service output ──
  testWidgets('complete: both outputs show, réserve == DonationService output',
      (tester) async {
    await _pump(
      tester,
      _FakeProvider(_profile(
        birthYear: 1965,
        canton: 'VD',
        epargneLiquide: 1000000,
        provided: {'canton', 'liquidSavings'},
      )),
    );
    await _touchNbEnfants(tester, 2);
    await _touchRegime(tester, 'participation_acquets');
    await _tapCalculer(tester);

    expect(find.byKey(_taxCard), findsOneWidget);
    expect(find.byType(SituationGateCard), findsNothing,
        reason: 'no gate remains when every fact is confirmed');

    final age = _state(tester).debugDonateurAge as int;
    final expected = DonationService.calculate(
      montant: 100000,
      donateurAge: age,
      lienParente: 'descendant',
      canton: 'VD',
      typeDonation: 'especes',
      valeurImmobiliere: 500000,
      avancementHoirie: true,
      nbEnfants: 2,
      fortuneTotaleDonateur: 1000000,
      regimeMatrimonial: 'participation_acquets',
    );
    final figure = tester.widget<Text>(find.byKey(_reserveFigure));
    expect(figure.data, _chf(expected.reserveHereditaireTotale));
  });

  // ── 4. No profile, user touches every control → outputs show ──
  testWidgets('touched-all path: confirmation via touch unlocks both outputs',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _touchCanton(tester, 'GE');
    await _touchFortune(tester, 500000);
    await _touchNbEnfants(tester, 2);
    await _touchRegime(tester, 'participation_acquets');
    await _tapCalculer(tester);

    expect(find.byKey(_taxCard), findsOneWidget);
    expect(find.byKey(_reserveFigure), findsOneWidget);
    expect(find.byType(SituationGateCard), findsNothing);
  });

  // ── 5. Two-notification race → fortune confirms after the 2nd notify ──
  testWidgets('race: fortune provenance flips confirmed after the 2nd notify',
      (tester) async {
    final fake = _MutableProvider();
    await _pump(tester, fake);
    expect(find.text('Compléter ma situation (0/4)'), findsOneWidget,
        reason: 'nothing confirmed before hydration');

    // Notify #1 — canton only.
    fake.hydrate(_profile(canton: 'GE', provided: {'canton'}));
    await tester.pump();
    expect(find.text('Compléter ma situation (1/4)'), findsOneWidget,
        reason: 'only canton confirmed after the 1st notify');

    // Notify #2 — canton + liquidSavings. A global _prefilled latch would
    // early-return here and strand fortune at 1/4.
    fake.hydrate(_profile(
      canton: 'GE',
      epargneLiquide: 500000,
      provided: {'canton', 'liquidSavings'},
    ));
    await tester.pump();
    expect(find.text('Compléter ma situation (2/4)'), findsOneWidget,
        reason: 'fortune confirms on the 2nd notify — latch is gone');
  });

  // ── 6a. Default-collision (with provenance) → shown ──
  // Value 800000 EQUALS the fabricated default, but the liquidSavings key is
  // present → confirmed → réserve shows. Fresh state (separate test) so no
  // provenance bleeds in from a sibling case.
  testWidgets('default-collision A: key present → identical value shows',
      (tester) async {
    await _pump(
      tester,
      _FakeProvider(_profile(
        canton: 'VD',
        epargneLiquide: 800000,
        provided: {'canton', 'liquidSavings'},
      )),
    );
    await _touchNbEnfants(tester, 2);
    await _touchRegime(tester, 'participation_acquets');
    await _tapCalculer(tester);
    expect(find.byKey(_reserveFigure), findsOneWidget,
        reason: 'fortune 800000 is confirmed by its provenance key');
  });

  // ── 6b. Default-collision (no provenance) → gated ──
  // No profile: the same 800000 sits in the field as a default, fortune is
  // unconfirmed → réserve gated. Same pixels as 6a, opposite gate.
  testWidgets('default-collision B: no key → identical value stays gated',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _touchNbEnfants(tester, 2);
    await _touchRegime(tester, 'participation_acquets');
    await _tapCalculer(tester);
    expect(find.byKey(_reserveFigure), findsNothing,
        reason: 'identical 800000 with no provenance stays gated');
    expect(find.byType(SituationGateCard), findsWidgets);
  });

  // ── 7. Stale invalidation → editing a fact removes the prior figure ──
  testWidgets('stale invalidation: a figure never outlives a fact change',
      (tester) async {
    await _pump(
      tester,
      _FakeProvider(_profile(
        canton: 'VD',
        epargneLiquide: 1000000,
        provided: {'canton', 'liquidSavings'},
      )),
    );
    await _touchNbEnfants(tester, 2);
    await _touchRegime(tester, 'participation_acquets');
    await _tapCalculer(tester);
    expect(find.byKey(_reserveFigure), findsOneWidget);

    // Edit a determinative fact (fortune) after the figure is shown.
    await _touchFortune(tester, 600000);
    expect(find.byKey(_reserveFigure), findsNothing,
        reason: 'the displayed réserve must vanish when fortune changes');
    expect(find.byKey(_taxCard), findsNothing,
        reason: 'the whole result area is invalidated until re-computed');
  });
}
