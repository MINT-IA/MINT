/// GoalSelectorSheet — bottom sheet for explicit goal selection.
///
/// Lets the user choose their active focus rather than relying on MINT's
/// auto-detection. Surfaces as a modal bottom sheet from PulseScreen.
///
/// UX contract:
///   - "Auto" option at the top (clear selection → MINT decides).
///   - Available goals as cards: icon + title + description.
///   - Selected goal: MintSurface(tone: sauge) with checkmark.
///   - Unselected goals: MintSurface(tone: blanc).
///   - Dismissible via drag or back button.
///   - All strings via AppLocalizations.
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/goal_selection_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows the [GoalSelectorSheet] as a modal bottom sheet.
///
/// [currentIntentTag] — the currently active intent tag (null = auto).
/// [profile]          — used to filter available goals by relevance.
/// [onSelected]       — called with the new intent tag (null = auto).
Future<void> showGoalSelectorSheet(
  BuildContext context, {
  required CoachProfile profile,
  String? currentIntentTag,
  required void Function(String? intentTag) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GoalSelectorSheet(
      profile: profile,
      currentIntentTag: currentIntentTag,
      onSelected: onSelected,
    ),
  );
}

/// The goal selector sheet widget.
class GoalSelectorSheet extends StatefulWidget {
  final CoachProfile profile;
  final String? currentIntentTag;
  final void Function(String? intentTag) onSelected;

  const GoalSelectorSheet({
    super.key,
    required this.profile,
    this.currentIntentTag,
    required this.onSelected,
  });

  @override
  State<GoalSelectorSheet> createState() => _GoalSelectorSheetState();
}

class _GoalSelectorSheetState extends State<GoalSelectorSheet> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentIntentTag;
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final goals = GoalSelectionService.availableGoals(widget.profile, l);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Drag handle ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: MintSpacing.md),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MintSpacing.lg,
                MintSpacing.lg,
                MintSpacing.lg,
                MintSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l.goalSelectorTitle,
                  style: MintTextStyles.headlineMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ),

            // ── Goal list ──────────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.lg,
                ),
                children: [
                  // Auto option (always first)
                  _buildAutoCard(l),
                  const SizedBox(height: MintSpacing.sm),

                  // Available goals
                  ...goals.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                      child: _buildGoalCard(g, l),
                    ),
                  ),

                  const SizedBox(height: MintSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AUTO CARD ───────────────────────────────────────────────────────────

  Widget _buildAutoCard(S l) {
    final isSelected = _selected == null;

    return Semantics(
      label: '${l.goalSelectorAuto} — ${l.goalSelectorAutoDesc}',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => _handleSelect(null),
        child: MintSurface(
          tone: isSelected ? MintSurfaceTone.sauge : MintSurfaceTone.blanc,
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(width: MintSpacing.md),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.goalSelectorAuto,
                      style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.goalSelectorAutoDesc,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Checkmark
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: MintColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── GOAL CARD ────────────────────────────────────────────────────────────

  Widget _buildGoalCard(SelectableGoal goal, S l) {
    final isSelected = _selected == goal.intentTag;
    final title = GoalSelectionService.resolveTitle(goal.titleKey, l);
    final description =
        GoalSelectionService.resolveDescription(goal.descriptionKey, l);

    return Semantics(
      label: '$title — $description',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => _handleSelect(goal.intentTag),
        child: MintSurface(
          tone: isSelected ? MintSurfaceTone.sauge : MintSurfaceTone.blanc,
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _resolveIcon(goal.iconName),
                  size: 20,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(width: MintSpacing.md),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Checkmark or chevron
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: MintColors.primary,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: MintColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SELECTION HANDLER ────────────────────────────────────────────────────

  Future<void> _handleSelect(String? intentTag) async {
    setState(() => _selected = intentTag);

    // Persist asynchronously — UI update is immediate.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (intentTag == null) {
        await GoalSelectionService.clearSelectedGoal(prefs);
      } else {
        await GoalSelectionService.setSelectedGoal(intentTag, prefs);
      }
    } catch (_) {
      // Graceful degradation: selection still applies for this session.
    }

    // Notify parent and dismiss.
    widget.onSelected(intentTag);
    if (mounted) Navigator.of(context).pop();
  }

  // ── ICON RESOLVER ────────────────────────────────────────────────────────

  /// Maps an icon name string to the corresponding [IconData].
  static IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'beach_access_outlined':
        return Icons.beach_access_outlined;
      case 'account_balance_wallet_outlined':
        return Icons.account_balance_wallet_outlined;
      case 'savings_outlined':
        return Icons.savings_outlined;
      case 'home_outlined':
        return Icons.home_outlined;
      case 'trending_down_outlined':
        return Icons.trending_down_outlined;
      case 'child_care_outlined':
        return Icons.child_care_outlined;
      case 'business_center_outlined':
        return Icons.business_center_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
