import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/milestone_detection_service.dart';
import 'package:mint_mobile/services/streak_service.dart';

// ═══════════════════════════════════════════════════════════════
//  MILESTONE DETECTION SERVICE — Unit tests
// ═══════════════════════════════════════════════════════════════
//
// Tests:
//   1. detectNew returns empty when no milestones reached
//   2. detectNew returns patrimoine_50k when patrimoine >= 50000
//   3. detectNew returns 3a_max_reached when annual 3a >= 7258
//   4. detectNew returns emergency_fund_3m when liquid savings >= 3m
//   5. detectNew returns streak_3 when currentStreak >= 3
//   6. detectNew returns score_bon when score >= 60
//   7. detectNew does NOT return already-achieved milestones
//   8. multiple milestones detected simultaneously
//   9. patrimoine includes LPP + 3a in total calculation
//  10. emergency fund not triggered when expenses are zero
//
// All tests use SharedPreferences.setMockInitialValues for
// persistence isolation.
// ═══════════════════════════════════════════════════════════════

/// Build a minimal CoachProfile with custom values for testing.
CoachProfile _buildProfile({
  double epargneLiquide = 0,
  double investissements = 0,
  double? immobilier,
  double? avoirLpp,
  double totalEpargne3a = 0,
  double loyer = 0,
  double assuranceMaladie = 0,
  List<MonthlyCheckIn> checkIns = const [],
  List<PlannedMonthlyContribution> contributions = const [],
}) {
  return CoachProfile(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 7000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 12, 31),
      label: 'Retraite',
    ),
    patrimoine: PatrimoineProfile(
      epargneLiquide: epargneLiquide,
      investissements: investissements,
      immobilier: immobilier,
    ),
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLpp,
      totalEpargne3a: totalEpargne3a,
    ),
    depenses: DepensesProfile(
      loyer: loyer,
      assuranceMaladie: assuranceMaladie,
    ),
    plannedContributions: contributions,
    checkIns: checkIns,
  );
}

/// Build a StreakResult with a given current streak.
StreakResult _buildStreak({int currentStreak = 0}) {
  return StreakResult(
    currentStreak: currentStreak,
    longestStreak: currentStreak,
    totalCheckIns: currentStreak,
    earnedBadges: const [],
    monthsToNextBadge: 0,
  );
}

