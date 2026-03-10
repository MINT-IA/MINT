import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/monthly_briefing_service.dart';
import 'package:mint_mobile/services/micro_action_engine.dart';

/// Unit tests for MonthlyBriefingService + MicroActionEngine — Coach Vivant
///
/// Tests month-to-month comparison logic, trend detection, insight generation,
/// and micro-action selection.
///
/// Legal references: OPP3 art. 7, LPP art. 79b, LIFD art. 33
void main() {
  // ── Helper: standard test profile ─────────────────────────
  CoachProfile _buildProfile({
    int birthYear = 1977,
    String canton = 'VS',
    double salaire = 9078,
    String employmentStatus = 'salarie',
    double avoirLpp = 70377,
    double assuranceMaladie = 450,
    double loyer = 925,
    double epargneLiquide = 15000,
    ConjointProfile? conjoint,
    List<MonthlyCheckIn> checkIns = const [],
  }) {
    return CoachProfile(
      firstName: 'Julien',
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      employmentStatus: employmentStatus,
      conjoint: conjoint,
      patrimoine: PatrimoineProfile(
        epargneLiquide: epargneLiquide,
      ),
      depenses: DepensesProfile(
        loyer: loyer,
        assuranceMaladie: assuranceMaladie,
      ),
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: avoirLpp,
        tauxConversion: 0.068,
      ),
      dettes: const DetteProfile(),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042),
        label: 'Retraite',
      ),
      checkIns: checkIns,
    );
  }

  MonthlyCheckIn _checkIn({
    required DateTime month,
    Map<String, double> versements = const {'3a_julien': 604.83},
    double? depensesExc,
    double? revenusExc,
  }) {
    return MonthlyCheckIn(
      month: month,
      versements: versements,
      depensesExceptionnelles: depensesExc,
      revenusExceptionnels: revenusExc,
      completedAt: DateTime.now(),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  MonthlyBriefingService.compare() — basic
  // ════════════════════════════════════════════════════════════

  group('MonthlyBriefingService.compare() — basic', () {
    test('first check-in (no previous) produces valid briefing', () {
      final profile = _buildProfile();
      final current = _checkIn(month: DateTime(2026, 3, 1));

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: current,
      );

      expect(briefing.isFirstCheckIn, isTrue);
      expect(briefing.versementsDeltaChf, closeTo(604.83, 0.01));
      expect(briefing.versementsDeltaPct, 0);
      expect(briefing.trend, BriefingTrend.stable);
      expect(briefing.insights, isNotEmpty);
      expect(briefing.disclaimer, isNotEmpty);
    });

    test('two months with same versements → stable trend', () {
      final profile = _buildProfile();
      final prev = _checkIn(month: DateTime(2026, 2, 1));
      final curr = _checkIn(month: DateTime(2026, 3, 1));

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: curr,
        previous: prev,
      );

      expect(briefing.isFirstCheckIn, isFalse);
      expect(briefing.trend, BriefingTrend.stable);
      expect(briefing.versementsDeltaChf, closeTo(0, 0.01));
    });

    test('versements increase > 10% → en hausse', () {
      final profile = _buildProfile();
      final prev = _checkIn(
        month: DateTime(2026, 2, 1),
        versements: {'3a': 500},
      );
      final curr = _checkIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a': 700},
      );

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: curr,
        previous: prev,
      );

      expect(briefing.trend, BriefingTrend.enHausse);
      expect(briefing.versementsDeltaChf, closeTo(200, 0.01));
      expect(briefing.versementsDeltaPct, closeTo(40, 0.1));
    });

    test('versements decrease > 10% → en baisse', () {
      final profile = _buildProfile();
      final prev = _checkIn(
        month: DateTime(2026, 2, 1),
        versements: {'3a': 700},
      );
      final curr = _checkIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a': 400},
      );

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: curr,
        previous: prev,
      );

      expect(briefing.trend, BriefingTrend.enBaisse);
      expect(briefing.versementsDeltaChf, closeTo(-300, 0.01));
    });

    test('depenses exceptionnelles delta is calculated', () {
      final profile = _buildProfile();
      final prev = _checkIn(
        month: DateTime(2026, 2, 1),
        depensesExc: 500,
      );
      final curr = _checkIn(
        month: DateTime(2026, 3, 1),
        depensesExc: 3000,
      );

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: curr,
        previous: prev,
      );

      expect(briefing.depensesExcDeltaChf, closeTo(2500, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MonthlyBriefingService.compare() — insights
  // ════════════════════════════════════════════════════════════

  group('MonthlyBriefingService.compare() — insights', () {
    test('first check-in gets welcome insight', () {
      final profile = _buildProfile();
      final current = _checkIn(month: DateTime(2026, 3, 1));

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: current,
      );

      expect(
        briefing.insights.any((i) => i.contains('Premier check-in')),
        isTrue,
      );
    });

    test('insights are max 3', () {
      final profile = _buildProfile();
      final prev = _checkIn(
        month: DateTime(2026, 2, 1),
        versements: {'3a': 500, 'lpp': 200},
        depensesExc: 100,
      );
      final curr = _checkIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a': 700, 'lpp': 400},
        depensesExc: 3000,
      );

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: curr,
        previous: prev,
      );

      expect(briefing.insights.length, lessThanOrEqualTo(3));
    });

    test('large depenses exc generates budget insight', () {
      final profile = _buildProfile();
      final prev = _checkIn(month: DateTime(2026, 2, 1));
      final curr = _checkIn(
        month: DateTime(2026, 3, 1),
        depensesExc: 5000,
      );

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: curr,
        previous: prev,
      );

      expect(
        briefing.insights.any((i) => i.toLowerCase().contains('depenses')),
        isTrue,
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MonthlyBriefingService.fromProfile()
  // ════════════════════════════════════════════════════════════

  group('MonthlyBriefingService.fromProfile()', () {
    test('returns null for empty check-ins', () {
      final profile = _buildProfile();
      final briefing = MonthlyBriefingService.fromProfile(profile);
      expect(briefing, isNull);
    });

    test('returns briefing for single check-in', () {
      final profile = _buildProfile(
        checkIns: [_checkIn(month: DateTime(2026, 3, 1))],
      );
      final briefing = MonthlyBriefingService.fromProfile(profile);
      expect(briefing, isNotNull);
      expect(briefing!.isFirstCheckIn, isTrue);
    });

    test('returns comparison for two check-ins', () {
      final profile = _buildProfile(
        checkIns: [
          _checkIn(
            month: DateTime(2026, 2, 1),
            versements: {'3a': 500},
          ),
          _checkIn(
            month: DateTime(2026, 3, 1),
            versements: {'3a': 700},
          ),
        ],
      );
      final briefing = MonthlyBriefingService.fromProfile(profile);
      expect(briefing, isNotNull);
      expect(briefing!.isFirstCheckIn, isFalse);
      expect(briefing.trend, BriefingTrend.enHausse);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MonthlyBriefingDelta — model
  // ════════════════════════════════════════════════════════════

  group('MonthlyBriefingDelta — model', () {
    test('trendLabel returns French labels', () {
      final profile = _buildProfile();

      final stable = MonthlyBriefingService.compare(
        profile: profile,
        current: _checkIn(month: DateTime(2026, 3, 1)),
      );
      expect(stable.trendLabel, 'stable');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MicroActionEngine.suggest() — basic
  // ════════════════════════════════════════════════════════════

  group('MicroActionEngine.suggest() — basic', () {
    test('returns non-empty list for standard profile', () {
      final profile = _buildProfile();
      final actions = MicroActionEngine.suggest(profile: profile);
      expect(actions, isNotEmpty);
    });

    test('respects limit parameter', () {
      final profile = _buildProfile();
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 1);
      expect(actions.length, lessThanOrEqualTo(1));
    });

    test('actions are sorted by priority (highest first)', () {
      final profile = _buildProfile();
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      if (actions.length >= 2) {
        for (var i = 0; i < actions.length - 1; i++) {
          expect(actions[i].priorityScore,
              greaterThanOrEqualTo(actions[i + 1].priorityScore));
        }
      }
    });

    test('actions are deduplicated by id', () {
      final profile = _buildProfile();
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      final ids = actions.map((a) => a.id).toSet();
      expect(ids.length, equals(actions.length));
    });

    test('every action has required fields', () {
      final profile = _buildProfile();
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      for (final action in actions) {
        expect(action.id, isNotEmpty);
        expect(action.title, isNotEmpty);
        expect(action.description, isNotEmpty);
        expect(action.category, isNotEmpty);
        expect(action.deeplink, startsWith('/'));
        expect(action.estimatedMinutes, greaterThan(0));
        expect(action.priorityScore, greaterThan(0));
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MicroActionEngine — profile gap detection
  // ════════════════════════════════════════════════════════════

  group('MicroActionEngine — profile gaps', () {
    test('missing LPP generates scan action', () {
      final profile = _buildProfile(avoirLpp: 0);
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      final scanAction = actions.where((a) => a.id == 'scan_lpp_cert');
      expect(scanAction, isNotEmpty,
          reason: 'Missing LPP should suggest certificate scan');
    });

    test('missing assurance generates add action', () {
      final profile = _buildProfile(assuranceMaladie: 0);
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      final assurAction = actions.where((a) => a.id == 'add_assurance');
      expect(assurAction, isNotEmpty,
          reason: 'Missing assurance should suggest adding it');
    });

    test('complete profile has fewer gap actions', () {
      final complete = _buildProfile();
      final incomplete = _buildProfile(avoirLpp: 0, assuranceMaladie: 0);

      final completeActions =
          MicroActionEngine.suggest(profile: complete, limit: 10);
      final incompleteActions =
          MicroActionEngine.suggest(profile: incomplete, limit: 10);

      final completeGaps =
          completeActions.where((a) => a.category == 'lpp' || a.category == 'assurance');
      final incompleteGaps =
          incompleteActions.where((a) => a.category == 'lpp' || a.category == 'assurance');

      expect(incompleteGaps.length, greaterThan(completeGaps.length));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MicroActionEngine — financial actions
  // ════════════════════════════════════════════════════════════

  group('MicroActionEngine — financial actions', () {
    test('45+ gets LPP rachat suggestion', () {
      final profile = _buildProfile(birthYear: 1977); // age ~49
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      final rachat = actions.where((a) => a.id == 'explore_rachat_lpp');
      expect(rachat, isNotEmpty,
          reason: '45+ with LPP should see rachat suggestion');
    });

    test('low liquidity generates emergency fund action', () {
      final profile = _buildProfile(
        epargneLiquide: 1000,
        loyer: 925,
        assuranceMaladie: 450,
      );
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      final fund = actions.where((a) => a.id == 'build_emergency_fund');
      expect(fund, isNotEmpty,
          reason: 'Low liquidity should suggest building emergency fund');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MicroActionEngine — couple actions
  // ════════════════════════════════════════════════════════════

  group('MicroActionEngine — couple actions', () {
    test('FATCA conjoint generates compliance action', () {
      final profile = _buildProfile(
        conjoint: ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 4800,
          isFatcaResident: true,
        ),
      );
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      final fatca = actions.where((a) => a.id == 'fatca_couple_check');
      expect(fatca, isNotEmpty,
          reason: 'FATCA conjoint should generate compliance action');
    });

    test('incomplete conjoint generates profile action', () {
      final profile = _buildProfile(
        conjoint: ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 0,
        ),
      );
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 10);
      final complete =
          actions.where((a) => a.id == 'complete_conjoint_profile');
      expect(complete, isNotEmpty,
          reason: 'Incomplete conjoint should suggest completing profile');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MicroActionEngine — check-in driven actions
  // ════════════════════════════════════════════════════════════

  group('MicroActionEngine — check-in driven', () {
    test('large depenses exc generates budget review', () {
      final profile = _buildProfile();
      final current = _checkIn(
        month: DateTime(2026, 3, 1),
        depensesExc: 5000,
      );
      final actions = MicroActionEngine.suggest(
        profile: profile,
        currentCheckIn: current,
        limit: 10,
      );
      final budget =
          actions.where((a) => a.id == 'budget_review_depexc');
      expect(budget, isNotEmpty,
          reason: 'Large exceptional expenses should suggest budget review');
    });

    test('versements drop generates alert', () {
      final profile = _buildProfile();
      final prev = _checkIn(
        month: DateTime(2026, 2, 1),
        versements: {'3a': 1000},
      );
      final curr = _checkIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a': 200},
      );
      final actions = MicroActionEngine.suggest(
        profile: profile,
        currentCheckIn: curr,
        previousCheckIn: prev,
        limit: 10,
      );
      final drop = actions.where((a) => a.id == 'versements_drop');
      expect(drop, isNotEmpty,
          reason: 'Significant versement drop should generate alert');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Integration: briefing includes micro-actions
  // ════════════════════════════════════════════════════════════

  group('Integration: briefing + micro-actions', () {
    test('briefing includes micro-actions', () {
      final profile = _buildProfile(avoirLpp: 0);
      final current = _checkIn(month: DateTime(2026, 3, 1));

      final briefing = MonthlyBriefingService.compare(
        profile: profile,
        current: current,
      );

      expect(briefing.microActions, isNotEmpty,
          reason: 'Briefing should include micro-actions');
      expect(briefing.microActions.length, lessThanOrEqualTo(3));
    });
  });
}
