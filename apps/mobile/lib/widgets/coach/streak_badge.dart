import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/streak_service.dart';

/// Compact streak counter displayed in the Agir tab header.
///
/// Shows the current streak count with a fire icon and
/// progress toward the next badge milestone.
class StreakBadgeWidget extends StatelessWidget {
  final StreakResult streak;

  const StreakBadgeWidget({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak.currentStreak == 0 && streak.totalCheckIns == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _streakColor.withValues(alpha: 0.06),
            _streakColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(color: _streakColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Streak fire icon with count
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _streakColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  streak.currentStreak > 0
                      ? Icons.local_fire_department
                      : Icons.timelapse,
                  color: _streakColor,
                  size: 22,
                ),
                Text(
                  '${streak.currentStreak}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _streakColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Message + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                if (streak.nextBadge != null) ...[
                  const SizedBox(height: 8),
                  // Progress bar toward next badge
                  ClipRRect(
                    borderRadius: const BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: streak.nextBadge!.requiredStreak > 0
                          ? streak.currentStreak /
                              streak.nextBadge!.requiredStreak
                          : 0,
                      backgroundColor: MintColors.lightBorder,
                      color: _streakColor,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${streak.monthsToNextBadge} mois → ${streak.nextBadge!.label}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Latest badge icon (if earned)
          if (streak.earnedBadges.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                streak.earnedBadges.last.icon,
                color: MintColors.warning,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  Color get _streakColor {
    if (streak.currentStreak >= 12) return MintColors.warning;
    if (streak.currentStreak >= 6) return const Color(0xFFEA580C);
    if (streak.currentStreak >= 3) return MintColors.success;
    return MintColors.coachAccent;
  }

  String get _title {
    if (streak.currentStreak == 0) {
      return 'Reprends ta série';
    }
    if (streak.currentStreak == 1) {
      return 'Série en cours';
    }
    return '${streak.currentStreak} mois consécutifs';
  }

  String get _subtitle {
    if (streak.currentStreak == 0 && streak.totalCheckIns > 0) {
      return 'Tu as fait ${streak.totalCheckIns} check-in${streak.totalCheckIns > 1 ? 's' : ''} au total. Fais ton check-in ce mois pour relancer ta série.';
    }
    if (streak.currentStreak == 0) {
      return 'Fais ton premier check-in pour démarrer ta série.';
    }
    if (streak.currentStreak >= 6) {
      return 'Impressionnant ! Ta régularité construit ta trajectoire.';
    }
    if (streak.currentStreak >= 3) {
      return 'Belle constance. Chaque mois compte.';
    }
    return 'Continue comme ça, la régularité fait la différence.';
  }
}

/// Horizontal row showing all earned badges with labels.
class EarnedBadgesRow extends StatelessWidget {
  final StreakResult streak;

  const EarnedBadgesRow({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak.earnedBadges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Badges obtenus',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: streak.earnedBadges.map((badge) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.circular(10),
                border: Border.all(
                  color: MintColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badge.icon, color: MintColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    badge.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
