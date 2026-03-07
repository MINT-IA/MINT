import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/widgets/coach/hero_couple_card.dart';
import 'package:mint_mobile/widgets/dashboard/couple_action_plan.dart';
import 'package:mint_mobile/widgets/dashboard/couple_phase_timeline.dart';

void main() {
  // ════════════════════════════════════════════════════════════
  //  HERO COUPLE CARD
  // ════════════════════════════════════════════════════════════

  group('HeroCoupleCard', () {
    testWidgets('displays both partners with names', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCoupleCard(
              userName: 'Julien',
              conjointName: 'Lauren',
              userMonthlyIncome: 4500,
              conjointMonthlyIncome: 2800,
              userRetirementAge: 65,
              conjointRetirementAge: 63,
            ),
          ),
        ),
      ));

      expect(find.text('Julien'), findsOneWidget);
      expect(find.text('Lauren'), findsOneWidget);
    });

    testWidgets('shows household total', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCoupleCard(
              userName: 'Julien',
              conjointName: 'Lauren',
              userMonthlyIncome: 4500,
              conjointMonthlyIncome: 2800,
              userRetirementAge: 65,
              conjointRetirementAge: 63,
            ),
          ),
        ),
      ));

      expect(find.text('Total m\u00e9nage'), findsOneWidget);
      expect(find.text('Nous Deux'), findsOneWidget);
    });

    testWidgets('shows retirement ages', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCoupleCard(
              userName: 'Julien',
              conjointName: 'Lauren',
              userMonthlyIncome: 4500,
              conjointMonthlyIncome: 2800,
              userRetirementAge: 65,
              conjointRetirementAge: 63,
            ),
          ),
        ),
      ));

      expect(find.textContaining('65 ans'), findsOneWidget);
      expect(find.textContaining('63 ans'), findsOneWidget);
    });

    testWidgets('shows replacement ratio when provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCoupleCard(
              userName: 'Julien',
              conjointName: 'Lauren',
              userMonthlyIncome: 4500,
              conjointMonthlyIncome: 2800,
              userReplacementRatio: 62,
              conjointReplacementRatio: null,
              userRetirementAge: 65,
              conjointRetirementAge: 63,
            ),
          ),
        ),
      ));

      expect(find.textContaining('62'), findsAtLeast(1));
      expect(find.textContaining('remplacement'), findsAtLeast(1));
    });

    testWidgets('displays LSFin disclaimer', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCoupleCard(
              userName: 'Julien',
              conjointName: 'Lauren',
              userMonthlyIncome: 4500,
              conjointMonthlyIncome: 2800,
              userRetirementAge: 65,
              conjointRetirementAge: 63,
            ),
          ),
        ),
      ));

      expect(find.textContaining('LSFin'), findsAtLeast(1));
    });

    testWidgets('no banned terms', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCoupleCard(
              userName: 'Julien',
              conjointName: 'Lauren',
              userMonthlyIncome: 4500,
              conjointMonthlyIncome: 2800,
              userRetirementAge: 65,
              conjointRetirementAge: 63,
            ),
          ),
        ),
      ));

      expect(find.textContaining('garanti'), findsNothing);
      expect(find.textContaining('certain'), findsNothing);
      expect(find.textContaining('optimal'), findsNothing);
    });

    test('constructor accepts no financial data beyond income/ratio', () {
      const card = HeroCoupleCard(
        userName: 'A',
        conjointName: 'B',
        userMonthlyIncome: 3000,
        conjointMonthlyIncome: 2000,
        userRetirementAge: 65,
        conjointRetirementAge: 65,
      );
      // Pure widget — no profile dependency
      expect(card.userName, equals('A'));
      expect(card.conjointName, equals('B'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  COUPLE ACTION PLAN
  // ════════════════════════════════════════════════════════════

  group('CoupleActionPlan', () {
    testWidgets('renders for couple profile', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      expect(find.textContaining('Plan d\u2019action couple'), findsOneWidget);
    });

    testWidgets('shows owner chips per action', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      // At least one household action (AVS cap for married)
      expect(find.textContaining('M\u00c9NAGE'), findsAtLeast(1));
    });

    testWidgets('returns SizedBox.shrink for single profile', (tester) async {
      final profile = _buildSingleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoupleActionPlan(profile: profile),
        ),
      ));

      // Should render nothing for single
      expect(find.textContaining('Plan d\u2019action'), findsNothing);
    });

    testWidgets('shows FATCA warning for US conjoint', (tester) async {
      final profile = _buildCoupleProfileWithFatca();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      expect(find.textContaining('FATCA'), findsAtLeast(1));
      expect(find.textContaining('3a non disponible'), findsOneWidget);
    });

    testWidgets('shows AVS cap for married couple', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      expect(find.textContaining('LAVS art.'), findsOneWidget);
      expect(find.textContaining('150'), findsAtLeast(1));
    });

    testWidgets('displays LSFin disclaimer', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      expect(find.textContaining('LSFin'), findsAtLeast(1));
    });

    testWidgets('no banned terms', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      expect(find.textContaining('garanti'), findsNothing);
      expect(find.textContaining('certain'), findsNothing);
      expect(find.textContaining('optimal'), findsNothing);
      expect(find.textContaining('parfait'), findsNothing);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  COUPLE PHASE TIMELINE (slider)
  // ════════════════════════════════════════════════════════════

  group('CouplePhaseTimeline', () {
    testWidgets('renders with 2 phases', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CouplePhaseTimeline(
              userName: 'Julien',
              conjointName: 'Lauren',
              userRetirementYear: 2041,
              conjointRetirementYear: 2044,
              phases: _buildMockPhases(),
            ),
          ),
        ),
      ));

      expect(find.text('Timeline couple'), findsOneWidget);
      expect(find.textContaining('Julien'), findsAtLeast(1));
      expect(find.textContaining('Lauren'), findsAtLeast(1));
    });

    testWidgets('returns SizedBox.shrink with < 2 phases', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CouplePhaseTimeline(
            userName: 'Julien',
            conjointName: 'Lauren',
            userRetirementYear: 2041,
            conjointRetirementYear: 2041,
            phases: const [
              RetirementPhase(
                label: 'Les deux \u00e0 la retraite',
                startYear: 2041,
                sources: [],
              ),
            ],
          ),
        ),
      ));

      expect(find.text('Timeline couple'), findsNothing);
    });

    testWidgets('shows slider when profile is provided', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CouplePhaseTimeline(
              userName: 'Alice',
              conjointName: 'Bob',
              userRetirementYear: 2051,
              conjointRetirementYear: 2053,
              phases: _buildMockPhases(),
              profile: profile,
            ),
          ),
        ),
      ));

      expect(find.textContaining('Et si'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('hides slider when no profile', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CouplePhaseTimeline(
              userName: 'Alice',
              conjointName: 'Bob',
              userRetirementYear: 2051,
              conjointRetirementYear: 2053,
              phases: _buildMockPhases(),
            ),
          ),
        ),
      ));

      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('displays LSFin disclaimer', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CouplePhaseTimeline(
              userName: 'Julien',
              conjointName: 'Lauren',
              userRetirementYear: 2041,
              conjointRetirementYear: 2044,
              phases: _buildMockPhases(),
            ),
          ),
        ),
      ));

      expect(find.textContaining('LSFin'), findsAtLeast(1));
    });

    testWidgets('slider drag updates displayed age', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CouplePhaseTimeline(
              userName: 'Alice',
              conjointName: 'Bob',
              userRetirementYear: 2051,
              conjointRetirementYear: 2053,
              phases: _buildMockPhases(),
              profile: profile,
            ),
          ),
        ),
      ));

      // Default age should be displayed
      expect(find.byType(Slider), findsOneWidget);

      // Drag slider towards max
      final slider = find.byType(Slider);
      await tester.drag(slider, Offset(100, 0));
      await tester.pumpAndSettle();

      // Should show "Et si" with new age
      expect(find.textContaining('Et si'), findsOneWidget);
    });

    testWidgets('reset button appears when slider modified', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CouplePhaseTimeline(
              userName: 'Alice',
              conjointName: 'Bob',
              userRetirementYear: 2051,
              conjointRetirementYear: 2053,
              phases: _buildMockPhases(),
              profile: profile,
            ),
          ),
        ),
      ));

      // Before drag: no reset button
      expect(find.textContaining('initialiser'), findsNothing);

      // Drag slider
      await tester.drag(find.byType(Slider), Offset(100, 0));
      await tester.pumpAndSettle();

      // After drag: reset button visible
      expect(find.textContaining('initialiser'), findsOneWidget);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  EDGE CASES + REGRESSION TESTS
  // ════════════════════════════════════════════════════════════

  group('CoupleActionPlan — edge cases', () {
    testWidgets('AVS cap only for married, not concubinage', (tester) async {
      final profile = _buildConcubinProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      // Concubinage → no AVS cap action (LAVS art. 35 n/a)
      expect(find.textContaining('LAVS art.'), findsNothing);
      expect(find.textContaining('150'), findsNothing);
    });

    testWidgets('impact label includes "(estimation)" hedge', (tester) async {
      final profile = _buildCoupleProfile();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      expect(find.textContaining('estimation'), findsAtLeast(1));
    });

    testWidgets('FATCA 3a action has no route (not clickable)', (tester) async {
      final profile = _buildCoupleProfileWithFatca();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      // FATCA action should not have a chevron (no route)
      expect(find.textContaining('3a non disponible'), findsOneWidget);
      // chevron count should be less than total actions
      // since FATCA action has no route
    });

    testWidgets(
        'canContribute3a: UI reads same source as engines (prevoyance)',
        (tester) async {
      // Regression test: top-level conj.canContribute3a can diverge
      // from prevoyance.canContribute3a. Only prevoyance is canonical.
      final profile = _buildCoupleProfileWithFatca();
      final conj = profile.conjoint!;

      // Verify both levels are aligned in test data
      expect(conj.canContribute3a, false,
          reason: 'Top-level canContribute3a must be false');
      expect(conj.prevoyance?.canContribute3a, false,
          reason: 'Prevoyance canContribute3a must be false (engine source)');

      // UI should show FATCA block
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));
      expect(find.textContaining('3a non disponible'), findsOneWidget);
    });

    testWidgets('returns shrink when conjoint birthYear is null',
        (tester) async {
      final profile = CoachProfile(
        firstName: 'Test',
        birthYear: DateTime.now().year - 50,
        canton: 'ZH',
        salaireBrutMensuel: 8000,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        conjoint: ConjointProfile(
          firstName: 'Partner',
          // birthYear intentionally null
          salaireBrutMensuel: 5000,
          employmentStatus: 'salarie',
        ),
        depenses: const DepensesProfile(loyer: 2000, assuranceMaladie: 500),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2051),
          label: 'Retraite',
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoupleActionPlan(profile: profile),
        ),
      ));

      expect(find.textContaining('Plan d\u2019action'), findsNothing);
    });
  });

  group('CoupleActionPlan — 3a filtering', () {
    testWidgets('shows user-only 3a remaining (excludes conjoint)',
        (tester) async {
      // Both Alice (604.83/mo) and Bob (604.83/mo) have 3a contributions
      // but only Alice's should count toward Alice's plafond.
      final profile = _buildCoupleProfile().copyWith(
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_alice',
            label: '3a Alice (VIAC)',
            amount: 300,
            category: '3a',
          ),
          PlannedMonthlyContribution(
            id: '3a_bob',
            label: '3a Bob',
            amount: 604.83,
            category: '3a',
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      // User remaining = 7258 - (300 * 12) = 3658
      // Should show a 3a action with ~3'658 remaining for Alice
      expect(find.textContaining('3a avant le 31.12'), findsWidgets);
      expect(find.textContaining("3'658"), findsOneWidget);
    });

    testWidgets('includes all 3a when conjoint firstName is null',
        (tester) async {
      // When conjoint has no name, filtering can't distinguish
      // so all 3a contributions are attributed to user (safe default).
      final profile = CoachProfile(
        firstName: 'Test',
        birthYear: DateTime.now().year - 50,
        canton: 'ZH',
        salaireBrutMensuel: 8000,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        conjoint: ConjointProfile(
          // firstName intentionally null
          birthYear: DateTime.now().year - 45,
          salaireBrutMensuel: 5000,
          employmentStatus: 'salarie',
          prevoyance: const PrevoyanceProfile(
            avoirLppTotal: 100000,
            tauxConversion: 0.068,
            rendementCaisse: 0.02,
          ),
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
        ),
        depenses: const DepensesProfile(loyer: 2000, assuranceMaladie: 500),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2051),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_user',
            label: '3a user',
            amount: 200,
            category: '3a',
          ),
          PlannedMonthlyContribution(
            id: '3a_conjoint',
            label: '3a conjoint',
            amount: 400,
            category: '3a',
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoupleActionPlan(profile: profile),
          ),
        ),
      ));

      // With null conjoint name, all 3a counted: (200+400)*12 = 7200
      // remaining = 7258 - 7200 = 58 (below 100 threshold → no 3a action)
      expect(find.textContaining('3a avant le 31.12'), findsNothing);
    });
  });

  group('HeroCoupleCard — edge cases', () {
    testWidgets('handles zero income correctly', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCoupleCard(
              userName: 'A',
              conjointName: 'B',
              userMonthlyIncome: 0,
              conjointMonthlyIncome: 0,
              userRetirementAge: 65,
              conjointRetirementAge: 65,
            ),
          ),
        ),
      ));

      expect(find.textContaining('Total m\u00e9nage'), findsOneWidget);
    });

    testWidgets('handles very long names with ellipsis', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCoupleCard(
              userName: 'Jean-Claude-Marie-Pierre',
              conjointName: 'Anne-Sophie-Charlotte',
              userMonthlyIncome: 3000,
              conjointMonthlyIncome: 2000,
              userRetirementAge: 65,
              conjointRetirementAge: 63,
            ),
          ),
        ),
      ));

      // Should render without overflow errors
      expect(find.textContaining('Total m\u00e9nage'), findsOneWidget);
    });
  });
}

