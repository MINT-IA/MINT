import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Data model for a single item in the Lightning Menu.
class LightningMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;

  /// Chat message to send, or route path if [isRoute] is true.
  final String action;
  final MintSurfaceTone tone;

  /// If true, [action] is a GoRouter path instead of a chat message.
  final bool isRoute;

  /// Optional tag used to filter out already-completed actions.
  /// Matched against [CapMemory.completedActions].
  final String? completionTag;

  const LightningMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
    required this.tone,
    this.isRoute = false,
    this.completionTag,
  });
}

/// Premium bottom sheet triggered by the bolt button in the chat input bar.
///
/// Items adapt dynamically based on 3 axes:
///   1. Profile confidence (stage 1/2/3)
///   2. Profile attributes (age, couple, debt, independent, rachat LPP)
///   3. Completed actions from [CapMemory] (already-done items filtered out)
///
/// Stage 1 — New user (confidence < 30): educational basics
/// Stage 2 — Building (confidence 30-60): first projections
/// Stage 3 — Mature (confidence > 60): personalized deep items
class LightningMenu extends StatelessWidget {
  final CoachProfile? profile;
  final CapMemory capMemory;
  final void Function(String message) onSendMessage;
  final void Function(String route) onNavigate;

  const LightningMenu({
    super.key,
    required this.profile,
    required this.capMemory,
    required this.onSendMessage,
    required this.onNavigate,
  });

  // ──────────────────────────────────────────────────────────
  //  STAGE COMPUTATION
  // ──────────────────────────────────────────────────────────

  /// Determine user stage from profile confidence.
  ///   1 = new (confidence < 30)
  ///   2 = building (30-60)
  ///   3 = mature (> 60)
  int _computeStage(CoachProfile? profile) {
    if (profile == null) return 1;
    try {
      final confidence = ConfidenceScorer.score(profile).score;
      if (confidence < 30) return 1;
      if (confidence < 60) return 2;
      return 3;
    } catch (_) {
      // Fallback if scoring fails (e.g. incomplete profile)
      return 1;
    }
  }

  // ──────────────────────────────────────────────────────────
  //  STAGE 1 — NEW USER (educational basics)
  // ──────────────────────────────────────────────────────────

  List<LightningMenuItem> _stage1Items(S s) => [
        LightningMenuItem(
          title: s.lightningMenuPayslipTitle,
          subtitle: s.lightningMenuPayslipSubtitle,
          icon: Icons.description_outlined,
          action: s.lightningMenuPayslipAction,
          tone: MintSurfaceTone.bleu,
          completionTag: 'payslip_explained',
        ),
        LightningMenuItem(
          title: s.lightningMenuThreePillarsTitle,
          subtitle: s.lightningMenuThreePillarsSubtitle,
          icon: Icons.account_balance_outlined,
          action: s.lightningMenuThreePillarsAction,
          tone: MintSurfaceTone.sauge,
          completionTag: 'three_pillars',
        ),
        LightningMenuItem(
          title: s.lightningMenuScanDocTitle,
          subtitle: s.lightningMenuScanDocSubtitle,
          icon: Icons.document_scanner_outlined,
          action: '/scan',
          tone: MintSurfaceTone.peche,
          isRoute: true,
        ),
        LightningMenuItem(
          title: s.lightningMenuFirstBudgetTitle,
          subtitle: s.lightningMenuFirstBudgetSubtitle,
          icon: Icons.receipt_long_outlined,
          action: s.lightningMenuFirstBudgetAction,
          tone: MintSurfaceTone.bleu,
          completionTag: 'first_budget',
        ),
      ];

  // ──────────────────────────────────────────────────────────
  //  STAGE 2 — BUILDING (first projections)
  // ──────────────────────────────────────────────────────────

  List<LightningMenuItem> _stage2Items(S s) => [
        LightningMenuItem(
          title: s.lightningMenuRetirementTitle,
          subtitle: s.lightningMenuRetirementSubtitle,
          icon: Icons.beach_access_outlined,
          action: s.lightningMenuRetirementAction,
          tone: MintSurfaceTone.sauge,
          completionTag: 'retirement_overview',
        ),
        LightningMenuItem(
          title: s.lightningMenuTaxReliefTitle,
          subtitle: s.lightningMenuTaxReliefSubtitle,
          icon: Icons.savings_outlined,
          action: s.lightningMenuTaxReliefAction,
          tone: MintSurfaceTone.bleu,
          completionTag: 'tax_relief',
        ),
        LightningMenuItem(
          title: s.lightningMenuBudgetTitle,
          subtitle: s.lightningMenuBudgetSubtitle,
          icon: Icons.receipt_long_outlined,
          action: s.lightningMenuBudgetAction,
          tone: MintSurfaceTone.peche,
        ),
        LightningMenuItem(
          title: s.lightningMenuCompleteProfileTitle,
          subtitle: s.lightningMenuCompleteProfileSubtitle,
          icon: Icons.person_add_alt_1_outlined,
          action: '/profile/bilan',
          tone: MintSurfaceTone.sauge,
          isRoute: true,
        ),
      ];

