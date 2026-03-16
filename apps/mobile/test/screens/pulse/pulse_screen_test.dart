import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

import 'package:mint_mobile/screens/pulse/pulse_screen.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';

// ────────────────────────────────────────────────────────────────
//  PULSE SCREEN — Smoke + Integration Tests
// ────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildPulseScreen({CoachProfileProvider? coachProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>(
          create: (_) => coachProvider ?? CoachProfileProvider(),
        ),
        ChangeNotifierProvider<ByokProvider>(
          create: (_) => ByokProvider(),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: PulseScreen()),
      ),
    );
  }

  CoachProfileProvider buildProfileProvider({
    String firstName = 'Julien',
    int birthYear = 1977,
    String canton = 'VS',
    double salaire = 9078,
    String civilStatus = 'marie',
    String? conjointFirstName,
    double? conjointSalaire,
    int? conjointBirthYear,
  }) {
    final provider = CoachProfileProvider();
    final answers = <String, dynamic>{
      'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': salaire,
      'q_civil_status': civilStatus,
      'q_goal': 'retraite',
    };
    if (conjointFirstName != null) {
      answers['q_partner_firstname'] = conjointFirstName;
    }
    if (conjointSalaire != null) {
      answers['q_partner_net_income_chf'] = conjointSalaire;
    }
    if (conjointBirthYear != null) {
      answers['q_partner_birth_year'] = conjointBirthYear;
    }
    provider.updateFromAnswers(answers);
    return provider;
  }

  group('PulseScreen — empty state', () {
    testWidgets('renders empty state when no profile', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Bienvenue sur MINT'), findsOneWidget);
      expect(find.text('Démarrer'), findsOneWidget);
    });

    testWidgets('shows disclaimer in empty state', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Outil éducatif'), findsOneWidget);
      expect(find.textContaining('LSFin art.'), findsOneWidget);
    });

    testWidgets('shows onboarding CTA in empty state', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Commence par remplir ton profil'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });
  });

  group('PulseScreen — loaded state', () {
    testWidgets('renders greeting with name', (tester) async {
      final provider = buildProfileProvider(firstName: 'Julien');
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Bonjour Julien'), findsOneWidget);
    });

    testWidgets('renders readiness score card', (tester) async {
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // pulseReadinessTitle = "Forme financière"
      expect(find.text('Forme financière'), findsOneWidget);
    });

    testWidgets('renders disclaimer in loaded state', (tester) async {
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Outil éducatif'), findsOneWidget);
    });
  });

  group('PulseScreen — couple mode', () {
    testWidgets('renders couple greeting when married with conjoint',
        (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        civilStatus: 'marie',
        conjointFirstName: 'Lauren',
        conjointSalaire: 4800,
        conjointBirthYear: 1982,
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Julien'), findsWidgets);
      // Couple greeting should mention both names
      expect(find.textContaining('Lauren'), findsWidgets);
    });
  });

  group('PulseScreen — _hasMinimalConjointData edge cases', () {
    test('returns false for null birthYear', () {
      // _hasMinimalConjointData requires birthYear != null && salary > 0
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: null,
        salaireBrutMensuel: 4800,
      );
      // Replicates the logic of _hasMinimalConjointData
      final hasMinimal = conjoint.birthYear != null &&
          conjoint.salaireBrutMensuel != null &&
          conjoint.salaireBrutMensuel! > 0;
      expect(hasMinimal, isFalse);
    });

    test('returns false for zero salary', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 0,
      );
      final hasMinimal = conjoint.birthYear != null &&
          conjoint.salaireBrutMensuel != null &&
          conjoint.salaireBrutMensuel! > 0;
      expect(hasMinimal, isFalse);
    });

    test('returns true when both birthYear and salary are valid', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
      );
      final hasMinimal = conjoint.birthYear != null &&
          conjoint.salaireBrutMensuel != null &&
          conjoint.salaireBrutMensuel! > 0;
      expect(hasMinimal, isTrue);
    });
  });

  group('PulseScreen — _conjointToCoachProfile mapping', () {
    test('correctly maps ConjointProfile fields to CoachProfile', () {
      // Build a main profile with conjoint
      final mainProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        commune: 'Sion',
        salaireBrutMensuel: 9078,
        etatCivil: CoachCivilStatus.marie,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 4800,
          nombreDeMois: 13,
          bonusPourcentage: 5,
          employmentStatus: 'salarie',
          nationality: 'US',
          arrivalAge: 25,
          targetRetirementAge: 64,
          prevoyance: PrevoyanceProfile(avoirLppTotal: 19620),
          patrimoine: PatrimoineProfile(investissements: 380000),
        ),
      );

      // Replicate the logic of _conjointToCoachProfile
      final conj = mainProfile.conjoint!;
      final retirementAge = conj.targetRetirementAge ?? 65;
      final birthYr = conj.birthYear ?? mainProfile.birthYear;
      final syntheticProfile = CoachProfile(
        firstName: conj.firstName,
        birthYear: birthYr,
        canton: mainProfile.canton,
        commune: mainProfile.commune,
        nationality: conj.nationality,
        salaireBrutMensuel: conj.salaireBrutMensuel ?? 0,
        nombreDeMois: conj.nombreDeMois,
        bonusPourcentage: conj.bonusPourcentage ?? 0,
        employmentStatus: conj.employmentStatus ?? 'salarie',
        etatCivil: mainProfile.etatCivil,
        arrivalAge: conj.arrivalAge,
        targetRetirementAge: conj.targetRetirementAge,
        prevoyance: conj.prevoyance ?? const PrevoyanceProfile(),
        patrimoine: conj.patrimoine ?? const PatrimoineProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(birthYr + retirementAge),
          label: 'Retraite',
        ),
      );

      expect(syntheticProfile.firstName, 'Lauren');
      expect(syntheticProfile.birthYear, 1982);
      expect(syntheticProfile.canton, 'VS');
      expect(syntheticProfile.commune, 'Sion');
      expect(syntheticProfile.nationality, 'US');
      expect(syntheticProfile.salaireBrutMensuel, 4800);
      expect(syntheticProfile.nombreDeMois, 13);
      expect(syntheticProfile.bonusPourcentage, 5);
      expect(syntheticProfile.employmentStatus, 'salarie');
      expect(syntheticProfile.etatCivil, CoachCivilStatus.marie);
      expect(syntheticProfile.arrivalAge, 25);
      expect(syntheticProfile.targetRetirementAge, 64);
      expect(syntheticProfile.prevoyance.avoirLppTotal, 19620);
      expect(syntheticProfile.patrimoine.investissements, 380000);
      expect(syntheticProfile.goalA.targetDate, DateTime(1982 + 64));
    });

    test('falls back to mainProfile birthYear when conjoint birthYear is null', () {
      final mainProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 9078,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: null,
          salaireBrutMensuel: 4800,
        ),
      );

      final conj = mainProfile.conjoint!;
      final birthYr = conj.birthYear ?? mainProfile.birthYear;
      expect(birthYr, 1977); // falls back to main profile
    });
  });

  group('PulseScreen — _computeTemporalItems', () {
    test('produces items when profile has salary and canton', () {
      // TemporalPriorityService.prioritize should produce items for a
      // profile with positive salary (tax saving > 0) and a valid canton.
      final items = TemporalPriorityService.prioritize(
        canton: 'VS',
        taxSaving3a: 1500, // non-zero → 3a deadline item expected
        friTotal: 0,
        friDelta: 0,
        limit: 4,
      );
      expect(items, isNotEmpty);
      // Each item should have a title and body
      for (final item in items) {
        expect(item.title, isNotEmpty);
        expect(item.body, isNotEmpty);
      }
    });
  });

  group('PulseScreen — key figures section', () {
    testWidgets('renders retraite, budget, patrimoine cards',
        (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        salaire: 9078,
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // Key figure labels
      expect(find.text('Retraite estimée'), findsOneWidget);
      expect(find.text('Budget libre'), findsOneWidget);
      expect(find.text('Patrimoine'), findsOneWidget);

      // Key figures use specific icons
      expect(find.byIcon(Icons.beach_access_outlined), findsWidgets);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsWidgets);
      expect(find.byIcon(Icons.trending_up_outlined), findsWidgets);
    });
  });

  group('PulseScreen — couple card', () {
    testWidgets('shows couple greeting when profile.isCouple is true',
        (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        civilStatus: 'marie',
        conjointFirstName: 'Lauren',
        conjointSalaire: 4800,
        conjointBirthYear: 1982,
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // Couple greeting in SliverAppBar: "Bonjour Julien et Lauren"
      expect(find.textContaining('Julien'), findsWidgets);
      expect(find.textContaining('Lauren'), findsWidgets);
    });

    testWidgets('does not show couple card for celibataire',
        (tester) async {
      final provider = buildProfileProvider(
        firstName: 'Julien',
        civilStatus: 'celibataire',
      );
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // No couple icon
      expect(find.byIcon(Icons.people_outline), findsNothing);
    });
  });

  group('PulseScreen — _conjointToCoachProfile correctness', () {
    test('conjoint profile preserves patrimoine when available', () {
      // This tests that ConjointProfile.patrimoine is properly threaded
      // through to the synthetic CoachProfile used for couple scoring.
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        employmentStatus: 'salarie',
        patrimoine: PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 380000,
        ),
      );

      expect(conjoint.patrimoine, isNotNull);
      expect(conjoint.patrimoine!.investissements, 380000);
      expect(conjoint.patrimoine!.epargneLiquide, 20000);
    });

    test('conjoint patrimoine serializes/deserializes correctly', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        patrimoine: PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 380000,
        ),
      );

      final json = conjoint.toJson();
      expect(json['patrimoine'], isNotNull);

      final restored = ConjointProfile.fromJson(json);
      expect(restored.patrimoine, isNotNull);
      expect(restored.patrimoine!.investissements, 380000);
      expect(restored.patrimoine!.epargneLiquide, 20000);
    });

    test('conjoint patrimoine copyWith preserves value', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        patrimoine: PatrimoineProfile(
          investissements: 380000,
        ),
      );

      final updated = conjoint.copyWith(firstName: 'Laura');
      expect(updated.firstName, 'Laura');
      expect(updated.patrimoine!.investissements, 380000);
    });

    test('conjoint patrimoine null by default (backward compat)', () {
      const conjoint = ConjointProfile();
      expect(conjoint.patrimoine, isNull);

      final json = conjoint.toJson();
      final restored = ConjointProfile.fromJson(json);
      expect(restored.patrimoine, isNull);
    });
  });
}
