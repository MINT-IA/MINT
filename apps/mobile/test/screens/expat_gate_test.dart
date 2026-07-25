import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/services/fiscal_service.dart';
import 'package:mint_mobile/widgets/coach/avs_gap_widget.dart';
import 'package:mint_mobile/widgets/coach/top_cantons_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for expat_screen.
///
/// The full-subtree audit found FIVE computed outputs, each gated on the facts
/// IT consumes (the manifest named three; two more — top-cantons and the
/// AvsGapWidget projection — surfaced from the subtree audit):
///   • Forfait fiscal (tab 1)      — forfaitCanton + livingExpenses + actualIncome
///                                    (TOUCH-ONLY, no clean profil source).
///   • Top cantons (tab 1)         — revenu réel + canton réel (profil only).
///   • Départ « capital en jeu » (tab 2 hero) — 3a + LPP (seedés).
///   • Lacune AVS (tab 3, _avsResult) — yearsInCh + yearsAbroad (TOUCH-ONLY).
///   • Projection AvsGapWidget (tab 3) — yearsInCh (touch) + âge réel (clé 'age').
///
/// Every assertion is on the RENDERED figure (a keyed result container / the
/// TopCantonWidget rankings / the AvsGapWidget inputs) or the rendered
/// [SituationGateCard], never on an internal bool. Each test goes RED if the
/// gate is removed (i.e. if the screen went back to auto-computing on the
/// fabricated defaults 1M / 5M / 80000 / 250000 / 20 / 10 / âge 40).
///
/// The screen is a `TabBarView` of lazy `ListView`s: only the current tab is
/// built, so tab-2/3 tests tap into their tab first, and a tall test surface
/// keeps each tab's result slot inflated without scrolling.

// ── Figure / result keys (mirror expat_screen.dart) ──
const _forfaitResult = Key('expatForfaitResult');
const _departHero = Key('expatDepartHero');
const _avsResult = Key('expatAvsResult');

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

  void clearProfile() {
    _p = null;
    notifyListeners();
  }
}

