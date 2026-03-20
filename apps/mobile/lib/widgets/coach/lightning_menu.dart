import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Data model for a single item in the Lightning Menu.
class LightningMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String action;
  final MintSurfaceTone tone;

  const LightningMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
    required this.tone,
  });
}

/// Premium bottom sheet triggered by the bolt button in the chat input bar.
///
/// Shows available widgets/simulators as tappable cards. Items adapt
/// to the user's profile (couple, debt, independent, age >= 50).
/// Tapping an item closes the sheet and sends the action as a message
/// to the coach via [onSendMessage].
class LightningMenu extends StatelessWidget {
  final CoachProfile? profile;
  final void Function(String message) onSendMessage;

  const LightningMenu({
    super.key,
    required this.profile,
    required this.onSendMessage,
  });

  /// Always-visible default items.
  List<LightningMenuItem> _defaultItems(S s) => [
        LightningMenuItem(
          title: s.lightningMenuRetirementTitle,
          subtitle: s.lightningMenuRetirementSubtitle,
          icon: Icons.trending_up_rounded,
          action: s.lightningMenuRetirementAction,
          tone: MintSurfaceTone.sauge,
        ),
        LightningMenuItem(
          title: s.lightningMenuBudgetTitle,
          subtitle: s.lightningMenuBudgetSubtitle,
          icon: Icons.account_balance_wallet_rounded,
          action: s.lightningMenuBudgetAction,
          tone: MintSurfaceTone.bleu,
        ),
        LightningMenuItem(
          title: s.lightningMenuRenteCapitalTitle,
          subtitle: s.lightningMenuRenteCapitalSubtitle,
          icon: Icons.compare_arrows_rounded,
          action: s.lightningMenuRenteCapitalAction,
          tone: MintSurfaceTone.peche,
        ),
        LightningMenuItem(
          title: s.lightningMenuScoreTitle,
          subtitle: s.lightningMenuScoreSubtitle,
          icon: Icons.speed_rounded,
          action: s.lightningMenuScoreAction,
          tone: MintSurfaceTone.sauge,
        ),
      ];

  /// Context-dependent items based on profile data.
  List<LightningMenuItem> _contextualItems(
    CoachProfile profile,
    S s,
  ) {
    final items = <LightningMenuItem>[];

    if (profile.isCouple) {
      items.add(LightningMenuItem(
        title: s.lightningMenuCoupleTitle,
        subtitle: s.lightningMenuCoupleSubtitle,
        icon: Icons.people_rounded,
        action: s.lightningMenuCoupleAction,
        tone: MintSurfaceTone.bleu,
      ));
    }

    if (profile.dettes.hasDette) {
      items.add(LightningMenuItem(
        title: s.lightningMenuDebtTitle,
        subtitle: s.lightningMenuDebtSubtitle,
        icon: Icons.trending_down_rounded,
        action: s.lightningMenuDebtAction,
        tone: MintSurfaceTone.peche,
      ));
    }

    if (profile.employmentStatus == 'independant') {
      items.add(LightningMenuItem(
        title: s.lightningMenuIndependantTitle,
        subtitle: s.lightningMenuIndependantSubtitle,
        icon: Icons.shield_rounded,
        action: s.lightningMenuIndependantAction,
        tone: MintSurfaceTone.sauge,
      ));
    }

    if (profile.age >= 50) {
      items.add(LightningMenuItem(
        title: s.lightningMenuRetirementPrepTitle,
        subtitle: s.lightningMenuRetirementPrepSubtitle,
        icon: Icons.event_rounded,
        action: s.lightningMenuRetirementPrepAction,
        tone: MintSurfaceTone.peche,
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final defaults = _defaultItems(s);
    final contextual =
        profile != null ? _contextualItems(profile!, s) : <LightningMenuItem>[];
    final allItems = [...defaults, ...contextual];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
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
              bottom: MintSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.lightningMenuTitle,
                style: MintTextStyles.headlineMedium(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: MintSpacing.lg,
              right: MintSpacing.lg,
              bottom: MintSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.lightningMenuSubtitle,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
            ),
          ),

          // Items list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(
                left: MintSpacing.lg,
                right: MintSpacing.lg,
                bottom: MintSpacing.xl,
              ),
              itemCount: allItems.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: MintSpacing.sm),
              itemBuilder: (context, index) {
                final item = allItems[index];
                return _LightningMenuItemTile(
                  item: item,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSendMessage(item.action);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A single tappable row inside the Lightning Menu.
class _LightningMenuItemTile extends StatelessWidget {
  final LightningMenuItem item;
  final VoidCallback onTap;

  const _LightningMenuItemTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MintSurface(
        tone: item.tone,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Row(
          children: [
            // Icon
            Icon(
              item.icon,
              size: 20,
              color: MintColors.textSecondary,
            ),
            const SizedBox(width: MintSpacing.md),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: MintTextStyles.titleMedium(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: MintColors.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
