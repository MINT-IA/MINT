import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Concrete action insight — shows context + CTA with number/deadline + impact.
///
/// RULE: every action has a NUMBER and a DEADLINE.
/// Generic CTAs ("Simule ton 3a", "Explorer mes options") are forbidden.
///
/// Example:
///   contextLine: "62\u00a0% — en dessous de la moyenne suisse (68\u00a0%)"
///   actionLine: "Verse 611\u00a0CHF avant le 31 décembre"
///   impactLine: "Économie fiscale\u00a0: 1\u2019833\u00a0CHF"
class ActionInsightWidget extends StatelessWidget {
  /// Explanatory context (1 line). E.g. replacement rate context.
  final String contextLine;

  /// Concrete CTA with amount + deadline.
  final String actionLine;

  /// Optional impact badge (green). E.g. "Économie : 1'833 CHF".
  final String? impactLine;

  /// GoRouter route to push when tapped.
  final String? route;

  /// Custom onTap — overrides [route] navigation.
  final VoidCallback? onTap;

  const ActionInsightWidget({
    super.key,
    required this.contextLine,
    required this.actionLine,
    this.impactLine,
    this.route,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: route != null || onTap != null,
      label: actionLine,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.bleuAir.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MintColors.bleuAir.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contextLine,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onTap ?? (route != null ? () => context.push(route!) : null),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      actionLine,
                      style: MintTextStyles.bodySmall().copyWith(
                        color: MintColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (impactLine != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MintColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        impactLine!,
                        style: MintTextStyles.labelSmall().copyWith(
                          color: MintColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: MintColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
