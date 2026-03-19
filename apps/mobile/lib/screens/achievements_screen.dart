import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/daily_engagement_service.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/services/milestone_detection_service.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  ACHIEVEMENTS SCREEN — S55 / Daily Streaks + Achievements
// ────────────────────────────────────────────────────────────
//
// Full screen showing all streaks, badges, and milestones.
//
// Section 1: Daily Streak Hero — flame icon, streak count,
//   longest streak, weekly calendar dots, "Engage today" CTA.
//
// Section 2: Badges (from StreakService) — grid of 4 badges.
//   Earned = full color + checkmark, Unearned = greyed + lock.
//
// Section 3: Milestones (from MilestoneDetectionService) —
//   grouped by category (Financial, Prevoyance, Securite,
//   Score, Engagement).
//
// Footer: Disclaimer — personal, no social comparison.
//
// Route: /achievements
// ────────────────────────────────────────────────────────────

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int _dailyStreak = 0;
  int _longestStreak = 0;
  bool _engagedToday = false;
  int _totalDays = 0;
  Set<String> _recentDates = {};
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        DailyEngagementService.currentStreak(),
        DailyEngagementService.longestStreak(),
        DailyEngagementService.hasEngagedToday(),
        DailyEngagementService.totalDays(),
        DailyEngagementService.recentDates(),
      ]);

      if (!mounted) return;
      setState(() {
        _dailyStreak = results[0] as int;
        _longestStreak = results[1] as int;
        _engagedToday = results[2] as bool;
        _totalDays = results[3] as int;
        _recentDates = results[4] as Set<String>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final profileProvider = context.watch<CoachProfileProvider>();
    final profile = profileProvider.profile;

    // If no profile yet, show empty state
    if (profile == null) {
      return Scaffold(
        backgroundColor: MintColors.background,
        appBar: AppBar(
          backgroundColor: MintColors.white,
          foregroundColor: MintColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            s.achievementsTitle,
            style: MintTextStyles.headlineMedium(),
          ),
        ),
        body: Center(
          child: Text(
            s.achievementsEmptyProfile,
            style: MintTextStyles.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final streakResult = StreakService.compute(profile);
    final milestones = StreakService.computeMilestones(profile);

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.achievementsTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(MintSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_hasError)
              Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                margin: const EdgeInsets.only(bottom: MintSpacing.md),
                decoration: BoxDecoration(
                  color: MintColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MintColors.error.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: MintColors.error, size: 20),
                    const SizedBox(width: MintSpacing.sm),
                    Expanded(child: Text(
                      s.achievementsErrorMessage,
                      style: MintTextStyles.bodySmall(color: MintColors.error),
                    )),
                  ],
                ),
              )
            else ...[
              // Section 1: Daily Streak Hero
              _buildDailyStreakHero(s),
              const SizedBox(height: MintSpacing.xl),

              // Section 2: Badges
              _buildBadgesSection(s, streakResult),
              const SizedBox(height: MintSpacing.xl),

              // Section 3: Milestones
              _buildMilestonesSection(s, milestones),
              const SizedBox(height: MintSpacing.xl),

              // Footer: Disclaimer
              _buildDisclaimer(s),
              const SizedBox(height: MintSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SECTION 1: Daily Streak Hero
  // ════════════════════════════════════════════════════════════

  Widget _buildDailyStreakHero(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.warning.withValues(alpha: 0.08),
            MintColors.deepOrange.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.warning.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Flame icon + streak count
          Semantics(
            label: '$_dailyStreak ${_dailyStreak == 1 ? s.achievementsDaysSingular : s.achievementsDaysPlural}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _dailyStreak > 0
                      ? Icons.local_fire_department
                      : Icons.local_fire_department_outlined,
                  color: _dailyStreak > 0
                      ? MintColors.warning
                      : MintColors.textMuted,
                  size: 48,
                ),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  '$_dailyStreak',
                  style: MintTextStyles.displayLarge(
                    color: _dailyStreak > 0
                        ? MintColors.warning
                        : MintColors.textMuted,
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  _dailyStreak == 1
                      ? s.achievementsDaysSingular
                      : s.achievementsDaysPlural,
                  style: MintTextStyles.headlineMedium(color: MintColors.textSecondary).copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm),

          // Longest streak + total days
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip(
                Icons.emoji_events_outlined,
                s.achievementsRecord(_longestStreak),
              ),
              const SizedBox(width: MintSpacing.md),
              _buildStatChip(
                Icons.calendar_today_outlined,
                s.achievementsTotalDays(_totalDays),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          // Weekly calendar dots (last 7 days)
          _buildWeeklyCalendar(s),
          const SizedBox(height: MintSpacing.md),

          // "Engage today" CTA — subtle per VOICE_SYSTEM
          if (!_engagedToday)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: MintSpacing.md),
              decoration: BoxDecoration(
                color: MintColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MintColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt,
                    color: MintColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.achievementsEngageCta,
                      style: MintTextStyles.bodySmall(color: MintColors.info),
                    ),
                  ),
                ],
              ),
            ),
          if (_engagedToday)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: MintColors.success,
                  size: 20,
                ),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  s.achievementsEngagedToday,
                  style: MintTextStyles.bodySmall(color: MintColors.success),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MintColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendar(S s) {
    final now = DateTime.now();
    final dayLabels = [
      s.achievementsDayMon,
      s.achievementsDayTue,
      s.achievementsDayWed,
      s.achievementsDayThu,
      s.achievementsDayFri,
      s.achievementsDaySat,
      s.achievementsDaySun,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final date = now.subtract(Duration(days: 6 - index));
        final key =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final isEngaged = _recentDates.contains(key);
        final isToday = index == 6;

        return Semantics(
          label: '${dayLabels[date.weekday - 1]} ${isEngaged ? "actif" : "inactif"}',
          child: Column(
            children: [
              Text(
                dayLabels[date.weekday - 1],
                style: MintTextStyles.labelSmall(),
              ),
              const SizedBox(height: 6),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isEngaged
                      ? MintColors.warning
                      : isToday
                          ? MintColors.surface
                          : MintColors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isEngaged
                      ? Border.all(
                          color: MintColors.warning.withValues(alpha: 0.4),
                          width: 2,
                        )
                      : null,
                ),
                child: Center(
                  child: isEngaged
                      ? const Icon(
                          Icons.check,
                          color: MintColors.white,
                          size: 16,
                        )
                      : Text(
                          '${date.day}',
                          style: MintTextStyles.labelSmall(),
                        ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SECTION 2: Badges (from StreakService)
  // ════════════════════════════════════════════════════════════

  Widget _buildBadgesSection(S s, StreakResult streakResult) {
    final allBadges = [
      _BadgeInfo(
        id: 'first_step',
        label: s.achievementsBadgeFirstStepLabel,
        description: s.achievementsBadgeFirstStepDesc,
        icon: Icons.emoji_events_outlined,
        requiredStreak: 1,
      ),
      _BadgeInfo(
        id: 'regulier',
        label: s.achievementsBadgeRegulierLabel,
        description: s.achievementsBadgeRegulierDesc,
        icon: Icons.local_fire_department,
        requiredStreak: 3,
      ),
      _BadgeInfo(
        id: 'constant',
        label: s.achievementsBadgeConstantLabel,
        description: s.achievementsBadgeConstantDesc,
        icon: Icons.whatshot,
        requiredStreak: 6,
      ),
      _BadgeInfo(
        id: 'discipline',
        label: s.achievementsBadgeDisciplineLabel,
        description: s.achievementsBadgeDisciplineDesc,
        icon: Icons.military_tech,
        requiredStreak: 12,
      ),
    ];

    final earnedIds =
        streakResult.earnedBadges.map((b) => b.id).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.achievementsBadgesTitle,
          style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          s.achievementsBadgesSubtitle,
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
        ),
        const SizedBox(height: MintSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: MintSpacing.sm,
          crossAxisSpacing: MintSpacing.sm,
          childAspectRatio: 1.3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: allBadges.map((badge) {
            final isEarned = earnedIds.contains(badge.id);
            return _buildBadgeCard(s, badge, isEarned);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(S s, _BadgeInfo badge, bool isEarned) {
    return Semantics(
      label: badge.label,
      button: true,
      child: GestureDetector(
      onTap: isEarned
          ? () => _showBadgeDetail(badge)
          : null,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: isEarned
              ? MintColors.warning.withValues(alpha: 0.06)
              : MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEarned
                ? MintColors.warning.withValues(alpha: 0.2)
                : MintColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Icon(
                  badge.icon,
                  size: 32,
                  color: isEarned
                      ? MintColors.warning
                      : MintColors.textMuted.withValues(alpha: 0.4),
                ),
                if (isEarned)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: MintColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 10,
                      color: MintColors.white,
                    ),
                  ),
                if (!isEarned)
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: MintColors.textMuted.withValues(alpha: 0.5),
                  ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall(
                color: isEarned
                    ? MintColors.textPrimary
                    : MintColors.textMuted,
              ),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              s.achievementsBadgeMonths(badge.requiredStreak),
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showBadgeDetail(_BadgeInfo badge) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MintColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: MintSpacing.lg),
            Icon(badge.icon, size: 48, color: MintColors.warning),
            const SizedBox(height: MintSpacing.md),
            Text(
              badge.label,
              style: MintTextStyles.headlineMedium().copyWith(fontSize: 20),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodyMedium(),
            ),
            const SizedBox(height: MintSpacing.lg),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SECTION 3: Milestones
  // ════════════════════════════════════════════════════════════

  Widget _buildMilestonesSection(S s, List<MintMilestone> milestones) {
    // Group milestones by category
    final categories = <_MilestoneCategory>[
      _MilestoneCategory(
        title: s.achievementsCatPatrimoine,
        icon: Icons.account_balance_wallet,
        color: MintColors.success,
        milestones: milestones
            .where((m) => m.id.startsWith('patrimoine'))
            .toList(),
      ),
      _MilestoneCategory(
        title: s.achievementsCatPrevoyance,
        icon: Icons.savings,
        color: MintColors.indigo,
        milestones: milestones
            .where((m) => m.id == '3a_max' || m.id.startsWith('lpp'))
            .toList(),
      ),
      _MilestoneCategory(
        title: s.achievementsCatSecurite,
        icon: Icons.shield,
        color: MintColors.teal,
        milestones: milestones
            .where((m) => m.id.startsWith('emergency'))
            .toList(),
      ),
    ];

    // Additional categories from MilestoneType enum
    final additionalCategories = <_MilestoneCategory>[
      _MilestoneCategory(
        title: s.achievementsCatScoreFri,
        icon: Icons.trending_up,
        color: MintColors.info,
        milestoneTypes: [
          _MilestoneTypeInfo(
            type: MilestoneType.friAbove50,
            label: s.achievementsFriAbove50Label,
            description: s.achievementsFriAbove50Desc,
          ),
          _MilestoneTypeInfo(
            type: MilestoneType.friAbove70,
            label: s.achievementsFriAbove70Label,
            description: s.achievementsFriAbove70Desc,
          ),
          _MilestoneTypeInfo(
            type: MilestoneType.friAbove85,
            label: s.achievementsFriAbove85Label,
            description: s.achievementsFriAbove85Desc,
          ),
          _MilestoneTypeInfo(
            type: MilestoneType.friImproved10Points,
            label: s.achievementsFriImproved10Label,
            description: s.achievementsFriImproved10Desc,
          ),
        ],
      ),
      _MilestoneCategory(
        title: s.achievementsCatEngagement,
        icon: Icons.local_fire_department,
        color: MintColors.warning,
        milestoneTypes: [
          _MilestoneTypeInfo(
            type: MilestoneType.checkInStreak6Months,
            label: s.achievementsStreak6MonthsLabel,
            description: s.achievementsStreak6MonthsDesc,
          ),
          _MilestoneTypeInfo(
            type: MilestoneType.checkInStreak12Months,
            label: s.achievementsStreak12MonthsLabel,
            description: s.achievementsStreak12MonthsDesc,
          ),
          _MilestoneTypeInfo(
            type: MilestoneType.firstArbitrageCompleted,
            label: s.achievementsFirstArbitrageLabel,
            description: s.achievementsFirstArbitrageDesc,
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.achievementsMilestonesTitle,
          style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          s.achievementsMilestonesSubtitle,
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
        ),
        const SizedBox(height: MintSpacing.md),

        // Categories from StreakService.computeMilestones
        ...categories
            .where((c) => c.milestones != null && c.milestones!.isNotEmpty)
            .map((cat) => _buildMilestoneCategoryCard(cat)),

        // Categories from MilestoneType enum
        ...additionalCategories
            .where(
                (c) => c.milestoneTypes != null && c.milestoneTypes!.isNotEmpty)
            .map((cat) => _buildMilestoneTypeCategoryCard(cat)),
      ],
    );
  }

  Widget _buildMilestoneCategoryCard(_MilestoneCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: MintSpacing.md),
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: MintSpacing.sm),
              Text(
                category.title,
                style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          ...category.milestones!.map((m) => _buildMilestoneRow(m)),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow(MintMilestone milestone) {
    return Semantics(
      label: '${milestone.label} ${milestone.isReached ? "atteint" : "non atteint"}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: milestone.isReached
                    ? MintColors.success.withValues(alpha: 0.12)
                    : MintColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                milestone.isReached ? Icons.check_circle : milestone.icon,
                size: 20,
                color: milestone.isReached
                    ? MintColors.success
                    : MintColors.textMuted.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.label,
                    style: MintTextStyles.bodyMedium(
                      color: milestone.isReached
                          ? MintColors.textPrimary
                          : MintColors.textMuted,
                    ),
                  ),
                  Text(
                    milestone.description,
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (milestone.isReached)
              const Icon(
                Icons.check,
                color: MintColors.success,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneTypeCategoryCard(_MilestoneCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: MintSpacing.md),
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: MintSpacing.sm),
              Text(
                category.title,
                style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          ...category.milestoneTypes!.map((mt) => _buildMilestoneTypeRow(mt)),
        ],
      ),
    );
  }

  Widget _buildMilestoneTypeRow(_MilestoneTypeInfo info) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: MintColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag_outlined,
              size: 20,
              color: MintColors.textMuted.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label,
                  style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
                ),
                Text(
                  info.description,
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FOOTER: Disclaimer
  // ════════════════════════════════════════════════════════════

  Widget _buildDisclaimer(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: MintColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.achievementsDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  HELPER MODELS
// ════════════════════════════════════════════════════════════

class _BadgeInfo {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final int requiredStreak;

  const _BadgeInfo({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.requiredStreak,
  });
}

class _MilestoneCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<MintMilestone>? milestones;
  final List<_MilestoneTypeInfo>? milestoneTypes;

  const _MilestoneCategory({
    required this.title,
    required this.icon,
    required this.color,
    this.milestones,
    this.milestoneTypes,
  });
}

class _MilestoneTypeInfo {
  final MilestoneType type;
  final String label;
  final String description;

  const _MilestoneTypeInfo({
    required this.type,
    required this.label,
    required this.description,
  });
}
