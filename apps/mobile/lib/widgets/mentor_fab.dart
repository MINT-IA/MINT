import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Coach MINT FAB — always-accessible entry point to the coach.
///
/// Tapping opens a compact bottom sheet with 3 contextual quick actions
/// instead of the old 5-button "Mentor Advisor" menu.
// TODO: add Semantics for accessibility
class MentorFAB extends StatelessWidget {
  const MentorFAB({super.key, this.currentTabIndex = 0});

  final int currentTabIndex;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showCoachSheet(context),
      backgroundColor: MintColors.primary,
      elevation: 4,
      child: const Icon(Icons.auto_awesome, color: MintColors.white, size: 22),
    );
  }

  void _showCoachSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.transparent,
      builder: (context) => _CoachQuickSheet(currentTabIndex: currentTabIndex),
    );
  }
}

/// Compact coach sheet — 3 contextual actions, clean design.
class _CoachQuickSheet extends StatelessWidget {
  const _CoachQuickSheet({this.currentTabIndex = 0});

  final int currentTabIndex;

  List<_CoachAction> _actionsForTab(S l) {
    final chat = _CoachAction(
      icon: Icons.chat_bubble_outline,
      title: l.mentorFabChatTitle,
      subtitle: l.mentorFabChatSubtitle,
      color: MintColors.coachAccent,
      route: '/coach/chat',
    );
    final scan = _CoachAction(
      icon: Icons.document_scanner_outlined,
      title: l.mentorFabScanTitle,
      subtitle: l.mentorFabScanSubtitle,
      color: MintColors.primary,
      route: '/scan',
    );
    final simuler = _CoachAction(
      icon: Icons.calculate_outlined,
      title: l.mentorFabSimulateTitle,
      subtitle: l.mentorFabSimulateSubtitle,
      color: MintColors.warning,
      route: '/tools',
    );
    final enrichir = _CoachAction(
      icon: Icons.tune_outlined,
      title: l.mentorFabProfileTitle,
      subtitle: l.mentorFabProfileSubtitle,
      color: MintColors.primary,
      route: '/profile/bilan',
    );

    switch (currentTabIndex) {
      case 0: // Pulse — chat first, then scan to enrich, then simulate
        return [chat, scan, simuler];
      // case 1: Mint tab — FAB is hidden, no actions needed
      case 2: // Coach — enrich first, then scan, then simulate
        return [enrichir, scan, simuler];
      default:
        return [chat, scan, simuler];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final actions = _actionsForTab(l);
    return Container(
      decoration: const BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header — compact
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MintColors.coachAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: MintColors.coachAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.mentorFabSheetTitle,
                      style: MintTextStyles.titleMedium(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        size: 20, color: MintColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Actions — 3 compact tiles
              ...actions.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildActionTile(context, action: a),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context,
      {required _CoachAction action}) {
    return Material(
      color: MintColors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          context.push(action.route);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: action.color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachAction {
  const _CoachAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
}
