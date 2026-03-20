import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

// ────────────────────────────────────────────────────────────
//  ACTION SUCCESS SHEET — Feedback loop after cap action
// ────────────────────────────────────────────────────────────
//
//  Spec: MINT_CAP_ENGINE_SPEC.md §12
//
//  Shows:
//  1. What was done (action label)
//  2. What changed (impact)
//  3. What's next (new cap or enrichment)
//
//  Displayed as a bottom sheet from Aujourd'hui or after
//  completing a flow that was triggered by a cap.
// ────────────────────────────────────────────────────────────

/// Data for the Action Success feedback.
class ActionSuccessData {
  /// What the user did (e.g. "Versement 3a ajouté").
  final String actionLabel;

  /// What changed as a result (e.g. "économie fiscale estimée CHF 1'240").
  final String? impactLabel;

  /// What's next (e.g. "vérifier ton certificat LPP").
  final String? nextLabel;

  /// Route to the next action (optional).
  final String? nextRoute;

  /// The cap that was completed (for CapMemory.markCompleted).
  final String? completedCapId;

  const ActionSuccessData({
    required this.actionLabel,
    this.impactLabel,
    this.nextLabel,
    this.nextRoute,
    this.completedCapId,
  });

  /// Build from a CapDecision + next cap suggestion.
  factory ActionSuccessData.fromCap({
    required CapDecision completedCap,
    CapDecision? nextCap,
  }) {
    return ActionSuccessData(
      actionLabel: completedCap.ctaLabel,
      impactLabel: completedCap.expectedImpact,
      nextLabel: nextCap?.headline,
      nextRoute: nextCap?.ctaRoute,
      completedCapId: completedCap.id,
    );
  }
}

/// Shows the Action Success bottom sheet.
///
/// Call after the user completes a flow triggered by a cap.
Future<void> showActionSuccessSheet(
  BuildContext context,
  ActionSuccessData data,
) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ActionSuccessContent(data: data),
  );
}

class _ActionSuccessContent extends StatelessWidget {
  final ActionSuccessData data;

  const _ActionSuccessContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(MintSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: MintColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Success icon + title
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: MintColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: MintSpacing.md),
              Expanded(
                child: Text(
                  data.actionLabel,
                  style: MintTextStyles.titleMedium(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Impact
          if (data.impactLabel != null) ...[
            const SizedBox(height: MintSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MintSpacing.md),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 18,
                    color: MintColors.success.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      data.impactLabel!,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.success,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Next step
          if (data.nextLabel != null) ...[
            const SizedBox(height: MintSpacing.lg),
            Text(
              l.actionSuccessNext,
              style: MintTextStyles.bodySmall(),
            ),
            const SizedBox(height: MintSpacing.sm),
            GestureDetector(
              onTap: data.nextRoute != null
                  ? () {
                      Navigator.of(context).pop();
                      context.push(data.nextRoute!);
                    }
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(MintSpacing.md),
                decoration: BoxDecoration(
                  color: MintColors.white,
                  border: Border.all(
                    color: MintColors.border.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.nextLabel!,
                        style: MintTextStyles.titleMedium(),
                      ),
                    ),
                    if (data.nextRoute != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: MintColors.textMuted,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: MintSpacing.lg),

          // Close button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l.actionSuccessDone,
                style: MintTextStyles.titleMedium(color: MintColors.white),
              ),
            ),
          ),

          const SizedBox(height: MintSpacing.sm),
        ],
      ),
    );
  }
}