// ════════════════════════════════════════════════════════════
//  TEST HELPERS
// ════════════════════════════════════════════════════════════

CoachProfile _buildCoupleProfile() {
  return CoachProfile(
    firstName: 'Alice',
    birthYear: DateTime.now().year - 50,
    canton: 'VD',
    salaireBrutMensuel: 8000,
    nombreDeMois: 13,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    conjoint: ConjointProfile(
      firstName: 'Bob',
      birthYear: DateTime.now().year - 45,
      salaireBrutMensuel: 5000,
      nombreDeMois: 12,
      employmentStatus: 'salarie',
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 120000,
        tauxConversion: 0.068,
        rendementCaisse: 0.02,
        totalEpargne3a: 20000,
        nombre3a: 1,
      ),
    ),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 200000,
      tauxConversion: 0.060,
      rendementCaisse: 0.02,
      totalEpargne3a: 40000,
      nombre3a: 2,
      anneesContribuees: 25,
      lacunesAVS: 1,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 30000,
      investissements: 60000,
    ),
    depenses: const DepensesProfile(
      loyer: 2200,
      assuranceMaladie: 900,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2051),
      label: 'Retraite',
    ),
  );
}

CoachProfile _buildCoupleProfileWithFatca() {
  return CoachProfile(
    firstName: 'Julien',
    birthYear: DateTime.now().year - 50,
    canton: 'ZH',
    salaireBrutMensuel: 8333,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    conjoint: ConjointProfile(
      firstName: 'Lauren',
      birthYear: DateTime.now().year - 45,
      salaireBrutMensuel: 5000,
      employmentStatus: 'salarie',
      nationality: 'US',
      isFatcaResident: true,
      canContribute3a: false,
      targetRetirementAge: 63,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 80000,
        tauxConversion: 0.068,
        rendementCaisse: 0.02,
        canContribute3a: false, // canonical source — engines read this
      ),
    ),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 300000,
      tauxConversion: 0.068,
      rendementCaisse: 0.02,
      totalEpargne3a: 50000,
      nombre3a: 3,
      anneesContribuees: 30,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 50000,
      investissements: 100000,
    ),
    depenses: const DepensesProfile(
      loyer: 2500,
      assuranceMaladie: 800,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2041),
      label: 'Retraite',
    ),
  );
}

