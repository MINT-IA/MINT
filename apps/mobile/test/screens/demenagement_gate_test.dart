import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/demenagement_cantonal_screen.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for demenagement_cantonal_screen.
///
/// The screen computes ONE personalised output — the annual economy (or extra
/// cost) of an inter-cantonal move = fiscal delta + LAMal delta — surfaced as a
/// hero total, a two-canton comparison, a per-post breakdown, and a
/// « months of rent » insight. Every rendered CHF in that block is gated behind
/// the four facts it consumes:
///   • revenu (key 'salary', value IN the slider range) — seeded from the user's
///     own income;
///   • cantonDepart (key 'canton') — the user's CURRENT canton;
///   • cantonArrivee — a HYPOTHETICAL destination, no profile source →
///     TOUCH-ONLY (the 'VS' default stays assumed until picked);
///   • situationFamiliale (key 'civilStatus') — drives the household LAMal
///     premium count.
///
/// The per-canton fiscal indices and average LAMal premiums shown in the
/// comparison card are GENERIC cantonal benchmarks (labelled by a caption), not
/// the user's real premium — so they are not per-user facts, but they only
/// render inside the gated block (never against a fabricated destination).
///
/// Every assertion is on the RENDERED figure (the [MintHeroNumber], the detail
/// bilan text) or on the rendered [SituationGateCard]'s facts — never an
/// internal bool. Each test goes RED if the gate is removed (i.e. if the screen
/// went back to computing on the fabricated defaults 120000 / GE / VS / marié).
///
/// The screen is a `SingleChildScrollView` → every child is built (offstage),
/// so `find.byType` / `find.byKey` work without scrolling.

const _revenuField = Key('demenagement_revenu_field');
const _cantonDepartField = Key('demenagement_canton_depart');
const _cantonArriveeField = Key('demenagement_canton_arrivee');
const _situationField = Key('demenagement_situation');

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

