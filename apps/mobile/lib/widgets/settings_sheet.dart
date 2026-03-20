import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Premium settings bottom sheet.
///
/// Fond porcelaine, handle bar, items on MintSurface(blanc).
/// Each item: icon textSecondary + title + chevron. Tap = pop + push route.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  /// Show the settings sheet from any context.
  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    final items = <_SettingsItem>[
      _SettingsItem(
        icon: Icons.verified_user_outlined,
        title: s.settingsConsentsTitle,
        subtitle: s.settingsConsentsSubtitle,
        route: '/profile/consent',
      ),
      _SettingsItem(
        icon: Icons.smart_toy_outlined,
        title: s.settingsSlmTitle,
        subtitle: s.settingsSlmSubtitle,
        route: '/profile/slm',
      ),
      _SettingsItem(
        icon: Icons.vpn_key_outlined,
        title: s.settingsByokTitle,
        subtitle: s.settingsByokSubtitle,
        route: '/profile/byok',
      ),
      _SettingsItem(
        icon: Icons.language_outlined,
        title: s.settingsLangueTitle,
        subtitle: s.settingsLangueSubtitle,
        route: '/settings/langue',
      ),
      _SettingsItem(
        icon: Icons.info_outline_rounded,
        title: s.settingsAboutTitle,
        subtitle: s.settingsAboutSubtitle,
        route: '/about',
      ),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: MintColors.porcelaine,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MintColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.only(
              left: MintSpacing.lg,
              right: MintSpacing.lg,
              top: MintSpacing.lg,
              bottom: MintSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.settingsSheetTitle,
                style: MintTextStyles.headlineMedium(),
              ),
            ),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.only(
              left: MintSpacing.lg,
              right: MintSpacing.lg,
              bottom: MintSpacing.xl,
            ),
            child: MintSurface(
              tone: MintSurfaceTone.blanc,
              padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
              child: Column(
                children: [
                  for (int i = 0; i < items.length; i++)
                    _SettingsRow(
                      item: items[i],
                      showDivider: i < items.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

class _SettingsRow extends StatelessWidget {
  final _SettingsItem item;
  final bool showDivider;

  const _SettingsRow({
    required this.item,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            context.push(item.route);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: MintSpacing.md,
              horizontal: MintSpacing.md,
            ),
            child: Row(
              children: [
                Icon(item.icon, color: MintColors.textSecondary, size: 20),
                const SizedBox(width: MintSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary,
                        ).copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
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
    );
  }
}
