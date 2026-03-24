import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

class SanteHubScreen extends StatelessWidget {
  const SanteHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: MintColors.porcelaine,
        title: Text(l.exploreHubSanteTitle, style: MintTextStyles.headlineMedium()),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg,
          vertical: MintSpacing.md,
        ),
        children: [
          MintEntrance(child: Text(
            l.exploreHubFeatured,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          )),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.santeHubFeaturedFranchise,
            subtitle: l.santeHubFeaturedFranchiseSub,
            icon: Icons.health_and_safety_outlined,
            tone: MintSurfaceTone.bleu,
            onTap: () => context.push('/assurances/lamal'),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.santeHubFeaturedInvalidite,
            subtitle: l.santeHubFeaturedInvaliditeSub,
            icon: Icons.accessible_outlined,
            tone: MintSurfaceTone.bleu,
            onTap: () => context.push('/invalidite'),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.santeHubFeaturedCheckup,
            subtitle: l.santeHubFeaturedCheckupSub,
            icon: Icons.verified_user_outlined,
            tone: MintSurfaceTone.bleu,
            onTap: () => context.push('/assurances/coverage'),
          ),
          const SizedBox(height: MintSpacing.xl),
          MintEntrance(delay: Duration(milliseconds: 100), child: Text(
            l.exploreHubSeeAll,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          )),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.santeHubToolAssuranceInvalidite,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/disability/insurance'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.santeHubToolInvaliditeIndependant,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/disability/self-employed'),
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
