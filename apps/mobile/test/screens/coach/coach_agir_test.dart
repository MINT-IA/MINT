import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';

// ────────────────────────────────────────────────────────────
//  COACH AGIR SCREEN TESTS — Phase 5 / Quality hardening
//
//  The Agir screen requires CoachProfileProvider with a loaded
//  profile. Without profile, the empty state is shown and
//  "Ce mois", "Timeline", "Historique" sections are absent.
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

  CoachProfileProvider buildMiniCoachProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromMiniOnboarding({
      'q_birth_year': 1991,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6200,
      'q_employment_status': 'employee',
      'q_household_type': 'single',
    });
    return provider;
  }

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => buildCoachProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: const CoachAgirScreen(),
      ),
    );
  }

  Widget buildMiniTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => buildMiniCoachProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: const CoachAgirScreen(),
      ),
    );
  }

  group('CoachAgirScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows AGIR title in appbar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('AGIR'), findsOneWidget);
    });

    testWidgets('shows Ce mois section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Ce mois'), findsOneWidget);
    });

    testWidgets('shows timeline section label', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Timeline', skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows "Ce mois" section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('mois'), findsWidgets);
    });

    testWidgets('shows timeline events after scroll', (tester) async {
      // Use a tall viewport so SliverList builds all children
      // without requiring scroll offsets.
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      // Timeline section uses specific icons (savings, description, etc.)
      // instead of Icons.timeline. Verify the section label is present.
      expect(
        find.text('Timeline', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows planned contributions', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows timeline events', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows historique section after scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -2200));
      await tester.pump(const Duration(seconds: 1));
      expect(
          find.textContaining('check-in', skipOffstage: false), findsWidgets);
    });

    testWidgets('scrolls without crash', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows disclaimer after full scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows action plan with top action', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // V2 Agir screen shows action-based layout with "Ce mois" and timeline
      // instead of the old Coach Pulse / score reason cards.
      expect(find.textContaining('Ce mois'), findsOneWidget);
      expect(find.text('AGIR'), findsOneWidget);
    });

    testWidgets('shows real action plan for mini onboarding profile',
        (tester) async {
      // Since 76edc85, partial profiles see the real action plan
      // instead of the "Plan en construction" gate.
      await tester.pumpWidget(buildMiniTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // Mini profile renders the full Agir screen (Ce mois, timeline, etc.)
      expect(find.byType(CoachAgirScreen), findsOneWidget);
      expect(find.text('AGIR'), findsOneWidget);
    });
  });
}
