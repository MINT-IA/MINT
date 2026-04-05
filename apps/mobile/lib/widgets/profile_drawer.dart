import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Right-side drawer replacing DossierTab.
///
/// Wire Spec V2 §3.6 — Profile/Dossier becomes a drawer accessible
/// via the user icon in MintHome header. Contains: profile summary,
/// plan progress, couple, documents, and settings.
class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final coachProvider = context.watch<CoachProfileProvider>();
    final profile = coachProvider.profile;

    return Drawer(
      backgroundColor: MintColors.craie,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Profile Header ──
            _buildProfileHeader(context, profile, l10n),
            const Divider(height: 1, color: MintColors.ardoise),

            // ── Mon profil ──
            _buildSection(
              context,
              icon: Icons.person_outline,
              title: l10n.drawerMyProfile,
              onTap: () => _navigate(context, '/profile'),
            ),

            // ── Mon bilan ──
            _buildSection(
              context,
              icon: Icons.bar_chart_outlined,
              title: l10n.drawerMyReport,
              onTap: () => _navigate(context, '/profile/bilan'),
            ),

            // ── Couple (only if in a couple) ──
            if (profile != null && profile.isCouple)
              _buildSection(
                context,
                icon: Icons.people_outline,
                title: l10n.drawerCouple,
                onTap: () => _navigate(context, '/couple'),
              ),

            // ── Mes documents ──
            _buildSection(
              context,
              icon: Icons.description_outlined,
              title: l10n.drawerDocuments,
              onTap: () => _navigate(context, '/documents'),
              trailing: Icons.camera_alt_outlined,
              trailingAction: () => _navigate(context, '/scan'),
            ),

            // ── Historique coach ──
            _buildSection(
              context,
              icon: Icons.history_outlined,
              title: l10n.drawerCoachHistory,
              onTap: () => _navigate(context, '/coach/history'),
            ),

            const Divider(height: 1, color: MintColors.ardoise),

            // ── Paramètres ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MintSpacing.md,
                MintSpacing.md,
                MintSpacing.md,
                MintSpacing.xs,
              ),
              child: Text(
                l10n.drawerSettings,
                style: MintTextStyles.labelMedium(color: MintColors.ardoise),
              ),
            ),

            _buildSection(
              context,
              icon: Icons.key_outlined,
              title: l10n.drawerApiKey,
              onTap: () => _navigate(context, '/profile/byok'),
            ),
            _buildSection(
              context,
              icon: Icons.shield_outlined,
              title: l10n.drawerPrivacy,
              onTap: () => _navigate(context, '/profile/consent'),
            ),
            _buildSection(
              context,
              icon: Icons.language_outlined,
              title: l10n.drawerLanguage,
              onTap: () {
                // TODO: inline language picker
              },
            ),
            _buildSection(
              context,
              icon: Icons.visibility_outlined,
              title: l10n.drawerDataTransparency,
              onTap: () => _navigate(context, '/profile/data-transparency'),
            ),

            const SizedBox(height: MintSpacing.xl),

            // ── Déconnexion ──
            _buildSection(
              context,
              icon: Icons.logout_outlined,
              title: l10n.drawerLogout,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/');
              },
              textColor: MintColors.corailDiscret,
            ),

            const SizedBox(height: MintSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    CoachProfile? profile,
    S l10n,
  ) {
    if (profile == null) {
      return Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Text(
          l10n.drawerNoProfile,
          style: MintTextStyles.bodyLarge(),
        ),
      );
    }

    final age = profile.age;
    final ageDisplay = age > 0 ? l10n.ageYears(age.toString()) : '';
    final cantonDisplay = profile.canton;
    final separator =
        ageDisplay.isNotEmpty && cantonDisplay.isNotEmpty ? ' \u2022 ' : '';

    return Padding(
      padding: const EdgeInsets.all(MintSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.firstName ?? l10n.drawerDefaultName,
            style:
                MintTextStyles.headlineMedium(color: MintColors.textPrimary),
          ),
          if (ageDisplay.isNotEmpty || cantonDisplay.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.xs),
            Text(
              '$ageDisplay$separator$cantonDisplay',
              style: MintTextStyles.bodyMedium(color: MintColors.ardoise),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    IconData? trailing,
    VoidCallback? trailingAction,
    Color? textColor,
  }) {
    final color = textColor ?? MintColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: MintTextStyles.bodyMedium(color: color),
      ),
      trailing: trailing != null
          ? IconButton(
              icon: Icon(trailing, color: MintColors.ardoise, size: 20),
              onPressed: trailingAction,
            )
          : const Icon(
              Icons.chevron_right,
              color: MintColors.ardoise,
              size: 20,
            ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md,
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.of(context).pop(); // Close drawer
    context.push(route);
  }
}
