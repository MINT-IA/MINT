import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/coach/survivor_pension_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/widgets/visualizations/concubinage_decision_matrix.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for concubinage_screen (the DUAL-PARTY
/// mariage-vs-concubinage comparator).
///
/// No computed « ta situation » figure is shown on a fabricated default. Each
/// result output gates on the facts IT consumes; a fact is CONFIRMED only when
/// it comes from real data — seeded from the user's profile (partner 1 = the
/// USER, or the real `conjoint` for partner 2) OR entered by the user (a non-null
/// value; canton confirmed via the on-screen picker OR a real profile canton).
/// A default is a null « Non renseigné », never an invented 80000/60000/300000.
///
/// Per-output fact manifest:
///   • Fiscal cluster (matrix + score + détail) → revenu1, revenu2, canton
///   • Impôt de succession                       → patrimoine, canton
///   • Hero patrimoine                           → shown only when patrimoine ≠ null
///   • Rente de survivant (Tab2)                 → renteLpp; MARRIED figure is the
///     LPP survivor pension only (renteLpp × 60%) — NO fabricated max-AVS
///   • Clause 3a (Tab2)                          → educational, conditional copy,
///     NO naked balance (no reliable provenance for the 3a balance)
///
/// SurvivorPensionWidget + Clause3aWidget are removed from concubinage (shared
/// widgets that fabricated a max-AVS married figure / a value-only 3a balance).
/// partner 2 income (le concubin) is NEVER seeded from the user's own salary.
///
/// Every assertion is on the RENDERED figure (gate card presence/absence, a
/// specific CHF, a widget) — each goes RED if the gate is removed (i.e. if the
/// screen went back to computing on 80000/60000/300000/'VD'/2500).

// ── Tab1 MintAmountField build order (top → bottom) ──
const _revenu1 = 0;
const _revenu2 = 1;
const _patrimoine = 2;

// ── Gate card titles ──
const _fiscalTitle = 'Comparaison fiscale';
const _inheritanceTitle = 'Impôt de succession';
const _survivorTitle = 'Rente de survivant';

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

CoachProfile _profile({
  double salaire = 8000,
  String canton = 'VD',
  Set<String> provided = const {},
  ConjointProfile? conjoint,
  PrevoyanceProfile? prevoyance,
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: canton,
    salaireBrutMensuel: salaire,
    etatCivil: CoachCivilStatus.celibataire,
    userProvidedFields: provided,
    conjoint: conjoint,
    prevoyance: prevoyance ?? const PrevoyanceProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(WidgetTester tester, CoachProfileProvider provider) async {
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
        home: ConcubinageScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(ConcubinageScreen)) as dynamic;

List<MintAmountField> _fields(WidgetTester tester) =>
    tester.widgetList<MintAmountField>(find.byType(MintAmountField)).toList();

Future<void> _setAmount(WidgetTester tester, int index, double v) async {
  _fields(tester)[index].onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Confirm the canton by invoking the on-screen picker's onChanged (same driving
/// technique as MintAmountField.onChanged — no fragile overlay tapping).
Future<void> _setCanton(WidgetTester tester, String code) async {
  tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .onChanged!(code);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Switch to the « Protection » tab (Tab2) — TabBarView builds it lazily.
Future<void> _openTab2(WidgetTester tester) async {
  _state(tester).debugTabController.animateTo(1);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Switch to the « Checklist » tab (Tab3).
Future<void> _openTab3(WidgetTester tester) async {
  _state(tester).debugTabController.animateTo(2);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Drive the Tab2 renteLpp slider by its label (robust to whether Tab1 is still
/// in the tree during/after the tab transition).
Future<void> _setRenteLpp(WidgetTester tester, double v) async {
  _fields(tester)
      .firstWhere((f) => f.label == 'Rente LPP mensuelle du partenaire')
      .onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

SituationGateCard? _gate(WidgetTester tester, String title) {
  for (final c
      in tester.widgetList<SituationGateCard>(find.byType(SituationGateCard))) {
    if (c.title == title) return c;
  }
  return null;
}

void main() {
  // ══════════════════════════════════════════════════════════════
  //  SCREEN OPEN, NO PROFILE → nothing computed on a fabricated default
  // ══════════════════════════════════════════════════════════════
  group('Screen open — Tab1 (no profile)', () {
    testWidgets('no CHF figure anywhere; fiscal + inheritance gated; no hero',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      // The two Tab1 outputs are gated.
      expect(_gate(tester, _fiscalTitle), isNotNull);
      expect(_gate(tester, _inheritanceTitle), isNotNull);
      // The fiscal-summary visual (matrix) is not built on invented income.
      expect(find.byType(ConcubinageDecisionMatrix), findsNothing);
      // The hero (patrimoine echo) is hidden until patrimoine is confirmed.
      expect(find.textContaining('CHF'), findsNothing,
          reason: 'no result number computed on 80000/60000/300000/VD');
    });

    testWidgets('state fields are null / unconfirmed on open', (tester) async {
      await _pump(tester, _FakeProvider(null));
      final st = _state(tester);
      expect(st.debugRevenu1, isNull);
      expect(st.debugRevenu2, isNull);
      expect(st.debugPatrimoine, isNull);
      expect(st.debugRenteLpp, isNull);
      expect(st.debugCantonConfirmed, isFalse,
          reason: 'default "VD" in the picker is NOT a confirmed fact');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  FISCAL CLUSTER — gated on revenu1 + revenu2 + canton
  // ══════════════════════════════════════════════════════════════
  group('Fiscal cluster', () {
    testWidgets('both incomes entered but canton untouched → still gated',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _revenu1, 80000);
      await _setAmount(tester, _revenu2, 60000);
      final g = _gate(tester, _fiscalTitle);
      expect(g, isNotNull,
          reason: 'no confirmed canton → the tax barème would be fabricated');
      expect(g!.gate.missing.map((f) => f.key), <String>['canton']);
      expect(find.byType(ConcubinageDecisionMatrix), findsNothing);
    });

    testWidgets('incomes + canton picked → fiscal cluster renders with CHF',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _revenu1, 80000);
      await _setAmount(tester, _revenu2, 60000);
      await _setCanton(tester, 'VD');
      expect(_gate(tester, _fiscalTitle), isNull, reason: 'all 3 facts confirmed');
      expect(find.byType(ConcubinageDecisionMatrix), findsOneWidget);
      expect(find.text('Impôts 2 célibataires'), findsOneWidget);
      expect(find.textContaining('CHF'), findsWidgets,
          reason: 'the fiscal detail figures render once unlocked');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  INHERITANCE — gated on patrimoine + canton, exact impôt on unlock
  // ══════════════════════════════════════════════════════════════
  group('Inheritance card', () {
    testWidgets('patrimoine entered but canton untouched → gated on canton',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _patrimoine, 300000);
      final g = _gate(tester, _inheritanceTitle);
      expect(g, isNotNull);
      expect(g!.gate.missing.map((f) => f.key), <String>['canton']);
      // The hero appears (patrimoine confirmed) but the succession impôt does not.
      expect(find.text(FamilyService.formatChf(75000)), findsNothing);
    });

    testWidgets('patrimoine + canton (VD 25%) → impôt = 75\'000 renders',
        (tester) async {
      // Canton seeded from the profile (key + valid); patrimoine typed.
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'VD', provided: {'canton'})),
      );
      await _setAmount(tester, _patrimoine, 300000);
      expect(_gate(tester, _inheritanceTitle), isNull);
      // Deterministic: 300000 × VD-taux-tiers 0.25 = 75000 (real canton rate,
      // never a hardcoded 24%).
      expect(find.text(FamilyService.formatChf(75000)), findsWidgets);
      expect(find.text(FamilyService.formatChf(300000)), findsWidgets);
      // HOLE 2: the CHF is framed CONDITIONALLY (no presumed inheritance). The
      // « sans testament → rien » + « si testament → taux tiers » wording must be
      // present, and the tax must read as conditional (« paierait », « Si tu »),
      // never « ton partenaire paie X » unconditionally.
      expect(find.textContaining('Sans testament'), findsWidgets,
          reason: 'the non-heir default is stated, not a presumed inheritance');
      expect(find.textContaining('Si tu'), findsWidgets,
          reason: 'the tax is conditional on a testament designation');
      // The tax is on 100% of the patrimoine → disclose it's a MAXIMUM: the
      // réserve héréditaire of descendants limits the transmissible share.
      expect(find.textContaining('réserve héréditaire'), findsWidgets,
          reason: 'the full-estate tax is caveated by the descendants reserve');
    });

    testWidgets('stale invalidation: editing patrimoine drops the old impôt',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'VD', provided: {'canton'})),
      );
      await _setAmount(tester, _patrimoine, 300000);
      expect(find.text(FamilyService.formatChf(75000)), findsWidgets);
      // Re-edit the determinative fact → the prior figure must not survive.
      await _setAmount(tester, _patrimoine, 400000);
      expect(find.text(FamilyService.formatChf(75000)), findsNothing,
          reason: 'a displayed figure never outlives a fact change');
      expect(find.text(FamilyService.formatChf(100000)), findsWidgets,
          reason: '400000 × 0.25 = 100000');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  HERO — patrimoine echo shown only once patrimoine confirmed
  // ══════════════════════════════════════════════════════════════
  group('Hero premier éclairage', () {
    testWidgets('absent on open, present after patrimoine entered',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(find.text(FamilyService.formatChf(300000)), findsNothing);
      await _setAmount(tester, _patrimoine, 300000);
      // The hero echoes the confirmed patrimoine (a real user input, not a
      // computed result on a fabricated default).
      expect(find.text(FamilyService.formatChf(300000)), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  CANTON provenance = on-screen touch OR real profile canton
  // ══════════════════════════════════════════════════════════════
  group('Canton provenance', () {
    testWidgets('on-screen picker touch confirms the canton', (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(_state(tester).debugCantonConfirmed, isFalse);
      await _setCanton(tester, 'GE');
      expect(_state(tester).debugCantonConfirmed, isTrue);
      expect(_state(tester).debugCanton, 'GE');
    });

    testWidgets('real profile canton (key + valid) → seeded confirmed',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'GE', provided: {'canton'})),
      );
      expect(_state(tester).debugCanton, 'GE');
      expect(_state(tester).debugCantonConfirmed, isTrue);
    });

    testWidgets('legacy valid "ZH" WITHOUT the canton key → NOT confirmed',
        (tester) async {
      // fromJson defaults canton to 'ZH' with no user input; provided is empty.
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'ZH', provided: {'salary'})),
      );
      expect(_state(tester).debugCantonConfirmed, isFalse,
          reason: 'no q_canton answer → the ZH default never confirms');
    });

    testWidgets('keyed-EMPTY canton ("") → NOT confirmed', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: '', provided: {'canton'})),
      );
      expect(_state(tester).debugCantonConfirmed, isFalse);
    });

    testWidgets('keyed-invalid junk "XX" → NOT confirmed', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'XX', provided: {'canton'})),
      );
      expect(_state(tester).debugCantonConfirmed, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SEED — revenu1 (user) key+range ; revenu2 (partner) NEVER from user
  // ══════════════════════════════════════════════════════════════
  group('Income seed provenance', () {
    testWidgets('revenu1: no salary key → not seeded', (tester) async {
      await _pump(tester, _FakeProvider(_profile(salaire: 8000, provided: {})));
      expect(_state(tester).debugRevenu1, isNull);
    });

    testWidgets('revenu1: in-range with key → seeded (8000×12)', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 8000, provided: {'salary'})),
      );
      expect(_state(tester).debugRevenu1, 96000.0);
    });

    testWidgets('revenu1: out-of-range (200000/mo) → not seeded', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 200000, provided: {'salary'})),
      );
      expect(_state(tester).debugRevenu1, isNull,
          reason: 'out-of-range annual is never clamped into a seed');
    });

    testWidgets('revenu2: user salary present but NO conjoint → stays null',
        (tester) async {
      // The critical cross-contamination guard: the partner income is never
      // seeded from the user's own salary.
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 8000, provided: {'salary'})),
      );
      expect(_state(tester).debugRevenu1, 96000.0);
      expect(_state(tester).debugRevenu2, isNull,
          reason: 'partner income is never the user salary');
    });

    testWidgets('revenu2: real conjoint income → seeded (5000×12)',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          provided: {'salary'},
          conjoint: const ConjointProfile(salaireBrutMensuel: 5000),
        )),
      );
      expect(_state(tester).debugRevenu2, 60000.0,
          reason: 'seeded from the real declared partner income');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TAB 2 — survivor gated on renteLpp (LPP-only, no max-AVS fabrication)
  //          + 3a educational (no naked balance, conditional heir copy)
  // ══════════════════════════════════════════════════════════════
  group('Tab2 protection', () {
    testWidgets('open with no data → survivor gated, no CHF, no shared widgets',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _openTab2(tester);
      expect(_gate(tester, _survivorTitle), isNotNull);
      // HOLE 1 / HOLE 3: the fabricating shared widgets are gone from concubinage.
      expect(find.byType(SurvivorPensionWidget), findsNothing,
          reason: 'removed: it showed a fabricated max-AVS married figure');
      expect(find.byType(Clause3aWidget), findsNothing,
          reason: 'removed: it showed a value-only (estimable) 3a balance');
      expect(find.textContaining('CHF'), findsNothing);
      // HOLE 3: the 3a message is present but CONDITIONAL, with no naked balance.
      expect(find.textContaining('Sans clause'), findsWidgets,
          reason: 'conditional 3a beneficiary copy, no computed balance');
    });

    testWidgets(
        'HOLE 1: renteLpp entered → married figure is LPP-only (renteLpp×60%), '
        'NOT the fabricated max-AVS blend', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _openTab2(tester);
      await _setRenteLpp(tester, 2500);
      expect(_gate(tester, _survivorTitle), isNull);
      // Married survivor = 2500 × lppSurvivorFactor(0.60) = 1500, grounded in the
      // confirmed renteLpp input.
      const lppSurvivor = 2500 * FamilyService.lppSurvivorFactor;
      expect(lppSurvivor, 1500.0);
      expect(find.text(FamilyService.formatChf(1500)), findsWidgets,
          reason: 'married figure is the LPP survivor pension only');
      // The OLD fabrication = maxAVS(≈2520 test fallback)×0.8 + 1500 = 3516, and
      // its AVS component 2016, must NOT appear as a personal figure.
      expect(find.text(FamilyService.formatChf(3516)), findsNothing,
          reason: 'no max-AVS + LPP blend');
      expect(find.text(FamilyService.formatChf(2016)), findsNothing,
          reason: 'no fabricated personal max-AVS component');
      // And the shared widget stays gone even once renteLpp is confirmed.
      expect(find.byType(SurvivorPensionWidget), findsNothing);
      // The married figure is CONDITIONAL on LPP art. 19 eligibility (dependent
      // child, or age 45 + 5 years of marriage) — not an unconditional CHF.
      expect(find.textContaining('conditions LPP art. 19'), findsOneWidget,
          reason: 'survivor rente presented as conditional, not a certain amount');
    });

    testWidgets(
        'HOLE 3: profile with a positive 3a balance but NO provided-key → the '
        'balance is NEVER shown (no Clause3aWidget), only conditional copy',
        (tester) async {
      // A value-only positive balance (could be an estimate) must not surface as
      // « ton 3a = CHF X » — there is no reliable provenance for it.
      await _pump(
        tester,
        _FakeProvider(_profile(
          prevoyance: const PrevoyanceProfile(totalEpargne3a: 40000),
        )),
      );
      await _openTab2(tester);
      expect(find.byType(Clause3aWidget), findsNothing,
          reason: 'value-only 3a balance is never rendered as a figure');
      expect(find.text(FamilyService.formatChf(40000)), findsNothing,
          reason: 'no naked 3a balance');
      expect(find.textContaining('Sans clause'), findsWidgets,
          reason: 'conditional beneficiary-order copy is shown instead');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  Tab3 checklist — heir destination stated as the legal ORDER,
  //  never presuming the user has no descendants
  // ══════════════════════════════════════════════════════════════
  group('Tab3 checklist', () {
    testWidgets('testament item states the legal order, not "tout va aux parents"',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _openTab3(tester);
      expect(find.textContaining('ordre légal'), findsWidgets,
          reason: 'succession follows descendants-first legal order');
      expect(find.textContaining('tout va à tes parents'), findsNothing,
          reason: 'never presume the user has no children');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  a11y root boundary + discrete gate nodes survive the refactor
  // ══════════════════════════════════════════════════════════════
  testWidgets('screen-root Semantics boundary + gate cards present',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakeProvider(null));
    expect(tester.getSemantics(find.byType(ConcubinageScreen)), isNotNull);
    // Tab1 shows exactly the two gated outputs on open.
    expect(find.byType(SituationGateCard), findsNWidgets(2));
    handle.dispose();
  });
}
