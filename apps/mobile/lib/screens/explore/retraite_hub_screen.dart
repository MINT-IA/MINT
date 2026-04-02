import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/action_insight_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/glossary_term.dart';

class RetraiteHubScreen extends StatelessWidget {
  const RetraiteHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    // Resolve cap for action insight — graceful degradation.
    CapDecision? cap;
    try {
      final profileProvider = context.watch<CoachProfileProvider>();
      if (profileProvider.hasProfile) {
        final profile = profileProvider.profile!;
        cap = CapEngine.compute(
          profile: profile,
          now: DateTime.now(),
          l: l,
          memory: const CapMemory(),
        );
      }
    } catch (_) {
      // Provider not in tree — no action insight shown.
    }

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: MintColors.porcelaine,
        title: Text(l.exploreHubRetraiteTitle, style: MintTextStyles.headlineMedium()),
        centerTitle: false,
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg,
          vertical: MintSpacing.md,
        ),
        children: [
          // ── ACTION INSIGHT (retirement-specific) ──
          if (cap != null && cap.ctaRoute != null)
            MintEntrance(child: ActionInsightWidget(
              contextLine: cap.whyNow,
              actionLine: cap.ctaLabel,
              impactLine: cap.expectedImpact,
              route: cap.ctaRoute,
            ))
          else
            ActionInsightWidget(
              contextLine: '',
              actionLine: l.actionInsightFallback,
              route: '/onboarding/quick',
            ),
          const SizedBox(height: MintSpacing.md),
          // Glossary quick-access: key retirement terms
          const MintEntrance(child: Wrap(
            spacing: MintSpacing.md,
            runSpacing: MintSpacing.sm,
            children: [
              GlossaryTerm(term: 'AVS'),
              GlossaryTerm(term: 'LPP'),
              GlossaryTerm(term: '3a'),
              GlossaryTerm(term: 'Taux de remplacement'),
            ],
          )),
          const SizedBox(height: MintSpacing.lg),
          MintEntrance(child: Text(
            l.exploreHubFeatured,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          )),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.retraiteHubFeaturedOverview,
            subtitle: l.retraiteHubFeaturedOverviewSub,
            icon: Icons.timeline_outlined,
            tone: MintSurfaceTone.sauge,
            onTap: () => context.push('/retraite'),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.retraiteHubFeaturedRenteCapital,
            subtitle: l.retraiteHubFeaturedRenteCapitalSub,
            icon: Icons.balance_outlined,
            tone: MintSurfaceTone.sauge,
            onTap: () => context.push('/rente-vs-capital'),
          ),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.retraiteHubFeaturedRachat,
            subtitle: l.retraiteHubFeaturedRachatSub,
            icon: Icons.add_chart_outlined,
            tone: MintSurfaceTone.sauge,
            onTap: () => context.push('/rachat-lpp'),
          ),
          const SizedBox(height: MintSpacing.xl),
          MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
            l.exploreHubSeeAll,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          )),
          const SizedBox(height: MintSpacing.md),
          _HubItemCard(
            title: l.retraiteHubToolPilier3a,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/pilier-3a'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.retraiteHubTool3aComparateur,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/3a-deep/comparator'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.retraiteHubTool3aRendement,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/3a-deep/real-return'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.retraiteHubTool3aRetrait,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/3a-deep/staggered-withdrawal'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.retraiteHubTool3aRetroactif,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/3a-retroactif'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.retraiteHubToolLibrePassage,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/libre-passage'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.retraiteHubToolDecaissement,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/decaissement'),
          ),
          const SizedBox(height: MintSpacing.sm),
          _HubItemCard(
            title: l.retraiteHubToolEpl,
            tone: MintSurfaceTone.blanc,
            onTap: () => context.push('/epl'),
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
      ))),
    );
  }
}

/// Unified hub item card — used for both featured and tool items.
/// Featured items have subtitle + icon; tool items are title-only.
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
