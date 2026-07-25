import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/naissance_screen.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/widgets/coach/baby_cost_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_bebe_widget.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for naissance_screen.
///
/// naissance has THREE computed outputs across tabs, each gated on the facts IT
/// consumes:
///   • Congé APG (tab 1)  — salaire (key 'salary') + rôle parental (gender).
///   • Allocations (tab 2) — canton (key 'canton') + nombre d'enfants (touch).
///   • Impact (tab 3)      — revenu (key 'salary') + frais de garde (touch) +
///                           nombre d'enfants (touch).
///
/// Every assertion is on the RENDERED figure (a keyed MintResultHeroCard / a
/// keyed CHF Text) or the rendered [SituationGateCard], never on an internal
/// bool: a refactor that keeps the number but swaps the flag is still caught.
/// Each test goes RED if the gate is removed (i.e. if the screen went back to
/// auto-computing on the fabricated defaults 6000 / VD / 1 enfant / 80000 /
/// 1500 / isMother=true).
///
/// The screen is a `TabBarView` of lazy `ListView`s: only the current tab is
/// built, so alloc/impact tests tap into their tab first, and a tall test
/// surface keeps each tab's result slot inflated without scrolling.

// ── Figure keys (mirror naissance_screen.dart) ──
const _congeHero = Key('naissanceCongeHero');
const _allocHero = Key('naissanceAllocHero');
const _impactFigure = Key('naissanceImpactFigure');

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
  double salaire = 6000,
  int nombreEnfants = 0,
  String? gender,
  double epargne3a = 0,
  Set<String> provided = const {},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    nombreEnfants: nombreEnfants,
    gender: gender,
    prevoyance: PrevoyanceProfile(totalEpargne3a: epargne3a),
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
  await tester.binding.setSurfaceSize(const Size(1200, 8000));
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
        home: NaissanceScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(NaissanceScreen)) as dynamic;

Future<void> _goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

MintAmountField _amountField(
  WidgetTester tester, {
  required double min,
  required double max,
}) =>
    tester
        .widgetList<MintAmountField>(find.byType(MintAmountField))
        .firstWhere((f) => f.min == min && f.max == max);