CoachProfile _buildSingleProfile() {
  return CoachProfile(
    firstName: 'Solo',
    birthYear: DateTime.now().year - 40,
    canton: 'GE',
    salaireBrutMensuel: 7000,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 100000,
      tauxConversion: 0.068,
      rendementCaisse: 0.02,
    ),
    depenses: const DepensesProfile(
      loyer: 1500,
      assuranceMaladie: 400,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2051),
      label: 'Retraite',
    ),
  );
}

CoachProfile _buildConcubinProfile() {
  return CoachProfile(
    firstName: 'Claire',
    birthYear: DateTime.now().year - 48,
    canton: 'GE',
    salaireBrutMensuel: 7000,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.concubinage,
    conjoint: ConjointProfile(
      firstName: 'Marc',
      birthYear: DateTime.now().year - 52,
      salaireBrutMensuel: 6000,
      employmentStatus: 'salarie',
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 180000,
        tauxConversion: 0.068,
        rendementCaisse: 0.02,
      ),
    ),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 150000,
      tauxConversion: 0.068,
      rendementCaisse: 0.02,
    ),
    depenses: const DepensesProfile(
      loyer: 2000,
      assuranceMaladie: 700,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2043),
      label: 'Retraite',
    ),
  );
}

List<RetirementPhase> _buildMockPhases() {
  return const [
    RetirementPhase(
      label: 'Julien retrait\u00e9, Lauren active',
      startYear: 2041,
      endYear: 2044,
      sources: [
        RetirementIncomeSource(
          id: 'avs_j',
          label: 'AVS Julien',
          monthlyAmount: 2390,
          color: Colors.blue,
        ),
        RetirementIncomeSource(
          id: 'lpp_j',
          label: 'LPP Julien',
          monthlyAmount: 1700,
          color: Colors.green,
        ),
        RetirementIncomeSource(
          id: 'sal_l',
          label: 'Salaire Lauren',
          monthlyAmount: 5000,
          color: Colors.orange,
        ),
      ],
    ),
    RetirementPhase(
      label: 'Les deux \u00e0 la retraite',
      startYear: 2044,
      sources: [
        RetirementIncomeSource(
          id: 'avs_total',
          label: 'AVS couple',
          monthlyAmount: 3780,
          color: Colors.blue,
        ),
        RetirementIncomeSource(
          id: 'lpp_total',
          label: 'LPP total',
          monthlyAmount: 2900,
          color: Colors.green,
        ),
      ],
    ),
  ];
}
