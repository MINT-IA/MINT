import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/coach/couple_narrative_timeline.dart';
import 'package:mint_mobile/widgets/coach/survivor_pension_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/widgets/visualizations/marriage_tax_comparison.dart';
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

Future<void> _pump(
  WidgetTester tester,
  CoachProfileProvider provider, {
  // Non-FR pump = the i18n probe : any string still hardcoded in French shows
  // up verbatim under another locale instead of being translated.
  Locale locale = const Locale('fr'),
}) async {
  // Tall surface so each (lazy) tab's result slot is inflated without scrolling.
  await tester.binding.setSurfaceSize(const Size(1200, 9000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: const MariageScreen(),
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
  // Sans signe : « + » / « - » était la forme typographique du verdict
  // « pénalité » / « bonus », que ce modèle forfaitaire ne peut pas porter.
  // Le sens de l'écart est désormais dans le LIBELLÉ sous le montant.
  final diff = r['difference'] as double;
  return FamilyService.formatChf(diff.abs());
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
      expect(find.byType(MarriageTaxComparison), findsNothing,
          reason: 'the tax comparison is a fiscal figure too → gated');
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
      expect(find.byType(MarriageTaxComparison), findsOneWidget);
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
    expect(find.byType(MarriageTaxComparison), findsNothing,
        reason: 'no fiscal figure computes without a confirmed fact');
  });

  // ══════════════════════════════════════════════════════════════
  //  IMPÔT DU COUPLE — mécanique, pas verdict
  //
  //  Même constat que sur concubinage (PR #1053) : « Pénalité » / « Bonus » et
  //  le rouge/vert sont des jugements de valeur posés sur une estimation
  //  forfaitaire (barème marié forfaitaire, ni déductions réelles, ni commune,
  //  ni barème cantonal détaillé). Les libellés DÉCRIVENT le sens de l'écart.
  //
  //  S'y ajoute un défaut propre à cet écran : les deux branches du ternaire du
  //  récit renvoyaient LA MÊME clé, si bien qu'un couple dont l'impôt BAISSE
  //  lisait un texte sur « la pénalité du mariage ». L'écran se contredisait.
  //
  //  Chaque assertion est sur le RENDU : elle repasse ROUGE si un verdict
  //  revient (mot, couleur, récit de la mauvaise branche, chaîne hors ARB).
  // ══════════════════════════════════════════════════════════════
  group('Impôt du couple — mécanique, pas verdict', () {
    // Revenus PROCHES → l'impôt du ménage marié dépasse celui de 2 célibataires.
    Future<void> unlockMariePlusEleve(WidgetTester tester,
        {Locale locale = const Locale('fr')}) async {
      await _pump(tester, _FakeProvider(null), locale: locale);
      await _touchRevenu1(tester, 80000);
      await _touchRevenu2(tester, 60000);
      await _touchCanton(tester, 'VD');
      await _incrementChildren(tester);
    }

    // Revenu TRÈS INÉGAL → le barème réduit fait passer l'impôt du ménage marié
    // sous celui de 2 célibataires. C'est la branche que le récit contredisait.
    Future<void> unlockCelibatairesPlusEleve(WidgetTester tester,
        {Locale locale = const Locale('fr')}) async {
      await _pump(tester, _FakeProvider(null), locale: locale);
      await _touchRevenu1(tester, 200000);
      await _touchRevenu2(tester, 0);
      await _touchCanton(tester, 'VD');
      await _incrementChildren(tester);
    }

    // Les deux fixtures ci-dessus valent par leur SENS, pas par leurs chiffres :
    // si le moteur change, ce test tombe avant les assertions de rendu et dit
    // pourquoi, au lieu de les laisser mentir.
    test('les deux fixtures encadrent bien les deux sens de l\'écart', () {
      expect(
        FamilyService.compareFiscalMariage(
            revenu1: 80000, revenu2: 60000, canton: 'VD', nbEnfants: 1)['isPenalite'],
        isTrue,
        reason: 'revenus proches → impôt du ménage plus élevé marié',
      );
      expect(
        FamilyService.compareFiscalMariage(
            revenu1: 200000, revenu2: 0, canton: 'VD', nbEnfants: 1)['isPenalite'],
        isFalse,
        reason: 'un revenu domine → impôt du ménage plus élevé à deux célibataires',
      );
    });

    /// Every rendered `Text.data` on the current tab.
    List<String> renderedTexts(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();

    // ── (a) aucun qualificatif de valeur sur les deux surfaces ──
    //
    // « pénalité » survit à UN seul endroit et c'est voulu : l'encart éducatif
    // en bas d'onglet, où c'est un fait de société (~700'000 couples, arrêt du
    // TF de 1984) et non le verdict rendu sur CE couple.
    void expectNoVerdictWord(WidgetTester tester) {
      final penalite = renderedTexts(tester)
          .where((s) => s.toLowerCase().contains('pénalité'))
          .toList();
      expect(penalite.length, 1,
          reason: '« pénalité » ne doit subsister que dans le fait éducatif, '
              'trouvé ${penalite.length} fois : $penalite');
      expect(penalite.single, contains("700'000"),
          reason: 'le seul « pénalité » restant est le fait de société, '
              'pas un verdict sur ce couple');

      final bonus = renderedTexts(tester)
          .where((s) => s.toLowerCase().contains('bonus'))
          .toList();
      expect(bonus, isEmpty,
          reason: '« bonus » est un jugement que ce modèle forfaitaire ne '
              'peut pas porter, trouvé : $bonus');
    }

    testWidgets('(a) branche « impôt plus élevé marié » : aucun qualificatif',
        (tester) async {
      await unlockMariePlusEleve(tester);
      expectNoVerdictWord(tester);
    });

    testWidgets('(a) branche « impôt plus élevé célibataires » : idem',
        (tester) async {
      await unlockCelibatairesPlusEleve(tester);
      expectNoVerdictWord(tester);
    });

    testWidgets('(a) le montant du hero est rendu sans signe', (tester) async {
      await unlockMariePlusEleve(tester);
      final hero =
          tester.widget<MintResultHeroCard>(find.byKey(_fiscalHero));
      expect(hero.primaryValue.startsWith('+'), isFalse,
          reason: 'le signe est la forme typographique du verdict');
      expect(hero.primaryValue.startsWith('-'), isFalse);
      expect(hero.primaryValue, _expectedFiscalPrimary(tester));
    });

    // ── (a) le rouge/vert, version chromatique du même verdict ──
    testWidgets('(a) le hero n\'est plus accentué en rouge ni en vert',
        (tester) async {
      await unlockMariePlusEleve(tester);
      final penalityHero =
          tester.widget<MintResultHeroCard>(find.byKey(_fiscalHero));
      expect(penalityHero.accentColor, isNot(MintColors.error));
      expect(penalityHero.accentColor, isNot(MintColors.success));

      await unlockCelibatairesPlusEleve(tester);
      final bonusHero =
          tester.widget<MintResultHeroCard>(find.byKey(_fiscalHero));
      expect(bonusHero.accentColor, isNot(MintColors.success));
      expect(bonusHero.accentColor, isNot(MintColors.error));
    });

    testWidgets('(a) aucun texte ni icône de l\'onglet Impôts en rouge/vert',
        (tester) async {
      await unlockMariePlusEleve(tester);
      // L'onglet Impôts (hero + saisies + comparaison + déductions + encart)
      // n'a plus aucune raison légitime de porter une couleur de valence : le
      // sens est porté par le libellé et par la longueur des barres.
      final colouredTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) =>
              t.style?.color == MintColors.error ||
              t.style?.color == MintColors.success)
          .map((t) => t.data ?? '')
          .toList();
      expect(colouredTexts, isEmpty,
          reason: 'rouge/vert = verdict chromatique, trouvé : $colouredTexts');

      final colouredIcons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((i) =>
              i.color == MintColors.error || i.color == MintColors.success)
          .map((i) => i.icon.toString())
          .toList();
      expect(colouredIcons, isEmpty,
          reason: 'idem pour les icônes, trouvé : $colouredIcons');
    });

    // ── (b) le récit du hero suit la branche ──
    testWidgets(
        '(b) impôt plus bas marié : le récit n\'est plus le texte de pénalité',
        (tester) async {
      await unlockCelibatairesPlusEleve(tester);
      final hero = tester.widget<MintResultHeroCard>(find.byKey(_fiscalHero));
      expect(hero.narrative, isNot(contains("700'000")),
          reason: 'un couple dont l\'impôt BAISSE lisait le fait « pénalité » : '
              'les deux branches du ternaire renvoyaient la même clé');
      expect(hero.narrative, contains('additionnés'),
          reason: 'le hero énonce le mécanisme, vrai dans les deux sens');
      expect(hero.narrative, contains('barème réduit'));
    });

    testWidgets('(b) le mécanisme est le même récit dans les deux branches',
        (tester) async {
      await unlockMariePlusEleve(tester);
      final a = tester.widget<MintResultHeroCard>(find.byKey(_fiscalHero));
      await unlockCelibatairesPlusEleve(tester);
      final b = tester.widget<MintResultHeroCard>(find.byKey(_fiscalHero));
      expect(a.narrative, b.narrative,
          reason: 'le mécanisme de l\'imposition commune ne dépend pas du sens '
              'de l\'écart — c\'est le libellé qui porte le sens');
    });

    testWidgets('(b) la limite du modèle accompagne le chiffre', (tester) async {
      await unlockMariePlusEleve(tester);
      expect(find.textContaining('Estimation simplifiée'), findsWidgets);
      expect(find.textContaining('barème cantonal détaillé'), findsWidgets);
    });

    // ── (d) la direction est énoncée textuellement, dans les deux sens ──
    testWidgets('(d) le sens de l\'écart est écrit, et il s\'inverse',
        (tester) async {
      await unlockMariePlusEleve(tester);
      expect(find.textContaining('plus élevé marié'), findsWidgets,
          reason: 'la direction ne peut pas reposer sur la seule couleur');
      expect(find.textContaining('plus élevé à deux célibataires'), findsNothing);

      await unlockCelibatairesPlusEleve(tester);
      expect(find.textContaining('plus élevé à deux célibataires'), findsWidgets);
      expect(find.textContaining('plus élevé marié'), findsNothing);
    });

    // ── (c) la comparaison ne rend plus aucune chaîne hors ARB ──
    testWidgets('(c) sous locale de, aucune chaîne française ne subsiste',
        (tester) async {
      await unlockMariePlusEleve(tester, locale: const Locale('de'));
      for (final fr in const [
        'Impact fiscal du mariage',
        'Pénalité du mariage',
        'Bonus du mariage',
        'Aucun impact',
        '2 célibataires',
        'Mariés',
        'Aucune différence',
        'par an',
      ]) {
        expect(find.text(fr), findsNothing,
            reason: '« $fr » est rendu en français à un germanophone');
      }
      expect(find.text('2 Alleinstehende'), findsWidgets,
          reason: 'preuve positive que la comparaison passe bien par l\'ARB');
    });

    testWidgets('(c) le label Semantics énonce le sens ET l\'ampleur',
        (tester) async {
      final handle = tester.ensureSemantics();
      await unlockMariePlusEleve(tester);
      // Ancien label : « Thermomètre pénalité du mariage. Différence: … » —
      // français dur, et un verdict jusque dans VoiceOver.
      final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('deux célibataires ou marié')).first);
      expect(node.label, contains('plus élevé marié'),
          reason: 'le sens doit rester accessible sans voir les barres');
      expect(node.label, contains('CHF'), reason: 'l\'ampleur aussi');
      expect(node.label.toLowerCase(), isNot(contains('pénalité')),
          reason: 'le verdict survivait en VoiceOver');
      handle.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  Tier B smoke — persona FAMILLE seedée (famille_bern) : preuve C2 chiffré.
  //  Le profil est hydraté depuis la SEULE seed (toWizardAnswers →
  //  fromWizardAnswers), sans aucun `_profile(...)` fabriqué : c'est la preuve
  //  bout-en-bout que MINT_E2E_ARCHETYPE=famille_bern débloque un RÉSULTAT
  //  chiffré sur mariage SANS toucher un seul champ à l'écran.
  // ══════════════════════════════════════════════════════════════
  group('famille_bern seed unlocks a chiffré result (no touch)', () {
    CoachProfile seededFamille() => CoachProfile.fromWizardAnswers(
        CoachProfileSeeds.registry['famille_bern']!.toWizardAnswers());

    testWidgets('timeline (Tab Régime) renders the couple monthly income',
        (tester) async {
      await _pump(tester, _FakeProvider(seededFamille()));
      await _goToTab(tester, 'Régime');

      // revenu1 (salaire user) + revenu2 (conjoint réel) confirmés par la seed.
      expect(_state(tester).debugRevenu1, 114000.0);
      expect(_state(tester).debugRevenu2, closeTo(78006, 5),
          reason: 'conjoint net 5556 × facteur IncomeConverter (~1.17) × 12.');
      // La timeline (revenu mensuel RÉEL du couple) rend : le gate revenu1+
      // revenu2 est ouvert par la seed seule (si un revenu manquait, la carte
      // gatée remplacerait la timeline). Le partage du régime reste gaté
      // (patrimoines touch-only) → une SituationGateCard régime subsiste, mais
      // AUCUNE ne liste revenu2 (le gate timeline est complet).
      expect(find.byType(CoupleNarrativeTimeline), findsOneWidget,
          reason: 'timeline gate (revenu1+revenu2) ouverte par la seed seule');
      final revenu2Gated = tester
          .widgetList<SituationGateCard>(find.byType(SituationGateCard))
          .any((c) => c.gate.facts.any((f) => f.key == 'revenu2'));
      expect(revenu2Gated, isFalse,
          reason: 'les deux revenus sont seededFromProfile → aucun gate revenu2');
    });

    testWidgets('survivor hero (Tab Protection) == service output',
        (tester) async {
      await _pump(tester, _FakeProvider(seededFamille()));
      await _goToTab(tester, 'Protection');

      // Rente LPP dérivée de l'avoir certifié (180000), pas du défaut 2500.
      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byKey(_survivorHero), findsOneWidget);
      expect(_state(tester).debugRenteLpp, isNot(2500.0));
      expect(_state(tester).debugRenteLpp, greaterThan(0));
      expect(
        find.descendant(
            of: find.byKey(_survivorHero),
            matching: find.text(_expectedSurvivorPrimary(tester))),
        findsOneWidget,
        reason: 'survivor = rente LPP du défunt × 60 % (LPP art. 19)',
      );
    });
  });
}