/// [salaire] × 12 is the annual income; the screen seeds revenu only when the
/// 'salary' key is present AND the annual lands in the slider range
/// [30000, 500000].
CoachProfile _profile({
  String canton = 'GE',
  double salaire = 8000, // → 96000 annual (in range, ≠ default 120000)
  CoachCivilStatus etatCivil = CoachCivilStatus.marie,
  Set<String> provided = const {},
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: canton,
    salaireBrutMensuel: salaire,
    etatCivil: etatCivil,
    userProvidedFields: provided,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}

/// A profile that confirms the three profile-seedable facts (revenu, canton
/// départ, situation) — the destination is always touch-only.
CoachProfile _fullSeed({
  String canton = 'GE',
  double salaire = 8000,
  CoachCivilStatus etatCivil = CoachCivilStatus.marie,
}) =>
    _profile(
      canton: canton,
      salaire: salaire,
      etatCivil: etatCivil,
      provided: {'salary', 'canton', 'civilStatus'},
    );

Future<void> _pump(WidgetTester tester, CoachProfileProvider provider) async {
  await tester.binding.setSurfaceSize(const Size(1200, 4000));
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
        home: DemenagementCantonalScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(DemenagementCantonalScreen)) as dynamic;

/// Single gate on this screen → exactly one card when the output is gated.
SituationGate _gate(WidgetTester tester) =>
    tester.widget<SituationGateCard>(find.byType(SituationGateCard)).gate;

Iterable<String> _missing(WidgetTester tester) =>
    _gate(tester).missing.map((f) => f.key);

Future<void> _touchRevenu(WidgetTester tester, double v) async {
  tester.widget<MintPremiumSlider>(find.byKey(_revenuField)).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _touchDepart(WidgetTester tester, String c) async {
  tester
      .widget<DropdownButton<String>>(find.byKey(_cantonDepartField))
      .onChanged!(c);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _touchArrivee(WidgetTester tester, String c) async {
  tester
      .widget<DropdownButton<String>>(find.byKey(_cantonArriveeField))
      .onChanged!(c);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _touchSituation(WidgetTester tester, String v) async {
  tester
      .widget<SegmentedButton<String>>(find.byKey(_situationField))
      .onSelectionChanged!({v});
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Detail-card bilan text for a signed annual total (e.g. "+CHF 7'920/an").
String _bilanText(double total) =>
    '${total >= 0 ? '+' : ''}${formatChfWithPrefix(total)}/an';

void main() {
  // ══════════════════════════════════════════════════════════════
  //  NO DATA → gated, lists all four facts
  // ══════════════════════════════════════════════════════════════
  group('No data', () {
    testWidgets('no profile: output gated, hero absent, lists 4 facts',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      expect(find.byType(MintHeroNumber), findsNothing,
          reason: 'no economy figure on the fabricated defaults 120000/GE/VS/marié');
      expect(find.byType(SituationGateCard), findsOneWidget);
      expect(
        _missing(tester),
        containsAll(<String>[
          'revenu',
          'cantonDepart',
          'cantonArrivee',
          'situationFamiliale',
        ]),
      );
    });

    testWidgets('no provider in tree: defaults kept, gated', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 4000));
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
          home: DemenagementCantonalScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DemenagementCantonalScreen), findsOneWidget);
      expect(find.byType(MintHeroNumber), findsNothing);
      expect(find.byType(SituationGateCard), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SEED (profile) + TOUCH destination → figure == computed output
  // ══════════════════════════════════════════════════════════════
  group('Seed + touch destination', () {
    testWidgets(
        'seed revenu+cantonDepart+situation via profile, touch cantonArrivee → '
        'figure == deterministic output', (tester) async {
      // GE (idx 100) → VS (idx 75), revenu 96000, marié.
      // econFiscale = 96000 * (0.22 - 0.165) = 5280
      // econLamal   = (480 - 370) * 12 * 2   = 2640
      // total       = 7920
      await _pump(tester, _FakeProvider(_fullSeed()));

      // Three facts seeded from the profile; destination still assumed → gated.
      expect(find.byType(MintHeroNumber), findsNothing);
      expect(_missing(tester), <String>['cantonArrivee'],
          reason: 'only the hypothetical destination remains');

      await _touchArrivee(tester, 'VS');

      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.byType(MintHeroNumber), findsOneWidget);
      expect(_state(tester).debugRevenu, 96000.0,
          reason: 'revenu seeded from salaireBrutMensuel*12');
      expect(_state(tester).debugCantonDepart, 'GE');
      expect(_state(tester).debugSituation, 'marie');
      expect(_state(tester).debugEconFiscale, closeTo(5280.0, 0.001));
      expect(_state(tester).debugEconLamal, 2640.0); // integer math, exact
      expect(_state(tester).debugTotal, closeTo(7920.0, 0.001));
      // Anti-façade: the RENDERED bilan echoes the computed total (rounded).
      expect(find.text(_bilanText(7920.0)), findsOneWidget);
    });

    testWidgets('cantonArrivee absent → gated until selected', (tester) async {
      await _pump(tester, _FakeProvider(_fullSeed()));
      expect(find.byType(MintHeroNumber), findsNothing);
      expect(_missing(tester), contains('cantonArrivee'));

      await _touchArrivee(tester, 'ZG');
      expect(find.byType(MintHeroNumber), findsOneWidget,
          reason: 'destination confirmed → the four facts are all real');
      expect(_state(tester).debugCantonArrivee, 'ZG');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TOUCH-ALL (no profile) → figure renders on user data only
  // ══════════════════════════════════════════════════════════════
  testWidgets('touch all four facts (no profile) → figure renders',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _touchRevenu(tester, 100000);
    await _touchDepart(tester, 'ZH');
    await _touchArrivee(tester, 'ZG');
    await _touchSituation(tester, 'celibataire');

    expect(find.byType(SituationGateCard), findsNothing);
    expect(find.byType(MintHeroNumber), findsOneWidget);
    // ZH idx 72 → ZG idx 40 : econFiscale = 100000 * (0.1584 - 0.088) = 7040
    // célibataire → 1 personne : econLamal = (390 - 310) * 12 * 1 = 960
    expect(_state(tester).debugEconFiscale, closeTo(7040.0, 0.001));
    expect(_state(tester).debugEconLamal, 960.0);
    expect(_state(tester).debugTotal, closeTo(8000.0, 0.001));
  });

  // ══════════════════════════════════════════════════════════════
  //  PARTIAL: one missing fact keeps the output gated
  // ══════════════════════════════════════════════════════════════
  testWidgets('revenu + both cantons but situation assumed → still gated',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _touchRevenu(tester, 100000);
    await _touchDepart(tester, 'GE');
    await _touchArrivee(tester, 'VS');
    // situationFamiliale never touched, no civilStatus key → assumed.
    expect(find.byType(MintHeroNumber), findsNothing);
    expect(_missing(tester), <String>['situationFamiliale']);
  });

  // ══════════════════════════════════════════════════════════════
  //  VALUE-IN-RANGE mutation-proofs (revenu)
  // ══════════════════════════════════════════════════════════════
  group('Revenu value-in-range mutation-proofs', () {
    testWidgets(
        'UPPER: salaire 50000 (annual 600000 > 500000) does NOT seed → gated',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 50000, provided: {'salary', 'canton', 'civilStatus'})),
      );
      expect(_state(tester).debugRevenu, 120000.0,
          reason: 'out-of-range annual is never clamped into the figure');
      expect(_missing(tester), contains('revenu'));
      expect(find.byType(MintHeroNumber), findsNothing);
    });

    testWidgets(
        'LOWER: salaire 2000 (annual 24000 < 30000) does NOT seed → gated',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 2000, provided: {'salary', 'canton', 'civilStatus'})),
      );
      expect(_state(tester).debugRevenu, 120000.0);
      expect(_missing(tester), contains('revenu'));
      expect(find.byType(MintHeroNumber), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  PROVENANCE = KEY, not value (default-collision) + no-key
  // ══════════════════════════════════════════════════════════════
  group('Provenance is the key, never the value', () {
    testWidgets(
        'DEFAULT-COLLISION: profile revenu==120000 & canton==GE (the defaults) '
        'confirm via KEY, while an identical no-profile screen stays gated',
        (tester) async {
      // salaire 10000 → 120000 == default; canton GE == default.
      await _pump(
        tester,
        _FakeProvider(_profile(
            salaire: 10000,
            canton: 'GE',
            provided: {'salary', 'canton', 'civilStatus'})),
      );
      // The three keyed facts confirm even though the values equal the defaults.
      expect(_missing(tester), <String>['cantonArrivee']);
      expect(_state(tester).debugRevenu, 120000.0);
      expect(_state(tester).debugCantonDepart, 'GE');
    });

    testWidgets('no keys: real values present but unconfirmed → all gated',
        (tester) async {
      // Values are there, but no provenance keys → every profile fact assumed.
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 8000, canton: 'GE', provided: {})),
      );
      expect(_state(tester).debugRevenu, 120000.0,
          reason: 'no salary key → not seeded (default kept)');
      expect(_state(tester).debugCantonDepart, 'GE',
          reason: 'GE is the default, not a confirmed seed (no canton key)');
      expect(
        _missing(tester),
        containsAll(<String>['revenu', 'cantonDepart', 'situationFamiliale']),
      );
    });

    testWidgets(
        'situationFamiliale needs the civilStatus key (non-nullable etatCivil '
        'default is never a confirmation)', (tester) async {
      // marié value present but no civilStatus key → assumed.
      await _pump(
        tester,
        _FakeProvider(_profile(
            etatCivil: CoachCivilStatus.marie,
            provided: {'salary', 'canton'})),
      );
      await _touchArrivee(tester, 'VS');
      expect(find.byType(MintHeroNumber), findsNothing,
          reason: 'civil status has no key → assumed → gated');
      expect(_missing(tester), <String>['situationFamiliale']);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  NULL-CLEAR re-gates seeded facts; TOUCHED facts survive
  // ══════════════════════════════════════════════════════════════
  group('Stale invalidation on profile clear', () {
    testWidgets(
        'clear re-gates the seeded facts (touched destination survives)',
        (tester) async {
      final mut = _MutableProvider();
      await _pump(tester, mut);
      mut.hydrate(_fullSeed());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _touchArrivee(tester, 'VS');
      expect(find.byType(MintHeroNumber), findsOneWidget);

      mut.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MintHeroNumber), findsNothing,
          reason: 'seeded revenu/cantonDepart/situation lose provenance');
      // The touched destination is user data → it survives the clear.
      expect(_missing(tester),
          containsAll(<String>['revenu', 'cantonDepart', 'situationFamiliale']));
      expect(_missing(tester), isNot(contains('cantonArrivee')),
          reason: 'cantonArrivee was touched → immune to the clear');
    });

    testWidgets('touched facts (all four) survive a profile clear',
        (tester) async {
      final mut = _MutableProvider();
      await _pump(tester, mut);
      await _touchRevenu(tester, 100000);
      await _touchDepart(tester, 'ZH');
      await _touchArrivee(tester, 'ZG');
      await _touchSituation(tester, 'celibataire');
      expect(find.byType(MintHeroNumber), findsOneWidget);

      mut.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MintHeroNumber), findsOneWidget,
          reason: 'touched facts are local user data, immune to a clear');
      expect(_state(tester).debugRevenu, 100000.0);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TWO-NOTIFICATION RACE: a late-arriving key confirms on notify #2
  // ══════════════════════════════════════════════════════════════
  testWidgets('per-notify re-eval: a key arriving on the 2nd notify confirms',
      (tester) async {
    final mut = _MutableProvider();
    await _pump(tester, mut);

    // Notify #1 — profile WITHOUT the salary key → revenu stays assumed.
    mut.hydrate(_profile(salaire: 8000, provided: {'canton', 'civilStatus'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_missing(tester), contains('revenu'),
        reason: 'no salary key yet → revenu not confirmed');
    expect(_state(tester).debugRevenu, 120000.0);

    // Notify #2 — the salary key arrives (loadFromWizard notifies repeatedly).
    mut.hydrate(_profile(salaire: 8000, provided: {'salary', 'canton', 'civilStatus'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_missing(tester), isNot(contains('revenu')),
        reason: 'no latch stranded the field — it confirms on notify #2');
    expect(_state(tester).debugRevenu, 96000.0);
    // Only the touch-only destination remains.
    expect(_missing(tester), <String>['cantonArrivee']);
  });

  // ══════════════════════════════════════════════════════════════
  //  EDGE: cantonDepart == cantonArrivee → 0 diff is a VALID result
  // ══════════════════════════════════════════════════════════════
  testWidgets(
      'cantonDepart == cantonArrivee (both confirmed) → total 0 renders '
      '(honest « no difference », not a fabrication)', (tester) async {
    // Seed départ = VS (profile canton + key), then touch arrivée = VS too.
    // Both cantons are user-confirmed → 0 is the truthful answer, so it renders.
    await _pump(tester, _FakeProvider(_fullSeed(canton: 'VS')));
    expect(_state(tester).debugCantonDepart, 'VS');
    await _touchArrivee(tester, 'VS');

    expect(find.byType(MintHeroNumber), findsOneWidget,
        reason: 'both cantons confirmed → the 0 result is real, not fabricated');
    expect(_state(tester).debugEconFiscale, 0.0);
    expect(_state(tester).debugEconLamal, 0.0);
    expect(_state(tester).debugTotal, 0.0);
    // All three detail rows (fiscale / LAMal / bilan) are 0 → same text ×3.
    expect(find.text(_bilanText(0.0)), findsNWidgets(3));
  });

  // ══════════════════════════════════════════════════════════════
  //  a11y root boundary survives the gate refactor
  // ══════════════════════════════════════════════════════════════
  testWidgets('screen-root Semantics boundary + discrete gate nodes',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakeProvider(null));
    expect(
      tester.getSemantics(find.byType(DemenagementCantonalScreen)),
      isNotNull,
    );
    // The gated result slot exposes the situation gate with focusable nodes.
    expect(find.byType(SituationGateCard), findsOneWidget);
    handle.dispose();
  });
}
