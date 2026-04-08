import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/widgets/coach/premier_eclairage_section.dart';
import 'package:mint_mobile/widgets/coach/early_retirement_comparison.dart';
import 'package:mint_mobile/widgets/coach/explore_hub.dart';
import 'package:mint_mobile/widgets/coach/low_confidence_card.dart';
import 'package:mint_mobile/widgets/coach/privacy_badge.dart';
import 'package:mint_mobile/widgets/coach/trajectory_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  REFONTE WIDGETS TESTS — Coach Dashboard Redesign
// ────────────────────────────────────────────────────────────
//
// Tests for 6 new coach widgets:
//   1. PrivacyBadge
//   2. ExploreHub
//   3. LowConfidenceCard
//   4. EarlyRetirementComparison
//   5. PremierEclairageSection
//   6. TrajectoryCard

/// Builds a MaterialApp wrapper with localization for widgets that use S.of().
Widget buildLocalizedApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('fr'),
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

/// Creates a CoachProfile for a 51-year-old (age >= 45) with LPP capital.
CoachProfile buildOlderProfile() {
  return CoachProfile(
    firstName: 'Marie',
    birthYear: 1975,
    canton: 'VD',
    salaireBrutMensuel: 8046, // ~7000 net / 0.87
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 250000,
      rachatMaximum: 80000,
      rachatEffectue: 0,
      tauxConversion: 0.068,
      rendementCaisse: 0.02,
      nombre3a: 1,
      totalEpargne3a: 20000,
      canContribute3a: true,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2040, 12, 31),
      label: 'Retraite a 65 ans',
    ),
  );
}

/// Creates a CoachProfile for a 28-year-old (age < 45).
CoachProfile buildYoungerProfile() {
  return CoachProfile(
    firstName: 'Lucas',
    birthYear: 1998,
    canton: 'ZH',
    salaireBrutMensuel: 5747, // ~5000 net / 0.87
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2063, 12, 31),
      label: 'Retraite a 65 ans',
    ),
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

/// Creates a profile with 3a gap and LPP buyback potential for shock cards.
CoachProfile buildProfileWith3aGap() {
  return CoachProfile(
    firstName: 'Sophie',
    birthYear: 1985,
    canton: 'VD',
    salaireBrutMensuel: 8000,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 150000,
      rachatMaximum: 100000,
      rachatEffectue: 0,
      nombre3a: 1,
      totalEpargne3a: 10000,
      canContribute3a: true,
      lacunesAVS: 3,
    ),
    // No 3a contribution planned → will trigger the 3a gap card
    plannedContributions: const [],
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050, 12, 31),
      label: 'Retraite a 65 ans',
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
        buildSimpleApp(child: LowConfidenceCard(profile: profile)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LowConfidenceCard), findsOneWidget);
    });

    testWidgets('shows disclaimer text about conseil financier',
        (tester) async {
      final profile = buildMinimalProfile();
      await tester.pumpWidget(
        buildSimpleApp(child: LowConfidenceCard(profile: profile)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('ne constitue pas un conseil financier'),
        findsOneWidget,
      );
    });

    testWidgets('shows info icon and header text', (tester) async {
      final profile = buildMinimalProfile();
      await tester.pumpWidget(
        buildSimpleApp(child: LowConfidenceCard(profile: profile)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(
        find.textContaining('Pas assez de donn'),
        findsOneWidget,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  4. EarlyRetirementComparison
  // ══════════════════════════════════════════════════════════════

  group('EarlyRetirementComparison', () {
    testWidgets('is hidden when profile age < 45', (tester) async {
      final youngProfile = buildYoungerProfile();
      await tester.pumpWidget(
        buildSimpleApp(
          child: EarlyRetirementComparison(profile: youngProfile),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Should render nothing (SizedBox.shrink)
      expect(find.textContaining('Comparaison retraite'), findsNothing);
    });

    testWidgets('shows comparison table when age >= 45', (tester) async {
      final olderProfile = buildOlderProfile();
      await tester.pumpWidget(
        buildSimpleApp(
          child: EarlyRetirementComparison(profile: olderProfile),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Comparaison retraite'),
        findsOneWidget,
      );
    });

    testWidgets('shows Age and Taux column headers when age >= 45',
        (tester) async {
      final olderProfile = buildOlderProfile();
      await tester.pumpWidget(
        buildSimpleApp(
          child: EarlyRetirementComparison(profile: olderProfile),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Taux'), findsOneWidget);
      expect(find.text('Revenu mensuel'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  5. PremierEclairageSection
  // ══════════════════════════════════════════════════════════════

  group('PremierEclairageSection', () {
    testWidgets('renders with profile that has 3a gap and LPP buyback',
        (tester) async {
      final profile = buildProfileWith3aGap();
      await tester.pumpWidget(
        buildLocalizedApp(
          child: PremierEclairageSection(
            profile: profile,
            narratives: const {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Should show the section title
      expect(find.textContaining('chiffres-chocs'), findsOneWidget);
    });

    testWidgets('shows nothing when profile has no gaps', (tester) async {
      // Profile with maxed-out 3a, no LPP buyback, no AVS gap
      final fullProfile = CoachProfile(
        firstName: 'Jean',
        birthYear: 1985,
        canton: 'ZH',
        salaireBrutMensuel: 8000,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          rachatMaximum: 0, // no buyback available
          rachatEffectue: 0,
          nombre3a: 1,
          totalEpargne3a: 50000,
          canContribute3a: true,
          lacunesAVS: 0, // no AVS gap
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a',
            label: '3a',
            amount: 604.83, // maxing 3a (7258/12)
            category: '3a',
          ),
        ],
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050, 12, 31),
          label: 'Retraite',
        ),
      );

      await tester.pumpWidget(
        buildLocalizedApp(
          child: PremierEclairageSection(
            profile: fullProfile,
            narratives: const {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // No shock cards should be shown
      expect(find.textContaining('chiffres-chocs'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  6. TrajectoryCard
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
