import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Tab 3 — Dossier
///
/// "Mes données, mes documents, mes réglages."
/// Regroupe : Profil, Documents, Couple, Consentements, BYOK/SLM, Paramètres.
///
/// Design: fond porcelaine, sections MintSurface(blanc), espacement xl.
/// Espace personnel calme — pas de couleurs vives, icônes textSecondary.
class DossierTab extends StatelessWidget {
  const DossierTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final firstName = provider.hasProfile
        ? (provider.profile!.firstName ?? '')
        : '';

    return ColoredBox(
      color: MintColors.porcelaine,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.porcelaine,
            surfaceTintColor: MintColors.porcelaine,
            elevation: 0,
            title: Text(
              l.tabDossier,
              style: MintTextStyles.headlineMedium(
                color: MintColors.textPrimary,
              ),
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
                // ═══════════════════════════════════════
                //  Mon dossier
                // ═══════════════════════════════════════
                MintSurface(
                  tone: MintSurfaceTone.blanc,
                  padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
                  child: Column(
                    children: [
                      // ── Profile ──
                      _DossierRow(
                        icon: Icons.person_outline,
                        title: firstName.isNotEmpty
                            ? firstName
                            : l.tabMoi,
                        subtitle: provider.hasProfile
                            ? l.dossierProfileCompleted((provider.profileCompleteness * 100).round())
                            : l.dossierStartProfile,
                        onTap: () => context.push('/profile'),
                      ),

                      // ── Documents ──
                      _DossierRow(
                        icon: Icons.folder_outlined,
                        title: l.dossierDocumentsTitle,
                        subtitle: l.dossierDocumentsSubtitle,
                        onTap: () => context.push('/documents'),
                      ),

                      // ── Couple ──
                      _DossierRow(
                        icon: Icons.people_outline,
                        title: l.dossierCoupleTitle,
                        subtitle: l.dossierCoupleSubtitle,
                        onTap: () => context.push('/couple'),
                      ),

                      // ── Bilan financier ──
                      _DossierRow(
                        icon: Icons.pie_chart_outline,
                        title: l.dossierBilanTitle,
                        subtitle: l.dossierBilanSubtitle,
                        onTap: () => context.push('/profile/bilan'),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MintSpacing.xl),

                // ═══════════════════════════════════════
                //  Réglages
                // ═══════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.only(
                    left: MintSpacing.xs,
                    bottom: MintSpacing.sm,
                  ),
                  child: Text(
                    l.dossierReglages,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textMuted,
                    ),
                  ),
                ),

                MintSurface(
                  tone: MintSurfaceTone.blanc,
                  padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
                  child: Column(
                    children: [
                      // ── Consentements ──
                      _DossierRow(
                        icon: Icons.verified_user_outlined,
                        title: l.dossierConsentsTitle,
                        subtitle: l.dossierConsentsSubtitle,
                        onTap: () => context.push('/profile/consent'),
                      ),

                      // ── Modèle local (SLM) ──
                      _DossierRow(
                        icon: Icons.smart_toy_outlined,
                        title: l.dossierSlmTitle,
                        subtitle: l.dossierSlmSubtitle,
                        onTap: () => context.push('/profile/slm'),
                      ),

                      // ── Clé API (BYOK) ──
                      _DossierRow(
                        icon: Icons.vpn_key_outlined,
                        title: l.dossierByokTitle,
                        subtitle: l.dossierByokSubtitle,
                        onTap: () => context.push('/profile/byok'),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row inside a dossier section surface.
/// Uses spacing instead of borders between items.
class _DossierRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _DossierRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MintSpacing.md,
                horizontal: MintSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(icon, color: MintColors.textSecondary, size: 20),
                  const SizedBox(width: MintSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MintTextStyles.titleMedium(
                            color: MintColors.textPrimary,
                          ).copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MintColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: Divider(
                height: 1,
                color: MintColors.textPrimary.withValues(alpha: 0.05),
              ),
            ),
        ],
      ),
    );
  }
}
