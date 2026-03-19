import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

class RetraiteHubScreen extends StatelessWidget {
  const RetraiteHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        title: Text(l.exploreHubRetraiteTitle, style: MintTextStyles.headlineMedium()),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        children: [
          Text(
            l.exploreHubFeatured,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _FeaturedCard(
            title: l.retraiteHubFeaturedOverview,
            subtitle: l.retraiteHubFeaturedOverviewSub,
            icon: Icons.timeline_outlined,
            iconColor: MintColors.info,
            onTap: () => context.push('/retraite'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _FeaturedCard(
            title: l.retraiteHubFeaturedRenteCapital,
            subtitle: l.retraiteHubFeaturedRenteCapitalSub,
            icon: Icons.balance_outlined,
            iconColor: MintColors.success,
            onTap: () => context.push('/rente-vs-capital'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _FeaturedCard(
            title: l.retraiteHubFeaturedRachat,
            subtitle: l.retraiteHubFeaturedRachatSub,
            icon: Icons.add_chart_outlined,
            iconColor: MintColors.purple,
            onTap: () => context.push('/rachat-lpp'),
          ),
          const SizedBox(height: MintSpacing.xl),
          Text(
            l.exploreHubSeeAll,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _ToolRow(
            title: l.retraiteHubToolPilier3a,
            onTap: () => context.push('/pilier-3a'),
          ),
          _ToolRow(
            title: l.retraiteHubTool3aComparateur,
            onTap: () => context.push('/3a-deep/comparator'),
          ),
          _ToolRow(
            title: l.retraiteHubTool3aRendement,
            onTap: () => context.push('/3a-deep/real-return'),
          ),
          _ToolRow(
            title: l.retraiteHubTool3aRetrait,
            onTap: () => context.push('/3a-deep/staggered-withdrawal'),
          ),
          _ToolRow(
            title: l.retraiteHubTool3aRetroactif,
            onTap: () => context.push('/3a-retroactif'),
          ),
          _ToolRow(
            title: l.retraiteHubToolLibrePassage,
            onTap: () => context.push('/libre-passage'),
          ),
          _ToolRow(
            title: l.retraiteHubToolDecaissement,
            onTap: () => context.push('/decaissement'),
          ),
          _ToolRow(
            title: l.retraiteHubToolEpl,
            onTap: () => context.push('/epl'),
          ),
          const SizedBox(height: MintSpacing.xl),
          TextButton.icon(
            onPressed: () => context.push('/education/hub'),
            icon: const Icon(
              Icons.school_outlined,
              size: 16,
              color: MintColors.info,
            ),
            label: Text(
              l.exploreHubLearnMore,
              style: MintTextStyles.bodySmall(color: MintColors.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconColor = MintColors.info,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.border.withAlpha(128),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MintTextStyles.titleMedium()),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    subtitle,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: MintColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(title, style: MintTextStyles.bodyMedium()),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: MintColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
