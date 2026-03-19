import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// Tab 2 — Explorer
///
/// 7 hubs thématiques. Chaque hub ouvre un écran dédié avec
/// 3 parcours vedettes + "Voir tout".
///
/// Hubs: Retraite, Famille, Travail & Statut, Logement,
///        Fiscalité, Patrimoine & Succession, Santé & Protection
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: MintColors.white,
          surfaceTintColor: MintColors.white,
          title: Text(
            l.tabExplore,
            style: MintTextStyles.headlineMedium(),
          ),
          centerTitle: false,
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.lg,
            vertical: MintSpacing.md,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _HubCard(
                icon: Icons.beach_access_outlined,
                title: l.exploreHubRetraiteTitle,
                subtitle: l.exploreHubRetraiteSubtitle,
                color: MintColors.info,
                onTap: () => context.push('/explore/retraite'),
              ),
              const SizedBox(height: MintSpacing.md),
              _HubCard(
                icon: Icons.family_restroom_outlined,
                title: l.exploreHubFamilleTitle,
                subtitle: l.exploreHubFamilleSubtitle,
                color: MintColors.pink,
                onTap: () => context.push('/explore/famille'),
              ),
              const SizedBox(height: MintSpacing.md),
              _HubCard(
                icon: Icons.work_outline,
                title: l.exploreHubTravailTitle,
                subtitle: l.exploreHubTravailSubtitle,
                color: MintColors.purple,
                onTap: () => context.push('/explore/travail'),
              ),
              const SizedBox(height: MintSpacing.md),
              _HubCard(
                icon: Icons.home_outlined,
                title: l.exploreHubLogementTitle,
                subtitle: l.exploreHubLogementSubtitle,
                color: MintColors.teal,
                onTap: () => context.push('/explore/logement'),
              ),
              const SizedBox(height: MintSpacing.md),
              _HubCard(
                icon: Icons.receipt_long_outlined,
                title: l.exploreHubFiscaliteTitle,
                subtitle: l.exploreHubFiscaliteSubtitle,
                color: MintColors.deepOrange,
                onTap: () => context.push('/explore/fiscalite'),
              ),
              const SizedBox(height: MintSpacing.md),
              _HubCard(
                icon: Icons.account_balance_outlined,
                title: l.exploreHubPatrimoineTitle,
                subtitle: l.exploreHubPatrimoineSubtitle,
                color: MintColors.indigo,
                onTap: () => context.push('/explore/patrimoine'),
              ),
              const SizedBox(height: MintSpacing.md),
              _HubCard(
                icon: Icons.health_and_safety_outlined,
                title: l.exploreHubSanteTitle,
                subtitle: l.exploreHubSanteSubtitle,
                color: MintColors.success,
                onTap: () => context.push('/explore/sante'),
              ),
              const SizedBox(height: MintSpacing.xxl),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Hub card — clean, minimal, one tap to enter a domain.
class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(MintSpacing.lg),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MintColors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: MintSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: MintTextStyles.bodySmall(),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MintColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