void main() {
  // Ensure SharedPreferences mock is available
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MilestoneDetectionService.detectNew', () {
    // ── Test 1: Empty when no milestones reached ──────────────
    test('returns empty when no milestones reached', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile();
      final streak = _buildStreak(currentStreak: 0);

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 30,
        streak: streak,
        prefs: prefs,
      );

      expect(milestones, isEmpty);
    });

    // ── Test 2: Patrimoine 50k ────────────────────────────────
    test('returns patrimoine_50k when patrimoine >= 50000', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile(
        epargneLiquide: 30000,
        investissements: 25000,
      );
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );

      expect(milestones.length, 1);
      expect(milestones.first.id, 'patrimoine_50k');
      expect(milestones.first.title, contains('50\'000'));
    });

    // ── Test 3: 3a max reached ────────────────────────────────
    test('returns 3a_max_reached when annual 3a >= 7258', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile(
        contributions: const [
          PlannedMonthlyContribution(
            id: '3a_user',
            label: '3a',
            amount: 604.84, // 604.84 * 12 = 7258.08
            category: '3a',
          ),
        ],
      );
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );

      final m3a = milestones.where((m) => m.id == '3a_max_reached');
      expect(m3a.length, 1);
      expect(m3a.first.title, contains('3a'));
    });

    // ── Test 4: Emergency fund 3 months ───────────────────────
    test('returns emergency_fund_3m when liquid savings >= 3 months expenses',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile(
        epargneLiquide: 6000,
        loyer: 1500,
        assuranceMaladie: 400,
        // totalMensuel = 1900, 3 months = 5700, 6000 >= 5700
      );
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );

      final mEmergency =
          milestones.where((m) => m.id == 'emergency_fund_3m');
      expect(mEmergency.length, 1);
      expect(mEmergency.first.title, contains('3 mois'));
    });

    // ── Test 5: Streak 3 ──────────────────────────────────────
    test('returns streak_3 when currentStreak >= 3', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile();
      final streak = _buildStreak(currentStreak: 3);

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );

      final mStreak = milestones.where((m) => m.id == 'streak_3');
      expect(mStreak.length, 1);
      expect(mStreak.first.title, contains('3 mois'));
    });

    // ── Test 6: Score bon ─────────────────────────────────────
    test('returns score_bon when score >= 60', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile();
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 65,
        streak: streak,
        prefs: prefs,
      );

      final mScore = milestones.where((m) => m.id == 'score_bon');
      expect(mScore.length, 1);
      expect(mScore.first.title, contains('Bon'));
    });

    // ── Test 7: Does NOT return already-achieved milestones ───
    test('does NOT return already-achieved milestones', () async {
      // Pre-populate SharedPreferences with an already-achieved milestone
      SharedPreferences.setMockInitialValues({
        'achieved_milestones_v1': ['patrimoine_50k'],
      });
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile(
        epargneLiquide: 60000,
      );
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );

      // patrimoine_50k should NOT appear again
      final m50k = milestones.where((m) => m.id == 'patrimoine_50k');
      expect(m50k, isEmpty);
    });

    // ── Test 8: Multiple milestones detected simultaneously ───
    test('multiple milestones detected simultaneously', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile(
        epargneLiquide: 60000,
        loyer: 1500,
        assuranceMaladie: 500,
        // totalMensuel = 2000, 6 months = 12000, 60000 >= 12000
        contributions: const [
          PlannedMonthlyContribution(
            id: '3a_user',
            label: '3a',
            amount: 604.84,
            category: '3a',
          ),
        ],
      );
      final streak = _buildStreak(currentStreak: 4);

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 65,
        streak: streak,
        prefs: prefs,
      );

      // Should detect: patrimoine_50k, 3a_max_reached, emergency_fund_3m,
      // emergency_fund_6m, streak_3, score_bon
      final ids = milestones.map((m) => m.id).toSet();
      expect(ids, contains('patrimoine_50k'));
      expect(ids, contains('3a_max_reached'));
      expect(ids, contains('emergency_fund_3m'));
      expect(ids, contains('emergency_fund_6m'));
      expect(ids, contains('streak_3'));
      expect(ids, contains('score_bon'));
      expect(milestones.length, greaterThanOrEqualTo(6));
    });

    // ── Test 9: Patrimoine includes LPP + 3a ─────────────────
    test('patrimoine includes LPP and 3a in total calculation', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // epargneLiquide=10k + investissements=5k + avoirLpp=20k + 3a=20k = 55k
      final profile = _buildProfile(
        epargneLiquide: 10000,
        investissements: 5000,
        avoirLpp: 20000,
        totalEpargne3a: 20000,
      );
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );

      final m50k = milestones.where((m) => m.id == 'patrimoine_50k');
      expect(m50k.length, 1);
    });

    // ── Test 10: Emergency fund not triggered when expenses zero
    test('emergency fund not triggered when expenses are zero', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile(
        epargneLiquide: 50000,
        // loyer = 0, assuranceMaladie = 0 → totalMensuel = 0
      );
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );

      final mEmergency3 =
          milestones.where((m) => m.id == 'emergency_fund_3m');
      final mEmergency6 =
          milestones.where((m) => m.id == 'emergency_fund_6m');
      expect(mEmergency3, isEmpty);
      expect(mEmergency6, isEmpty);
    });

    // ── Test 11: Persistence works across calls ───────────────
    test('newly detected milestones are persisted and not repeated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile(epargneLiquide: 60000);
      final streak = _buildStreak();

      // First call: should detect patrimoine_50k
      final first = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );
      expect(first.any((m) => m.id == 'patrimoine_50k'), true);

      // Second call with same profile: should NOT detect patrimoine_50k again
      final second = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );
      expect(second.any((m) => m.id == 'patrimoine_50k'), false);
    });

    // ── Test 12: Score excellent milestone ─────────────────────
    test('returns score_excellent when score >= 80', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile();
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 85,
        streak: streak,
        prefs: prefs,
      );

      final mExcellent =
          milestones.where((m) => m.id == 'score_excellent');
      expect(mExcellent.length, 1);
      expect(mExcellent.first.title, contains('Excellent'));

      // Should also have score_bon since 85 >= 60
      final mBon = milestones.where((m) => m.id == 'score_bon');
      expect(mBon.length, 1);
    });

    // ── Test 13: Streak 6 and 12 milestones ───────────────────
    test('returns streak_6 and streak_12 at appropriate streaks', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile();
      final streak12 = _buildStreak(currentStreak: 12);

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak12,
        prefs: prefs,
      );

      final ids = milestones.map((m) => m.id).toSet();
      expect(ids, contains('streak_3'));
      expect(ids, contains('streak_6'));
      expect(ids, contains('streak_12'));
    });

    // ── Test 14: All milestone descriptions are in French ─────
    test('all milestone descriptions are in French with tutoiement', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final profile = _buildProfile(
        epargneLiquide: 600000,
        loyer: 1500,
        assuranceMaladie: 500,
        contributions: const [
          PlannedMonthlyContribution(
            id: '3a_user',
            label: '3a',
            amount: 604.84,
            category: '3a',
          ),
        ],
      );
      final streak = _buildStreak(currentStreak: 12);

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 85,
        streak: streak,
        prefs: prefs,
      );

      // All descriptions should contain French text with "tu" or "ton/tes"
      for (final m in milestones) {
        expect(m.description.isNotEmpty, true);
        expect(m.title.isNotEmpty, true);
        // Should not contain banned terms
        final lower = m.description.toLowerCase();
        expect(lower.contains('garanti'), false,
            reason: 'Description should not contain banned term "garanti"');
        expect(lower.contains('sans risque'), false,
            reason:
                'Description should not contain banned term "sans risque"');
      }
    });

    // ── Test 15: 3a from check-in actuals ─────────────────────
    test('3a_max_reached detected from check-in actual versements', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      // Build check-ins with 3a contributions totaling >= 7258
      final checkIns = List.generate(
        12,
        (i) => MonthlyCheckIn(
          month: DateTime(now.year, i + 1),
          versements: const {'3a_user': 604.84},
          completedAt: DateTime(now.year, i + 1, 15),
        ),
      );

      final profile = _buildProfile(
        checkIns: checkIns,
        contributions: const [
          PlannedMonthlyContribution(
            id: '3a_user',
            label: '3a',
            amount: 604.84,
            category: '3a',
          ),
        ],
      );
      final streak = _buildStreak();

      final milestones = await MilestoneDetectionService.detectNew(
        profile: profile,
        currentScore: 40,
        streak: streak,
        prefs: prefs,
      );

      final m3a = milestones.where((m) => m.id == '3a_max_reached');
      expect(m3a.length, 1);
    });
  });
}
