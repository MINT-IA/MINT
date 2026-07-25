import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// P2 « gate dur » — anti-façade contract for first_job_screen.
///
/// The screen has ONE output: the salary breakdown ([SalaryBreakdownWidget] +
/// the derived figures from [FirstJobService.analyzeSalary]). Every assertion is
/// on the RENDERED breakdown widget (its presence / its `netEstime` field) or on
/// the rendered [SituationGateCard], never on an internal bool. Each test goes
/// RED if the gate is removed (i.e. if the screen went back to auto-computing on
/// the fabricated defaults salaire 5000 / âge 25 / canton ZH).
///
/// The screen renders a lazy [CustomScrollView], so the result slot is only
/// inflated when it is inside the viewport. A tall test surface keeps it built
/// without scrolling.

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

/// birthYear 2001 → âge 25 (fenêtre premier emploi 18-30) au 2026.
CoachProfile _profile({
  int birthYear = 2001,
  String canton = 'GE',
  double salaire = 5500,
  Set<String> provided = const {},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    userProvidedFields: provided,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(WidgetTester tester, CoachProfileProvider provider) async {
  // Tall surface so the (lazy) result slot is inflated without scrolling.
  await tester.binding.setSurfaceSize(const Size(1200, 7000));
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
        home: FirstJobScreen(),
      ),
    ),
  );
  await tester.pump(); // build + postFrame (_readSequenceContext)
  await tester.pump(const Duration(milliseconds: 500)); // settle entrances
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(FirstJobScreen)) as dynamic;

MintPremiumSlider _slider(WidgetTester tester, double min, double max) => tester
    .widgetList<MintPremiumSlider>(find.byType(MintPremiumSlider))
    .firstWhere((s) => s.min == min && s.max == max);

