import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final profileProvider = context.watch<CoachProfileProvider>();
    final profile = profileProvider.profile;

    // If no profile yet, show empty state
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            s.achievementsTitle,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
        ),
        body: Center(
          child: Text(
            s.achievementsEmptyProfile,
            style: GoogleFonts.inter(color: MintColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final streakResult = StreakService.compute(profile);
    final milestones = StreakService.computeMilestones(profile);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar with gradient ────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                s.achievementsTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: MintColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MintColors.primary, MintColors.primaryLight],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.white),
              onPressed: () => context.pop(),
            ),
          ),

          // ── Content ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  // Section 1: Daily Streak Hero
                  _buildDailyStreakHero(s),
                  const SizedBox(height: 28),

                  // Section 2: Badges
                  _buildBadgesSection(s, streakResult),
                  const SizedBox(height: 28),

                  // Section 3: Milestones
                  _buildMilestonesSection(s, milestones),
                  const SizedBox(height: 28),

                  // Footer: Disclaimer
                  _buildDisclaimer(s),
                  const SizedBox(height: 20),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SECTION 1: Daily Streak Hero
  // ════════════════════════════════════════════════════════════

  Widget _buildDailyStreakHero(S s) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Row(
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
              const SizedBox(width: 12),
              Text(
                '$_dailyStreak',
                style: GoogleFonts.montserrat(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: _dailyStreak > 0
                      ? MintColors.warning
                      : MintColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _dailyStreak == 1
                    ? s.achievementsDaysSingular
                    : s.achievementsDaysPlural,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Longest streak + total days
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip(
                Icons.emoji_events_outlined,
                s.achievementsRecord(_longestStreak),
              ),
              const SizedBox(width: 16),
              _buildStatChip(
                Icons.calendar_today_outlined,
                s.achievementsTotalDays(_totalDays),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Weekly calendar dots (last 7 days)
          _buildWeeklyCalendar(s),
          const SizedBox(height: 16),

          // "Engage today" CTA
          if (!_engagedToday)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MintColors.info,
                      ),
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
                const SizedBox(width: 8),
                Text(
                  s.achievementsEngagedToday,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.success,
                  ),
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
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MintColors.textSecondary,
            ),
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

        return Column(
          children: [
            Text(
              dayLabels[date.weekday - 1],
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: MintColors.textMuted,
              ),
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
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: MintColors.textMuted,
                        ),
                      ),
              ),
            ),
          ],
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
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.achievementsBadgesSubtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
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
    return GestureDetector(
      onTap: isEarned
          ? () => _showBadgeDetail(badge)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEarned
              ? MintColors.warning.withValues(alpha: 0.06)
              : MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEarned
                ? MintColors.warning.withValues(alpha: 0.2)
                : MintColors.lightBorder,
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
            const SizedBox(height: 8),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isEarned
                    ? MintColors.textPrimary
                    : MintColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              s.achievementsBadgeMonths(badge.requiredStreak),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            Icon(badge.icon, size: 48, color: MintColors.warning),
            const SizedBox(height: 16),
            Text(
              badge.label,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
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
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.achievementsMilestonesSubtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: 8),
              Text(
                category.title,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...category.milestones!.map((m) => _buildMilestoneRow(m)),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow(MintMilestone milestone) {
    return Padding(
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: milestone.isReached
                        ? MintColors.textPrimary
                        : MintColors.textMuted,
                  ),
                ),
                Text(
                  milestone.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
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
    );
  }

  Widget _buildMilestoneTypeCategoryCard(_MilestoneCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: 8),
              Text(
                category.title,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textMuted,
                  ),
                ),
                Text(
                  info.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.disclaimerBg,
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
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
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