  // ──────────────────────────────────────────────────────────
  //  STAGE 3 — MATURE (personalized deep items)
  // ──────────────────────────────────────────────────────────

  List<LightningMenuItem> _stage3Items(CoachProfile profile, S s) {
    final items = <LightningMenuItem>[];

    // Age >= 45 → rente ou capital
    if (profile.age >= 45) {
      items.add(LightningMenuItem(
        title: s.lightningMenuRenteCapitalTitle,
        subtitle: s.lightningMenuRenteCapitalSubtitle,
        icon: Icons.account_balance_outlined,
        action: s.lightningMenuRenteCapitalAction,
        tone: MintSurfaceTone.sauge,
        completionTag: 'rente_capital',
      ));
    }

    // Has debt → debt reduction
    if (profile.dettes.hasDette) {
      items.add(LightningMenuItem(
        title: s.lightningMenuDebtTitle,
        subtitle: s.lightningMenuDebtSubtitle,
        icon: Icons.trending_down_outlined,
        action: s.lightningMenuDebtAction,
        tone: MintSurfaceTone.peche,
        completionTag: 'debt_plan',
      ));
    }

    // Couple → couple situation
    if (profile.isCouple) {
      items.add(LightningMenuItem(
        title: s.lightningMenuCoupleTitle,
        subtitle: s.lightningMenuCoupleSubtitle,
        icon: Icons.family_restroom_outlined,
        action: s.lightningMenuCoupleAction,
        tone: MintSurfaceTone.peche,
        completionTag: 'couple_prevoyance',
      ));
    }

    // Independent → safety net
    if (profile.employmentStatus == 'independant') {
      items.add(LightningMenuItem(
        title: s.lightningMenuIndependantTitle,
        subtitle: s.lightningMenuIndependantSubtitle,
        icon: Icons.work_outline,
        action: s.lightningMenuIndependantAction,
        tone: MintSurfaceTone.bleu,
        completionTag: 'independant_net',
      ));
    }

    // Rachat LPP > 10k → buyback opportunity
    if (profile.prevoyance.lacuneRachatRestante > 10000) {
      items.add(LightningMenuItem(
        title: s.lightningMenuLppBuybackTitle,
        subtitle: s.lightningMenuLppBuybackSubtitle,
        icon: Icons.add_chart_outlined,
        action: s.lightningMenuLppBuybackAction,
        tone: MintSurfaceTone.sauge,
        completionTag: 'lpp_buyback',
      ));
    }

    // Always: living budget
    items.add(LightningMenuItem(
      title: s.lightningMenuLivingBudgetTitle,
      subtitle: s.lightningMenuLivingBudgetSubtitle,
      icon: Icons.receipt_long_outlined,
      action: s.lightningMenuLivingBudgetAction,
      tone: MintSurfaceTone.bleu,
    ));

    return items;
  }

  // ──────────────────────────────────────────────────────────
  //  ITEM ASSEMBLY
  // ──────────────────────────────────────────────────────────

  /// Build the final item list: stage-based + filter completed actions.
  List<LightningMenuItem> _buildItems(S s) {
    final stage = _computeStage(profile);

    final List<LightningMenuItem> raw;
    switch (stage) {
      case 1:
        raw = _stage1Items(s);
      case 2:
        raw = _stage2Items(s);
      case 3:
        raw = profile != null ? _stage3Items(profile!, s) : _stage2Items(s);
      default:
        raw = _stage1Items(s);
    }

    // Filter out items the user already completed.
    final completed = capMemory.completedActions.toSet();
    final filtered = raw.where((item) {
      if (item.completionTag == null) return true;
      return !completed.contains(item.completionTag);
    }).toList();

    // Always show at least 2 items — if filtering removed too many,
    // fall back to the unfiltered list.
    return filtered.length >= 2 ? filtered : raw.take(4).toList();
  }

  // ──────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final allItems = _buildItems(s);

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
                    if (item.isRoute) {
                      onNavigate(item.action);
                    } else {
                      onSendMessage(item.action);
                    }
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
              item.isRoute
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
              color: MintColors.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
