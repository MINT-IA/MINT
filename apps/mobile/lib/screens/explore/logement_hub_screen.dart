import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

class LogementHubScreen extends StatelessWidget {
  const LogementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        title: Text(l.exploreHubLogementTitle, style: MintTextStyles.headlineMedium()),
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
            title: l.logementHubFeaturedCapacite,
            subtitle: l.logementHubFeaturedCapaciteSub,
            icon: Icons.home_outlined,
            iconColor: MintColors.info,
            onTap: () => context.push('/hypotheque'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _FeaturedCard(
            title: l.logementHubFeaturedLocationPropriete,
            subtitle: l.logementHubFeaturedLocationProprieteSub,
            icon: Icons.compare_arrows_outlined,
            iconColor: MintColors.success,
            onTap: () => context.push('/arbitrage/location-vs-propriete'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _FeaturedCard(
            title: l.logementHubFeaturedVente,
            subtitle: l.logementHubFeaturedVenteSub,
            icon: Icons.sell_outlined,
            iconColor: MintColors.warning,
            onTap: () => context.push('/life-event/housing-sale'),
          ),
          const SizedBox(height: MintSpacing.xl),
          Text(
            l.exploreHubSeeAll,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _ToolRow(
            title: l.logementHubToolAmortissement,
            onTap: () => context.push('/mortgage/amortization'),
          ),
          _ToolRow(
            title: l.logementHubToolEplCombine,
            onTap: () => context.push('/mortgage/epl-combined'),
          ),
          _ToolRow(
            title: l.logementHubToolValeurLocative,
            onTap: () => context.push('/mortgage/imputed-rental'),
          ),
          _ToolRow(
            title: l.logementHubToolSaronFixe,
            onTap: () => context.push('/mortgage/saron-vs-fixed'),
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
