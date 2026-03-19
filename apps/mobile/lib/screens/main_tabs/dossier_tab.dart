import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// Tab 3 — Dossier
///
/// "Mes données, mes documents, mes réglages."
/// Regroupe : Profil, Documents, Couple, Consentements, BYOK/SLM, Paramètres.
class DossierTab extends StatelessWidget {
  const DossierTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final firstName = provider.hasProfile
        ? (provider.profile!.firstName ?? '')
        : '';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: MintColors.white,
          surfaceTintColor: MintColors.white,
          title: Text(
            l.tabDossier,
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
              // ── Profile card ──
              _DossierSection(
                icon: Icons.person_outline,
                title: firstName.isNotEmpty
                    ? firstName
                    : l.tabMoi,
                subtitle: provider.hasProfile
                    ? l.dossierProfileCompleted((provider.profileCompleteness * 100).round())
                    : l.dossierStartProfile,
                onTap: () => context.push('/profile'),
              ),
              const SizedBox(height: MintSpacing.sm),

              // ── Documents ──
              _DossierSection(
                icon: Icons.folder_outlined,
                title: l.dossierDocumentsTitle,
                subtitle: l.dossierDocumentsSubtitle,
                onTap: () => context.push('/documents'),
              ),
              const SizedBox(height: MintSpacing.sm),

              // ── Couple ──
              _DossierSection(
                icon: Icons.people_outline,
                title: l.dossierCoupleTitle,
                subtitle: l.dossierCoupleSubtitle,
                onTap: () => context.push('/couple'),
              ),
              const SizedBox(height: MintSpacing.sm),

              // ── Bilan financier ──
              _DossierSection(
                icon: Icons.pie_chart_outline,
                title: l.dossierBilanTitle,
                subtitle: l.dossierBilanSubtitle,
                onTap: () => context.push('/profile/bilan'),
              ),

              const SizedBox(height: MintSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                child: Text(
                  l.dossierReglages,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textMuted,
                  ),
                ),
              ),

              // ── Consentements ──
              _DossierSection(
                icon: Icons.verified_user_outlined,
                title: l.dossierConsentsTitle,
                subtitle: l.dossierConsentsSubtitle,
                onTap: () => context.push('/profile/consent'),
              ),
              const SizedBox(height: MintSpacing.sm),

              // ── Modèle local (SLM) ──
              _DossierSection(
                icon: Icons.smart_toy_outlined,
                title: l.dossierSlmTitle,
                subtitle: l.dossierSlmSubtitle,
                onTap: () => context.push('/profile/slm'),
              ),
              const SizedBox(height: MintSpacing.sm),

              // ── Clé API (BYOK) ──
              _DossierSection(
                icon: Icons.vpn_key_outlined,
                title: l.dossierByokTitle,
                subtitle: l.dossierByokSubtitle,
                onTap: () => context.push('/profile/byok'),
              ),

              const SizedBox(height: MintSpacing.xxl),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DossierSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DossierSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MintSpacing.md,
            horizontal: MintSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, color: MintColors.textSecondary, size: 22),
              const SizedBox(width: MintSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MintTextStyles.titleMedium()
                          .copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      subtitle,
                      style: MintTextStyles.labelSmall(),
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
    );
  }
}
