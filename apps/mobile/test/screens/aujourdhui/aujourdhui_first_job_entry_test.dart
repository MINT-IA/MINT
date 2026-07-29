// PR-D (TRANCHE-FIRSTJOB-SPEC §1 T3 / §3.1) — /home mount smoke.
//
// Anti-facade proof: LifeEventSuggestionsSection had zero mount points
// (life_event_suggestions.dart:186). This pumps the REAL AujourdhuiScreen with
// a seeded 25-year-old profile and asserts the /home route anchor plus the
// firstJob card actually render — on BOTH render paths:
//   - empty timeline (the path a freshly-onboarded firstJob persona hits: no
//     commitments / landmarks / conversations -> _cards == [] -> isEmpty), and
//   - populated timeline (spec's post-timeline CustomScrollView location).
//
// Tall surface so the non-lazy post-timeline sliver is built (memory:
// lazy CustomScrollView breaks find; use a tall surface / scrollUntilVisible).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';

class _SeededProfileProvider extends CoachProfileProvider {
  _SeededProfileProvider(this._seed);
  final CoachProfile _seed;
  @override
  CoachProfile? get profile => _seed;
}

/// Deterministic timeline stand-in — no async service calls.
class _FakeTimeline extends TimelineProvider {
  _FakeTimeline({required this.empty});
  final bool empty;

  @override
  bool get isLoading => false;
  @override
  bool get isEmpty => empty;
  @override
  bool get hasNodes => false;
  @override
  bool get hasMore => false;
  @override
  List<TimelineMonth> get months => const [];
  @override
  CleoLoopPosition get loopPosition => CleoLoopPosition.insight;
  @override
  List<TensionCard> get cards => empty
      ? const []
      : const [
          TensionCard(
            type: TensionType.earned,
            title: 'tensionEarnedFirstConvo',
            subtitle: '',
            deepLink: '/coach/chat',
          ),
          TensionCard(
            type: TensionType.pulsing,
            title: 'tensionPulsingTalkToCoach',
            subtitle: '',
            deepLink: '/coach/chat',
          ),
          TensionCard(
            type: TensionType.ghosted,
            title: 'tensionGhostedFuture',
            subtitle: '',
            deepLink: '/coach/chat',
          ),
        ];

  @override
  Future<void> refresh() async {}
}

CoachProfile _firstJobProfile() {
  final now = DateTime.now();
  return CoachProfile(
    birthYear: now.year - 25, // age 25 -> firstJob card eligible (<= 28)
    canton: 'ZH',
    salaireBrutMensuel: 6500,
    employmentStatus: 'salarie',
    // firstJob requires a *provided* age (provenance gate).
    userProvidedFields: const {'age'},
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(now.year + 40),
      label: 'test',
    ),
  );
}

Finder _bySemanticsIdentifier(String identifier) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.identifier == identifier,
    );

Widget _harness({required bool emptyTimeline, required CoachProfile profile}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => _SeededProfileProvider(profile),
      ),
      ChangeNotifierProvider<TimelineProvider>(
        create: (_) => _FakeTimeline(empty: emptyTimeline),
      ),
      ChangeNotifierProvider<FinancialPlanProvider>(
        create: (_) => FinancialPlanProvider(),
      ),
      ChangeNotifierProvider<MintStateProvider>(
        create: (_) => MintStateProvider(),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: AujourdhuiScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('empty timeline — /home anchor + firstJob card render',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      _harness(emptyTimeline: true, profile: _firstJobProfile()),
    );
    await tester.pumpAndSettle();

    expect(_bySemanticsIdentifier('home_route_state'), findsOneWidget);
    expect(_bySemanticsIdentifier('home-lifeevent-card-firstJob'),
        findsOneWidget);
  });

  testWidgets('populated timeline — post-timeline firstJob card renders',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      _harness(emptyTimeline: false, profile: _firstJobProfile()),
    );
    // The populated path renders CleoLoopIndicator, whose looping animation
    // never settles — bounded pumps instead of pumpAndSettle. Two frames let
    // the post-frame refresh + first layout build the non-lazy sliver.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_bySemanticsIdentifier('home_route_state'), findsOneWidget);
    expect(_bySemanticsIdentifier('home-lifeevent-card-firstJob'),
        findsOneWidget);
  });

  testWidgets('no profile — no firstJob card, no dead section (D4)',
      (tester) async {
    useTallSurface(tester);
    // Default CoachProfileProvider -> profile null -> section suppressed.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<TimelineProvider>(
            create: (_) => _FakeTimeline(empty: true),
          ),
          ChangeNotifierProvider<FinancialPlanProvider>(
            create: (_) => FinancialPlanProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: AujourdhuiScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Home anchor still present; no firstJob entry without a profile.
    expect(_bySemanticsIdentifier('home_route_state'), findsOneWidget);
    expect(_bySemanticsIdentifier('home-lifeevent-card-firstJob'),
        findsNothing);
  });
}
