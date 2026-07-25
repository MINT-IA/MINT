import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/widgets/coach/divorce_film_widget.dart';
import 'package:mint_mobile/widgets/coach/prix_du_silence_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for divorce_simulator_screen (the
/// DUAL-PARTY divorce simulator).
///
/// No computed « votre situation » figure is shown on a fabricated default. Each
/// result card gates on the facts IT consumes; a fact is CONFIRMED only when it
/// comes from real data — seeded from the user's profile (conjoint 1 = the USER)
/// OR entered by the user (a non-null value). A default is a null « Non
/// renseigné », never an invented number.
///
/// Per-card fact manifest:
///   • LPP split         → lpp1, lpp2, avoir1, avoir2
///   • Tax impact        → income1, income2
///   • Patrimoine split  → fortune, dettes (+ income1, income2 in séparation)
///   • Pension           → income1, income2, children (touched), duration (touched)
///   • Hero              → primary gated on LPP, secondary (tax delta) on income
///
/// conjoint 2 = the EX-SPOUSE → NEVER seeded from the user's own profile.
///
/// Every assertion is on the RENDERED figure (the gate card's presence/absence,
/// a specific CHF, a row label) — each goes RED if the gate is removed (i.e. if
/// the screen went back to computing on 90000/50000/180000/80000/200000).
///
/// The screen is a `SingleChildScrollView` → every child is built, so
/// `find.byType` works without scrolling. Inputs are driven via `.onChanged`
/// (no viewport hit-test), the CTA via a text tap.

// ── MintAmountField build order (top → bottom on the screen) ──
const _income1 = 0;
const _income2 = 1;
const _lpp1 = 2;
const _avoir1 = 3;
const _lpp2 = 4;
const _avoir2 = 5;
const _fortune = 8;
const _dettes = 9;

// ── MintPickerTile build order ──
const _durationPicker = 0;
const _childrenPicker = 1;

// ── Gate card titles (used to identify each output's gate) ──
const _lppTitle = 'PARTAGE LPP';
const _taxTitle = 'IMPACT FISCAL';
const _patTitle = 'PARTAGE DU PATRIMOINE';
const _pensionTitle = 'PENSION ALIMENTAIRE (ESTIMATION)';

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

CoachProfile _profile({
  double salaire = 8000,
  String canton = 'GE',
  Set<String> provided = const {},
  PrevoyanceProfile? prevoyance,
  int nombreEnfants = 0,
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: canton,
    salaireBrutMensuel: salaire,
    etatCivil: CoachCivilStatus.marie,
    userProvidedFields: provided,
    nombreEnfants: nombreEnfants,
    prevoyance: prevoyance ?? const PrevoyanceProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}

/// A profile that confirms every conjoint-1 seedable fact: revenu (salary key,
/// 96000 in range), LPP from a certificate (200000), 3a (40000), 2 children.
/// conjoint 2 must stay null on every one of these.
CoachProfile _fullSeed() => _profile(
      salaire: 8000, // → 96000/an
      provided: {'salary', 'canton'},
      nombreEnfants: 2,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 200000,
        avoirLppObligatoire: 120000, // → isLppFromCertificate == true
        totalEpargne3a: 40000,
      ),
    );

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
        home: DivorceSimulatorScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(DivorceSimulatorScreen)) as dynamic;

List<MintAmountField> _fields(WidgetTester tester) =>
    tester.widgetList<MintAmountField>(find.byType(MintAmountField)).toList();

List<MintPickerTile> _pickers(WidgetTester tester) =>
    tester.widgetList<MintPickerTile>(find.byType(MintPickerTile)).toList();

Future<void> _setAmount(WidgetTester tester, int index, double v) async {
  _fields(tester)[index].onChanged(v);
  await tester.pump();
}

Future<void> _setPicker(WidgetTester tester, int index, int v) async {
  _pickers(tester)[index].onChanged(v);
  await tester.pump();
}

