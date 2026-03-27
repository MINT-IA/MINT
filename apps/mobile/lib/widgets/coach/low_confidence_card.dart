import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Card displayed when confidence score < 40%.
///
/// Shows educational message + top 3 EVI-ranked enrichment prompts with CTA.
/// Each prompt shows its expected confidence gain (+X pts) and routes to
/// the appropriate data capture surface (scan, question, etc.).
///
/// S57 EVI Bridge: prompts now route to category-specific screens,
/// not just a generic /scan button.
class LowConfidenceCard extends StatelessWidget {
  final CoachProfile profile;

  const LowConfidenceCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final confidence = ConfidenceScorer.score(profile);
    final topPrompts = confidence.prompts.take(3).toList();

    // Determine the best CTA route from the highest-impact prompt
    final bestRoute = topPrompts.isNotEmpty
        ? _routeForCategory(topPrompts.first.category) ?? '/scan'
        : '/scan';
    final bestLabel = topPrompts.isNotEmpty
        ? topPrompts.first.action
        : 'Compl\u00e9ter mon profil';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.scoreAttention.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: MintColors.scoreAttention, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pas assez de donn\u00e9es pour une projection fiable',
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Confidence score bar
          Row(
            children: [
              Text(
                '${confidence.score.round()}/100',
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (confidence.score / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: MintColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      confidence.score >= 70
                          ? MintColors.success
                          : confidence.score >= 40
                              ? MintColors.warning
                              : MintColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Voici ce qui am\u00e9liorerait le plus tes projections\u00a0:',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                .copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          // EVI-ranked prompts with tappable rows
          ...topPrompts.map((p) {
            final route = _routeForCategory(p.category);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: route != null ? () => context.push(route) : null,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MintColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${p.impact}\u00a0pts',
                          style: MintTextStyles.labelSmall(
                                  color: MintColors.primary)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.label,
                          style: MintTextStyles.bodySmall(
                              color: MintColors.textPrimary),
                        ),
                      ),
                      if (route != null)
                        const Icon(Icons.chevron_right,
                            size: 18, color: MintColors.textMuted),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          // Primary CTA — drives to the highest-impact action
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(bestRoute),
              icon: Icon(
                _iconForCategory(
                    topPrompts.isNotEmpty ? topPrompts.first.category : ''),
                size: 18,
              ),
              label: Text(
                bestLabel,
                style: MintTextStyles.bodySmall(color: MintColors.white)
                    .copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Map enrichment category to the best data capture route.
  static String? _routeForCategory(String category) {
    return switch (category) {
      'lpp' => '/scan',
      'avs' => '/scan/avs-guide',
      '3a' => '/scan',
      'patrimoine' => null, // Coach handles conversationally
      'menage' => null,
      'income' => null,
      'objectif_retraite' => null,
      'foreign_pension' => null,
      _ => null,
    };
  }

  /// Icon for each enrichment category.
  static IconData _iconForCategory(String category) {
    return switch (category) {
      'lpp' => Icons.document_scanner_outlined,
      'avs' => Icons.document_scanner_outlined,
      '3a' => Icons.document_scanner_outlined,
      'patrimoine' => Icons.account_balance_wallet_outlined,
      'menage' => Icons.people_outline,
      'income' => Icons.payments_outlined,
      'objectif_retraite' => Icons.flag_outlined,
      _ => Icons.edit_outlined,
    };
  }
}