// ── Congé interactions ──
Future<void> _touchSalaire(WidgetTester tester, double v) async {
  _amountField(tester, min: 2000, max: 15000).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _selectParent(WidgetTester tester, {required bool isMother}) async {
  final sb =
      tester.widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>));
  sb.onSelectionChanged!({isMother});
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── Alloc interactions ──
Future<void> _touchCanton(WidgetTester tester, String c) async {
  final dd =
      tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
  dd.onChanged!(c);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _incrementChildren(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_circle_outline).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── Impact interactions ──
Future<void> _touchRevenu(WidgetTester tester, double v) async {
  _amountField(tester, min: 30000, max: 200000).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _touchFraisGarde(WidgetTester tester, double v) async {
  _amountField(tester, min: 0, max: 3000).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── Expected service outputs for the screen's CURRENT confirmed inputs ──
String _expectedCongeTotal(WidgetTester tester) {
  final st = _state(tester);
  final r = FamilyService.simulateCongeParental(
    salaireMensuel: st.debugSalaire as double,
    isMother: st.debugIsMother as bool,
  );
  return FamilyService.formatChf(r['totalApg'] as double);
}

String _expectedAllocMensuel(WidgetTester tester) {
  final st = _state(tester);
  final r = FamilyService.estimateAllocations(
    canton: st.debugCanton as String,
    nbEnfants: st.debugNbEnfantsAlloc as int,
  );
  return '${FamilyService.formatChf(r['mensuelTotal'] as double)}/mois';
}

String _expectedImpactEconomie(WidgetTester tester) {
  final st = _state(tester);
  final revenu = st.debugRevenu as double;
  final r = FamilyService.calculateImpactFiscalEnfant(
    revenuImposable: revenu,
    tauxMarginal: 0.15 + (revenu / 1000000),
    nbEnfants: st.debugNbEnfantsImpact as int,
    fraisGarde: st.debugFraisGarde as double,
  );
  return FamilyService.formatChf(r['economieFiscale'] as double);
}

/// Expected NET impact for the current confirmed inputs — with the fabricated
/// « autres coûts » forfaitaire (1500/enfant/mois) EXCLUDED. Only gated inputs:
/// net = économie fiscale + allocations − frais de garde réels.
({double net, double netWithFakeCost}) _expectedImpactNet(WidgetTester tester) {
  final st = _state(tester);
  final revenu = st.debugRevenu as double;
  final nb = st.debugNbEnfantsImpact as int;
  final frais = st.debugFraisGarde as double;
  final eco = FamilyService.calculateImpactFiscalEnfant(
    revenuImposable: revenu,
    tauxMarginal: 0.15 + (revenu / 1000000),
    nbEnfants: nb,
    fraisGarde: frais,
  )['economieFiscale'] as double;
  final alloc = FamilyService.estimateAllocations(
    canton: st.debugCanton as String,
    nbEnfants: nb,
  )['annuelTotal'] as double;
  final fraisAnnuel = frais * 12 * nb;
  final net = eco + alloc - fraisAnnuel;
  // The pre-fix formula also subtracted a fabricated 1500/enfant/mois.
  final netWithFakeCost = net - (1500.0 * nb * 12);
  return (net: net, netWithFakeCost: netWithFakeCost);
}

String _fmtNet(double net) =>
    '${net >= 0 ? "+" : ""}${FamilyService.formatChf(net)}';

void main() {
  // ══════════════════════════════════════════════════════════════
  //  CONGÉ APG (tab 1) — gated on salaire + rôle parental
  // ══════════════════════════════════════════════════════════════
  group('Congé APG output', () {
    testWidgets('no profile: congé gated, gate lists {salaire, parentRole}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      expect(find.byKey(_congeHero), findsNothing,
          reason: 'no congé figure on fabricated defaults 6000 / isMother=true');
      final gate =
          tester.widget<SituationGateCard>(find.byType(SituationGateCard));
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['salaire', 'parentRole']));
    });

    testWidgets('seeded (salary key + gender F): hero == service, isMother true',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          salaire: 7200,
          gender: 'F',
          provided: {'salary'},
        )),
      );

      expect(find.byType(SituationGateCard), findsNothing,
          reason: 'salary key + non-null gender confirm both congé facts');
      expect(find.byKey(_congeHero), findsOneWidget);
      expect(_state(tester).debugIsMother, isTrue);
      expect(
        find.descendant(
            of: find.byKey(_congeHero),
            matching: find.text(_expectedCongeTotal(tester))),
        findsOneWidget,
        reason: 'the hero renders the maternité APG from the seeded salary',
      );
    });

    testWidgets('parent-role: gender M seeded → father congé (paternité) shows',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          salaire: 7200,
          gender: 'M',
          provided: {'salary'},
        )),
      );

      expect(find.byKey(_congeHero), findsOneWidget,
          reason: 'gender=M is real data → parent role confirmed');
      expect(_state(tester).debugIsMother, isFalse,
          reason: 'gender M seeds the father role');
      // Paternité total (14 j) ≠ maternité total (98 j): the rendered figure
      // proves the father path, not a fabricated maternité default.
      expect(
        find.descendant(
            of: find.byKey(_congeHero),
            matching: find.text(_expectedCongeTotal(tester))),
        findsOneWidget,
      );
    });

    testWidgets('parent-role: null gender stays gated even with salary seeded',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          salaire: 7200,
          gender: null,
          provided: {'salary'},
        )),
      );

      expect(find.byKey(_congeHero), findsNothing,
          reason: 'null gender is ASSUMED → showing maternité would fabricate');
      final gate =
          tester.widget<SituationGateCard>(find.byType(SituationGateCard));
      expect(gate.gate.missing.map((f) => f.key), contains('parentRole'));
      expect(gate.gate.missing.map((f) => f.key), isNot(contains('salaire')),
          reason: 'salary was confirmed by its key; only parent role remains');
    });

    testWidgets('touched-all: touch salary + select Mère unlocks the hero',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _touchSalaire(tester, 8000);
      await _selectParent(tester, isMother: true);

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_congeHero), findsOneWidget);
      expect(_state(tester).debugIsMother, isTrue);
      expect(
        find.descendant(
            of: find.byKey(_congeHero),
            matching: find.text(_expectedCongeTotal(tester))),
        findsOneWidget,
      );
    });

    testWidgets('race: parentRole confirms on the 2nd notify (no global latch)',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      expect(find.byKey(_congeHero), findsNothing);

      // Notify #1 — salary key only, gender ABSENT → parent role unconfirmed.
      fake.hydrate(_profile(salaire: 7200, provided: {'salary'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_congeHero), findsNothing,
          reason: 'parent role not yet confirmed after the 1st notify');

      // Notify #2 — adds gender. A global _prefilled latch would strand it.
      fake.hydrate(_profile(salaire: 7200, gender: 'F', provided: {'salary'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_congeHero), findsOneWidget,
          reason: 'gender arrives on the 2nd notify — latch is gone');
    });

    testWidgets('default-collision A: value == default but key+gender confirm',
        (tester) async {
      // salaire 6000 EQUALS the on-screen default, but salary key + gender are
      // present → confirmed → congé shows.
      await _pump(
        tester,
        _FakeProvider(_profile(
          salaire: 6000,
          gender: 'F',
          provided: {'salary'},
        )),
      );
      expect(find.byKey(_congeHero), findsOneWidget,
          reason: 'identical-to-default salary is confirmed by its provenance');
    });

    testWidgets('default-collision B: no profile, same 6000 stays gated',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(find.byKey(_congeHero), findsNothing,
          reason: 'identical 6000 with no provenance stays gated');
      expect(find.byType(SituationGateCard), findsOneWidget);
    });

    testWidgets('clearing the profile re-gates a purely-seeded congé',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(salaire: 7200, gender: 'F', provided: {'salary'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_congeHero), findsOneWidget);

      // Logout / account reset while mounted: seeded provenance disappears.
      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_congeHero), findsNothing,
          reason: 'seeded salary + gender lose provenance → congé re-gates');
      expect(find.byType(SituationGateCard), findsOneWidget);
    });

    testWidgets('touched congé (seed superseded) survives a profile clear',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(salaire: 7200, gender: 'F', provided: {'salary'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // The user touches both congé facts (supersedes the seed).
      await _touchSalaire(tester, 9000);
      await _selectParent(tester, isMother: false);
      expect(find.byKey(_congeHero), findsOneWidget);

      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_congeHero), findsOneWidget,
          reason: 'touched facts are local user data, immune to a clear');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  ALLOCATIONS (tab 2) — gated on canton + nombre d'enfants
  // ══════════════════════════════════════════════════════════════
  group('Allocations output', () {
    testWidgets('no profile: alloc gated, gate lists {canton, nbEnfants}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Allocations');

      expect(find.byKey(_allocHero), findsNothing,
          reason: 'no allocation figure on a fabricated canton VD default');
      final gate =
          tester.widget<SituationGateCard>(find.byType(SituationGateCard));
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['canton', 'nbEnfants']));
    });

    testWidgets('seed canton + touch nbEnfants: hero == service output',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'GE', provided: {'canton'})),
      );
      await _goToTab(tester, 'Allocations');
      // canton seeded; nombre d'enfants has NO provenance key → touch confirms.
      await _incrementChildren(tester);

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_allocHero), findsOneWidget);
      expect(
        find.descendant(
            of: find.byKey(_allocHero),
            matching: find.text(_expectedAllocMensuel(tester))),
        findsOneWidget,
        reason: 'the hero renders the estimateAllocations output for GE',
      );
    });

    testWidgets('touched-all: touch canton + nbEnfants unlocks the hero',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Allocations');
      await _touchCanton(tester, 'GE');
      await _incrementChildren(tester);

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_allocHero), findsOneWidget);
    });

    testWidgets('clearing profile re-gates: seeded canton gone, touched survives',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(canton: 'GE', provided: {'canton'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _goToTab(tester, 'Allocations');
      await _incrementChildren(tester); // nbEnfants touched
      expect(find.byKey(_allocHero), findsOneWidget);

      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_allocHero), findsNothing,
          reason: 'seeded canton loses provenance on clear → alloc re-gates');
      final gate =
          tester.widget<SituationGateCard>(find.byType(SituationGateCard));
      expect(gate.gate.missing.map((f) => f.key), contains('canton'));
      expect(gate.gate.missing.map((f) => f.key), isNot(contains('nbEnfants')),
          reason: 'nbEnfants was touched (user data) → survives the clear');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  IMPACT (tab 3) — gated on revenu + frais de garde + nb enfants
  // ══════════════════════════════════════════════════════════════
  group('Impact output', () {
    testWidgets(
        'no profile: impact gated, gate lists {revenu, fraisGarde, nbEnfants}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Impact');

      expect(find.byKey(_impactFigure), findsNothing,
          reason: 'no impact figure on fabricated 80000 / 1500 defaults');
      final gate =
          tester.widget<SituationGateCard>(find.byType(SituationGateCard));
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['revenu', 'fraisGarde', 'nbEnfants']));
    });

    testWidgets('seed revenu + touch fraisGarde + nbEnfants: figure == service',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          salaire: 6500,
          canton: 'GE',
          gender: 'F',
          provided: {'salary', 'canton'},
        )),
      );
      await _goToTab(tester, 'Impact');
      // revenu + canton + rôle parental seedés ; frais de garde + nb enfants
      // (impact consomme aussi canton/rôle → gatés) : touch.
      await _touchFraisGarde(tester, 1200);
      await _incrementChildren(tester);

      expect(find.byType(SituationGateCard), findsNothing);
      final figure = tester.widget<Text>(find.byKey(_impactFigure));
      expect(figure.data, _expectedImpactEconomie(tester),
          reason: 'the tax-saving figure equals calculateImpactFiscalEnfant');
    });

    testWidgets(
        'impact gated when canton/rôle assumed even if revenu+frais+enfants set',
        (tester) async {
      // The Impact figures also consume canton + parent-role (allocations row,
      // LPP career-gap). With those still at the VD/maternité defaults, the
      // impact output must NOT compute — no secondary figure on fabricated facts.
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Impact');
      await _touchRevenu(tester, 90000);
      await _touchFraisGarde(tester, 1000);
      await _incrementChildren(tester);

      expect(find.byKey(_impactFigure), findsNothing,
          reason: 'canton + parentRole still assumed → impact stays gated');
      final gate =
          tester.widget<SituationGateCard>(find.byType(SituationGateCard));
      expect(gate.gate.missing.map((f) => f.key),
          containsAll(<String>['canton', 'parentRole']));
    });

    testWidgets('impact facts touched + canton/rôle seedés unlocks figure',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(
            _profile(canton: 'GE', gender: 'F', provided: {'canton'})),
      );
      await _goToTab(tester, 'Impact');
      await _touchRevenu(tester, 90000);
      await _touchFraisGarde(tester, 1000);
      await _incrementChildren(tester);

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_impactFigure), findsOneWidget);
      final figure = tester.widget<Text>(find.byKey(_impactFigure));
      expect(figure.data, _expectedImpactEconomie(tester));
    });

    testWidgets('stale invalidation: editing frais de garde refreshes figure',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(
            _profile(canton: 'GE', gender: 'F', provided: {'canton'})),
      );
      await _goToTab(tester, 'Impact');
      await _touchRevenu(tester, 90000);
      await _touchFraisGarde(tester, 500);
      await _incrementChildren(tester);
      final before = tester.widget<Text>(find.byKey(_impactFigure)).data;

      // frais de garde feeds the childcare deduction → économie fiscale changes.
      await _touchFraisGarde(tester, 2500);
      final after = tester.widget<Text>(find.byKey(_impactFigure)).data;
      expect(after, isNot(before),
          reason: 'a fact edit recomputes; no stale figure survives');
      expect(after, _expectedImpactEconomie(tester));
    });

    testWidgets('clearing profile re-gates: seeded revenu gone, touched survive',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(
        salaire: 6500,
        canton: 'GE',
        gender: 'F',
        provided: {'salary', 'canton'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _goToTab(tester, 'Impact');
      await _touchFraisGarde(tester, 1200); // touched
      await _incrementChildren(tester); // touched
      expect(find.byKey(_impactFigure), findsOneWidget);

      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_impactFigure), findsNothing,
          reason: 'seeded revenu loses provenance on clear → impact re-gates');
      final gate =
          tester.widget<SituationGateCard>(find.byType(SituationGateCard));
      expect(gate.gate.missing.map((f) => f.key), contains('revenu'));
      expect(gate.gate.missing.map((f) => f.key),
          isNot(contains('fraisGarde')),
          reason: 'touched frais de garde + nbEnfants survive the clear');
    });

    // ── Codex re-review: NO fabricated personal CHF in the revealed subtree ──
    testWidgets('net impact excludes the fabricated 1500/enfant « autres coûts »',
        (tester) async {
      // Canton + rôle seedés (impact gate les consomme aussi) ; revenu + frais
      // + enfants touchés → sortie impact complète.
      await _pump(
        tester,
        _FakeProvider(
            _profile(canton: 'GE', gender: 'F', provided: {'canton'})),
      );
      await _goToTab(tester, 'Impact');
      await _touchRevenu(tester, 90000);
      await _touchFraisGarde(tester, 800);
      await _incrementChildren(tester);

      final exp = _expectedImpactNet(tester);
      // Sanity: with nb ≥ 1 the two formulas differ (1500×nb×12 > 0), so the
      // assertion below cannot pass vacuously.
      expect(exp.net, isNot(exp.netWithFakeCost));
      expect(
        find.descendant(
            of: find.byKey(const Key('naissanceImpactNet')),
            matching: find.text(_fmtNet(exp.net))),
        findsOneWidget,
        reason: 'net = économie fiscale + allocations − frais de garde only',
      );
      expect(
        find.descendant(
            of: find.byKey(const Key('naissanceImpactNet')),
            matching: find.text(_fmtNet(exp.netWithFakeCost))),
        findsNothing,
        reason: 'the pre-fix net (with the 1500 forfait) must NOT be rendered',
      );
    });

    testWidgets('Clause 3a renders the REAL profile 3a balance when > 0',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          salaire: 6500,
          canton: 'GE',
          gender: 'F',
          epargne3a: 35000,
          provided: {'salary', 'canton'},
        )),
      );
      await _goToTab(tester, 'Impact');
      await _touchFraisGarde(tester, 1200);
      await _incrementChildren(tester);

      final clause = find.byType(Clause3aWidget);
      expect(clause, findsOneWidget,
          reason: 'a real profile 3a balance (>0) shows the clause widget');
      expect(tester.widget<Clause3aWidget>(clause).balance3a, 35000.0,
          reason: 'the widget carries the REAL profile 3a, not revenu × 0.3');
    });

    testWidgets('Clause 3a is absent when the profile 3a balance is 0/unknown',
        (tester) async {
      await _pump(
        // epargne3a defaults to 0 → unknown 3a balance.
        tester,
        _FakeProvider(_profile(
          salaire: 6500,
          canton: 'GE',
          gender: 'F',
          provided: {'salary', 'canton'},
        )),
      );
      await _goToTab(tester, 'Impact');
      await _touchFraisGarde(tester, 1200);
      await _incrementChildren(tester);

      expect(find.byKey(_impactFigure), findsOneWidget,
          reason: 'the impact output is otherwise complete');
      expect(find.byType(Clause3aWidget), findsNothing,
          reason: 'no real 3a balance → no invented 30%-of-income clause shown');
    });

    testWidgets('Clause 3a does not survive a profile clear (no stale balance)',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      // Real 3a balance, but NO provenance keys + gender null → every fact is
      // confirmed by TOUCH, so a clear changes no seeded flag (Codex's exact
      // scenario where build() would skip setState and strand the 3a balance).
      fake.hydrate(_profile(epargne3a: 35000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await _selectParent(tester, isMother: true); // congé tab (default)
      await _goToTab(tester, 'Allocations');
      await _touchCanton(tester, 'GE');
      await _goToTab(tester, 'Impact');
      await _touchRevenu(tester, 90000);
      await _touchFraisGarde(tester, 1200);
      await _incrementChildren(tester);

      expect(find.byType(Clause3aWidget), findsOneWidget);
      expect(
          tester.widget<Clause3aWidget>(find.byType(Clause3aWidget)).balance3a,
          35000.0);

      // Cleared while mounted: touched facts survive (impact stays shown) but
      // the profile 3a must vanish, not persist stale.
      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(_impactFigure), findsOneWidget,
          reason: 'touched facts survive the clear → impact still shown');
      expect(find.byType(Clause3aWidget), findsNothing,
          reason: 'profile 3a is now a state field → 0 on clear, no stale CHF');
    });

    testWidgets('generic-example caption sits above the cost widgets',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(
            _profile(canton: 'GE', gender: 'F', provided: {'canton'})),
      );
      await _goToTab(tester, 'Impact');
      await _touchRevenu(tester, 90000);
      await _touchFraisGarde(tester, 1000);
      await _incrementChildren(tester);

      // The generic Swiss-average widgets stay, but are explicitly framed.
      expect(find.text('Exemple — coûts moyens en Suisse, pas ta situation'),
          findsOneWidget,
          reason: 'the generic-average caption must be present');
      expect(find.byType(BudgetBebeWidget), findsOneWidget);
      expect(find.byType(BabyCostWidget), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  Per-output independence — one output confirmed never leaks another
  // ══════════════════════════════════════════════════════════════
  testWidgets('congé confirmed does not unlock alloc or impact',
      (tester) async {
    // Only the congé facts are confirmed (salary key + gender). Canton stays
    // the VD default (assumed); frais de garde stays assumed.
    await _pump(
      tester,
      _FakeProvider(_profile(salaire: 7200, gender: 'F', provided: {'salary'})),
    );
    expect(find.byKey(_congeHero), findsOneWidget,
        reason: 'congé facts confirmed');

    await _goToTab(tester, 'Allocations');
    expect(find.byKey(_allocHero), findsNothing,
        reason: 'canton still assumed → alloc gated independently');
    expect(find.byType(SituationGateCard), findsOneWidget);

    await _goToTab(tester, 'Impact');
    expect(find.byKey(_impactFigure), findsNothing,
        reason: 'frais de garde still assumed → impact gated independently');
    expect(find.byType(SituationGateCard), findsOneWidget);
  });

  // A screen with no provider (isolated pump) must not crash and must gate.
  testWidgets('no provider in tree: defaults kept, every output gated',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 8000));
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
        home: NaissanceScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NaissanceScreen), findsOneWidget);
    expect(find.byKey(_congeHero), findsNothing);
    expect(find.byType(MintResultHeroCard), findsNothing,
        reason: 'no output computes without a confirmed fact');
  });
}