CoachProfile _profile({
  int birthYear = 1990,
  String canton = 'GE',
  double salaire = 0,
  int nombreEnfants = 0,
  double avoirLpp = 0,
  double epargne3a = 0,
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  Set<String> provided = const {},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    nombreEnfants: nombreEnfants,
    etatCivil: etatCivil,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLpp > 0 ? avoirLpp : null,
      totalEpargne3a: epargne3a,
    ),
    userProvidedFields: provided,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(WidgetTester tester, CoachProfileProvider provider) async {
  // Tall surface so each (lazy) tab's result slot is inflated without scrolling.
  await tester.binding.setSurfaceSize(const Size(1400, 9000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
        home: ExpatScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(ExpatScreen)) as dynamic;

Future<void> _goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Picks the gate card guarding the output that consumes [factKey] (several
/// gate cards can coexist on one tab).
SituationGateCard _gateWith(WidgetTester tester, String factKey) =>
    tester
        .widgetList<SituationGateCard>(find.byType(SituationGateCard))
        .firstWhere((c) => c.gate.facts.any((f) => f.key == factKey));

MintAmountField _amountField(
  WidgetTester tester, {
  required double min,
  required double max,
}) =>
    tester
        .widgetList<MintAmountField>(find.byType(MintAmountField))
        .firstWhere((f) => f.min == min && f.max == max);

// ── Forfait interactions (tab 1) ──
Future<void> _pumpEdit(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _touchForfaitCanton(WidgetTester tester, String c) async {
  tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .onChanged!(c);
  await _pumpEdit(tester);
}

Future<void> _touchLivingExpenses(WidgetTester tester, double v) async {
  _amountField(tester, min: 250000, max: 5000000).onChanged(v);
  await _pumpEdit(tester);
}

Future<void> _touchActualIncome(WidgetTester tester, double v) async {
  _amountField(tester, min: 500000, max: 20000000).onChanged(v);
  await _pumpEdit(tester);
}

// ── Départ interactions (tab 2) ──
Future<void> _touch3a(WidgetTester tester, double v) async {
  _amountField(tester, min: 0, max: 500000).onChanged(v);
  await _pumpEdit(tester);
}

Future<void> _touchLpp(WidgetTester tester, double v) async {
  _amountField(tester, min: 0, max: 1000000).onChanged(v);
  await _pumpEdit(tester);
}

// ── AVS interactions (tab 3) — two same-range pickers, disambiguated by order.
Future<void> _touchYearsInCh(WidgetTester tester, int v) async {
  tester.widgetList<MintPickerTile>(find.byType(MintPickerTile)).first.onChanged(v);
  await _pumpEdit(tester);
}

Future<void> _touchYearsAbroad(WidgetTester tester, int v) async {
  tester
      .widgetList<MintPickerTile>(find.byType(MintPickerTile))
      .toList()[1]
      .onChanged(v);
  await _pumpEdit(tester);
}

void main() {
  // ══════════════════════════════════════════════════════════════
  //  FORFAIT FISCAL (tab 1) — gated on canton + living expenses + income
  // ══════════════════════════════════════════════════════════════
  group('Forfait fiscal output', () {
    testWidgets(
        'no profile: forfait gated, lists {forfaitCanton, livingExpenses, actualIncome}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      expect(find.byKey(_forfaitResult), findsNothing,
          reason: 'no forfait figure on the fabricated 1M / 5M defaults');
      final gate = _gateWith(tester, 'livingExpenses');
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['forfaitCanton', 'livingExpenses', 'actualIncome']));
    });

    testWidgets('touch all 3 forfait facts: figure == ExpatService output',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _touchForfaitCanton(tester, 'GE');
      await _touchLivingExpenses(tester, 2000000);
      await _touchActualIncome(tester, 8000000);

      expect(_gateWith0(tester, 'livingExpenses'), isNull,
          reason: 'all three forfait facts confirmed → no forfait gate card');
      expect(find.byKey(_forfaitResult), findsOneWidget);
      final expected = ExpatService.simulateForfaitFiscal(
        canton: 'GE',
        livingExpenses: _state(tester).debugLivingExpenses as double,
        actualIncome: _state(tester).debugActualIncome as double,
      )['forfaitTax'] as double;
      expect(
        find.descendant(
            of: find.byKey(_forfaitResult),
            matching: find.text(ExpatService.formatChf(expected))),
        findsOneWidget,
        reason: 'the card renders simulateForfaitFiscal on the touched inputs',
      );
    });

    testWidgets('forfait stays gated until ALL three facts touched',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _touchLivingExpenses(tester, 2000000);
      await _touchActualIncome(tester, 8000000);
      // Canton still assumed (default VD) → gated.
      expect(find.byKey(_forfaitResult), findsNothing,
          reason: 'canton not touched → forfait stays gated');
      expect(_gateWith(tester, 'forfaitCanton').gate.missing.map((f) => f.key),
          contains('forfaitCanton'));
    });

    // actualIncome / livingExpenses are worldwide facts with NO profil source:
    // a Swiss salary must NEVER seed them (salaire×12 ≠ worldwide income).
    testWidgets(
        'huge profile salary does NOT seed forfait (worldwide facts touch-only)',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 500000, canton: 'GE', provided: {'salary', 'canton'})),
      );
      expect(find.byKey(_forfaitResult), findsNothing,
          reason: 'a 500k/mo salary must not seed the forfait income/expenses');
      expect(_state(tester).debugActualIncome, 5000000,
          reason: 'actualIncome stays the editable default, never salaire×12');
      expect(_state(tester).debugLivingExpenses, 1000000);
    });

    testWidgets('tiny profile salary also leaves forfait gated (no seed path)',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 100, canton: 'GE', provided: {'salary', 'canton'})),
      );
      expect(find.byKey(_forfaitResult), findsNothing);
      expect(_state(tester).debugActualIncome, 5000000);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TOP CANTONS (tab 1) — personalised ranking, gated on real income + canton
  // ══════════════════════════════════════════════════════════════
  group('Top cantons output', () {
    testWidgets('no profile: ranking gated, lists {income, canton}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(find.byType(TopCantonWidget), findsNothing,
          reason: 'no personalised ranking on the fabricated 5M / VD defaults');
      final gate = _gateWith(tester, 'income');
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['income', 'canton']));
    });

    testWidgets('real income + canton: ranking shows REAL FiscalService savings',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 10000, canton: 'GE', provided: {'salary', 'canton'})),
      );
      expect(find.byType(TopCantonWidget), findsOneWidget,
          reason: 'salary + canton keys confirm both top-cantons facts');
      final income = _state(tester).debugTopIncome as double;
      expect(income, 120000, reason: 'income = salaire × 12 (real profil)');
      final w = tester.widget<TopCantonWidget>(find.byType(TopCantonWidget));
      expect(w.rankings, isNotEmpty,
          reason: 'GE is highly taxed → favorable candidates exist');
      final first = w.rankings.first;
      final chargeAnchor = FiscalService.estimateTax(
        revenuBrut: income,
        canton: 'GE',
        etatCivil: 'celibataire',
        nombreEnfants: 0,
      )['chargeTotale'] as double;
      final chargeCand = FiscalService.estimateTax(
        revenuBrut: income,
        canton: first.shortCode,
        etatCivil: 'celibataire',
        nombreEnfants: 0,
      )['chargeTotale'] as double;
      expect(first.annualTaxSaving, closeTo(chargeAnchor - chargeCand, 1),
          reason: 'the écart is the real FiscalService delta, not a fabrication');
    });

    testWidgets('below-range income (12000/an) does NOT unlock the ranking',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 1000, canton: 'GE', provided: {'salary', 'canton'})),
      );
      expect(find.byType(TopCantonWidget), findsNothing,
          reason: '12000/an < 20000 → income un-confirmed → ranking gated');
      expect(_gateWith(tester, 'income').gate.missing.map((f) => f.key),
          contains('income'));
    });

    testWidgets('above-range income (2.4M/an) does NOT unlock the ranking',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 200000, canton: 'GE', provided: {'salary', 'canton'})),
      );
      expect(find.byType(TopCantonWidget), findsNothing,
          reason: '2.4M/an > 2M → income un-confirmed → ranking gated (no clamp)');
      expect(_gateWith(tester, 'income').gate.missing.map((f) => f.key),
          contains('income'));
    });

    testWidgets('income confirmed but canton key missing → still gated',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 10000, canton: 'GE', provided: {'salary'})),
      );
      expect(find.byType(TopCantonWidget), findsNothing);
      final gate = _gateWith(tester, 'income');
      expect(gate.gate.missing.map((f) => f.key), contains('canton'));
      expect(gate.gate.missing.map((f) => f.key), isNot(contains('income')),
          reason: 'salary key confirmed income; only the canton anchor remains');
    });

    testWidgets('canton confirmed but salary key missing → still gated',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 10000, canton: 'GE', provided: {'canton'})),
      );
      expect(find.byType(TopCantonWidget), findsNothing);
      expect(_gateWith(tester, 'income').gate.missing.map((f) => f.key),
          contains('income'));
    });

    testWidgets('clearing profile re-gates the ranking (no stale 5M)',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(
          _profile(salaire: 10000, canton: 'GE', provided: {'salary', 'canton'}));
      await _pumpEdit(tester);
      expect(find.byType(TopCantonWidget), findsOneWidget);

      fake.clearProfile();
      await _pumpEdit(tester);
      expect(find.byType(TopCantonWidget), findsNothing,
          reason: 'seeded income/canton lose provenance on clear → re-gates');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  DÉPART « capital en jeu » (tab 2 hero) — gated on 3a + LPP
  // ══════════════════════════════════════════════════════════════
  group('Départ capital hero', () {
    testWidgets('no profile: hero gated, lists {pillar3a, lpp}', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Départ');

      expect(find.byKey(_departHero), findsNothing,
          reason: 'no capital figure on the fabricated 80000 + 250000 defaults');
      final gate = _gateWith(tester, 'lpp');
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['pillar3a', 'lpp']));
    });

    testWidgets('seed LPP (avoirLpp key) + real 3a: hero == 3a + LPP',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            avoirLpp: 200000, epargne3a: 40000, provided: {'avoirLpp'})),
      );
      await _goToTab(tester, 'Départ');

      expect(find.byType(SituationGateCard), findsNothing,
          reason: 'avoirLpp key + real 3a balance confirm both facts');
      expect(find.byKey(_departHero), findsOneWidget);
      expect(_state(tester).debugLpp, 200000);
      expect(_state(tester).debugPillar3a, 40000);
      final total =
          (_state(tester).debugPillar3a as double) + (_state(tester).debugLpp as double);
      expect(
        find.descendant(
            of: find.byKey(_departHero),
            matching: find.text(ExpatService.formatChf(total))),
        findsOneWidget,
        reason: 'the hero renders the confirmed 3a + LPP total',
      );
    });

    testWidgets('touched-all: touch 3a + LPP unlocks the hero', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Départ');
      await _touch3a(tester, 30000);
      await _touchLpp(tester, 150000);

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_departHero), findsOneWidget);
    });

    testWidgets('LPP above range (2M) is NOT clamp-confirmed → hero gated',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            avoirLpp: 2000000, epargne3a: 40000, provided: {'avoirLpp'})),
      );
      await _goToTab(tester, 'Départ');
      expect(find.byKey(_departHero), findsNothing,
          reason: '2M > 1M range → LPP unconfirmed, never clamped to 1M');
      expect(_state(tester).debugLpp, 250000,
          reason: 'the LPP field keeps its editable default, no clamp');
      expect(_gateWith(tester, 'lpp').gate.missing.map((f) => f.key),
          contains('lpp'));
    });

    testWidgets('3a above range (600k) is NOT clamp-confirmed → hero gated',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            avoirLpp: 200000, epargne3a: 600000, provided: {'avoirLpp'})),
      );
      await _goToTab(tester, 'Départ');
      expect(find.byKey(_departHero), findsNothing,
          reason: '600k > 500k range → 3a unconfirmed, never clamped');
      expect(_state(tester).debugPillar3a, 80000);
      expect(_gateWith(tester, 'pillar3a').gate.missing.map((f) => f.key),
          contains('pillar3a'));
    });

    testWidgets('race: 3a confirms on the 2nd notify (no global latch)',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      await _goToTab(tester, 'Départ');

      // Notify #1 — LPP only. 3a still unconfirmed (default 80000 assumed).
      fake.hydrate(_profile(avoirLpp: 200000, provided: {'avoirLpp'}));
      await _pumpEdit(tester);
      expect(find.byKey(_departHero), findsNothing,
          reason: '3a not yet confirmed after the 1st notify');

      // Notify #2 — adds a real 3a balance. A global latch would strand it.
      fake.hydrate(
          _profile(avoirLpp: 200000, epargne3a: 40000, provided: {'avoirLpp'}));
      await _pumpEdit(tester);
      expect(find.byKey(_departHero), findsOneWidget,
          reason: '3a arrives on the 2nd notify — latch is gone');
    });

    testWidgets('clearing profile re-gates a purely-seeded hero', (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      await _goToTab(tester, 'Départ');
      fake.hydrate(
          _profile(avoirLpp: 200000, epargne3a: 40000, provided: {'avoirLpp'}));
      await _pumpEdit(tester);
      expect(find.byKey(_departHero), findsOneWidget);

      fake.clearProfile();
      await _pumpEdit(tester);
      expect(find.byKey(_departHero), findsNothing,
          reason: 'seeded 3a + LPP lose provenance on clear → hero re-gates');
    });

    testWidgets('touched hero (seed superseded) survives a profile clear',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      await _goToTab(tester, 'Départ');
      fake.hydrate(
          _profile(avoirLpp: 200000, epargne3a: 40000, provided: {'avoirLpp'}));
      await _pumpEdit(tester);
      // User touches both balances (supersedes the seed).
      await _touch3a(tester, 55000);
      await _touchLpp(tester, 120000);
      expect(find.byKey(_departHero), findsOneWidget);

      fake.clearProfile();
      await _pumpEdit(tester);
      expect(find.byKey(_departHero), findsOneWidget,
          reason: 'touched balances are local user data, immune to a clear');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  LACUNE AVS (tab 3, _avsResult) — gated on yearsInCh + yearsAbroad
  // ══════════════════════════════════════════════════════════════
  group('Lacune AVS output', () {
    testWidgets('no profile: AVS gated, lists {yearsInCh, yearsAbroad}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'AVS');

      expect(find.byKey(_avsResult), findsNothing,
          reason: 'no AVS gap figure on the fabricated 20 / 10 defaults');
      final gate = _gateWith(tester, 'yearsAbroad');
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['yearsInCh', 'yearsAbroad']));
    });

    testWidgets('touch both years: figure == estimateAvsGap output',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'AVS');
      await _touchYearsInCh(tester, 30);
      await _touchYearsAbroad(tester, 14);

      expect(find.byKey(_avsResult), findsOneWidget,
          reason: 'both years touched → AVS reduction card renders');
      final annualLoss = ExpatService.estimateAvsGap(
        yearsAbroad: _state(tester).debugYearsAbroad as int,
        yearsInCh: _state(tester).debugYearsInCh as int,
      )['annualLoss'] as double;
      expect(
        find.descendant(
            of: find.byKey(_avsResult),
            matching: find.text('-${ExpatService.formatChf(annualLoss)}')),
        findsOneWidget,
        reason: 'the annual loss equals estimateAvsGap on the touched years',
      );
    });

    testWidgets('AVS gated until BOTH years touched', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'AVS');
      await _touchYearsInCh(tester, 30);
      // yearsAbroad still the fabricated default 10.
      expect(find.byKey(_avsResult), findsNothing,
          reason: 'yearsAbroad not touched → AVS reduction stays gated');
      expect(_gateWith(tester, 'yearsAbroad').gate.missing.map((f) => f.key),
          contains('yearsAbroad'));
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  PROJECTION AvsGapWidget (tab 3) — gated on yearsInCh + real age
  // ══════════════════════════════════════════════════════════════
  group('AVS projection (AvsGapWidget)', () {
    testWidgets('no profile: projection gated, lists {yearsInCh, age}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'AVS');

      expect(find.byType(AvsGapWidget), findsNothing,
          reason: 'no rente projection on the fabricated 20 ans / âge 40');
      final gate = _gateWith(tester, 'age');
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['yearsInCh', 'age']));
    });

    testWidgets('seed real age + touch yearsInCh: projection uses real inputs',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(birthYear: 1985, provided: {'age'})),
      );
      await _goToTab(tester, 'AVS');
      await _touchYearsInCh(tester, 28);

      expect(find.byType(AvsGapWidget), findsOneWidget,
          reason: 'age key + touched yearsInCh confirm the projection facts');
      final w = tester.widget<AvsGapWidget>(find.byType(AvsGapWidget));
      expect(w.currentAge, DateTime.now().year - 1985,
          reason: 'the projection carries the REAL profile age, not 40');
      expect(w.currentContributionYears, 28);
    });

    testWidgets('real age present but no key → projection gated on age',
        (tester) async {
      // birthYear resolves a real age, but the 'age' key is absent → not
      // provenance-backed → the fact is assumed, never confirmed by value.
      await _pump(tester, _FakeProvider(_profile(birthYear: 1985)));
      await _goToTab(tester, 'AVS');
      await _touchYearsInCh(tester, 28);

      expect(find.byType(AvsGapWidget), findsNothing,
          reason: 'age without its provenance key stays assumed → gated');
      expect(_gateWith(tester, 'age').gate.missing.map((f) => f.key),
          contains('age'));
    });

    testWidgets('clearing profile re-gates the projection (no stale age)',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      await _goToTab(tester, 'AVS');
      fake.hydrate(_profile(birthYear: 1985, provided: {'age'}));
      await _pumpEdit(tester);
      await _touchYearsInCh(tester, 28);
      expect(find.byType(AvsGapWidget), findsOneWidget);

      fake.clearProfile();
      await _pumpEdit(tester);
      expect(find.byType(AvsGapWidget), findsNothing,
          reason: 'seeded age loses provenance on clear → projection re-gates');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  Per-output independence — one output confirmed never leaks another
  // ══════════════════════════════════════════════════════════════
  testWidgets('touching forfait facts does NOT unlock the top-cantons ranking',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _touchForfaitCanton(tester, 'GE');
    await _touchLivingExpenses(tester, 2000000);
    await _touchActualIncome(tester, 8000000);

    expect(find.byKey(_forfaitResult), findsOneWidget,
        reason: 'forfait facts confirmed');
    expect(find.byType(TopCantonWidget), findsNothing,
        reason: 'top-cantons needs real profil income/canton → gated apart');
    expect(_gateWith(tester, 'income').gate.missing.map((f) => f.key),
        containsAll(<String>['income', 'canton']));
  });

  testWidgets('seeded départ does NOT unlock the AVS outputs', (tester) async {
    await _pump(
      tester,
      _FakeProvider(
          _profile(avoirLpp: 200000, epargne3a: 40000, provided: {'avoirLpp'})),
    );
    await _goToTab(tester, 'Départ');
    expect(find.byKey(_departHero), findsOneWidget,
        reason: 'départ facts confirmed');

    await _goToTab(tester, 'AVS');
    expect(find.byKey(_avsResult), findsNothing,
        reason: 'AVS years still assumed → gated independently');
    expect(find.byType(AvsGapWidget), findsNothing,
        reason: 'projection years/age still assumed → gated independently');
  });

  // A screen with no provider (isolated pump) must not crash and must gate.
  testWidgets('no provider in tree: defaults kept, every output gated',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 9000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ExpatScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpatScreen), findsOneWidget);
    expect(find.byKey(_forfaitResult), findsNothing);
    expect(find.byType(TopCantonWidget), findsNothing,
        reason: 'no output computes without a confirmed fact');
  });
}

/// Like [_gateWith] but returns null when no such gate card is present (used to
/// assert the ABSENCE of a specific output's gate once its facts are confirmed).
SituationGateCard? _gateWith0(WidgetTester tester, String factKey) {
  final matches = tester
      .widgetList<SituationGateCard>(find.byType(SituationGateCard))
      .where((c) => c.gate.facts.any((f) => f.key == factKey));
  return matches.isEmpty ? null : matches.first;
}
