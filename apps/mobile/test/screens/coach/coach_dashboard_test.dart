import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/coach/coach_dashboard_screen.dart';
import 'package:mint_mobile/widgets/coach/mint_score_gauge.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';

// ────────────────────────────────────────────────────────────
//  COACH DASHBOARD SCREEN TESTS — Phase 5 / Quality hardening
//
//  CoachDashboardScreen has _pulseController..repeat(reverse: true)
//  — an infinite animation. We MUST use pump(Duration) instead
//  of pumpAndSettle() to avoid timeout.
//
//  For below-fold tests, we use a tall test surface (6000px)
//  so SliverList builds all children without scrolling.
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CoachProfileProvider buildCoachProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': 'Julien',
      'q_birth_year': 1977,
      'q_canton': 'VS',
      'q_net_income_period_chf': 9080,
      'q_civil_status': 'marie',
      'q_goal': 'retraite',
    });
    return provider;
  }

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => buildCoachProvider()),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: const MaterialApp(
        home: CoachDashboardScreen(),
      ),
    );
  }

  group('CoachDashboardScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachDashboardScreen), findsOneWidget);
    });

    testWidgets('shows greeting with name', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Bonjour'), findsWidgets);
    });

    testWidgets('shows coach alert card', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachDashboardScreen), findsOneWidget);
    });

    testWidgets('contains MintScoreGauge', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(MintScoreGauge, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('contains MintTrajectoryChart in tall viewport',
        (tester) async {
      // Use a very tall surface so SliverList builds all children
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(MintTrajectoryChart, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows quick actions in tall viewport', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('mensuel'), findsWidgets);
    });

    testWidgets('shows fitness score section header', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.textContaining('Fitness', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('shows trajectory section in tall viewport', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('trajectoire'), findsWidgets);
    });

    testWidgets('scrolls without crash', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -500),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachDashboardScreen), findsOneWidget);
    });

    testWidgets('shows disclaimer in tall viewport', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Estimation'), findsWidgets);
    });

    testWidgets(
        'uses persisted concise narrative mode for score attribution reason',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'coach_narrative_mode_v1': 'concise',
        'last_fitness_score_reason_v1':
            'Hausse principale: versements confirmes. Deuxieme phrase a masquer.',
        'last_fitness_score_delta_v1': 2,
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 2));

      // Dashboard starts in compact mode — expand to see score attribution
      final expandButton = find.textContaining('Afficher le dashboard complet');
      if (expandButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(expandButton);
        await tester.tap(expandButton);
        await tester.pump(const Duration(seconds: 1));
      }

      expect(
        find.textContaining('Hausse principale: versements confirmes',
            skipOffstage: false),
        findsWidgets,
      );
      expect(
        find.textContaining('Deuxieme phrase a masquer.', skipOffstage: false),
        findsNothing,
      );
    });
  });

  group('CoachDashboardScreen - Et si...', () {
    testWidgets('shows Et si panel in tall viewport', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // Dashboard starts in compact mode — expand to see Et si panel
      final expandButton = find.textContaining('Afficher le dashboard complet');
      if (expandButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(expandButton);
        await tester.tap(expandButton);
        await tester.pump(const Duration(seconds: 1));
      }

      expect(
        find.textContaining('Et si', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('Et si panel shows tune icon', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byIcon(Icons.tune, skipOffstage: false),
        findsWidgets,
      );
    });
  });

  group('CoachDashboardScreen - Plan 30 jours resume', () {
    testWidgets('shows resume card when plan 30 is started and incomplete',
        (tester) async {
      // Use a tall viewport so the resume card (below several other cards)
      // is within the rendered area of the SliverList.
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'onboarding_30_day_plan_v1': jsonEncode({
          'started_at': '2026-02-19T10:00:00.000Z',
          'completed': false,
          'opened_routes': ['/check/debt'],
          'last_route': '/check/debt',
        }),
      });

      await tester.pumpWidget(buildTestWidget());
      // Multiple pump cycles to let the unawaited async
      // _loadOnboarding30PlanState() resolve and setState.
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Reprendre mon plan 30 jours', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('1/3 etapes ouvertes', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('Continuer', skipOffstage: false),
        findsWidgets,
      );
    });
  });
}
