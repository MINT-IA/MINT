import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/life_events_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
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
///   • Tax impact        → income1, income2, canton
///   • Liquidation du régime → NO gate, NO amount, for ANY régime. A single
///     household pot halved is not the Swiss liquidation (CC art. 215 splits
///     the OTHER spouse's bénéfice from per-spouse acquest accounts; CC art.
///     242 governs communauté at divorce, not art. 241; CC art. 247-251 leaves
///     nothing to divide). The card states the selected régime's mechanics.
///   • Entretien         → NO gate, NO amount. A maintenance amount cannot be
///     derived from income + children, and child (CC 276/285/285a) and spousal
///     (CC 125) maintenance are legally distinct subjects, stated separately.
///
/// Invariant: a SituationGate exists IF AND ONLY IF a CHF sits behind it.
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
const _patTitle = 'LIQUIDATION DU RÉGIME MATRIMONIAL';

// ── Entretien: educational copy fragments (no gate card, no CHF) ──
const _pensionNoEstimate = 'Il n\'existe pas de barème';
const _pensionSpecialiste = 'ou, faute d\'accord, par le tribunal';
const _pensionEnfantTitre = 'Entretien de l\'enfant (CC art. 276, 285, 285a)';
const _pensionConjointTitre = 'Entretien du conjoint (CC art. 125)';
const _pensionMethode = 'se fait en deux étapes';

// ── Liquidation: the per-régime legal mechanics actually rendered ──
const _acquetsRegle = 'moitié du bénéfice de l\'autre';
const _communauteRegle = 'CC art. 242 al. 1';
const _separationRegle = 'chacun garde ce qui lui appartient';
const _noShare = 'deux inventaires séparés';

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

