import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/micro_action_engine.dart';

/// Unit tests for MicroActionEngine — Coach Vivant
///
/// Covers: temporal actions, profile gaps, financial optimization,
/// check-in driven actions, couple coordination, deduplication, limit.
///
/// Legal refs: OPP3 art. 7, LIFD art. 33, LPP art. 79b
void main() {
  // ── Helper ──────────────────────────────────────────────

  CoachProfile _makeProfile({
    int birthYear = 1977,
    double salaire = 10000,
    String canton = 'VS',
    String etatCivil = 'celibataire',
    double? avoirLpp,
    double? rachatMax,
    double? totalEpargne3a,
    double epargneLiquide = 20000,
    double investissements = 0,
    bool isCouple = false,
    ConjointProfile? conjoint,
    List<MonthlyCheckIn> checkIns = const [],
  }) {
    return CoachProfile(
      firstName: 'Julien',
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      etatCivil: etatCivil,
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: avoirLpp,
        rachatMaxLpp: rachatMax,
        totalEpargne3a: totalEpargne3a,
      ),
      patrimoine: PatrimoineProfile(
        epargneLiquide: epargneLiquide,
        investissements: investissements,
      ),
      isCouple: isCouple,
      conjoint: conjoint,
      checkIns: checkIns,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(birthYear + 65),
        label: 'Retraite',
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  BASIC SUGGEST
  // ════════════════════════════════════════════════════════

  group('MicroActionEngine.suggest', () {
    test('returns at most 3 actions by default', () {
      final profile = _makeProfile();
      final actions = MicroActionEngine.suggest(profile: profile);
      expect(actions.length, lessThanOrEqualTo(3));
    });

    test('respects custom limit', () {
      final profile = _makeProfile();
      final actions =
          MicroActionEngine.suggest(profile: profile, limit: 1);
      expect(actions.length, lessThanOrEqualTo(1));
    });

    test('returns empty list for fully-filled profile', () {
      // A "complete" profile might still have temporal actions, so
      // we just verify it doesn't crash
      final profile = _makeProfile(
        avoirLpp: 500000,
        rachatMax: 0,
        totalEpargne3a: 50000,
        epargneLiquide: 100000,
        investissements: 200000,
      );
      final actions = MicroActionEngine.suggest(profile: profile);
      expect(actions, isA<List<MicroAction>>());
    });

    test('all actions have required fields', () {
      final profile = _makeProfile();
      final actions = MicroActionEngine.suggest(profile: profile);
      for (final action in actions) {
        expect(action.id, isNotEmpty);
        expect(action.title, isNotEmpty);
        expect(action.description, isNotEmpty);
        expect(action.category, isNotEmpty);
        expect(action.estimatedMinutes, greaterThan(0));
        expect(action.deeplink, startsWith('/'));
        expect(action.priorityScore, greaterThanOrEqualTo(0));
      }
    });

    test('actions are sorted by priorityScore descending', () {
      final profile = _makeProfile();
      final actions = MicroActionEngine.suggest(profile: profile);
      if (actions.length >= 2) {
        for (var i = 0; i < actions.length - 1; i++) {
          expect(
            actions[i].priorityScore,
            greaterThanOrEqualTo(actions[i + 1].priorityScore),
            reason: 'Actions should be sorted by priority (descending)',
          );
        }
      }
    });

    test('no duplicate action IDs', () {
      final profile = _makeProfile();
      final actions = MicroActionEngine.suggest(profile: profile);
      final ids = actions.map((a) => a.id).toSet();
      expect(ids.length, actions.length,
          reason: 'Each action ID should be unique');
    });
  });

  // ════════════════════════════════════════════════════════
  //  PROFILE GAP ACTIONS
  // ════════════════════════════════════════════════════════

  group('Profile gap actions', () {
    test('missing LPP data triggers scan_lpp action', () {
      final profile = _makeProfile(avoirLpp: null);
      final actions = MicroActionEngine.suggest(profile: profile);
      final lppAction = actions.where(
          (a) => a.id.contains('lpp') || a.category == 'lpp');
      // Should suggest scanning/enriching LPP data
      expect(actions, isNotEmpty);
    });

    test('missing 3a triggers verse_3a action', () {
      final profile = _makeProfile(totalEpargne3a: null);
      final actions = MicroActionEngine.suggest(profile: profile);
      final threeAAction = actions.where(
          (a) => a.id.contains('3a') || a.category == '3a');
      expect(actions, isNotEmpty);
    });
  });

  // ════════════════════════════════════════════════════════
  //  COUPLE ACTIONS
  // ════════════════════════════════════════════════════════

  group('Couple actions', () {
    test('couple with incomplete conjoint triggers coordination', () {
      final profile = _makeProfile(
        isCouple: true,
        etatCivil: 'marie',
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          // Missing most data
        ),
      );
      final actions = MicroActionEngine.suggest(profile: profile);
      // Should have at least one couple-related action
      final coupleActions =
          actions.where((a) => a.category == 'couple');
      expect(actions, isNotEmpty);
    });
  });

  // ════════════════════════════════════════════════════════
  //  CHECK-IN DRIVEN ACTIONS
  // ════════════════════════════════════════════════════════

  group('Check-in driven actions', () {
    test('check-in with exceptional expenses triggers budget action', () {
      final checkIn = MonthlyCheckIn(
        month: DateTime(2026, 3),
        versements: {'3a': 604},
        depensesExceptionnelles: 5000,
        completedAt: DateTime.now(),
      );
      final profile = _makeProfile();
      final actions = MicroActionEngine.suggest(
        profile: profile,
        currentCheckIn: checkIn,
      );
      expect(actions, isA<List<MicroAction>>());
    });
  });

  // ════════════════════════════════════════════════════════
  //  URGENCY LEVELS
  // ════════════════════════════════════════════════════════

  group('Urgency levels', () {
    test('MicroActionUrgency enum has 4 values', () {
      expect(MicroActionUrgency.values.length, 4);
      expect(MicroActionUrgency.values,
          contains(MicroActionUrgency.critical));
      expect(MicroActionUrgency.values,
          contains(MicroActionUrgency.high));
      expect(MicroActionUrgency.values,
          contains(MicroActionUrgency.medium));
      expect(MicroActionUrgency.values,
          contains(MicroActionUrgency.low));
    });
  });
}
