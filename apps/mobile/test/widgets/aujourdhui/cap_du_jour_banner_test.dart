/// Phase 97 W7 iter#3 (S001 fix) — widget test for the CapDuJourBanner
/// MintCardActionBar wiring.
///
/// Asserts the contract :
///   1. `Key('card_cap_du_jour')` is in the rendered widget tree (Maestro
///      assertVisible: { id: card_cap_du_jour } resolves)
///   2. `MintCardActionBar` is a descendant of `CapDuJourBanner`
///   3. The 3 verb labels (« Explique-moi » / « Simule » / « Rassure-moi »)
///      render
///   4. Tapping « Simule » triggers `context.push('/explore?simulate=
///      cap_du_jour')` (zero LLM call per CONTEXT D-06)
///
/// Per CONTEXT D-37, this is the DETERMINISTIC gate for the S001 fix
/// (the Maestro flow `bug__S001__cap_du_jour_action_bar_reachable.yaml`
/// LIVES in CI for future regression detection — it becomes runnable
/// end-to-end once Phase 97 W1 fragments / S003 deep-link / explicit
/// /home navigation from LandingScreen land).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/widgets/aujourdhui/cap_du_jour_banner.dart';
import 'package:mint_mobile/widgets/mint_card_action_bar.dart';

class _FakeCoachProfileProvider extends ChangeNotifier
    implements CoachProfileProvider {
  _FakeCoachProfileProvider(this._profile);
  final CoachProfile? _profile;

  @override
  CoachProfile? get profile => _profile;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMintStateProvider extends ChangeNotifier
    implements MintStateProvider {
  _FakeMintStateProvider(this._state);

  MintUserState? _state;
  int forceRecomputeCalls = 0;

  @override
  MintUserState? get state => _state;

  @override
  Future<void> forceRecompute(CoachProfile profile) async {
    forceRecomputeCalls += 1;
    final memory = await CapMemoryStore.load();
    _state = _state?.copyWith(profile: profile, capMemory: memory);
    notifyListeners();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SimulateRecorder {
  String? lastSimulatePath;
}

CoachProfile _profile() => CoachProfile(
      birthYear: 1980,
      canton: 'VD',
      salaireBrutMensuel: 8000,
      employmentStatus: 'salarie',
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );

const _cap = CapDecision(
  id: 'pillar_3a',
  kind: CapKind.optimize,
  priorityScore: 72,
  headline: 'Ton 3a peut encore réduire tes impôts',
  whyNow: 'La fenêtre fiscale de fin d’année est ouverte.',
  ctaLabel: 'Comparer mes options',
  ctaMode: CtaMode.route,
  ctaRoute: '/pilier-3a',
);

MintUserState _state({
  required CoachProfile profile,
  CapDecision? cap = _cap,
  CapMemory memory = const CapMemory(),
}) =>
    MintUserState(
      profile: profile,
      lifecyclePhase: LifecyclePhase.acceleration,
      archetype: FinancialArchetype.swissNative,
      currentCap: cap,
      confidenceScore: 72,
      capMemory: memory,
      computedAt: DateTime(2026, 6, 5),
    );

Widget _harness({
  required _SimulateRecorder recorder,
  CoachProfile? profile,
  _FakeMintStateProvider? mintStateProvider,
}) {
  final resolvedProfile = profile ?? _profile();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: CapDuJourBanner()),
      ),
      GoRoute(
        path: '/explore',
        builder: (_, state) {
          recorder.lastSimulatePath = '/explore?${state.uri.query}';
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
      GoRoute(
        path: '/coach/chat',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MintStateProvider>(
        create: (_) =>
            mintStateProvider ?? _FakeMintStateProvider(null),
      ),
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => _FakeCoachProfileProvider(resolvedProfile),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
    ),
  );
}

void main() {
  group('CapDuJourBanner — S001 MintCardActionBar wiring', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders root Key(card_cap_du_jour)', (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_cap_du_jour')), findsOneWidget);
    });

    testWidgets('card root carries Semantics(identifier: card_cap_du_jour)',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('card_cap_du_jour')),
      );
      expect(semantics.identifier, 'card_cap_du_jour');
    });

    testWidgets('MintCardActionBar is a descendant of CapDuJourBanner',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      final actionBar = find.descendant(
        of: find.byType(CapDuJourBanner),
        matching: find.byType(MintCardActionBar),
      );
      expect(actionBar, findsOneWidget);
    });

    testWidgets('action bar exposes Key(mint_card_action_bar)', (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mint_card_action_bar')), findsOneWidget);
    });

    testWidgets(
        'action bar carries Semantics(identifier: mint_card_action_bar)',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('mint_card_action_bar')),
      );
      expect(semantics.identifier, 'mint_card_action_bar');
    });

    testWidgets('renders 3 verb labels (Explique-moi, Simule, Rassure-moi)',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      expect(find.text('Explique-moi'), findsOneWidget);
      expect(find.text('Simule'), findsOneWidget);
      expect(find.text('Rassure-moi'), findsOneWidget);
    });

    testWidgets(
        'tapping « Simule » navigates to /explore?simulate=cap_du_jour',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      // Tap « Simule » verb chip (the middle verb, no LLM call per D-06).
      await tester.tap(find.text('Simule'));
      await tester.pumpAndSettle();

      expect(recorder.lastSimulatePath, isNotNull);
      expect(recorder.lastSimulatePath, '/explore?simulate=cap_du_jour');
    });

    testWidgets('tapping « Simule » records the visible cap as acknowledged',
        (tester) async {
      final recorder = _SimulateRecorder();
      final profile = _profile();
      final mintStateProvider = _FakeMintStateProvider(
        _state(profile: profile),
      );
      await tester.pumpWidget(_harness(
        recorder: recorder,
        profile: profile,
        mintStateProvider: mintStateProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simule'));
      await tester.pumpAndSettle();

      final memory = await CapMemoryStore.load();
      expect(memory.lastCapServed, 'pillar_3a');
      expect(memory.lastCapDate, isNotNull);
      expect(memory.completedActions, isEmpty);
      expect(memory.lastCompletedCapHeadline, isNull);
      expect(memory.lastCompletedCapCtaLabel, isNull);
      expect(mintStateProvider.forceRecomputeCalls, 1);
    });
  });
}