/// P3 « zéro impasse » : the canton fact is completable on screen (Revenus
/// section). Only one `DropdownButton<String>` exists on this screen.
Future<void> _setCanton(WidgetTester tester, String c) async {
  tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .onChanged!(c);
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
    testWidgets('both computed cards are gated, NO CHF figure anywhere',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _simulate(tester);

      expect(find.byType(SituationGateCard), findsNWidgets(2),
          reason: 'LPP + tax gated; liquidation and entretien show no figure');
      expect(_gate(tester, _lppTitle), isNotNull);
      expect(_gate(tester, _taxTitle), isNotNull);
      expect(_gate(tester, _patTitle), isNull,
          reason: 'no share is computed → gating it would be a dead promise');
      // Liquidation + entretien cards are educational and always rendered.
      expect(find.textContaining(_noShare), findsOneWidget);
      expect(find.textContaining(_pensionNoEstimate), findsOneWidget);
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
      expect(find.byType(SituationGateCard), findsNWidgets(2));
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
      // Le transfert affiché ne modélise NI l'intérêt sur la prestation de
      // sortie au mariage NI la date de valorisation légale (introduction de la
      // procédure) — c'est divulgué sous le chiffre plutôt que laissé implicite.
      expect(find.textContaining("l'intérêt qui court"), findsOneWidget,
          reason: 'the LPP transfer states what it does NOT model');
      expect(find.textContaining('date de valorisation'), findsOneWidget);
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

    // ── P3 « zéro impasse » : before P3 the `canton` fact had NO on-screen
    //    control and NO `onComplete` — an anonymous user could never open the
    //    tax card. It is now completable in place (Revenus section picker).
    testWidgets(
        'P3: EVERY fact of EVERY remaining gate carries an onComplete (no dead end)',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _simulate(tester);
      final cards = tester
          .widgetList<SituationGateCard>(find.byType(SituationGateCard))
          .toList();
      expect(cards, hasLength(2));
      for (final card in cards) {
        expect(card.gate.facts, isNotEmpty,
            reason: '${card.title} gate has no fact left after the P0 cleanup');
        for (final f in card.gate.facts) {
          expect(f.onComplete, isNotNull,
              reason: '${card.title}/${f.key} has no completion path → impasse');
        }
      }
    });

    testWidgets(
        'P3 ANTI-IMPASSE — ANON picks the canton on screen + both incomes → the '
        'tax figure renders', (tester) async {
      await _pump(tester, _FakeProvider(null));
      // The picker exists and starts EMPTY (« Non renseigné » hint) — never the
      // legacy fabricated 'ZH'.
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(_state(tester).debugCanton, isNull);
      expect(find.text('Non renseigné'), findsWidgets);

      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setCanton(tester, 'VD');
      await _simulate(tester);

      expect(_state(tester).debugCanton, 'VD',
          reason: 'touching the picker confirms the fact, like a profile seed');
      expect(_gate(tester, _taxTitle), isNull,
          reason: 'an anonymous user CAN now unlock the tax card on screen');
      expect(find.textContaining('/an'), findsWidgets);
      // The figures are the service output on the PICKED canton.
      final expected = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 0,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          canton: 'VD',
          incomeConjoint1: 90000,
          incomeConjoint2: 50000,
          lppConjoint1: 0,
          lppConjoint2: 0,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );
      expect(find.text(_chf(expected.taxImpact.estimatedTaxMarried)),
          findsWidgets,
          reason: 'the married-tax row is the real VD figure, not a ZH default');
    });

    testWidgets('P3: picking the canton invalidates the stale result',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setCanton(tester, 'VD');
      await _simulate(tester);
      expect(_gate(tester, _taxTitle), isNull);

      // Changing the canton drops the computed result (stale-invalidation).
      await _setCanton(tester, 'GE');
      expect(_state(tester).debugCanton, 'GE');
      expect(find.textContaining('/an'), findsNothing,
          reason: 'the previous VD figures must not survive a canton change');
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
  //  TAX DELTA LSFin FRAMING — a decrease is NEUTRAL, never green/success
  // ══════════════════════════════════════════════════════════════
  group('Tax delta LSFin framing (negative delta ≠ success/green)', () {
    testWidgets(
        'two-earner NEGATIVE delta: neutral info tone/color, mechanism-named copy',
        (tester) async {
      // Canton seeded (GE), incomes driven explicitly → GE 90k + 50k. Depuis la
      // bascule vers l'impôt EFFECTIF, ce couple à deux revenus a un delta
      // NÉGATIF (le divorce baisse l'impôt du ménage — fin du splitting). Ce cas
      // ne doit JAMAIS être cadré en vert « succès » : cadrer « le divorce fait
      // baisser l'impôt » comme un gain, c'est orienter vers le divorce (LSFin).
      await _pump(tester, _FakeProvider(_profile(provided: {'canton'})));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _simulate(tester);

      // Tax card unlocked (canton + income1 + income2 all confirmed).
      expect(_gate(tester, _taxTitle), isNull);

      // The delta readout is present and mechanism-named (« fin du splitting »).
      final deltaText = find.textContaining('fin du splitting marié');
      expect(deltaText, findsOneWidget,
          reason: 'the neutral mechanism-named delta copy renders');

      // COLOR: the delta text is NEUTRAL info blue, never success green.
      final txt = tester.widget<Text>(deltaText);
      expect(txt.style?.color, MintColors.info,
          reason: 'a tax decrease is informative-neutral, not a win');
      expect(txt.style?.color, isNot(MintColors.success),
          reason: 'never green-frame « divorce lowers tax » (LSFin steering)');

      // TONE: the closest surface is the neutral « bleu » tone, never « sauge »
      // (the explicit success/positive green surface).
      final surfaces = tester
          .widgetList<MintSurface>(
            find.ancestor(of: deltaText, matching: find.byType(MintSurface)),
          )
          .toList();
      expect(surfaces.first.tone, MintSurfaceTone.bleu,
          reason: 'the delta box uses the neutral informational tone');
      expect(surfaces.map((s) => s.tone), isNot(contains(MintSurfaceTone.sauge)),
          reason: 'no success/green surface anywhere above the delta');

      // COPY neutrality: shown as a signed écart, never a saving/gain/économie.
      final label = txt.data ?? '';
      expect(label.contains('économie'), isFalse);
      expect(label.contains('gain'), isFalse);
      expect(label.contains('/an'), isTrue);
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
  //  HIGH #3 — LIQUIDATION: no per-spouse CHF under ANY régime
  // ══════════════════════════════════════════════════════════════
  group('Liquidation du régime card', () {
    /// Enters both patrimoine amounts and both incomes — the exact inputs that
    /// fed BOTH deleted rules (50/50 of the net pot, and the income-proportional
    /// allocation under séparation de biens).
    Future<void> fillPatrimoineAndIncome(WidgetTester tester) async {
      await _setAmount(tester, _fortune, 300000);
      await _setAmount(tester, _dettes, 100000);
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
    }

    /// Every per-spouse CHF the old card could render, for every régime.
    ///
    /// Scoped to the liquidation card: the INPUT fields legitimately echo the
    /// CHF the user just typed (100'000 of debts, 300'000 of assets). What must
    /// never exist is a COMPUTED figure in the result card.
    void expectNoShareAnywhere(WidgetTester tester) {
      final card = find.byKey(const Key('divorce_liquidation_card'));
      expect(card, findsOneWidget);
      // Row labels + split bar are gone entirely.
      expect(find.text('Conjoint 1'), findsNothing);
      expect(find.text('Conjoint 2'), findsNothing);
      expect(find.text('C1'), findsNothing, reason: 'no split bar');
      expect(find.text('C2'), findsNothing);
      expect(find.text('Acquêts nets'), findsNothing);
      expect(find.text('Fortune nette'), findsNothing);
      // NOT ONE CHF is rendered inside the liquidation card.
      expect(find.descendant(of: card, matching: find.textContaining('CHF')),
          findsNothing,
          reason: 'the liquidation card renders no amount at all');
      // The specific figures the two deleted rules produced:
      //  • 50/50 of the net pot (300000 − 100000) / 2 = 100'000
      //  • the net pot itself                          = 200'000
      //  • income-proportional 200000 × 90/140, × 50/140 = 128'571 / 71'429
      for (final v in <double>[100000, 200000, 128571, 71429]) {
        expect(find.descendant(of: card, matching: find.text(_chf(v))),
            findsNothing);
      }
      // 128'571 / 71'429 match no input value, so they must be absent SCREEN-wide.
      expect(find.text(_chf(128571)), findsNothing);
      expect(find.text(_chf(71429)), findsNothing);
      // No gate card either: gating a card that shows no figure is a dead promise.
      expect(_gate(tester, _patTitle), isNull);
      // Every régime states MINT computes no personal share.
      expect(find.textContaining(_noShare), findsOneWidget);
    }

    testWidgets(
        'participation aux acquêts: CC art. 215 mechanics, no computed share',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await fillPatrimoineAndIncome(tester);
      await _simulate(tester);

      // The régime's OWN mechanics: half of the OTHER's bénéfice, from
      // per-spouse acquest accounts — not a single pot halved.
      expect(find.textContaining(_acquetsRegle), findsWidgets,
          reason: 'CC art. 215 — half of the OTHER spouse\'s bénéfice');
      expect(find.textContaining('comparaison de vos deux comptes'),
          findsOneWidget,
          reason: 'the two accounts decide, not a common pot');
      expect(find.textContaining('pas une cagnotte commune'), findsOneWidget);
      expect(find.textContaining('celui qui a le plus accumulé verse'),
          findsOneWidget,
          reason: 'a non-lawyer must grasp WHO owes WHOM');
      // CC art. 215 quantum : après compensation des deux créances, le solde dû
      // est la MOITIÉ de la différence entre les bénéfices, pas la différence
      // entière — dire « la différence » ferait raisonner l'utilisateur à 2×.
      expect(find.textContaining('MOITIÉ de la différence'), findsOneWidget,
          reason: 'CC 215: half the difference, never the whole difference');
      expect(find.textContaining('biens propres'), findsWidgets,
          reason: 'what stays out of the comparison is named');
      expect(find.textContaining('art. 208'), findsOneWidget,
          reason: 'réunions aux acquêts');
      expect(find.textContaining('art. 206 et 209'), findsOneWidget,
          reason: 'récompenses entre masses');
      expectNoShareAnywhere(tester);
    });

    testWidgets(
        'communauté de biens: CC art. 242 mechanics (not art. 241), no share',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await fillPatrimoineAndIncome(tester);
      await tester.tap(find.text('Communauté de biens'));
      await tester.pump();
      await _simulate(tester);

      expect(find.textContaining(_communauteRegle), findsOneWidget,
          reason: 'divorce is governed by art. 242, reprise then remainder');
      expect(find.textContaining('reprend d\'abord'), findsOneWidget);
      expect(find.textContaining('solde'), findsWidgets);
      expect(find.textContaining('on ne coupe pas cette masse en deux'),
          findsOneWidget,
          reason: 'the plain-language correction of the naive 50/50');
      // The misclassification is named explicitly so it cannot silently return.
      expect(find.textContaining('L\'article 241'), findsOneWidget,
          reason: 'art. 241 only covers death / change of regime');
      expectNoShareAnywhere(tester);
    });

    testWidgets(
        'séparation de biens: CC art. 247-251 mechanics, no share, no income rule',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await fillPatrimoineAndIncome(tester);
      await tester.tap(find.text('Séparation de biens'));
      await tester.pump();
      await _simulate(tester);

      expect(find.textContaining(_separationRegle), findsOneWidget,
          reason: 'each spouse keeps ownership and use of their own assets');
      expect(find.textContaining('CC art. 248'), findsOneWidget,
          reason: 'proof of ownership, else co-ownership presumption');
      expect(find.textContaining('art. 251'), findsWidgets,
          reason: 'allocation of a co-owned asset against compensation');
      // Plain language: what actually decides is proof of ownership.
      expect(find.textContaining('la preuve de la propriété'), findsOneWidget);
      expect(find.textContaining('registre foncier'), findsOneWidget,
          reason: 'concrete evidence a non-lawyer can go and find');
      // Having financed an asset founds a claim; it does not replace title.
      expect(find.textContaining('sans remplacer le titre'), findsOneWidget);
      expectNoShareAnywhere(tester);
    });

    testWidgets('switching régime swaps the stated mechanics', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await fillPatrimoineAndIncome(tester);
      await _simulate(tester);
      expect(find.textContaining(_acquetsRegle), findsWidgets);
      expect(find.textContaining('CC art. 248'), findsNothing);

      await tester.tap(find.text('Séparation de biens'));
      await tester.pump();
      await _simulate(tester);
      expect(find.textContaining('CC art. 248'), findsOneWidget);
      expect(find.textContaining('comparaison de vos deux comptes'),
          findsNothing);
    });

    testWidgets('the patrimoine inputs are framed as indicative, not a mass',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      // The labels no longer promise a divisible « acquêts » mass.
      expect(find.text('Patrimoine du ménage (indicatif)'), findsOneWidget);
      expect(find.text('Dettes du ménage (indicatif)'), findsOneWidget);
      expect(find.text('Acquêts (biens acquis pendant le mariage)'),
          findsNothing);
      expect(find.text('Fortune commune'), findsNothing);
      expect(
        find.textContaining('ne servent à calculer aucune part'),
        findsOneWidget,
        reason: 'the hint says plainly that no share is derived from them',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  HIGH #1 — the entretien ALERT invites an examination, not a right
  // ══════════════════════════════════════════════════════════════
  group('CC art. 125 alert wording', () {
    testWidgets('long marriage + income gap: no « probable », no entitlement',
        (tester) async {
      await _pump(tester, _FakeProvider(_profile(provided: {'canton'})));
      await _setAmount(tester, _income1, 150000);
      await _setAmount(tester, _income2, 50000);
      await _setAmount(tester, _lpp1, 180000);
      await _setAmount(tester, _lpp2, 80000);
      await _setAmount(tester, _avoir1, 40000);
      await _setAmount(tester, _avoir2, 20000);
      await _setPicker(tester, _durationPicker, 15);
      await _simulate(tester);

      // Alerts are unlocked (LPP + tax confirmed) so the string really renders.
      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.textContaining('examiner une éventuelle contribution'),
          findsOneWidget,
          reason: 'it invites an examination under CC art. 125');
      expect(find.textContaining('CC art. 125'), findsWidgets);
      expect(find.textContaining('n\'établissent'), findsOneWidget,
          reason: 'it states plainly that the facts establish no entitlement');
      // MUTATION-PROOF on the removed claim.
      expect(find.textContaining('est probable'), findsNothing,
          reason: 'a long marriage creates no automatic entitlement');
      expect(find.textContaining('contribution d\'entretien au conjoint est'),
          findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  P0 #1 — ENTRETIEN: educational only, NEVER an amount
  // ══════════════════════════════════════════════════════════════
  group('Entretien (contribution) card', () {
    testWidgets('educational content is present without any fact entered',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _simulate(tester);
      // ── LUCIDITÉ, pas conseil. The card must make the Swiss mechanism
      //    UNDERSTANDABLE so the user can reason about their own case. « We
      //    can't compute it, go see a lawyer » would be the opposite product.
      expect(find.textContaining(_pensionNoEstimate), findsOneWidget,
          reason: 'no scale exists — and we say why, then explain');
      expect(find.textContaining('raisonner sur ta situation'), findsOneWidget,
          reason: 'the card hands the user the tool, it does not defer');

      // (2) THE mechanism: two stages, minimum vital then surplus.
      expect(find.textContaining(_pensionMethode), findsOneWidget);
      expect(find.textContaining('147 III 265'), findsOneWidget);
      expect(find.textContaining('minimum vital'), findsOneWidget);
      expect(find.textContaining('revenus disponibles nets'), findsOneWidget);
      expect(find.textContaining('jamais sur les salaires bruts'),
          findsOneWidget,
          reason: 'net vs gross is the single most useful distinction here');
      expect(find.textContaining('l\'excédent'), findsOneWidget);

      // (3) Levers, in plain language — what raises and lowers the amount.
      expect(find.textContaining('fait monter ou descendre'), findsOneWidget);
      expect(find.textContaining('plus tu gardes l\'enfant, moins tu verses'),
          findsOneWidget,
          reason: 'custody share explained, not just listed');
      expect(find.textContaining('revenu hypothétique'), findsOneWidget);
      expect(find.textContaining('sert de plafond'), findsOneWidget,
          reason: 'the marital standard of living is a ceiling');
      expect(find.textContaining('clean-break'), findsWidgets);

      // ── HIGH #2 — child maintenance and spousal maintenance are two legally
      //    distinct subjects with different criteria. They must be stated
      //    SEPARATELY, each under its own articles, never merged into one list.
      expect(find.text(_pensionEnfantTitre), findsOneWidget,
          reason: 'CC art. 276, 285, 285a — child maintenance');
      expect(find.text(_pensionConjointTitre), findsOneWidget,
          reason: 'CC art. 125 — spousal maintenance');

      // Child-specific criteria.
      expect(find.textContaining('besoins de l\'enfant'), findsOneWidget);
      expect(find.textContaining('contribution en nature'), findsOneWidget,
          reason: 'daily care counts as an in-kind contribution');
      expect(find.textContaining('frais de garde et de formation'),
          findsOneWidget);
      expect(find.textContaining('allocations familiales'), findsOneWidget);
      expect(find.textContaining('part d\'épargne'), findsOneWidget);

      // Spouse-specific criteria (CC art. 125 al. 2 list).
      expect(find.textContaining('subvenir seul à ses besoins'),
          findsOneWidget);
      expect(find.textContaining('répartition des tâches pendant le mariage'),
          findsOneWidget);
      expect(find.textContaining('train de vie'), findsWidgets);
      expect(find.textContaining('perspectives de formation et de gain'),
          findsOneWidget);
      expect(
        find.textContaining('longue durée de mariage ne crée aucun droit'),
        findsOneWidget,
      );

      // (5) The specialist/court referral comes LAST and only for what is
      //     really theirs: the binding amount, the agreement, the judgment.
      expect(find.textContaining(_pensionSpecialiste), findsOneWidget,
          reason: 'binding fixation is the court/agreement, not the explanation');
      expect(find.textContaining('chiffre le cas concret'), findsOneWidget);
      // It must NOT be the card's answer to « how does this work ».
      expect(find.textContaining('relève d\'un·e spécialiste'), findsNothing,
          reason: 'no « you cannot understand, go ask someone » framing');
    });

    testWidgets('the merged single factor list is gone', (tester) async {
      // MUTATION-PROOF: the pre-fix copy folded child and spouse criteria into
      // one sentence beginning « Il dépend des revenus disponibles nets des deux
      // parents, du minimum vital … » — a single undifferentiated list.
      await _pump(tester, _FakeProvider(null));
      await _simulate(tester);
      expect(
        find.textContaining(
            'Il dépend des revenus disponibles nets des deux parents'),
        findsNothing,
        reason: 'child and spouse criteria are no longer merged',
      );
      // The merged list ended on « ainsi que du traitement fiscal et des
      // allocations familiales » — a flat enumeration with no mechanism.
      expect(find.textContaining('ainsi que du traitement fiscal'),
          findsNothing);
    });

    testWidgets(
        'ALL facts confirmed → still NO pension CHF anywhere on the screen',
        (tester) async {
      // This is the exact input set that produced the fabricated figure:
      // 1 child × 600 + (gap 40000 / 12) × 0.15 = 1'100/mois → 13'200/an.
      await _pump(tester, _FakeProvider(_profile(provided: {'canton'})));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setAmount(tester, _lpp1, 180000);
      await _setAmount(tester, _lpp2, 80000);
      await _setAmount(tester, _avoir1, 40000);
      await _setAmount(tester, _avoir2, 20000);
      await _setAmount(tester, _fortune, 300000);
      await _setAmount(tester, _dettes, 100000);
      await _setPicker(tester, _childrenPicker, 1);
      await _setPicker(tester, _durationPicker, 10);
      await _simulate(tester);

      // Everything else is unlocked (so this is not a « gated away » pass).
      expect(find.byType(SituationGateCard), findsNothing);
      // MUTATION-PROOF on the previously-rendered strings.
      expect(find.text("CHF 1'100/mois"), findsNothing,
          reason: 'the 600×children + 15%-of-gap figure must not render');
      expect(find.text("soit CHF 13'200/an"), findsNothing);
      expect(find.textContaining("1'100"), findsNothing,
          reason: 'the fabricated monthly maintenance is absent everywhere');
      expect(find.textContaining('soit '), findsNothing);
      // The educational statement is what stands in its place — on BOTH
      // surfaces that used to carry a CHF (the card and the film's acte 3).
      expect(find.textContaining(_pensionNoEstimate), findsNWidgets(2),
          reason: 'entretien card + DivorceFilmWidget acte 3');
      expect(find.textContaining(_pensionSpecialiste), findsWidgets);
    });

    testWidgets('a 3-child long marriage produces no amount either',
        (tester) async {
      // 3 × 600 + (gap 40000/12 × 0.15 = 500) = 2'300/mois under the old rule.
      await _pump(tester, _FakeProvider(_profile(provided: {'canton'})));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setPicker(tester, _childrenPicker, 3);
      await _setPicker(tester, _durationPicker, 20);
      await _simulate(tester);
      expect(find.textContaining("2'300"), findsNothing);
      expect(find.textContaining(_pensionNoEstimate), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  MEDIUM — no leftover copy contradicting the new framing
  // ══════════════════════════════════════════════════════════════
  group('Copy coherence sweep', () {
    testWidgets('the « Comprendre » tile no longer teaches the old 50/50',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      // NB: the FR title carries a NBSP before « ? » (French typography), so
      // match on a fragment rather than the full literal.
      await tester.tap(
        find.textContaining('Qu\'est-ce que la participation aux acquêts'),
      );
      await tester.pumpAndSettle();
      // Pre-fix copy: « Les acquêts … sont partagés à parts égales en cas de
      // divorce » — the single-pot 50/50 the cards no longer apply.
      expect(find.textContaining('sont partagés à parts égales en cas de divorce'),
          findsNothing);
      expect(find.textContaining('la moitié du bénéfice de l\'autre'),
          findsWidgets,
          reason: 'the expandable teaches the same rule as the card');
      expect(find.textContaining('pas sur un patrimoine commun unique'),
          findsOneWidget);
    });

    testWidgets('income gate « why » no longer promises a maintenance estimate',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _simulate(tester);
      final tax = _gate(tester, _taxTitle)!;
      final ctx = tester.element(find.byType(DivorceSimulatorScreen));
      final whys = tax.gate.facts
          .map((f) => f.why?.call(ctx) ?? '')
          .toList();
      for (final w in whys) {
        expect(w.contains('contribution d\'entretien'), isFalse,
            reason: 'income feeds the tax comparison only: « $w »');
      }
      expect(whys.any((w) => w.contains('impôt du ménage')), isTrue);
    });

    testWidgets('the intro no longer frames the tool around « pension »',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(find.textContaining('liquidation du régime matrimonial'),
          findsOneWidget,
          reason: 'the intro names what the screen actually covers');
      expect(find.textContaining('et pension alimentaire'), findsNothing);
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
    testWidgets('tax gated (no canton) → film ABSENT', (tester) async {
      // The film renders LPP CHF and tax CHF. It stays gated behind exactly the
      // gates that own those figures — no more (patrimoine no longer renders a
      // CHF, so requiring it would be over-gating) and no less.
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setAmount(tester, _lpp1, 180000);
      await _setAmount(tester, _lpp2, 80000);
      await _setAmount(tester, _avoir1, 40000);
      await _setAmount(tester, _avoir2, 20000);
      // canton NOT confirmed → tax gate open → no tax CHF may reach the film.
      await _simulate(tester);
      expect(_gate(tester, _taxTitle), isNotNull);
      expect(find.byType(DivorceFilmWidget), findsNothing,
          reason: 'the film carries tax CHF → it needs the tax gate closed');
    });

    testWidgets('LPP gated (avoir missing) → film ABSENT', (tester) async {
      await _pump(tester, _FakeProvider(_profile(provided: {'canton'})));
      await _setAmount(tester, _income1, 90000);
      await _setAmount(tester, _income2, 50000);
      await _setAmount(tester, _lpp1, 180000);
      await _setAmount(tester, _lpp2, 80000);
      await _setAmount(tester, _avoir1, 40000);
      // avoir2 missing → the CC art. 122 transfer cannot be established.
      await _simulate(tester);
      expect(_gate(tester, _lppTitle), isNotNull);
      expect(find.byType(DivorceFilmWidget), findsNothing);
    });

    testWidgets(
        'all computed outputs complete → film present, NO pension amount',
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

      expect(find.byType(DivorceFilmWidget), findsOneWidget,
          reason: 'LPP + tax confirmed → every CHF the film renders is real');
      final film = find.byType(DivorceFilmWidget);
      // ── ACT 3: no personal maintenance CHF, only the educational statement. ──
      expect(
        find.descendant(of: film, matching: find.textContaining("1'100")),
        findsNothing,
        reason: 'the income-gap pension is a non-Swiss rule → never rendered',
      );
      expect(
        find.descendant(of: film, matching: find.textContaining("1'500")),
        findsNothing,
        reason: 'nor the older childrenCount × 1500 forfait',
      );
      expect(
        find.descendant(
            of: film, matching: find.textContaining(_pensionNoEstimate)),
        findsOneWidget,
        reason: 'acte 3 states that no amount can be estimated',
      );
      // The direction-neutral deductibility rule stays (it is educational).
      expect(
        find.descendant(
          of: film,
          matching:
              find.textContaining('déductible du revenu de la personne qui la verse'),
        ),
        findsOneWidget,
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
    expect(find.byType(SituationGateCard), findsNWidgets(2));
    handle.dispose();
  });

  // ══════════════════════════════════════════════════════════════
  //  Tier B smoke — persona FAMILLE seedée (famille_bern) : preuve C2 chiffré.
  //  Profil hydraté depuis la SEULE seed. Le divorce est un cas particulier :
  //  le côté EX-conjoint (revenu 2, avoir au mariage) NE PEUT PAS venir du
  //  profil (doctrine anti-contamination — le profil ne décrit pas l'ex). La
  //  seed débloque donc tout le côté UTILISATEUR (income1, LPP certifiée,
  //  canton, enfants) ; le résultat fiscal se rend après la SEULE saisie
  //  irréductible : le revenu de l'ex.
  // ══════════════════════════════════════════════════════════════
  group('famille_bern seed unlocks the user side; ex income is the only touch',
      () {
    CoachProfile seededFamille() => CoachProfile.fromWizardAnswers(
        CoachProfileSeeds.registry['famille_bern']!.toWizardAnswers());

    testWidgets('conjoint-1 facts (income1, LPP certifiée, canton, enfants) seedés',
        (tester) async {
      await _pump(tester, _FakeProvider(seededFamille()));
      await _simulate(tester);

      expect(_state(tester).debugIncome1, 114000.0);
      expect(_state(tester).debugCanton, 'BE');
      expect(_state(tester).debugLpp1, 180000.0,
          reason: 'LPP certifiée (salaire assuré déclaré) → seedable, '
              'jamais une estimation âge×salaire.');
      expect(_state(tester).debugChildrenTouched, isTrue,
          reason: 'nombreEnfants>0 confirme le fait enfants.');
      // Le fiscal reste gaté sur le SEUL revenu de l'ex (jamais dérivé du profil).
      final gated = _gate(tester, _taxTitle);
      expect(gated, isNotNull);
      expect(gated!.gate.missing.map((f) => f.key), <String>['income2'],
          reason: 'seul le revenu de l\'ex manque — tout le reste est seedé');
    });

    testWidgets('seed + ex income touch → tax figure renders (C2 chiffré)',
        (tester) async {
      await _pump(tester, _FakeProvider(seededFamille()));
      // La SEULE saisie irréductible : le revenu de l'ex-conjoint.
      await _setAmount(tester, _income2, 78000);
      await _simulate(tester);

      expect(_gate(tester, _taxTitle), isNull,
          reason: 'income1 + canton seedés + income2 saisi → fiscal complet');
      expect(find.textContaining('/an'), findsWidgets,
          reason: 'le delta fiscal du divorce rend une fois déverrouillé');
    });
  });
}
