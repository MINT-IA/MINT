import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/coach/couple_narrative_timeline.dart';
import 'package:mint_mobile/widgets/coach/survivor_pension_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/widgets/visualizations/marriage_penalty_gauge.dart';
import 'package:mint_mobile/widgets/visualizations/regime_matrimonial_pie.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for mariage_screen.
///
/// mariage has FOUR computed outputs, each gated on the facts IT consumes:
///   • Impôt du couple (tab 1)   — revenu1 ('salary') + revenu2 (conjoint réel)
///                                 + canton ('canton') + nombre d'enfants (touch).
///   • Partage du régime (tab 2) — patrimoine1 + patrimoine2 (touch seul).
///   • Histoire à deux (tab 2)   — revenu1 + revenu2 (revenu mensuel du couple).
///   • Rente de survivant (tab 3)— rente LPP ('avoirLpp' → LppCalculator, ou touch).
///
/// Every assertion is on the RENDERED figure (a keyed MintResultHeroCard, a
/// secondary widget, or the rendered [SituationGateCard]), never on an internal
/// bool: a refactor that keeps the number but swaps the flag is still caught.
/// Each test goes RED if the gate is removed (i.e. if the screen went back to
/// auto-computing on the fabricated defaults 80000 / 60000 / VD / 0 / 2500 /
/// 200000 / 100000).
///
/// The screen is a `TabBarView` of lazy `ListView`s: only the current tab is
/// built, so régime/protection tests tap into their tab first, and a tall test
/// surface keeps each tab's result slot inflated without scrolling.

const _fiscalHero = Key('mariageFiscalHero');
const _survivorHero = Key('mariageSurvivorHero');
const _revenu2Field = Key('mariage_revenu2_field');

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
  int birthYear = 1985,
  String canton = 'GE',
  double salaire = 8000,
  int nombreEnfants = 0,
  double? conjointSalaire, // null ⇒ pas de conjoint réel
  double conjointMois = 12,
  double? avoirLpp, // null ⇒ pas d'avoir LPP
  double tauxConversion = 0.068,
  double epargne3a = 0,
  Set<String> provided = const {},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    nombreEnfants: nombreEnfants,
    conjoint: conjointSalaire == null
        ? null
        : ConjointProfile(
            salaireBrutMensuel: conjointSalaire, nombreDeMois: conjointMois),
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLpp,
      tauxConversion: tauxConversion,
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
  await tester.binding.setSurfaceSize(const Size(1200, 9000));
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
        home: MariageScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(MariageScreen)) as dynamic;

Future<void> _goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// The gate whose facts include [key] (Tab 2 shows two gate cards: régime +
/// timeline — this picks the right one).
SituationGate _gateWith(WidgetTester tester, String key) => tester
    .widgetList<SituationGateCard>(find.byType(SituationGateCard))
    .firstWhere((c) => c.gate.facts.any((f) => f.key == key))
    .gate;

