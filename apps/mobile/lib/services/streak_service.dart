import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Badge earned by consistent check-in behavior.
class MintBadge {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final int requiredStreak;

  const MintBadge({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.requiredStreak,
  });
}

/// Result of streak computation from check-in history.
class StreakResult {
  final int currentStreak;
  final int longestStreak;
  final int totalCheckIns;
  final List<MintBadge> earnedBadges;
  final MintBadge? nextBadge;
  final int monthsToNextBadge;

  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCheckIns,
    required this.earnedBadges,
    this.nextBadge,
    required this.monthsToNextBadge,
  });
}

/// Computes check-in streaks and milestone badges from profile data.
///
/// All logic is pure and deterministic. No network calls.
class StreakService {
  StreakService._();

  static const List<MintBadge> _allBadges = [
    MintBadge(
      id: 'first_step',
      label: 'Premier pas',
      description: 'Tu as fait ton premier check-in.',
      icon: Icons.emoji_events_outlined,
      requiredStreak: 1,
    ),
    MintBadge(
      id: 'regulier',
      label: 'Régulier·e',
      description: '3 mois consécutifs de check-in.',
      icon: Icons.local_fire_department,
      requiredStreak: 3,
    ),
    MintBadge(
      id: 'constant',
      label: 'Constant·e',
      description: '6 mois sans interruption.',
      icon: Icons.whatshot,
      requiredStreak: 6,
    ),
    MintBadge(
      id: 'discipline',
      label: 'Discipliné·e',
      description: '12 mois consécutifs — une année complète.',
      icon: Icons.military_tech,
      requiredStreak: 12,
    ),
  ];

  /// Compute the streak result from a coach profile's check-in history.
  static StreakResult compute(CoachProfile profile) {
    final checkIns = profile.checkIns.toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    if (checkIns.isEmpty) {
      return StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        totalCheckIns: 0,
        earnedBadges: const [],
        nextBadge: _allBadges.first,
        monthsToNextBadge: 1,
      );
    }

    // Compute current streak (counting backwards from most recent)
    int currentStreak = 1;
    final now = DateTime.now();
    final sortedDesc = checkIns.reversed.toList();

    // Check if the most recent check-in is within current or previous month
    final latest = sortedDesc.first.month;
    final isRecent = (latest.year == now.year && latest.month == now.month) ||
        (latest.year == now.year && latest.month == now.month - 1) ||
        (latest.year == now.year - 1 && latest.month == 12 && now.month == 1);

    if (!isRecent) {
      currentStreak = 0;
    } else {
      for (int i = 1; i < sortedDesc.length; i++) {
        final prev = sortedDesc[i - 1].month;
        final curr = sortedDesc[i].month;
        final expectedMonth = DateTime(prev.year, prev.month - 1);
        if (curr.year == expectedMonth.year &&
            curr.month == expectedMonth.month) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    // Compute longest streak
    int longest = 1;
    int running = 1;
    for (int i = 1; i < checkIns.length; i++) {
      final prev = checkIns[i - 1].month;
      final curr = checkIns[i].month;
      final expected = DateTime(prev.year, prev.month + 1);
      if (curr.year == expected.year && curr.month == expected.month) {
        running++;
        if (running > longest) longest = running;
      } else {
        running = 1;
      }
    }
    if (checkIns.length == 1) longest = 1;

    // Determine earned badges
    final earned = _allBadges
        .where((b) => longest >= b.requiredStreak)
        .toList();

    // Find next badge
    MintBadge? next;
    int monthsToNext = 0;
    for (final badge in _allBadges) {
      if (currentStreak < badge.requiredStreak) {
        next = badge;
        monthsToNext = badge.requiredStreak - currentStreak;
        break;
      }
    }

    return StreakResult(
      currentStreak: currentStreak,
      longestStreak: longest,
      totalCheckIns: checkIns.length,
      earnedBadges: earned,
      nextBadge: next,
      monthsToNextBadge: monthsToNext,
    );
  }

  /// Compute capital & financial milestones from a coach profile.
  ///
  /// Returns a list of [MintMilestone] with `isReached` flags based
  /// on the user's current patrimoine, 3a contributions, and emergency fund.
  /// All thresholds are based on Swiss financial planning best practices.
  static List<MintMilestone> computeMilestones(CoachProfile profile) {
    // Total patrimoine = epargne liquide + investissements + immobilier
    // + avoir LPP + epargne 3a
    final patrimoine = profile.patrimoine.totalPatrimoine +
        (profile.prevoyance.avoirLppTotal ?? 0) +
        profile.prevoyance.totalEpargne3a;

    // Annual 3a contribution from planned monthly contributions
    final annual3a = profile.total3aMensuel * 12;

    // Monthly expenses from depenses profile
    final monthlyExpenses = profile.depenses.totalMensuel;

    // Liquid savings (available for emergency fund)
    final liquidSavings = profile.patrimoine.epargneLiquide;

    return [
      MintMilestone(
        id: 'patrimoine_50k',
        label: 'Premier jalon',
        description: 'Patrimoine atteint 50\'000 CHF',
        icon: Icons.emoji_events,
        threshold: 50000,
        isReached: patrimoine >= 50000,
      ),
      MintMilestone(
        id: 'patrimoine_100k',
        label: 'Cap des 100k',
        description: 'Patrimoine atteint 100\'000 CHF',
        icon: Icons.workspace_premium,
        threshold: 100000,
        isReached: patrimoine >= 100000,
      ),
      MintMilestone(
        id: 'patrimoine_250k',
        label: 'Quart de million',
        description: 'Patrimoine atteint 250\'000 CHF',
        icon: Icons.diamond,
        threshold: 250000,
        isReached: patrimoine >= 250000,
      ),
      MintMilestone(
        id: 'patrimoine_500k',
        label: 'Demi-million',
        description: 'Patrimoine atteint 500\'000 CHF',
        icon: Icons.stars,
        threshold: 500000,
        isReached: patrimoine >= 500000,
      ),
      MintMilestone(
        id: '3a_max',
        label: '3a au max',
        description: 'Versement 3a au plafond (7\'258 CHF)',
        icon: Icons.savings,
        threshold: pilier3aPlafondAvecLpp,
        isReached: annual3a >= pilier3aPlafondAvecLpp,
      ),
      MintMilestone(
        id: 'emergency_fund',
        label: 'Matelas 6 mois',
        description: '6 mois de depenses en epargne liquide',
        icon: Icons.shield,
        threshold: monthlyExpenses * 6,
        isReached:
            monthlyExpenses > 0 && liquidSavings >= monthlyExpenses * 6,
      ),
    ];
  }
}

/// Capital & financial milestone badge.
///
/// Unlike [MintBadge] (which tracks streak consistency),
/// [MintMilestone] tracks financial progress thresholds
/// (patrimoine, 3a contributions, emergency fund).
class MintMilestone {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final double threshold;
  final bool isReached;

  const MintMilestone({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.threshold,
    required this.isReached,
  });
}
