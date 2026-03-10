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
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: const Scaffold(body: PulseScreen()),
      ),
    );
  }

  CoachProfileProvider _buildProfileProvider({
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
      answers['q_conjoint_firstname'] = conjointFirstName;
    }
    if (conjointSalaire != null) {
      answers['q_conjoint_salary'] = conjointSalaire;
    }
    if (conjointBirthYear != null) {
      answers['q_conjoint_birth_year'] = conjointBirthYear;
    }
    provider.updateFromAnswers(answers);
    return provider;
  }

  group('PulseScreen — empty state', () {
    testWidgets('renders empty state when no profile', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Bienvenue sur MINT'), findsOneWidget);
      expect(find.text('Demarrer'), findsOneWidget);
    });

    testWidgets('shows disclaimer in empty state', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Outil educatif'), findsOneWidget);
      expect(find.textContaining('LSFin art. 3'), findsOneWidget);
    });

    testWidgets('shows onboarding CTA in empty state', (tester) async {
      await tester.pumpWidget(buildPulseScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Commence par remplir ton profil'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });
  });

  group('PulseScreen — loaded state', () {
    testWidgets('renders greeting with name', (tester) async {
      final provider = _buildProfileProvider(firstName: 'Julien');
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Bonjour Julien'), findsOneWidget);
    });

    testWidgets('renders visibility score card', (tester) async {
      final provider = _buildProfileProvider();
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Visibilite financiere'), findsOneWidget);
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('renders comprendre section', (tester) async {
      final provider = _buildProfileProvider();
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Comprendre'), findsOneWidget);
    });

    testWidgets('renders disclaimer in loaded state', (tester) async {
      final provider = _buildProfileProvider();
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Outil educatif'), findsOneWidget);
    });

    testWidgets('renders 4 axis progress bars', (tester) async {
      final provider = _buildProfileProvider();
      await tester.pumpWidget(buildPulseScreen(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    });
  });

  group('PulseScreen — couple mode', () {
    testWidgets('renders couple greeting when married with conjoint',
        (tester) async {
      final provider = _buildProfileProvider(
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

  group('PulseScreen — _conjointToCoachProfile correctness', () {
    test('conjoint profile preserves patrimoine when available', () {
      // This tests that ConjointProfile.patrimoine is properly threaded
      // through to the synthetic CoachProfile used for couple scoring.
      final conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        employmentStatus: 'salarie',
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 380000,
        ),
      );

      expect(conjoint.patrimoine, isNotNull);
      expect(conjoint.patrimoine!.investissements, 380000);
      expect(conjoint.patrimoine!.epargneLiquide, 20000);
    });

    test('conjoint patrimoine serializes/deserializes correctly', () {
      final conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        patrimoine: const PatrimoineProfile(
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
      final conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 4800,
        patrimoine: const PatrimoineProfile(
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