// ── Tab 1 interactions ──
Future<void> _touchRevenu1(WidgetTester tester, double v) async {
  tester.widgetList<MintAmountField>(find.byType(MintAmountField)).first.onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _touchRevenu2(WidgetTester tester, double v) async {
  tester.widget<MintAmountField>(find.byKey(_revenu2Field)).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _touchCanton(WidgetTester tester, String c) async {
  tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .onChanged!(c);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _incrementChildren(WidgetTester tester) async {
  // The stepper's «+» sits AFTER any gate-card missing-fact rows (which also use
  // add_circle_outline), so target the LAST one.
  await tester.tap(find.byIcon(Icons.add_circle_outline).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── Tab 2 interactions ──
Future<void> _touchPatrimoine1(WidgetTester tester, double v) async {
  tester.widgetList<MintAmountField>(find.byType(MintAmountField)).first.onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _touchPatrimoine2(WidgetTester tester, double v) async {
  tester
      .widgetList<MintAmountField>(find.byType(MintAmountField))
      .toList()[1]
      .onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── Tab 3 interactions ──
Future<void> _touchRenteLpp(WidgetTester tester, double v) async {
  tester.widget<MintAmountField>(find.byType(MintAmountField)).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── Expected service outputs for the CURRENT confirmed inputs ──
String _expectedFiscalPrimary(WidgetTester tester) {
  final st = _state(tester);
  final r = FamilyService.compareFiscalMariage(
    revenu1: st.debugRevenu1 as double,
    revenu2: st.debugRevenu2 as double,
    canton: st.debugCanton as String,
    nbEnfants: st.debugNbEnfants as int,
  );
  final diff = r['difference'] as double;
  final isPen = r['isPenalite'] as bool;
  return '${isPen ? "+" : "-"}${FamilyService.formatChf(diff.abs())}';
}

String _expectedSurvivorPrimary(WidgetTester tester) {
  final st = _state(tester);
  // P2 residual fix: the survivor figure is the CONFIRMED LPP survivor rente
  // ONLY (renteLpp × 60%). No fabricated max-AVS component — the AVS survivor
  // rente depends on an unconfirmed contribution history (LAVS art. 23) and is
  // stated qualitatively, never as a personal CHF.
  final lpp = (st.debugRenteLpp as double) * FamilyService.lppSurvivorFactor;
  return '${FamilyService.formatChf(lpp)}/mois';
}

void main() {
  // ══════════════════════════════════════════════════════════════
  //  IMPÔT DU COUPLE (tab 1) — revenu1 + revenu2 + canton + nbEnfants
  // ══════════════════════════════════════════════════════════════
  group('Fiscal output', () {
    testWidgets(
        'no profile: fiscal gated, gate lists {revenu1,revenu2,canton,nbEnfants}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      expect(find.byKey(_fiscalHero), findsNothing,
          reason: 'no fiscal figure on fabricated defaults 80000/60000/VD/0');
      expect(find.byType(MarriagePenaltyGauge), findsNothing,
          reason: 'the penalty gauge is a fiscal figure too → gated');
      final gate = _gateWith(tester, 'revenu1');
      expect(gate.missing.map((f) => f.key),
          containsAll(<String>['revenu1', 'revenu2', 'canton', 'nbEnfants']));
    });

    testWidgets('seed salary+canton+conjoint, touch nbEnfants: hero == service',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          salaire: 8000, // revenu1 = 96000 ≠ 80000 défaut
          canton: 'GE',
          conjointSalaire: 5500, // revenu2 = 66000 ≠ 60000 défaut
          provided: {'salary', 'canton'},
        )),
      );
      // nombre d'enfants n'a pas de clé de provenance → touch confirme.
      await _incrementChildren(tester);

      expect(find.byType(SituationGateCard), findsNothing,
          reason: 'salary key + canton key + conjoint + touched nbEnfants');
      expect(find.byKey(_fiscalHero), findsOneWidget);
      expect(find.byType(MarriagePenaltyGauge), findsOneWidget);
      expect(_state(tester).debugRevenu1, 96000.0);
      expect(_state(tester).debugRevenu2, 66000.0);
      expect(
        find.descendant(
            of: find.byKey(_fiscalHero),
            matching: find.text(_expectedFiscalPrimary(tester))),
        findsOneWidget,
        reason: 'the hero renders compareFiscalMariage on the seeded inputs',
      );
    });

    testWidgets('conjoint absent: revenu2 stays gated until touched',
        (tester) async {
      // salary + canton seeded, nbEnfants touched, but NO conjoint → revenu2 is
      // an ASSUMED hypothesis (défaut 60000). Fiscal must stay gated on revenu2.
      await _pump(
        tester,
        _FakeProvider(
            _profile(salaire: 8000, canton: 'GE', provided: {'salary', 'canton'})),
      );
      await _incrementChildren(tester);

      expect(find.byKey(_fiscalHero), findsNothing,
          reason: 'no conjoint → revenu2 assumed → showing 60000 would fabricate');
      final gate = _gateWith(tester, 'revenu2');
      expect(gate.missing.map((f) => f.key), contains('revenu2'));
      expect(gate.missing.map((f) => f.key), isNot(contains('revenu1')),
          reason: 'revenu1 confirmed by its salary key');
      expect(gate.missing.map((f) => f.key), isNot(contains('canton')));

      // Touching Revenu 2 confirms it (user data) → hero appears.
      await _touchRevenu2(tester, 54000);
      expect(find.byKey(_fiscalHero), findsOneWidget);
      expect(_state(tester).debugRevenu2, 54000.0);
    });

    testWidgets('touched-all: touch revenu1 + revenu2 + canton + nbEnfants',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _touchRevenu1(tester, 90000);
      await _touchRevenu2(tester, 70000);
      await _touchCanton(tester, 'ZH');
      await _incrementChildren(tester);

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_fiscalHero), findsOneWidget);
      expect(_state(tester).debugCanton, 'ZH');
      expect(
        find.descendant(
            of: find.byKey(_fiscalHero),
            matching: find.text(_expectedFiscalPrimary(tester))),
        findsOneWidget,
      );
    });

    testWidgets('race: revenu2 (conjoint) confirms on the 2nd notify (no latch)',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      // Confirm nbEnfants up front so revenu2 is the only pending fact.
      await _incrementChildren(tester);

      // Notify #1 — salary + canton keys, NO conjoint → revenu2 unconfirmed.
      fake.hydrate(_profile(salaire: 8000, canton: 'GE', provided: {'salary', 'canton'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_fiscalHero), findsNothing,
          reason: 'revenu2 not yet confirmed after the 1st notify');

      // Notify #2 — adds the real conjoint. A global _prefilled latch would strand it.
      fake.hydrate(_profile(
          salaire: 8000,
          canton: 'GE',
          conjointSalaire: 5000,
          provided: {'salary', 'canton'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_fiscalHero), findsOneWidget,
          reason: 'conjoint arrives on the 2nd notify — latch is gone');
    });

    testWidgets('default-collision A: canton VD + revenu2 60000 == defaults',
        (tester) async {
      // canton 'VD' (default) confirmed by key; conjoint 5000 → revenu2 60000
      // (default) confirmed by conjoint provenance. Identical-to-default values
      // must still be treated as confirmed.
      await _pump(
        tester,
        _FakeProvider(_profile(
          salaire: 8000,
          canton: 'VD',
          conjointSalaire: 5000,
          provided: {'salary', 'canton'},
        )),
      );
      await _incrementChildren(tester);
      expect(find.byKey(_fiscalHero), findsOneWidget,
          reason: 'VD + 60000 equal the defaults but are confirmed by provenance');
    });

    testWidgets('default-collision B: no profile, same defaults stay gated',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(find.byKey(_fiscalHero), findsNothing,
          reason: 'identical VD/60000/80000 with no provenance stays gated');
      expect(find.byType(SituationGateCard), findsOneWidget);
    });

    testWidgets('clearing the profile re-gates a purely-seeded fiscal output',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(
          salaire: 8000,
          canton: 'GE',
          conjointSalaire: 5000,
          provided: {'salary', 'canton'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _incrementChildren(tester); // nbEnfants touched
      expect(find.byKey(_fiscalHero), findsOneWidget);

      // Logout / reset while mounted: seeded provenance disappears.
      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_fiscalHero), findsNothing,
          reason: 'seeded salary/canton/conjoint lose provenance → re-gates');
      final gate = _gateWith(tester, 'revenu1');
      expect(gate.missing.map((f) => f.key),
          containsAll(<String>['revenu1', 'revenu2', 'canton']));
      expect(gate.missing.map((f) => f.key), isNot(contains('nbEnfants')),
          reason: 'nbEnfants was touched (user data) → survives the clear');
    });

    testWidgets('touched facts (seed superseded) survive a profile clear',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(
          salaire: 8000,
          canton: 'GE',
          conjointSalaire: 5000,
          provided: {'salary', 'canton'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // User touches every fiscal fact (supersedes the seed).
      await _touchRevenu1(tester, 88000);
      await _touchRevenu2(tester, 52000);
      await _touchCanton(tester, 'ZH');
      await _incrementChildren(tester);
      expect(find.byKey(_fiscalHero), findsOneWidget);

      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_fiscalHero), findsOneWidget,
          reason: 'touched facts are local user data, immune to a clear');
    });
  });

  // ── Revenu range provenance (Codex): a 'salary' key with an out-of-range
  //    value must NOT confirm the fact (else fiscal unlocks on a clamped/fake
  //    revenu). The revenu field range is [>0, 300000]. ──
  group('revenu1 provenance requires an in-range value', () {
    testWidgets('salary key with a zero value does NOT confirm revenu1',
        (tester) async {
      // Lower boundary: 0 is the field minimum → not a confirmed revenu.
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 0,
            canton: 'GE',
            conjointSalaire: 5000,
            provided: {'salary', 'canton'})),
      );
      await _incrementChildren(tester);
      expect(find.byKey(_fiscalHero), findsNothing,
          reason: 'revenu1 = 0 is not a confirmed revenu');
      expect(_gateWith(tester, 'revenu1').missing.map((f) => f.key),
          contains('revenu1'));
    });

    testWidgets('above-range salary (30000/mo → 360000/an) is not clamped-confirmed',
        (tester) async {
      // Upper boundary: 360000 > 300000 must NOT confirm/clamp to 300000.
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 30000,
            canton: 'GE',
            conjointSalaire: 5000,
            provided: {'salary', 'canton'})),
      );
      await _incrementChildren(tester);
      expect(find.byKey(_fiscalHero), findsNothing,
          reason: '360000 > 300000 → revenu1 unconfirmed → fiscal gated');
      final gate = _gateWith(tester, 'revenu1');
      expect(gate.missing.map((f) => f.key), contains('revenu1'));
      expect(gate.missing.map((f) => f.key), isNot(contains('revenu2')),
          reason: 'the real conjoint confirmed revenu2 — only revenu1 remains');
    });

    testWidgets('valid→zero salary rehydration re-gates fiscal (no stale revenu1)',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(
          salaire: 8000,
          canton: 'GE',
          conjointSalaire: 5000,
          provided: {'salary', 'canton'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _incrementChildren(tester);
      expect(find.byKey(_fiscalHero), findsOneWidget);

      fake.hydrate(_profile(
          salaire: 0,
          canton: 'GE',
          conjointSalaire: 5000,
          provided: {'salary', 'canton'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_fiscalHero), findsNothing,
          reason: 'salary→0 un-confirms revenu1 → fiscal re-gates, no stale 96000');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  PARTAGE DU RÉGIME (tab 2, secondary) — gated on patrimoine1 + patrimoine2
  // ══════════════════════════════════════════════════════════════
  group('Régime output', () {
    testWidgets('no profile: régime gated, gate lists {patrimoine1,patrimoine2}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Régime');

      expect(find.byType(RegimeMatrimonialPie), findsNothing,
          reason: 'no asset split on the fabricated 200000/100000 defaults');
      final gate = _gateWith(tester, 'patrimoine1');
      expect(gate.missing.map((f) => f.key),
          containsAll(<String>['patrimoine1', 'patrimoine2']));
    });

    testWidgets('touch both patrimoines: the pie split renders', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Régime');
      await _touchPatrimoine1(tester, 300000);
      await _touchPatrimoine2(tester, 150000);

      expect(find.byType(RegimeMatrimonialPie), findsOneWidget);
      expect(_state(tester).debugPatrimoine1, 300000.0);
      expect(_state(tester).debugPatrimoine2, 150000.0);
      expect(_gateWith(tester, 'revenu1').facts, isNotEmpty,
          reason: 'the timeline gate (revenu) is still present in tab 2');
    });

    testWidgets('touch only patrimoine1: régime stays gated on patrimoine2',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Régime');
      await _touchPatrimoine1(tester, 300000);

      expect(find.byType(RegimeMatrimonialPie), findsNothing);
      final gate = _gateWith(tester, 'patrimoine2');
      expect(gate.missing.map((f) => f.key), contains('patrimoine2'));
      expect(gate.missing.map((f) => f.key), isNot(contains('patrimoine1')),
          reason: 'patrimoine1 was touched → confirmed');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  HISTOIRE À DEUX (tab 2, secondary) — gated on revenu1 + revenu2
  // ══════════════════════════════════════════════════════════════
  group('Timeline output', () {
    testWidgets('no profile: timeline gated, gate lists {revenu1,revenu2}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Régime');

      expect(find.byType(CoupleNarrativeTimeline), findsNothing,
          reason: 'no couple income arc on the fabricated 80000/60000 defaults');
      final gate = _gateWith(tester, 'revenu1');
      expect(gate.missing.map((f) => f.key),
          containsAll(<String>['revenu1', 'revenu2']));
    });

    testWidgets('salary key + real conjoint seed both revenus: timeline renders',
        (tester) async {
      // The timeline gate needs ONLY the two revenus — a complete fiscal profile
      // (salary key + conjoint) unlocks it with no extra touch.
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 8000,
            canton: 'GE',
            conjointSalaire: 5000,
            provided: {'salary', 'canton'})),
      );
      await _goToTab(tester, 'Régime');
      expect(find.byType(CoupleNarrativeTimeline), findsOneWidget);
    });

    // ── HOLE C: acts 2/3 used (revenu1+revenu2)/12 × 1.15 / × 0.65 — hardcoded
    //    multipliers rendered as the couple's FUTURE monthly income. Only Act 1
    //    (real, confirmed current income) may show a CHF; the future acts are
    //    illustrative (delta % + insight under a « Parcours illustratif »
    //    caption), never a fabricated future personal CHF. ──
    testWidgets(
        'timeline future acts are illustrative — no fabricated future CHF, '
        'caption present', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 8000, // revenu1 = 96000
            canton: 'GE',
            conjointSalaire: 5000, // revenu2 = 60000
            provided: {'salary', 'canton'})),
      );
      await _goToTab(tester, 'Régime');
      expect(find.byType(CoupleNarrativeTimeline), findsOneWidget);

      final r1 = _state(tester).debugRevenu1 as double;
      final r2 = _state(tester).debugRevenu2 as double;
      final act1 = (r1 + r2) / 12; // real confirmed couple monthly income

      // Act 1 (real, confirmed) income IS shown.
      expect(find.textContaining(formatChf(act1), skipOffstage: false),
          findsWidgets,
          reason: 'act 1 = the real confirmed couple monthly income');
      // Acts 2/3 fabricated future income (×1.15 / ×0.65) must NOT be rendered.
      expect(find.textContaining(formatChf(act1 * 1.15), skipOffstage: false),
          findsNothing,
          reason: 'no fabricated +15% future CHF presented as a projection');
      expect(find.textContaining(formatChf(act1 * 0.65), skipOffstage: false),
          findsNothing,
          reason: 'no fabricated -35% future CHF presented as a projection');
      // The illustrative caption frames the future acts.
      expect(find.textContaining('Parcours illustratif', skipOffstage: false),
          findsOneWidget,
          reason: 'future acts framed as an illustrative parcours, not a projection');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  RENTE DE SURVIVANT (tab 3, secondary) — gated on rente LPP
  // ══════════════════════════════════════════════════════════════
  group('Protection output', () {
    testWidgets('no profile: protection gated, gate lists {renteLpp}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Protection');

      expect(find.byKey(_survivorHero), findsNothing,
          reason: 'no survivor figure on the fabricated 2500 LPP default');
      expect(find.byType(SurvivorPensionWidget), findsNothing,
          reason: 'the survivor-pension widget is a LPP figure too → gated');
      expect(_gateWith(tester, 'renteLpp').missing.map((f) => f.key),
          contains('renteLpp'));
    });

    testWidgets('seed avoirLpp key: survivor hero == service output',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(avoirLpp: 300000, provided: {'avoirLpp'})),
      );
      await _goToTab(tester, 'Protection');

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_survivorHero), findsOneWidget);
      // 300000 × 6.8% / 12 ≈ 1700 ≠ the fabricated 2500 default.
      expect(_state(tester).debugRenteLpp, isNot(2500.0));
      expect(
        find.descendant(
            of: find.byKey(_survivorHero),
            matching: find.text(_expectedSurvivorPrimary(tester))),
        findsOneWidget,
        reason: 'the hero renders the LPP survivor rente only (no max-AVS blend)',
      );
    });

    // ── P2 residual fix (mirrors concubinage): the survivor figure must be the
    //    CONFIRMED LPP survivor rente only. The fabricated max-AVS component
    //    (avsRenteMaxMensuelle × avsSurvivorFactor) and any total blending it in
    //    are ABSENT; the shared SurvivorPensionWidget (which carried the
    //    fabrication) is gone; the art. 19 / LAVS art. 23 caveats are present. ──
    testWidgets(
        'survivor figure is LPP-only — no fabricated max-AVS, no shared widget, '
        'eligibility caveats present', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(avoirLpp: 300000, provided: {'avoirLpp'})),
      );
      await _goToTab(tester, 'Protection');

      expect(find.byKey(_survivorHero), findsOneWidget);
      final rente = _state(tester).debugRenteLpp as double;
      final lppSurvivor = rente * FamilyService.lppSurvivorFactor;

      // Hero == the confirmed LPP survivor rente (renteLpp × 60%), scoped to the
      // hero (the LPP card renders the same figure below).
      expect(
        find.descendant(
            of: find.byKey(_survivorHero),
            matching: find.text('${FamilyService.formatChf(lppSurvivor)}/mois')),
        findsOneWidget,
        reason: 'hero shows the confirmed LPP survivor rente, not a max-AVS blend',
      );

      // OLD fabrication: max-AVS as a personal figure (2520 × 0.80 = 2016) and the
      // total that blended it into the hero — both must be ABSENT anywhere.
      const avsFab = avsRenteMaxMensuelle * FamilyService.avsSurvivorFactor;
      expect(find.text('${FamilyService.formatChf(avsFab)}/mois'), findsNothing,
          reason: 'no fabricated personal max-AVS component');
      expect(
        find.text('${FamilyService.formatChf(avsFab + lppSurvivor)}/mois'),
        findsNothing,
        reason: 'no max-AVS + LPP blended total in the hero',
      );

      // The shared widget (carried partnerAvsRente = max-AVS) is removed.
      expect(find.byType(SurvivorPensionWidget), findsNothing,
          reason: 'SurvivorPensionWidget removed from mariage protection');

      // LPP figure is CONDITIONAL on art. 19 eligibility, and the AVS advantage is
      // stated qualitatively (LAVS art. 23) with no CHF.
      expect(find.textContaining('enfant à charge'), findsOneWidget,
          reason: 'LPP art. 19 eligibility caveat present under the LPP figure');
      // « LAVS art. 23 » now appears in BOTH the qualitative AVS note and the
      // HOLE-A conditions caveat under the comparison table — at least one.
      expect(find.textContaining('LAVS art. 23'), findsWidgets,
          reason: 'AVS advantage stated qualitatively, no fabricated CHF');
    });

    testWidgets('touch renteLpp: survivor hero renders', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Protection');
      await _touchRenteLpp(tester, 3200);

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_survivorHero), findsOneWidget);
      expect(_state(tester).debugRenteLpp, 3200.0);
    });

    testWidgets('avoirLpp key with a zero value does NOT confirm renteLpp',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(avoirLpp: 0, provided: {'avoirLpp'})),
      );
      await _goToTab(tester, 'Protection');
      expect(find.byKey(_survivorHero), findsNothing,
          reason: 'avoir = 0 → rente 0 → unconfirmed → protection gated');
    });

    testWidgets('above-range LPP (huge avoir → rente > 8000) is not clamped',
        (tester) async {
      // Upper boundary: rente ≈ 11333 > 8000 must NOT confirm/clamp to 8000.
      await _pump(
        tester,
        _FakeProvider(_profile(avoirLpp: 2000000, provided: {'avoirLpp'})),
      );
      await _goToTab(tester, 'Protection');
      expect(find.byKey(_survivorHero), findsNothing,
          reason: 'rente > 8000 → renteLpp unconfirmed → protection gated');
      expect(_gateWith(tester, 'renteLpp').missing.map((f) => f.key),
          contains('renteLpp'));
    });

    testWidgets('clearing profile re-gates a seeded protection output',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(avoirLpp: 300000, provided: {'avoirLpp'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _goToTab(tester, 'Protection');
      expect(find.byKey(_survivorHero), findsOneWidget);

      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_survivorHero), findsNothing,
          reason: 'seeded LPP loses provenance on clear → protection re-gates');
    });

    // ── HOLE A: the ✓/✗ comparison table rendered married ✓ for AVS + LPP
    //    survivor pensions UNCONDITIONALLY. Eligibility is conditional (LPP
    //    art. 19, LAVS art. 23) → a caveat must sit under the table. The table
    //    is educational (always rendered, even with no profile). ──
    testWidgets('protection comparison table carries the conditions caveat',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Protection');
      expect(
          find.textContaining('réception automatique', skipOffstage: false),
          findsOneWidget,
          reason: 'the ✓ table states married pensions are conditional access, '
              'not an automatic payout');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  CHECKLIST (tab 4) — HOLE B: the LPP-beneficiary item must be CONDITIONAL.
  //  Old copy said the spouse « devient automatiquement bénéficiaire » — false
  //  and contradicts the art. 19 caveat shown elsewhere.
  // ══════════════════════════════════════════════════════════════
  group('Checklist honesty (LPP beneficiary conditional)', () {
    testWidgets('item is conditional — no « automatiquement »', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _goToTab(tester, 'Checklist');
      // AnimatedCrossFade builds the (collapsed) description → skipOffstage:false
      // reaches it without expanding the item.
      expect(
          find.textContaining('automatiquement', skipOffstage: false),
          findsNothing,
          reason: 'the spouse does NOT automatically become the LPP survivor '
              'beneficiary — eligibility is conditional (art. 19)');
      expect(find.textContaining('sous conditions', skipOffstage: false),
          findsWidgets,
          reason: 'the LPP survivor beneficiary is framed as conditional');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  CLAUSE 3a (tab 3) — Codex subtree audit: NO invented balance.
  //  Old code rendered (_revenu1 + _revenu2) × 0.05 × 10 when no real 3a.
  // ══════════════════════════════════════════════════════════════
  group('Clause 3a (no fabricated balance)', () {
    testWidgets('renders the REAL profile 3a balance when > 0', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(epargne3a: 42000)),
      );
      await _goToTab(tester, 'Protection');

      final clause = find.byType(Clause3aWidget);
      expect(clause, findsOneWidget,
          reason: 'a real profile 3a balance (>0) shows the clause widget');
      expect(tester.widget<Clause3aWidget>(clause).balance3a, 42000.0,
          reason: 'the widget carries the REAL profile 3a, not revenu × 0.05 × 10');
    });

    testWidgets('absent when the profile 3a balance is 0/unknown', (tester) async {
      // A profile WITH income but no 3a: the old code would still render an
      // invented balance (revenu × 0.05 × 10). It must now be absent.
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 9000,
            conjointSalaire: 6000,
            provided: {'salary'})),
      );
      await _goToTab(tester, 'Protection');
      expect(find.byType(Clause3aWidget), findsNothing,
          reason: 'no real 3a balance → no invented %-of-income clause shown');
    });

    testWidgets('does not survive a profile clear (no stale balance)',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      fake.hydrate(_profile(epargne3a: 42000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _goToTab(tester, 'Protection');
      expect(find.byType(Clause3aWidget), findsOneWidget);

      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Clause3aWidget), findsNothing,
          reason: 'profile 3a is a state field → 0 on clear, no stale CHF');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  Per-output independence + no-provider safety
  // ══════════════════════════════════════════════════════════════
  testWidgets('fiscal confirmed does not unlock régime or protection',
      (tester) async {
    // Fiscal facts confirmed (salary + canton keys + conjoint), nbEnfants
    // touched. Patrimoines + renteLpp stay assumed.
    await _pump(
      tester,
      _FakeProvider(_profile(
          salaire: 8000,
          canton: 'GE',
          conjointSalaire: 5000,
          provided: {'salary', 'canton'})),
    );
    await _incrementChildren(tester);
    expect(find.byKey(_fiscalHero), findsOneWidget, reason: 'fiscal confirmed');

    await _goToTab(tester, 'Régime');
    expect(find.byType(RegimeMatrimonialPie), findsNothing,
        reason: 'patrimoines still assumed → régime gated independently');

    await _goToTab(tester, 'Protection');
    expect(find.byKey(_survivorHero), findsNothing,
        reason: 'renteLpp still assumed → protection gated independently');
    expect(find.byType(SituationGateCard), findsWidgets);
  });

  testWidgets('no provider in tree: defaults kept, every output gated',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 9000));
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
        home: MariageScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MariageScreen), findsOneWidget);
    expect(find.byKey(_fiscalHero), findsNothing);
    expect(find.byType(MarriagePenaltyGauge), findsNothing,
        reason: 'no fiscal figure computes without a confirmed fact');
  });
}
