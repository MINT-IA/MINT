import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/coaching_service.dart';

// ────────────────────────────────────────────────────────────
//  COACHING PROACTIF SCREEN — Sprint S11
// ────────────────────────────────────────────────────────────
//
// Full-screen display of personalised coaching tips.
// Uses a demo profile in preview mode; will integrate with
// ProfileProvider when profile data is available.
// ────────────────────────────────────────────────────────────

class CoachingScreen extends StatefulWidget {
  const CoachingScreen({super.key});

  @override
  State<CoachingScreen> createState() => _CoachingScreenState();
}

class _CoachingScreenState extends State<CoachingScreen> {
  // Active filter
  String _activeFilter = 'tous';

  // All tips generated from the profile
  late List<CoachingTip> _allTips;

  // Demo profile for preview
  late CoachingProfile _demoProfile;

  @override
  void initState() {
    super.initState();
    _demoProfile = CoachingService.buildDemoProfile();
    _allTips = CoachingService.generateTips(profile: _demoProfile);
  }

  /// Filter categories.
  static const _filters = <String, String>{
    'tous': 'Tous',
    'haute': 'Haute priorite',
    'fiscalite': 'Fiscalite',
    'prevoyance': 'Prevoyance',
    'budget': 'Budget',
    'retraite': 'Retraite',
  };

  /// Filtered tips based on active filter.
  List<CoachingTip> get _filteredTips {
    if (_activeFilter == 'tous') return _allTips;
    if (_activeFilter == 'haute') {
      return _allTips
          .where((t) => t.priority == CoachingPriority.haute)
          .toList();
    }
    return _allTips.where((t) => t.category == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header section
                _buildHeader(),
                const SizedBox(height: 20),

                // Intro text
                _buildIntroCard(),
                const SizedBox(height: 24),

                // Filter chips
                _buildFilterChips(),
                const SizedBox(height: 24),

                // Tips count
                _buildTipsCount(),
                const SizedBox(height: 16),

                // Tips list or empty state
                if (_filteredTips.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredTips
                      .map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _CoachingTipCard(tip: tip),
                          ))
                      .toList(),

                const SizedBox(height: 24),

                // Demo mode badge
                _buildDemoModeBadge(),
                const SizedBox(height: 16),

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'COACHING PROACTIF',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.tips_and_updates,
            color: Colors.amber.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coaching proactif',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vos suggestions personnalisees',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: MintColors.info,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Suggestions personnalisees basees sur votre profil. '
              'Plus votre profil est complet, plus les conseils sont pertinents.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.entries.map((entry) {
          final isActive = _activeFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),
              selected: isActive,
              onSelected: (selected) {
                setState(() {
                  _activeFilter = selected ? entry.key : 'tous';
                });
              },
              selectedColor: MintColors.primary,
              backgroundColor: MintColors.surface,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? Colors.white : MintColors.textPrimary,
              ),
              side: BorderSide(
                color: isActive ? MintColors.primary : MintColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTipsCount() {
    final count = _filteredTips.length;
    final label = count == 1 ? '1 conseil' : '$count conseils';
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: MintColors.textMuted,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: MintColors.success,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Votre profil est complet et bien gere. Bravo !',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoModeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: Colors.blue.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode demo : profil exemple (35 ans, VD, CHF 85\'000). '
              'Completez votre diagnostic pour des conseils personnalises.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.blue.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange.shade700,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les suggestions presentees sont des pistes de reflexion '
              'basees sur des estimations simplifiees. Elles ne constituent '
              'pas un conseil financier personnalise. Consultez un '
              'professionnel qualifie avant toute decision.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  Coaching Tip Card Widget
// ────────────────────────────────────────────────────────────

class _CoachingTipCard extends StatelessWidget {
  final CoachingTip tip;

  const _CoachingTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF1D1D1F).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: MintColors.border.withOpacity(0.6),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: priority badge + icon + title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(tip.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tip.icon,
                    color: _getCategoryColor(tip.category),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Priority badge
                      _PriorityBadge(priority: tip.priority),
                      const SizedBox(height: 6),
                      // Title
                      Text(
                        tip.title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            color: MintColors.border.withOpacity(0.4),
            height: 1,
          ),

          // Body: message
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              tip.message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),

          // Impact estimate (if available)
          if (tip.estimatedImpactChf != null && tip.estimatedImpactChf! > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: MintColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: MintColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Impact estime : ${CoachingService.formatChf(tip.estimatedImpactChf!)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Footer: source + action
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: MintColors.surface.withOpacity(0.5),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Source
                Expanded(
                  child: Text(
                    tip.source,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Action button
                TextButton(
                  onPressed: () {
                    _handleTipAction(context, tip);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    backgroundColor: MintColors.primary.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    tip.action,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MintColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Route to the appropriate screen based on tip ID.
  void _handleTipAction(BuildContext context, CoachingTip tip) {
    switch (tip.id) {
      case 'deadline_3a':
      case 'missing_3a':
      case '3a_not_maxed':
        context.push('/simulator/3a');
      case 'lpp_buyback':
        context.push('/tools');
      case 'tax_deadline':
        // No specific screen yet — could link to a checklist
        break;
      case 'retirement_countdown':
        context.push('/simulator/rente-capital');
      case 'emergency_fund':
      case 'budget_missing':
        context.push('/budget');
      case 'debt_ratio':
        context.push('/check/debt');
      case 'part_time_gap':
      case 'independant_alert':
        context.push('/advisor');
      default:
        break;
    }
  }

  /// Get a color for the tip category.
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'fiscalite':
        return Colors.green.shade700;
      case 'prevoyance':
        return const Color(0xFF4F46E5);
      case 'budget':
        return Colors.amber.shade700;
      case 'retraite':
        return Colors.purple.shade600;
      default:
        return MintColors.primary;
    }
  }
}

// ────────────────────────────────────────────────────────────
//  Priority Badge Widget
// ────────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  final CoachingPriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      CoachingPriority.haute => ('Haute priorite', MintColors.error),
      CoachingPriority.moyenne => ('Priorite moyenne', MintColors.warning),
      CoachingPriority.basse => ('Information', MintColors.info),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
