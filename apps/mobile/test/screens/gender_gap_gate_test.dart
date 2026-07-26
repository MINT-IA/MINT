import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/gender_gap_screen.dart';
import 'package:mint_mobile/services/segments_service.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for gender_gap_screen (the LPP
/// pension-gap explorer for part-time work).
///
/// No computed « ta situation » figure is shown on a fabricated default. The
/// screen used to compute the gap on invented defaults (revenu 85000 / avoir LPP
/// 120000 / âge 40 / années 15 / canton 'ZH') the instant it opened. It now
/// computes only AFTER a real profile seed, and each result card gates on the
/// facts IT consumes:
///   • Comparaison de rente (rente projetée + lacune) → revenu + avoir LPP + âge
///   • Détail de coordination (salaire coordonné)      → revenu
///
/// A fact is CONFIRMED only from real data — seeded from the profile (provided
/// key + value in range; avoir LPP requires the certificate flag, never the
/// estimate) — else it renders « Non renseigné », never the fabricated number.
///
/// `canton` and `anneesCotisation` are NOT consumed by `GenderGapService` (the
/// LPP is federal; `anneesCotisation` is unread), so per ADR §2 they do NOT gate
/// a figure they cannot change (« age drives neither output → not gated »). They
/// are still never displayed fabricated: an unconfirmed value shows « Non
/// renseigné », closing the `fromJson canton ?? 'ZH'` default.
///
/// The taux-activité slider is the EXPLORATORY knob: its position is explicit on
/// screen, so it is not a hidden fabrication — it stays interactive while the
/// result stays gated on the situation facts.
///
/// Every assertion is on the RENDERED figure/card (gate presence, a specific CHF,
/// a card title). Each goes RED if the gate is removed (i.e. if the screen went
/// back to rendering the two result cards on open).

// ── The two result-card gate titles ──
const _pensionGateTitle = 'Complète ta situation pour estimer ta rente';
const _coordGateTitle = 'Complète ta situation pour ce détail de coordination';

// ── Result-card headings (present only once unlocked) ──
const _pensionHeading = 'Rente LPP'; // genderGapRenteLppEstimee = "Rente LPP estimée"
const _coordHeading = 'omprendre la d'; // genderGapCoordinationTitle
const _lacuneLabel = 'Lacune annuelle';
const _nonRenseigne = 'Non renseigné';

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

/// A LPP prévoyance block. When [cert] is true a caisse-specific field
/// (`avoirLppObligatoire`) is set so `isLppFromCertificate` is true — a REAL
/// scanned value. When false, the balance is an ESTIMATE and must NOT seed.
PrevoyanceProfile _prev({double? lpp, bool cert = true, int? annees}) {
  return PrevoyanceProfile(
    avoirLppTotal: lpp,
    avoirLppObligatoire: (lpp != null && cert) ? lpp * 0.7 : null,
    anneesContribuees: annees,
  );
}

