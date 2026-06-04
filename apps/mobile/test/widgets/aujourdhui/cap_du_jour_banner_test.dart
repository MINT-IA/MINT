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

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
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
  @override
  MintUserState? get state => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SimulateRecorder {
  String? lastSimulatePath;
}

Widget _harness({required _SimulateRecorder recorder}) {
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
        create: (_) => _FakeMintStateProvider(),
      ),
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => _FakeCoachProfileProvider(null),
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
  });
}
