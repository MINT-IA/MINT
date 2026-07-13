import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/widgets/coach/explore_hub.dart';
import 'package:mint_mobile/widgets/coach/low_confidence_card.dart';
import 'package:mint_mobile/widgets/coach/privacy_badge.dart';
import 'package:mint_mobile/widgets/coach/trajectory_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  REFONTE WIDGETS TESTS — Coach Dashboard Redesign
// ────────────────────────────────────────────────────────────
//
// Tests for the live coach dashboard widgets:
//   1. PrivacyBadge
//   2. ExploreHub
//   3. LowConfidenceCard
//   4. TrajectoryCard

/// Builds a MaterialApp wrapper with localization for widgets that use S.of().
Widget buildLocalizedApp({
  required Widget child,
  Locale locale = const Locale('fr'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

/// Builds a simple MaterialApp wrapper (no localization needed).
Widget buildSimpleApp({required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

Widget buildRoutedApp({
  required Widget child,
  required ValueChanged<Uri> onDataBlockRoute,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) {
          onDataBlockRoute(state.uri);
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
      GoRoute(
        path: '/scan',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/scan/avs-guide',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
  );
}

/// Creates a minimal CoachProfile (few data points for low confidence).
CoachProfile buildMinimalProfile() {
  return CoachProfile(
    firstName: 'Test',
    birthYear: 1990,
    canton: 'GE',
    salaireBrutMensuel: 5000,
    employmentStatus: 'salarie',
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 12, 31),
      label: 'Retraite',
    ),
  );
}

/// Creates a profile where the only high-impact visible gap is salary.
CoachProfile buildProfileMissingSalaryOnly() {
  return CoachProfile(
    firstName: 'Nina',
    birthYear: 1990,
    canton: 'GE',
    salaireBrutMensuel: 0,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.divorce,
    targetRetirementAge: 65,
    prevoyance: const PrevoyanceProfile(
      anneesContribuees: 20,
      avoirLppTotal: 180000,
      salaireAssure: 76000,
      tauxConversion: 0.055,
      nombre3a: 2,
      totalEpargne3a: 42000,
      canContribute3a: true,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 50000,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 12, 31),
      label: 'Retraite',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ══════════════════════════════════════════════════════════════
  //  1. PrivacyBadge
  // ══════════════════════════════════════════════════════════════

  group('PrivacyBadge', () {
    testWidgets('renders lock icon and text when SLM is active',
        (tester) async {
      await tester.pumpWidget(
        buildSimpleApp(child: const PrivacyBadge(isSlmActive: true)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.textContaining('100% on-device'), findsOneWidget);
    });

    testWidgets('is hidden (SizedBox.shrink) when SLM is inactive',
        (tester) async {
      await tester.pumpWidget(
        buildSimpleApp(child: const PrivacyBadge(isSlmActive: false)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.textContaining('100% on-device'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  2. ExploreHub
  // ══════════════════════════════════════════════════════════════

  group('ExploreHub', () {
    testWidgets('renders all 5 navigation row titles', (tester) async {
      await tester.pumpWidget(
        buildLocalizedApp(child: const ExploreHub()),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Mon profil'), findsOneWidget);
      expect(find.text('Rente vs capital'), findsOneWidget);
      expect(find.text('Coach & check-in'), findsOneWidget);
      expect(find.text('Scanner un document'), findsOneWidget);
      expect(find.text('Extrait AVS'), findsOneWidget);
    });

    testWidgets('shows chevron_right icons for each row', (tester) async {
      await tester.pumpWidget(
        buildLocalizedApp(child: const ExploreHub()),
      );
      await tester.pump(const Duration(seconds: 1));

      // 5 navigation rows should each have a chevron icon
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
    });

    testWidgets('shows Explorer title', (tester) async {
      await tester.pumpWidget(
        buildLocalizedApp(child: const ExploreHub()),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Explorer'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  3. LowConfidenceCard
  // ══════════════════════════════════════════════════════════════

  group('LowConfidenceCard', () {
    testWidgets('renders with minimal profile', (tester) async {
      final profile = buildMinimalProfile();
      await tester.pumpWidget(
        buildLocalizedApp(child: LowConfidenceCard(profile: profile)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LowConfidenceCard), findsOneWidget);
    });

    testWidgets('shows disclaimer text about conseil financier',
        (tester) async {
      final profile = buildMinimalProfile();
      await tester.pumpWidget(
        buildLocalizedApp(child: LowConfidenceCard(profile: profile)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('constitue pas un conseil financier'),
        findsOneWidget,
      );
    });

    testWidgets('shows info icon and header text', (tester) async {
      final profile = buildMinimalProfile();
      await tester.pumpWidget(
        buildLocalizedApp(child: LowConfidenceCard(profile: profile)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(
        find.textContaining('Pas assez de donn'),
        findsOneWidget,
      );
    });

    testWidgets('routes salary prompt to targeted revenue inputKey',
        (tester) async {
      Uri? capturedRoute;
      await tester.pumpWidget(
        buildRoutedApp(
          child: LowConfidenceCard(profile: buildProfileMissingSalaryOnly()),
          onDataBlockRoute: (uri) => capturedRoute = uri,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajoute ton salaire'));
      await tester.pumpAndSettle();

      expect(capturedRoute?.path, '/data-block/revenu');
      expect(capturedRoute?.queryParameters['inputKey'], 'salary');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  4. TrajectoryCard
  // ══════════════════════════════════════════════════════════════

  group('TrajectoryCard', () {
    late CoachProfile profile;
    late ProjectionResult projection;

    setUp(() {
      // ignore: deprecated_member_use
      profile = CoachProfile.buildDemo();
      projection = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
    });

    testWidgets('renders with valid projection', (tester) async {
      await tester.pumpWidget(
        buildLocalizedApp(
          child: TrajectoryCard(
            profile: profile,
            projection: projection,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TrajectoryCard), findsOneWidget);
    });

    testWidgets('shows trajectoire text', (tester) async {
      await tester.pumpWidget(
        buildLocalizedApp(
          child: TrajectoryCard(
            profile: profile,
            projection: projection,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // TrajectoryCard title + MintTrajectoryChart may both contain the word
      expect(find.textContaining('trajectoire'), findsWidgets);
    });
  });
}