CoachProfile _profile({
  double salaire = 8000, // monthly → ×12 annual
  int birthYear = 1985,
  String canton = 'ZH',
  Set<String> provided = const {},
  PrevoyanceProfile? prevoyance,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    etatCivil: CoachCivilStatus.celibataire,
    userProvidedFields: provided,
    prevoyance: prevoyance ?? const PrevoyanceProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}

/// A fully-confirmed profile: salary + age + canton keys, real certificate LPP,
/// contribution years. Every determinative fact seeds.
CoachProfile _fullProfile() => _profile(
      salaire: 8000, // 96'000 annual — in range
      birthYear: 1985,
      canton: 'ZH',
      provided: {'salary', 'age', 'canton'},
      prevoyance: _prev(lpp: 120000, cert: true, annees: 15),
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
        home: GenderGapScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(GenderGapScreen)) as dynamic;

SituationGateCard? _gate(WidgetTester tester, String title) {
  for (final c
      in tester.widgetList<SituationGateCard>(find.byType(SituationGateCard))) {
    if (c.title == title) return c;
  }
  return null;
}

/// Drive the exploratory taux-activité slider (10–100 range).
Future<void> _setTaux(WidgetTester tester, double v) async {
  tester
      .widget<MintPremiumSlider>(find.byType(MintPremiumSlider))
      .onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── P3 « zéro impasse » : the on-screen controls of the « Paramètres » block.
//    Each situation fact is editable here, so an anonymous user (no profile)
//    can complete the gate without ever leaving the screen. Fields are
//    disambiguated by their (min, max) range — all four differ.
MintAmountField _field(
  WidgetTester tester, {
  required double min,
  required double max,
}) =>
    tester
        .widgetList<MintAmountField>(find.byType(MintAmountField))
        .firstWhere((f) => f.min == min && f.max == max);

Future<void> _pumpEdit(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _enterRevenu(WidgetTester tester, double v) async {
  _field(tester, min: 0, max: 2000000).onChanged(v);
  await _pumpEdit(tester);
}

Future<void> _enterAge(WidgetTester tester, double v) async {
  _field(tester, min: 16, max: 99).onChanged(v);
  await _pumpEdit(tester);
}

Future<void> _enterAvoirLpp(WidgetTester tester, double v) async {
  _field(tester, min: 0, max: 5000000).onChanged(v);
  await _pumpEdit(tester);
}

Future<void> _enterAnnees(WidgetTester tester, double v) async {
  _field(tester, min: 0, max: 50).onChanged(v);
  await _pumpEdit(tester);
}

Future<void> _enterCanton(WidgetTester tester, String c) async {
  tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .onChanged!(c);
  await _pumpEdit(tester);
}

void main() {
  // ══════════════════════════════════════════════════════════════
  //  SCREEN OPEN, NO PROFILE → nothing computed on a fabricated default
  // ══════════════════════════════════════════════════════════════
  group('Screen open — no profile', () {
    testWidgets('both result cards gated; no result heading; no gap figure',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      // Both computed cards are gated (their result headings never render).
      expect(_gate(tester, _pensionGateTitle), isNotNull);
      expect(_gate(tester, _coordGateTitle), isNotNull);
      expect(find.byType(SituationGateCard), findsNWidgets(2));
      // Result headings absent → the figures did NOT render (RED if gate removed).
      expect(find.textContaining(_pensionHeading), findsNothing,
          reason: 'no rente card computed on 85000/120000/40');
      expect(find.textContaining(_coordHeading), findsNothing,
          reason: 'no coordination detail computed on a fabricated revenu');
      expect(find.text(_lacuneLabel), findsNothing,
          reason: 'no gap figure on open');
    });

    testWidgets('every situation fact is null / unconfirmed on open',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      final st = _state(tester);
      expect(st.debugRevenuAnnuel, isNull);
      expect(st.debugAvoirLpp, isNull);
      expect(st.debugAge, isNull);
      expect(st.debugAnneesCotisation, isNull);
      expect(st.debugCantonConfirmed, isFalse,
          reason: 'the legacy "ZH" default is NOT a confirmed fact');
    });

    testWidgets('every parameter row reads « Non renseigné », never a number',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      // revenu / âge / avoir LPP / années / canton → 5 rows, all "Non renseigné".
      expect(find.text(_nonRenseigne), findsNWidgets(5));
    });

    testWidgets('pension gate lists exactly revenu + avoir LPP + âge',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      final g = _gate(tester, _pensionGateTitle)!;
      expect(g.gate.missing.map((f) => f.key),
          <String>['revenu', 'avoirLpp', 'age']);
    });

    testWidgets('coordination gate lists exactly revenu', (tester) async {
      await _pump(tester, _FakeProvider(null));
      final g = _gate(tester, _coordGateTitle)!;
      expect(g.gate.missing.map((f) => f.key), <String>['revenu']);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  PER-OUTPUT GATING — revenu unlocks coordination but NOT the rente card
  // ══════════════════════════════════════════════════════════════
  group('Per-output gating', () {
    testWidgets(
        'revenu confirmed only → coordination renders, rente card still gated',
        (tester) async {
      // salary key only: revenu seeds, but no cert LPP and no age key.
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 8000, provided: {'salary'})),
      );
      final st = _state(tester);
      expect(st.debugRevenuAnnuel, 96000.0);
      expect(st.debugAvoirLpp, isNull);
      expect(st.debugAge, isNull);

      // Coordination (needs only revenu) unlocks.
      expect(_gate(tester, _coordGateTitle), isNull);
      expect(find.textContaining(_coordHeading), findsOneWidget);

      // Pension (needs revenu + avoirLpp + âge) stays gated on the remainder.
      final pg = _gate(tester, _pensionGateTitle);
      expect(pg, isNotNull);
      expect(pg!.gate.missing.map((f) => f.key), <String>['avoirLpp', 'age']);
      expect(find.textContaining(_pensionHeading), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  FULL REAL PROFILE → both cards render REAL figures, no gate, no gaps
  // ══════════════════════════════════════════════════════════════
  group('Full real profile', () {
    testWidgets('both cards render the service figures on the seeded values',
        (tester) async {
      await _pump(tester, _FakeProvider(_fullProfile()));
      final st = _state(tester);

      // All determinative facts seeded from real data.
      expect(st.debugRevenuAnnuel, 96000.0);
      expect(st.debugAvoirLpp, 120000.0);
      expect(st.debugAge, isNotNull);
      expect(st.debugCantonConfirmed, isTrue);

      // No gate cards.
      expect(find.byType(SituationGateCard), findsNothing);
      expect(find.textContaining(_pensionHeading), findsOneWidget);
      expect(find.textContaining(_coordHeading), findsOneWidget);

      // The rendered gap equals the service output on the screen's own input.
      final expected = GenderGapService.analyse(
        input: GenderGapInput(
          tauxActivite: st.debugTauxActivite,
          age: st.debugAge!,
          revenuAnnuel: st.debugRevenuAnnuel! * (st.debugTauxActivite / 100),
          avoirLpp: st.debugAvoirLpp!,
          anneesCotisation: st.debugAnneesCotisation ?? 0,
          canton: st.debugCanton,
        ),
      );
      expect(
        find.text(GenderGapService.formatChf(expected.lacuneAnnuelle)),
        findsWidgets,
        reason: 'the gap is the real service figure, not a fabricated one',
      );
      expect(
        find.text(GenderGapService.formatChf(expected.salaireCoordonne100)),
        findsWidgets,
        reason: 'the coordinated salary is the real service figure',
      );
      // The projection's hardcoded assumptions (1.5%/yr return, ~20 retirement
      // years) are DISCLOSED under the figure, not left implicit.
      expect(find.textContaining('Hypothèses de projection'), findsOneWidget,
          reason: 'projection assumptions are disclosed, not silent');
      // No parameter row is "Non renseigné" once everything is confirmed.
      expect(find.text(_nonRenseigne), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SEED PROVENANCE — key + range, certificate flag, never a default
  // ══════════════════════════════════════════════════════════════
  group('Seed provenance', () {
    testWidgets('revenu: no salary key → not seeded (gated)', (tester) async {
      await _pump(tester, _FakeProvider(_profile(salaire: 8000, provided: {})));
      expect(_state(tester).debugRevenuAnnuel, isNull);
      expect(_gate(tester, _pensionGateTitle), isNotNull);
      expect(_gate(tester, _coordGateTitle), isNotNull);
    });

    testWidgets('revenu: out-of-range (2.4M annual) → not seeded', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 200000, provided: {'salary'})),
      );
      expect(_state(tester).debugRevenuAnnuel, isNull,
          reason: 'out-of-range annual is never clamped into a seed');
    });

    testWidgets('avoir LPP: ESTIMATED (no certificate) → not seeded',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          provided: {'salary', 'age'},
          prevoyance: _prev(lpp: 120000, cert: false),
        )),
      );
      expect(_state(tester).debugAvoirLpp, isNull,
          reason: 'an estimated LPP balance never feeds a projection');
      // Pension card stays gated on the missing avoir LPP.
      final pg = _gate(tester, _pensionGateTitle);
      expect(pg, isNotNull);
      expect(pg!.gate.missing.map((f) => f.key), contains('avoirLpp'));
    });

    testWidgets('avoir LPP: real certificate value → seeded', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          provided: {'salary', 'age'},
          prevoyance: _prev(lpp: 120000, cert: true),
        )),
      );
      expect(_state(tester).debugAvoirLpp, 120000.0);
    });

    testWidgets('avoir LPP: certificate but out-of-range (6M) → not seeded',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          provided: {'salary', 'age'},
          prevoyance: _prev(lpp: 6000000, cert: true),
        )),
      );
      expect(_state(tester).debugAvoirLpp, isNull);
    });

    testWidgets('âge: no age key (birthYear present) → not seeded',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(birthYear: 1985, provided: {'salary'})),
      );
      expect(_state(tester).debugAge, isNull,
          reason: 'a birthYear without the q_birth_year provenance never seeds');
    });

    testWidgets('âge: age key + valid birthYear → seeded', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(birthYear: 1985, provided: {'age'})),
      );
      expect(_state(tester).debugAge, isNotNull);
      expect(_state(tester).debugAge, greaterThan(0));
    });

    testWidgets('années de cotisation: real value → seeded (display-only)',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          provided: {'salary'},
          prevoyance: _prev(lpp: 120000, cert: true, annees: 15),
        )),
      );
      expect(_state(tester).debugAnneesCotisation, 15);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  CANTON — closes the fromJson `?? 'ZH'` default; display-only (federal LPP)
  // ══════════════════════════════════════════════════════════════
  group('Canton provenance (display-only, non-determinative)', () {
    testWidgets('real canton (key + valid) → confirmed, shown', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'GE', provided: {'canton'})),
      );
      expect(_state(tester).debugCantonConfirmed, isTrue);
      expect(_state(tester).debugCanton, 'GE');
      // The picker shows the seeded canton (code — name, concubinage idiom).
      expect(find.text('GE — Geneve'), findsOneWidget);
    });

    testWidgets('legacy valid "ZH" WITHOUT the canton key → NOT confirmed',
        (tester) async {
      // fromJson defaults canton to 'ZH' with no user input; provided has no key.
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'ZH', provided: {'salary'})),
      );
      expect(_state(tester).debugCantonConfirmed, isFalse,
          reason: 'no q_canton answer → the ZH default never confirms');
      // The canton row reads "Non renseigné", never the fabricated 'ZH'.
      expect(find.text('ZH'), findsNothing);
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
      expect(find.text('XX'), findsNothing);
    });

    testWidgets(
        'canton unconfirmed does NOT block the rente (federal LPP) when the '
        'determinative facts are present', (tester) async {
      // revenu + age + real LPP seeded, but canton is legacy 'ZH' without key.
      await _pump(
        tester,
        _FakeProvider(_profile(
          canton: 'ZH',
          provided: {'salary', 'age'},
          prevoyance: _prev(lpp: 120000, cert: true),
        )),
      );
      expect(_state(tester).debugCantonConfirmed, isFalse);
      // The rente card renders — canton is not one of its determinative facts.
      expect(_gate(tester, _pensionGateTitle), isNull,
          reason: 'canton does not gate a federal LPP figure it cannot change');
      expect(find.textContaining(_pensionHeading), findsOneWidget);
      // But the canton parameter row is still honest: "Non renseigné".
      expect(find.text(_nonRenseigne), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TAUX SLIDER — exploratory knob stays interactive and recomputes
  // ══════════════════════════════════════════════════════════════
  group('Taux slider (exploratory)', () {
    testWidgets('slider present and drives taux + recompute', (tester) async {
      await _pump(tester, _FakeProvider(_fullProfile()));
      expect(find.byType(Slider), findsOneWidget);
      final st = _state(tester);
      final before = st.debugTauxActivite;

      // The rente at the current taux before the change.
      final expectedBefore = GenderGapService.analyse(
        input: GenderGapInput(
          tauxActivite: before,
          age: st.debugAge!,
          revenuAnnuel: st.debugRevenuAnnuel! * (before / 100),
          avoirLpp: st.debugAvoirLpp!,
          anneesCotisation: st.debugAnneesCotisation ?? 0,
          canton: st.debugCanton,
        ),
      );
      expect(find.text(GenderGapService.formatChf(expectedBefore.lacuneAnnuelle)),
          findsWidgets);

      // Move the slider — it stays interactive (not disabled by the gate).
      await _setTaux(tester, 90);
      expect(_state(tester).debugTauxActivite, 90);

      // The figure recomputed (stale-invalidation): the old gap is gone, the new
      // one is present.
      final expectedAfter = GenderGapService.analyse(
        input: GenderGapInput(
          tauxActivite: 90,
          age: st.debugAge!,
          revenuAnnuel: st.debugRevenuAnnuel! * (90 / 100),
          avoirLpp: st.debugAvoirLpp!,
          anneesCotisation: st.debugAnneesCotisation ?? 0,
          canton: st.debugCanton,
        ),
      );
      expect(expectedAfter.lacuneAnnuelle, lessThan(expectedBefore.lacuneAnnuelle),
          reason: 'a higher activity rate shrinks the gap — the knob matters');
      expect(find.text(GenderGapService.formatChf(expectedAfter.lacuneAnnuelle)),
          findsWidgets);
    });

    testWidgets('slider is interactive even while the result is gated',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(find.byType(Slider), findsOneWidget);
      await _setTaux(tester, 40);
      expect(_state(tester).debugTauxActivite, 40);
      // Result stays gated (taux is not a situation fact).
      expect(find.byType(SituationGateCard), findsNWidgets(2));
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  P3 « ZÉRO IMPASSE » — every gated fact is completable ON SCREEN
  //
  //  Before P3 the « Paramètres » block was DISPLAY-ONLY and no fact carried an
  //  `onComplete`: an anonymous user could never confirm revenu / avoir LPP /
  //  âge / canton, so the pension gate could never open. A gate the user cannot
  //  complete is a dead end, not a gate. These tests go RED if the controls are
  //  reverted to read-only rows or if an `onComplete` is dropped.
  // ══════════════════════════════════════════════════════════════
  group('P3 zéro impasse — on-screen completion (no profile)', () {
    testWidgets('every fact of both gates carries a non-null onComplete',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      for (final title in <String>[_pensionGateTitle, _coordGateTitle]) {
        final g = _gate(tester, title)!;
        for (final f in g.gate.facts) {
          expect(f.onComplete, isNotNull,
              reason: '${g.title} / ${f.key} has no completion path → impasse');
        }
      }
    });

    testWidgets('an editable control exists for each parameter, all unconfirmed',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      // 4 amount fields (revenu / âge / avoir LPP / années) + 1 canton picker.
      expect(find.byType(MintAmountField), findsNWidgets(4));
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      // NONE of them is pre-filled with the old fabricated default
      // (85000 / 40 / 120000 / 15 / 'ZH') — they all read « Non renseigné ».
      expect(find.text(_nonRenseigne), findsNWidgets(5));
      final st = _state(tester);
      expect(st.debugRevenuAnnuel, isNull);
      expect(st.debugAge, isNull);
      expect(st.debugAvoirLpp, isNull);
      expect(st.debugAnneesCotisation, isNull);
      expect(st.debugCantonConfirmed, isFalse);
      // The gate-dur invariant still holds: no figure on open.
      expect(find.byType(SituationGateCard), findsNWidgets(2));
      expect(find.textContaining(_pensionHeading), findsNothing);
    });

    testWidgets('typing the revenu on screen unlocks the coordination detail',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(_gate(tester, _coordGateTitle), isNotNull);

      await _enterRevenu(tester, 96000);

      expect(_state(tester).debugRevenuAnnuel, 96000.0);
      expect(_gate(tester, _coordGateTitle), isNull,
          reason: 'the revenu fact was completed in place → gate lifted');
      expect(find.textContaining(_coordHeading), findsOneWidget);
      // The figure is the real service output on the typed value.
      final st = _state(tester);
      final expected = GenderGapService.analyse(
        input: GenderGapInput(
          tauxActivite: st.debugTauxActivite,
          age: 0,
          revenuAnnuel: 96000.0 * (st.debugTauxActivite / 100),
          avoirLpp: 0,
          anneesCotisation: 0,
          canton: '',
        ),
      );
      expect(find.text(GenderGapService.formatChf(expected.salaireCoordonne100)),
          findsWidgets);
      // Pension still gated on the two facts NOT yet entered.
      expect(_gate(tester, _pensionGateTitle)!.gate.missing.map((f) => f.key),
          <String>['avoirLpp', 'age']);
    });

    testWidgets(
        'ANTI-IMPASSE PROOF — revenu + avoir LPP + âge + canton typed on screen '
        'unlock the pension figure with NO profile at all', (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(find.byType(SituationGateCard), findsNWidgets(2));

      await _enterRevenu(tester, 96000);
      await _enterAvoirLpp(tester, 120000);
      await _enterAge(tester, 40);
      await _enterAnnees(tester, 15);
      await _enterCanton(tester, 'GE');

      final st = _state(tester);
      expect(st.debugRevenuAnnuel, 96000.0);
      expect(st.debugAvoirLpp, 120000.0);
      expect(st.debugAge, 40);
      expect(st.debugAnneesCotisation, 15);
      expect(st.debugCantonConfirmed, isTrue);
      expect(st.debugCanton, 'GE');

      // No gate card left, and the rente card renders the REAL service figure.
      expect(find.byType(SituationGateCard), findsNothing,
          reason: 'an anonymous user CAN complete the gate on screen');
      expect(find.textContaining(_pensionHeading), findsOneWidget);
      expect(find.text(_nonRenseigne), findsNothing);

      final expected = GenderGapService.analyse(
        input: GenderGapInput(
          tauxActivite: st.debugTauxActivite,
          age: 40,
          revenuAnnuel: 96000.0 * (st.debugTauxActivite / 100),
          avoirLpp: 120000,
          anneesCotisation: 15,
          canton: 'GE',
        ),
      );
      expect(find.text(GenderGapService.formatChf(expected.lacuneAnnuelle)),
          findsWidgets,
          reason: 'the gap is the service output on the TYPED facts');
      expect(find.text(_lacuneLabel), findsOneWidget);
    });

    testWidgets('editing a typed fact invalidates the stale figure',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _enterRevenu(tester, 96000);
      await _enterAvoirLpp(tester, 120000);
      await _enterAge(tester, 40);

      final st = _state(tester);
      GenderGapResult analyse(double revenu) => GenderGapService.analyse(
            input: GenderGapInput(
              tauxActivite: st.debugTauxActivite,
              age: 40,
              revenuAnnuel: revenu * (st.debugTauxActivite / 100),
              avoirLpp: 120000,
              anneesCotisation: 0,
              canton: '',
            ),
          );
      final before = analyse(96000);
      expect(find.text(GenderGapService.formatChf(before.lacuneAnnuelle)),
          findsWidgets);

      await _enterRevenu(tester, 150000);

      final after = analyse(150000);
      expect(after.lacuneAnnuelle, isNot(before.lacuneAnnuelle));
      expect(find.text(GenderGapService.formatChf(before.lacuneAnnuelle)),
          findsNothing,
          reason: 'the stale gap must not survive an input change');
      expect(find.text(GenderGapService.formatChf(after.lacuneAnnuelle)),
          findsWidgets);
    });

    testWidgets('a typed canton is confirmed provenance (touch == real data)',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(_state(tester).debugCantonConfirmed, isFalse);
      await _enterCanton(tester, 'VD');
      expect(_state(tester).debugCantonConfirmed, isTrue);
      expect(_state(tester).debugCanton, 'VD');
      expect(find.text('VD — Vaud'), findsOneWidget);
    });

    testWidgets('a profile-seeded fact still seeds — the picker is an ADDITIONAL '
        'path, not a replacement', (tester) async {
      await _pump(tester, _FakeProvider(_fullProfile()));
      final st = _state(tester);
      expect(st.debugRevenuAnnuel, 96000.0);
      expect(st.debugCantonConfirmed, isTrue);
      expect(find.byType(SituationGateCard), findsNothing);
      // …and the seeded value stays editable in place.
      await _enterRevenu(tester, 120000);
      expect(_state(tester).debugRevenuAnnuel, 120000.0);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  a11y root boundary + discrete gate nodes
  // ══════════════════════════════════════════════════════════════
  testWidgets('screen-root Semantics boundary + two gate cards on open',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakeProvider(null));
    expect(tester.getSemantics(find.byType(GenderGapScreen)), isNotNull);
    expect(find.byType(SituationGateCard), findsNWidgets(2));
    handle.dispose();
  });
}