Future<void> _touchSalaire(WidgetTester tester, double v) async {
  _slider(tester, 2000, 15000).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _touchAge(WidgetTester tester, double v) async {
  _slider(tester, 18, 30).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _touchTaux(WidgetTester tester, double v) async {
  _slider(tester, 10, 100).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _touchCanton(WidgetTester tester, String c) async {
  final dd = tester.widget<DropdownButton<String>>(
    find.byType(DropdownButton<String>).first,
  );
  dd.onChanged!(c);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

double _renderedNet(WidgetTester tester) => tester
    .widget<SalaryBreakdownWidget>(find.byType(SalaryBreakdownWidget))
    .netEstime;

/// The service output for the screen's CURRENT confirmed inputs.
FirstJobResult _expectedFor(WidgetTester tester, {double? taux}) {
  final st = _state(tester);
  return FirstJobService.analyzeSalary(
    salaireBrutMensuel: st.debugSalaire as double,
    age: st.debugAge as int,
    canton: st.debugCanton as String,
    tauxActivite: taux ?? st.debugTaux as double,
  );
}

void main() {
  // ── 1. No profile → breakdown gated, gate card lists all 3 facts ──
  testWidgets('no profile: breakdown gated, gate lists {salary, age, canton}',
      (tester) async {
    await _pump(tester, _FakeProvider(null));

    expect(find.byType(SalaryBreakdownWidget), findsNothing,
        reason: 'no breakdown may compute on fabricated defaults 5000/25/ZH');
    final gate =
        tester.widget<SituationGateCard>(find.byType(SituationGateCard));
    expect(gate.gate.missing.map((f) => f.key),
        containsAll(<String>['salary', 'age', 'canton']));
  });

  // ── 2. Seed all via keys → breakdown == analyzeSalary output ──
  testWidgets('seeded via keys: breakdown shows == FirstJobService output',
      (tester) async {
    await _pump(
      tester,
      _FakeProvider(_profile(
        birthYear: 2001, // âge 25
        canton: 'VD',
        salaire: 5500,
        provided: {'salary', 'age', 'canton'},
      )),
    );

    expect(find.byType(SituationGateCard), findsNothing,
        reason: 'every determinative fact is confirmed by its provenance key');
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget);
    expect(_renderedNet(tester), _expectedFor(tester).netEstime,
        reason: 'the rendered breakdown carries the service-computed net');
  });

  // ── 3. No profile, user touches every control → breakdown shows ──
  testWidgets('touched-all: confirmation via touch unlocks the breakdown',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _touchSalaire(tester, 6000);
    await _touchAge(tester, 26);
    await _touchCanton(tester, 'GE');

    expect(find.byType(SituationGateCard), findsNothing);
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget);
    expect(_renderedNet(tester), _expectedFor(tester).netEstime);
  });

  // ── 4. Two-notification race → canton confirms after the 2nd notify ──
  testWidgets('race: canton confirms on the 2nd notify (no global latch)',
      (tester) async {
    final fake = _MutableProvider();
    await _pump(tester, fake);
    expect(find.byType(SalaryBreakdownWidget), findsNothing,
        reason: 'nothing confirmed before hydration');

    // Notify #1 — salary + age keys, canton key ABSENT.
    fake.hydrate(_profile(canton: 'GE', provided: {'salary', 'age'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalaryBreakdownWidget), findsNothing,
        reason: 'canton not yet confirmed after the 1st notify');
    final gate1 =
        tester.widget<SituationGateCard>(find.byType(SituationGateCard));
    expect(gate1.gate.missing.map((f) => f.key), contains('canton'));

    // Notify #2 — adds the canton key. A global _seededFromProfile latch would
    // early-return here and strand canton, never revealing the breakdown.
    fake.hydrate(_profile(canton: 'GE', provided: {'salary', 'age', 'canton'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget,
        reason: 'canton confirms on the 2nd notify — latch is gone');
  });

  // ── 5a. Default-collision (key present) → identical numbers show ──
  // Values EQUAL the on-screen defaults (5000 / 25 / ZH) but the keys are
  // present → confirmed → breakdown shows.
  testWidgets('default-collision A: keys present → identical values show',
      (tester) async {
    await _pump(
      tester,
      _FakeProvider(_profile(
        birthYear: 2001, // âge 25 (défaut)
        canton: 'ZH', // canton défaut
        salaire: 5000, // salaire défaut
        provided: {'salary', 'age', 'canton'},
      )),
    );
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget,
        reason: 'values equal the defaults but their provenance keys confirm');
  });

  // ── 5b. Default-collision (no key) → same numbers stay gated ──
  // No profile: 5000 / 25 / ZH sit on screen as fabricated defaults, no
  // provenance → gated. Same pixels as 5a, opposite gate.
  testWidgets('default-collision B: no key → identical values stay gated',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    expect(find.byType(SalaryBreakdownWidget), findsNothing,
        reason: 'identical default values with no provenance stay gated');
    expect(find.byType(SituationGateCard), findsOneWidget);
  });

  // ── 6a. Scenario-param (tauxActivite) edit never bypasses the gate ──
  testWidgets('tauxActivite edit never fabricates a gated breakdown',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    expect(find.byType(SalaryBreakdownWidget), findsNothing);

    await _touchTaux(tester, 80); // scenario param, not a gated fact
    expect(find.byType(SalaryBreakdownWidget), findsNothing,
        reason: 'editing a scenario param must not compute on fabricated facts');
    expect(find.byType(SituationGateCard), findsOneWidget);
  });

  // ── 6b. Edits (situation + tauxActivite) refresh the figure — never stale ──
  testWidgets('situation & tauxActivite edits keep the figure fresh, not stale',
      (tester) async {
    await _pump(
      tester,
      _FakeProvider(_profile(
        canton: 'GE',
        salaire: 5500,
        provided: {'salary', 'age', 'canton'},
      )),
    );
    final net0 = _renderedNet(tester);

    // Situation edit: change salaire → the figure tracks the new input.
    await _touchSalaire(tester, 9000);
    final netAfterSalaire = _renderedNet(tester);
    expect(netAfterSalaire, isNot(net0),
        reason: 'a situation edit must recompute, not show a stale figure');
    expect(netAfterSalaire, _expectedFor(tester).netEstime);

    // Scenario edit: change tauxActivite → the figure refreshes too.
    await _touchTaux(tester, 50);
    expect(_renderedNet(tester), _expectedFor(tester, taux: 50).netEstime,
        reason: 'tauxActivite feeds analyzeSalary → figure refreshes');
  });

  // ── 7. Profile cleared while mounted → seeded breakdown vanishes ──
  testWidgets('clearing the profile re-gates a purely-seeded breakdown',
      (tester) async {
    final fake = _MutableProvider();
    await _pump(tester, fake);
    fake.hydrate(_profile(
      canton: 'GE',
      salaire: 5500,
      provided: {'salary', 'age', 'canton'},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget);

    // Logout / account reset while mounted: seeded provenance disappears.
    fake.clearProfile();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalaryBreakdownWidget), findsNothing,
        reason: 'seeded facts lose provenance on clear → breakdown re-gates');
    expect(find.byType(SituationGateCard), findsOneWidget);
  });

  // ── 8. Touched facts are user data → immune to a profile clear ──
  testWidgets('a breakdown built purely on TOUCHED facts survives a clear',
      (tester) async {
    final fake = _MutableProvider();
    await _pump(tester, fake);
    await _touchSalaire(tester, 6000);
    await _touchAge(tester, 27);
    await _touchCanton(tester, 'GE');
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget);

    fake.clearProfile();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget,
        reason: 'touched facts are local user data, immune to a profile clear');
  });

  // ── 8b. Seed → touch → clear: the touched value survives (seed superseded) ─
  testWidgets('seed then touch then clear: touched supersedes seed, survives',
      (tester) async {
    final fake = _MutableProvider();
    await _pump(tester, fake);
    fake.hydrate(_profile(
      canton: 'VD',
      salaire: 5500,
      provided: {'salary', 'age', 'canton'},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget);

    // The user touches every control (supersedes the seed).
    await _touchSalaire(tester, 7000);
    await _touchAge(tester, 28);
    await _touchCanton(tester, 'GE');
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget);

    fake.clearProfile();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget,
        reason: 'touched (seed superseded) → survives the clear');
  });

  // ── Return contract: the gate must not turn a real interaction into an
  //    abandoned return (Codex regression finding on the scenario chip). ──
  group('First Job return contract', () {
    testWidgets('selecting a salary scenario counts as interaction → completed',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      // All three facts SEEDED (keys) → gate complete, result + scenario chips
      // render, but the user has TOUCHED nothing yet (_hasUserInteracted false).
      final profile = _profile(
        canton: 'GE',
        salaire: 5500,
        provided: {'salary', 'age', 'canton'},
      );
      await _pump(tester, _FakeProvider(profile));

      final state = tester.state(find.byType(FirstJobScreen)) as dynamic;
      expect(state.debugHasUserInteracted, isFalse,
          reason: 'seeded, not touched — no interaction yet');
      expect(find.byType(SalaryBreakdownWidget), findsOneWidget,
          reason: 'all facts seeded → result (and scenario chips) render');

      // Choose the "Médian CH" salary scenario chip (changes salary by touch).
      await tester.tap(find.textContaining('Médian CH'));
      await tester.pumpAndSettle();

      expect(state.debugHasUserInteracted, isTrue,
          reason: 'choosing a salary scenario is a real user interaction');
      expect(find.byType(SalaryBreakdownWidget), findsOneWidget,
          reason: 'still complete after the scenario touch');

      // The routed final return must be completed, never abandoned.
      state.debugEmitFinalReturn(runId: 'r1', stepId: 's1');
      await tester.pumpAndSettle();
      expect(await ScreenCompletionTracker.lastOutcome('first_job'),
          ScreenOutcome.completed,
          reason: 'interacted → completed, not abandoned');
    });

    testWidgets('no interaction → abandoned (contract still honored)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, _FakeProvider(null));
      final state = tester.state(find.byType(FirstJobScreen)) as dynamic;
      state.debugEmitFinalReturn(runId: 'r2', stepId: 's2');
      await tester.pumpAndSettle();
      expect(await ScreenCompletionTracker.lastOutcome('first_job'),
          ScreenOutcome.abandoned);
    });
  });
}
