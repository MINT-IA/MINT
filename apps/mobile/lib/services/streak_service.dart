import 'package:flutter/material.dart';
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
}