Future<void> _simulate(WidgetTester tester) async {
  await tester.tap(find.text('Simuler'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// The gate card guarding a given output (identified by its title), or null when
/// that output already renders its figures.
SituationGateCard? _gate(WidgetTester tester, String title) {
  for (final c
      in tester.widgetList<SituationGateCard>(find.byType(SituationGateCard))) {
    if (c.title == title) return c;
  }
  return null;
}

// Swiss CHF formatter mirroring the screen (nbsp + apostrophe grouping).
String _chfSwiss(double value) {
  final intVal = value.round();
  final isNeg = intVal < 0;
  final str = intVal.abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) b.write("'");
    b.write(str[i]);
  }
  return '${isNeg ? '-' : ''}$b';
}

String _chf(double v) => 'CHF ${_chfSwiss(v)}';

void main() {
  // ══════════════════════════════════════════════════════════════
  //  NO DATA → tap Simuler untouched → all four cards gated, no CHF
  // ══════════════════════════════════════════════════════════════
  group('Untouched Simuler', () {
    testWidgets('all four result cards are gated, NO CHF figure anywhere',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _simulate(tester);

      expect(find.byType(SituationGateCard), findsNWidgets(4),
          reason: 'LPP + tax + patrimoine + pension all gated');
      expect(_gate(tester, _lppTitle), isNotNull);
      expect(_gate(tester, _taxTitle), isNotNull);
      expect(_gate(tester, _patTitle), isNotNull);
      expect(_gate(tester, _pensionTitle), isNotNull);
      // The hero renders « Donnée requise », never a fabricated transfer.
      expect(find.text('Donnée requise'), findsOneWidget);
      // Zero CHF figure on the fabricated defaults.
      expect(find.textContaining('CHF'), findsNothing,
          reason: 'no result number is computed on invented inputs');
    });

    testWidgets('no provider in tree: defaults kept null, gated', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _simulate(tester);
      expect(_state(tester).debugIncome1, isNull);
      expect(_state(tester).debugFortune, isNull);
      expect(find.byType(SituationGateCard), findsNWidgets(4));
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  LPP SPLIT — gated on lpp1 + lpp2 + avoir1 + avoir2
  // ══════════════════════════════════════════════════════════════
  group('LPP split card', () {
    testWidgets('gated until the last avoir is entered, then the figure renders',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _lpp1, 180000);
      await _setAmount(tester, _lpp2, 80000);
      await _setAmount(tester, _avoir1, 40000);
      // avoir2 still missing.
      await _simulate(tester);
      final gated = _gate(tester, _lppTitle);
      expect(gated, isNotNull, reason: 'one avoir missing → still gated');
      expect(gated!.gate.missing.map((f) => f.key), contains('avoir2'));
      expect(find.text(_chf(260000)), findsNothing,
          reason: 'no total LPP computed on a 0-derived avoir');

      await _setAmount(tester, _avoir2, 20000);
      await _simulate(tester);
      expect(_gate(tester, _lppTitle), isNull, reason: 'all LPP facts confirmed');
      expect(find.text('Avoir LPP total (actuel)'), findsOneWidget);
      // Deterministic: totalLpp = 180000 + 80000.
      expect(find.text(_chf(260000)), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TAX IMPACT — gated on income1 + income2 + canton (real, from profile)
  // ══════════════════════════════════════════════════════════════
  group('Tax impact card', () {
    testWidgets(
        'ANON (no canton): both incomes entered but tax STILL gated on canton',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _simulate(tester);
      final gated = _gate(tester, _taxTitle);
      expect(gated, isNotNull,
          reason: 'no real canton → tax would use a fabricated barème → blocked');
      expect(gated!.gate.missing.map((f) => f.key), contains('canton'));
      expect(find.textContaining('/an'), findsNothing,
          reason: 'no tax delta CHF on an unconfirmed canton');
    });

    testWidgets('canton from profile + income2 (ex) missing → gated on income2',
        (tester) async {
      // income1 + canton seeded from the profile; the ex income is touch-only.
      await _pump(
        tester,
        _FakeProvider(_profile(provided: {'salary', 'canton'})),
      );
      await _simulate(tester);
      final gated = _gate(tester, _taxTitle);
      expect(gated, isNotNull);
      expect(gated!.gate.missing.map((f) => f.key), <String>['income2'],
          reason: 'canton + income1 confirmed via profile; only the ex remains');
    });

    testWidgets('canton from profile + both incomes → figure renders',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(provided: {'salary', 'canton'})),
      );
      // income1 (96000) + canton (GE) seeded; enter the ex income manually.
      await _setAmount(tester, _income2, 50000);
      await _simulate(tester);
      expect(_gate(tester, _taxTitle), isNull,
          reason: 'income1 + income2 + canton all confirmed');
      // The fiscal delta (« Différence : …/an ») only renders when unlocked.
      expect(find.textContaining('/an'), findsWidgets);
      // Transparence : la note dit explicitement que le canton du ménage est
      // appliqué aux deux conjoints (le canton futur de l'ex n'est pas inventé).
      expect(find.textContaining('canton actuel du ménage'), findsOneWidget,
          reason: 'the shared-canton basis is disclosed, not silent');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  PrixDuSilenceWidget — REMOVED (concubinage device, hardcoded 24% rate)
  // ══════════════════════════════════════════════════════════════
  testWidgets('the concubinage « prix du silence » widget is gone',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _setAmount(tester, _fortune, 300000);
    // Entering fortune must NOT resurrect the fabricated concubinage-succession
    // widget (fortune × hardcoded 24% → « Le silence te coûte … »).
    expect(find.byType(PrixDuSilenceWidget), findsNothing);
    // The succession-comparison copy is absent (the fortune input still shows
    // its own CHF value — that is a confirmed user input, not a computed result).
    expect(find.textContaining('Patrimoine transmis'), findsNothing);
    expect(find.textContaining('silence'), findsNothing);
  });

  // ══════════════════════════════════════════════════════════════
  //  PATRIMOINE SPLIT — gated on fortune + dettes
  // ══════════════════════════════════════════════════════════════
  group('Patrimoine split card', () {
    testWidgets('gated until fortune AND dettes entered, then figure renders',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _fortune, 300000);
      await _simulate(tester);
      final gated = _gate(tester, _patTitle);
      expect(gated, isNotNull, reason: 'dettes still missing');
      expect(gated!.gate.missing.map((f) => f.key), contains('dettes'));
      expect(find.text('Fortune nette'), findsNothing);

      await _setAmount(tester, _dettes, 100000);
      await _simulate(tester);
      expect(_gate(tester, _patTitle), isNull);
      expect(find.text('Fortune nette'), findsOneWidget);
      // fortuneNette = 300000 - 100000.
      expect(find.text(_chf(200000)), findsOneWidget);
    });

    testWidgets(
        'séparation de biens adds income facts to the patrimoine gate',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _fortune, 300000);
      await _setAmount(tester, _dettes, 100000);
      // Select séparation de biens régime.
      await tester.tap(find.text('Séparation de biens'));
      await tester.pump();
      await _simulate(tester);
      final gated = _gate(tester, _patTitle);
      expect(gated, isNotNull,
          reason: 'séparation splits by income → income now determinative');
      expect(gated!.gate.missing.map((f) => f.key),
          containsAll(<String>['income1', 'income2']));
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  PENSION — gated on income1 + income2 + children + duration
  // ══════════════════════════════════════════════════════════════
  group('Pension card', () {
    testWidgets('children/duration untouched keep it gated', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      // children + duration never touched.
      await _simulate(tester);
      final gated = _gate(tester, _pensionTitle);
      expect(gated, isNotNull);
      expect(gated!.gate.missing.map((f) => f.key),
          containsAll(<String>['enfants', 'duree']));
      expect(find.textContaining('/mois'), findsNothing);
    });

    testWidgets('all four facts entered → the monthly figure renders',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setPicker(tester, _childrenPicker, 1);
      await _setPicker(tester, _durationPicker, 10);
      await _simulate(tester);
      expect(_gate(tester, _pensionTitle), isNull,
          reason: 'income + children + duration all confirmed');
      // childContribution 600 + spouse (gap 40000/12*0.15=500) = 1100 > 0.
      expect(find.textContaining('/mois'), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  HERO — tax delta secondary is dropped when income is missing
  // ══════════════════════════════════════════════════════════════
  testWidgets('hero: LPP done shows transfer; tax missing drops the delta',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _setAmount(tester, _lpp1, 180000);
    await _setAmount(tester, _lpp2, 80000);
    await _setAmount(tester, _avoir1, 40000);
    await _setAmount(tester, _avoir2, 20000);
    // income NOT entered → tax gate incomplete.
    await _simulate(tester);
    // Hero primary (LPP transfer) is present, not « Donnée requise ».
    expect(find.text('Donnée requise'), findsNothing,
        reason: 'LPP fully confirmed → primary transfer computed');
    // The secondary « IMPACT FISCAL » label is dropped (tax gated) — it only
    // remains as the tax gate-card title, never as a hero secondary figure.
    expect(_gate(tester, _taxTitle), isNotNull,
        reason: 'income missing → tax still gated, no fabricated delta');
  });

  // ══════════════════════════════════════════════════════════════
  //  SEED — conjoint 1 (the USER) only; conjoint 2 (ex) NEVER
  // ══════════════════════════════════════════════════════════════
  group('Profile seed touches conjoint 1 only', () {
    testWidgets('full profile seeds conjoint 1; conjoint 2 stays « Non renseigné »',
        (tester) async {
      await _pump(tester, _FakeProvider(_fullSeed()));
      final st = _state(tester);
      // Conjoint 1 = the user → seeded from real, in-range data.
      expect(st.debugIncome1, 96000.0, reason: 'salary 8000 * 12');
      expect(st.debugLpp1, 200000.0, reason: 'LPP from certificate');
      expect(st.debug3a1, 40000.0);
      expect(st.debugChildren, 2);
      expect(st.debugChildrenTouched, true);
      expect(st.debugCanton, 'GE', reason: 'the user canton seeds the tax barème');
      // Conjoint 2 = the EX-SPOUSE → NEVER seeded from the user's own profile.
      expect(st.debugIncome2, isNull, reason: 'ex income never seeded');
      expect(st.debugLpp2, isNull, reason: 'ex LPP never seeded');
      expect(st.debug3a2, isNull, reason: 'ex 3a never seeded');
      // Touch-only facts are never seeded.
      expect(st.debugAvoir1, isNull);
      expect(st.debugAvoir2, isNull);
      expect(st.debugFortune, isNull);
      expect(st.debugDettes, isNull);
      expect(st.debugMarriageDurationTouched, false);

      // The tax output stays gated because the ex's income is required.
      await _simulate(tester);
      final gated = _gate(tester, _taxTitle);
      expect(gated, isNotNull);
      expect(gated!.gate.missing.map((f) => f.key), contains('income2'),
          reason: 'only conjoint-2 income remains → the split cannot resolve');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  VALUE-IN-RANGE + KEY mutation-proofs (income1 seed)
  // ══════════════════════════════════════════════════════════════
  group('income1 seed provenance = key + value-in-range', () {
    testWidgets('no salary key: value present but unconfirmed → not seeded',
        (tester) async {
      await _pump(tester, _FakeProvider(_profile(salaire: 8000, provided: {})));
      expect(_state(tester).debugIncome1, isNull,
          reason: 'no salary key → not seeded (default stays null)');
    });

    testWidgets('LOWER out-of-range: 1000/mo (12000/an < 20000) → not seeded',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 1000, provided: {'salary'})),
      );
      expect(_state(tester).debugIncome1, isNull,
          reason: 'out-of-range annual is never clamped into a seed');
    });

    testWidgets('UPPER out-of-range: 200000/mo (2.4M/an > 300000) → not seeded',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 200000, provided: {'salary'})),
      );
      expect(_state(tester).debugIncome1, isNull,
          reason: 'out-of-range annual is never clamped into a seed');
    });

    testWidgets('in-range with key → seeded', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 10000, provided: {'salary'})),
      );
      expect(_state(tester).debugIncome1, 120000.0);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  CANTON seed: real profile canton confirms it; anon → null
  // ══════════════════════════════════════════════════════════════
  group('canton seed provenance', () {
    testWidgets('anon (no profile) → canton null → tax gated', (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(_state(tester).debugCanton, isNull);
    });

    testWidgets('profile with a real canton (key + valid) → seeded',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'VD', provided: {'canton'})),
      );
      expect(_state(tester).debugCanton, 'VD');
    });

    // ── HOLE 6: a VALID code WITHOUT the provided key (legacy fromJson
    //    `canton ?? 'ZH'`) is NOT user-confirmed → must stay gated. ──
    testWidgets(
        'legacy valid canton "ZH" WITHOUT the canton key → null → tax gated',
        (tester) async {
      // fromJson defaults canton to 'ZH' with no user input; provided is empty.
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'ZH', provided: {'salary'})),
      );
      expect(_state(tester).debugCanton, isNull,
          reason: 'valid but unconfirmed (no q_canton answer) → not seeded');
      await _setAmount(tester, _income2, 50000);
      await _simulate(tester);
      final g = _gate(tester, _taxTitle);
      expect(g, isNotNull, reason: 'no confirmed canton → tax fabrication blocked');
      expect(g!.gate.missing.map((f) => f.key), contains('canton'));
      expect(find.textContaining('/an'), findsNothing);
    });

    // ── HOLE 3: keyed-but-invalid canton must NOT bypass the tax gate ──
    testWidgets(
        'keyed-EMPTY canton ("" with the canton key) → null → tax gated',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: '', provided: {'canton'})),
      );
      expect(_state(tester).debugCanton, isNull,
          reason: 'empty is not a valid 26-code canton');
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _simulate(tester);
      final g = _gate(tester, _taxTitle);
      expect(g, isNotNull, reason: 'no valid canton → tax still gated');
      expect(g!.gate.missing.map((f) => f.key), contains('canton'));
      expect(find.textContaining('/an'), findsNothing,
          reason: 'no fabricated ZH-fallback tax delta on an empty canton');
    });

    testWidgets('invalid junk canton "XX" → null (gated)', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'XX', provided: {'canton'})),
      );
      expect(_state(tester).debugCanton, isNull);
    });

    testWidgets('whitespace canton "  " → null (gated)', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: '  ', provided: {'canton'})),
      );
      expect(_state(tester).debugCanton, isNull);
    });

    testWidgets('placeholder canton "unknown" → null (gated)', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'unknown', provided: {'canton'})),
      );
      expect(_state(tester).debugCanton, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  HOLE 4: DivorceFilmWidget — gated on ALL 4, real pension only
  // ══════════════════════════════════════════════════════════════
  group('Divorce film', () {
    testWidgets(
        'LPP + tax complete but patrimoine/pension missing → film ABSENT',
        (tester) async {
      // Canton seeded from profile; enter LPP + income facts only.
      await _pump(
        tester,
        _FakeProvider(_profile(provided: {'canton'})),
      );
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setAmount(tester, _lpp1, 180000);
      await _setAmount(tester, _lpp2, 80000);
      await _setAmount(tester, _avoir1, 40000);
      await _setAmount(tester, _avoir2, 20000);
      // fortune/dettes/children/duration NOT provided.
      await _simulate(tester);
      expect(find.byType(DivorceFilmWidget), findsNothing,
          reason: 'film now gated on all four outputs, not just lpp+tax');
    });

    testWidgets(
        'all four outputs complete → film present, real pension (not 1500×kids)',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(provided: {'canton'})),
      );
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setAmount(tester, _lpp1, 180000);
      await _setAmount(tester, _lpp2, 80000);
      // avoir1 160000 / avoir2 20000 → acquis1 20000, acquis2 60000 →
      // service transfer = |20000-60000|/2 = 20000, direction "2 → 1".
      await _setAmount(tester, _avoir1, 160000);
      await _setAmount(tester, _avoir2, 20000);
      await _setAmount(tester, _fortune, 300000);
      await _setAmount(tester, _dettes, 100000);
      await _setPicker(tester, _childrenPicker, 1);
      await _setPicker(tester, _durationPicker, 10);
      await _simulate(tester);

      expect(find.byType(DivorceFilmWidget), findsOneWidget);
      final film = find.byType(DivorceFilmWidget);
      // Real service pension = 1 child × 600 + spouse (gap 40000/12 × 0.15 = 500)
      // = 1100 → the film renders it, the same value as the PensionAlimentaireCard.
      expect(
        find.descendant(of: film, matching: find.textContaining("1'100")),
        findsWidgets,
        reason: 'the film shows the REAL income-gap pension',
      );
      // The fabricated childrenCount × 1500 forfait is gone from the film.
      expect(
        find.descendant(of: film, matching: find.textContaining("1'500")),
        findsNothing,
      );
      // HOLE 5: the film's LPP transfer == the SERVICE value (20'000, part
      // acquired during marriage), NEVER the total-balance recompute 50'000.
      expect(
        find.descendant(of: film, matching: find.textContaining("20'000")),
        findsWidgets,
        reason: 'film consumes r.lppSplit.transferAmount',
      );
      expect(
        find.descendant(of: film, matching: find.textContaining("50'000")),
        findsNothing,
        reason: 'no (myLpp + partnerLpp) / 2 recompute in the film',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  a11y root boundary survives the gate refactor
  // ══════════════════════════════════════════════════════════════
  testWidgets('screen-root Semantics boundary + discrete gate nodes',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakeProvider(null));
    await _simulate(tester);
    expect(tester.getSemantics(find.byType(DivorceSimulatorScreen)), isNotNull);
    expect(find.byType(SituationGateCard), findsNWidgets(4));
    handle.dispose();
  });
}
