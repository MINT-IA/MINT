import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class LogementHubScreen extends StatelessWidget {
  const LogementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: MintColors.porcelaine,
        title: Text(l.exploreHubLogementTitle, style: MintTextStyles.headlineMedium()),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg,
          vertical: MintSpacing.md,
        ),
        children: [
          Text(
            l.exploreHubFeatured,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.logementHubFeaturedCapacite,
            subtitle: l.logementHubFeaturedCapaciteSub,
            icon: Icons.home_outlined,
            tone: MintSurfaceTone.craie,
            onTap: () => context.push('/hypotheque'),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.logementHubFeaturedLocationPropriete,
            subtitle: l.logementHubFeaturedLocationProprieteSub,
            icon: Icons.compare_arrows_outlined,
            tone: MintSurfaceTone.craie,
            onTap: () => context.push('/arbitrage/location-vs-propriete'),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.logementHubFeaturedVente,
            subtitle: l.logementHubFeaturedVenteSub,
            icon: Icons.sell_outlined,
            tone: MintSurfaceTone.craie,
            onTap: () => context.push('/life-event/housing-sale'),
          ),
          const SizedBox(height: MintSpacing.xl),
          Text(
            l.exploreHubSeeAll,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.logementHubToolAmortissement,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/mortgage/amortization'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.logementHubToolEplCombine,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/mortgage/epl-combined'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.logementHubToolValeurLocative,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/mortgage/imputed-rental'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.logementHubToolSaronFixe,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/mortgage/saron-vs-fixed'),
          ),
          const SizedBox(height: MintSpacing.xl),
          TextButton.icon(
            onPressed: () => context.push('/education/hub'),
            icon: const Icon(
              Icons.school_outlined,
              size: 16,
              color: MintColors.textMuted,
            ),
            label: Text(
              l.exploreHubLearnMore,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
          ),
          const SizedBox(height: MintSpacing.xxl),
        ],
      ),
    );
  }
}

class _HubItemCard extends StatelessWidget {
  const _HubItemCard({
    required this.title,
    required this.tone,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final MintSurfaceTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: MintSurface(
          tone: tone,
          padding: EdgeInsets.symmetric(
            horizontal: MintSpacing.lg,
            vertical: subtitle != null ? MintSpacing.lg : MintSpacing.md,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: MintColors.textSecondary, size: 22),
                const SizedBox(width: MintSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: subtitle != null
                          ? MintTextStyles.titleMedium()
                          : MintTextStyles.bodyMedium(),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        subtitle!,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: MintColors.textMuted.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
