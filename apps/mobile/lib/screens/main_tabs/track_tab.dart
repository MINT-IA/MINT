import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

/// Tab SUIVRE - Progrès et achievements
///
/// Focus sur la motivation et la fierté du chemin parcouru
class TrackTab extends StatelessWidget {
  const TrackTab({super.key});

  @override
  Widget build(BuildContext context) {
    final hasDebt = context.watch<ProfileProvider>().profile?.hasDebt ?? false;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildScoreSection(context),
                const SizedBox(height: 32),
                SafeModeGate(
                  hasDebt: hasDebt,
                  lockedTitle: 'Priorite au desendettement',
                  lockedMessage:
                      'Tes objectifs d\'epargne et d\'investissement sont suspendus '
                      'en mode protection. Concentre-toi sur la reduction de tes dettes.',
                  child: _buildGoalsSection(context),
                ),
                const SizedBox(height: 32),
                _buildImpactSection(context),
                const SizedBox(height: 32),
                _buildAchievementsSection(context),
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
      floating: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      title: Text(
        'SUIVRE',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildScoreSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.insert_chart_outlined,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'TON ÉVOLUTION',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                MintColors.primary.withOpacity(0.1),
                MintColors.appleSurface.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text(
                'Score de Santé Financière',
                style: TextStyle(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '78',
                    style: GoogleFonts.montserrat(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: MintColors.primary,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 24,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.78,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    MintColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.trending_up,
                    color: MintColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+12 pts depuis 3 mois',
                    style: TextStyle(
                      fontSize: 13,
                      color: MintColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.track_changes,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'OBJECTIFS EN COURS',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGoalProgress(
          title: 'Fonds d\'urgence',
          current: 2500,
          target: 3000,
          status: 'Plus que CHF 500 !',
          isCompleted: false,
        ),
        const SizedBox(height: 16),
        _buildGoalProgress(
          title: '3a ouvert',
          current: 0,
          target: pilier3aPlafondAvecLpp,
          status: 'En attente versement',
          isCompleted: false,
          subtitle: 'Économie fiscale : CHF 1\'764/an',
        ),
      ],
    );
  }

  Widget _buildGoalProgress({
    required String title,
    required double current,
    required double target,
    required String status,
    required bool isCompleted,
    String? subtitle,
  }) {
    final progress = current / target;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isCompleted ? MintColors.success : MintColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CHF ${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: MintColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? MintColors.success : MintColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: MintColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImpactSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.show_chart, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'IMPACT CUMULÉ',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildImpactCard(
                icon: Icons.savings_outlined,
                label: 'Économisé',
                value: 'CHF 3\'240',
                color: MintColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildImpactCard(
                icon: Icons.trending_down,
                label: 'Dettes réduites',
                value: '-CHF 1\'800',
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildImpactCard(
          icon: Icons.school_outlined,
          label: 'Modules complétés',
          value: '4/12',
          color: MintColors.warning,
        ),
      ],
    );
  }

  Widget _buildImpactCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'ACHIEVEMENTS',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAchievementBadge(
                icon: Icons.workspace_premium,
                title: 'Premier\nversement 3a',
                isUnlocked: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAchievementBadge(
                icon: Icons.bar_chart,
                title: 'Budget maîtrisé\n3 mois',
                isUnlocked: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAchievementBadge(
                icon: Icons.school,
                title: 'Expert\nPilier 3a',
                isUnlocked: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievementBadge({
    required IconData icon,
    required String title,
    required bool isUnlocked,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? MintColors.appleSurface : MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? MintColors.primary.withOpacity(0.3)
              : MintColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color:
                isUnlocked ? MintColors.primary : Colors.black.withOpacity(0.2),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isUnlocked ? MintColors.textPrimary : MintColors.textMuted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
