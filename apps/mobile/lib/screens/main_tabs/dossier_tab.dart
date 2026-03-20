import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/profile/trajectory_view.dart';
import 'package:mint_mobile/widgets/settings_sheet.dart';

/// Tab 3 — Dossier
///
/// "Ma vie financiere, ma trajectoire."
/// Hero: TrajectoryView (goal, known data, decisions, confidence).
/// Puis 4 liens: Profil, Couple (si applicable), Documents, Bilan.
/// Reglages accessibles via icone engrenage dans l'AppBar.
///
/// Design: fond porcelaine, MintSurface(blanc), espacement xl.
class DossierTab extends StatefulWidget {
  const DossierTab({super.key});

  @override
  State<DossierTab> createState() => _DossierTabState();
}

class _DossierTabState extends State<DossierTab> {
  CapMemory _capMemory = const CapMemory();

  @override
  void initState() {
    super.initState();
    _loadCapMemory();
  }

  Future<void> _loadCapMemory() async {
    final mem = await CapMemoryStore.load();
    if (mounted) {
      setState(() => _capMemory = mem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final hasProfile = provider.hasProfile;
    final profile = hasProfile ? provider.profile! : null;
    final firstName = hasProfile ? (profile!.firstName ?? '') : '';
    final isCouple = hasProfile && profile!.isCouple;

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
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: MintColors.textSecondary,
                  size: 22,
                ),
                tooltip: l.dossierReglages,
                onPressed: () => SettingsSheet.show(context),
              ),
              const SizedBox(width: MintSpacing.xs),
            ],
          ),

          // ═══════════════════════════════════════
          //  Hero: TrajectoryView
          // ═══════════════════════════════════════
          if (hasProfile)
            SliverToBoxAdapter(
              child: TrajectoryView(
                profile: profile!,
                capMemory: _capMemory,
              ),
            ),

          // ═══════════════════════════════════════
          //  Links: Profil, Couple, Documents, Bilan
          // ═══════════════════════════════════════
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                MintSurface(
                  tone: MintSurfaceTone.blanc,
                  padding:
                      const EdgeInsets.symmetric(vertical: MintSpacing.xs),
                  child: Column(
                    children: [
                      // -- Profil --
                      _DossierRow(
                        icon: Icons.person_outline,
                        title: firstName.isNotEmpty ? firstName : l.tabMoi,
                        subtitle: hasProfile
                            ? l.dossierProfileCompleted(
                                (provider.profileCompleteness * 100).round())
                            : l.dossierStartProfile,
                        onTap: () => context.push('/profile'),
                      ),

                      // -- Couple (conditional) --
                      if (isCouple)
                        _DossierRow(
                          icon: Icons.people_outline,
                          title: l.dossierCoupleTitle,
                          subtitle: l.dossierCoupleSubtitle,
                          onTap: () => context.push('/couple'),
                        ),

                      // -- Documents --
                      _DossierRow(
                        icon: Icons.folder_outlined,
                        title: l.dossierDocumentsTitle,
                        subtitle: l.dossierDocumentsSubtitle,
                        onTap: () => context.push('/documents'),
                      ),

                      // -- Bilan financier --
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
