import 'package:flutter/material.dart';
import 'package:mint_mobile/services/financial_core/bayesian_enricher.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Confidence score banner for retirement projections.
///
/// Shows a progress bar (green/amber/red), the score percentage,
/// and the top 2 enrichment prompts with "+X%" impact badges.
class ConfidenceBanner extends StatelessWidget {
  final ProjectionConfidence confidence;

  const ConfidenceBanner({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(confidence.level);
    final label = _levelLabel(confidence.level);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + score
          Row(
            children: [
              Icon(
                _levelIcon(confidence.level),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fiabilite de la projection',
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${confidence.score.round()}% — $label',
                  style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence.score / 100,
              minHeight: 6,
              backgroundColor: color.withAlpha(30),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),

          // Bayesian EVI prompts (preferred) or fallback to static prompts
          if (_hasPrompts) ...[
            const SizedBox(height: 14),
            Text(
              'Ameliore ta projection :',
              style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._buildPromptsList(),
          ],
        ],
      ),
    );
  }

  bool get _hasPrompts {
    final bayesian = confidence.bayesianResult;
    if (bayesian != null && bayesian.rankedPrompts.isNotEmpty) return true;
    return confidence.prompts.isNotEmpty;
  }

  List<Widget> _buildPromptsList() {
    final bayesian = confidence.bayesianResult;
    // Prefer Bayesian EVI prompts (richer, better ranked)
    if (bayesian != null && bayesian.rankedPrompts.isNotEmpty) {
      return bayesian.rankedPrompts
          .take(2)
          .map(_buildEviPromptChip)
          .toList();
    }
    // Fallback to static prompts
    return confidence.prompts.take(2).map(_buildPromptChip).toList();
  }

  Widget _buildEviPromptChip(EviPrompt prompt) {
    // Convert EVI to a human-readable impact score (0-20 scale)
    final impactPct = (prompt.evi * 100).round().clamp(1, 20);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        label: 'interactive element',
        button: true,
        child: InkWell(
        onTap: () {
          // Placeholder — enrichment action to be connected later
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MintColors.greyBorder),
          ),
          child: Row(
            children: [
              Icon(
                _categoryIcon(prompt.category),
                size: 16,
                color: MintColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt.label,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      prompt.action,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$impactPct%',
                  style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),),
    );
  }

  Widget _buildPromptChip(EnrichmentPrompt prompt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        label: 'interactive element',
        button: true,
        child: InkWell(
        onTap: () {
          // Placeholder — enrichment action to be connected later
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MintColors.greyBorder),
          ),
          child: Row(
            children: [
              Icon(
                _categoryIcon(prompt.category),
                size: 16,
                color: MintColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt.label,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      prompt.action,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${prompt.impact}%',
                  style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'high':
        return MintColors.successDeep; // Green
      case 'medium':
        return MintColors.warningText; // Amber
      default:
        return MintColors.redDark; // Red
    }
  }

  String _levelLabel(String level) {
    switch (level) {
      case 'high':
        return 'Fiable';
      case 'medium':
        return 'Moderee';
      default:
        return 'Estimative';
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'high':
        return Icons.verified_outlined;
      case 'medium':
        return Icons.info_outline;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'lpp':
        return Icons.account_balance;
      case 'avs':
        return Icons.elderly;
      case '3a':
        return Icons.savings;
      case 'patrimoine':
        return Icons.home_outlined;
      case 'foreign_pension':
        return Icons.public;
      case 'income':
        return Icons.monetization_on_outlined;
      case 'depenses':
        return Icons.receipt_long;
      case 'conjoint':
        return Icons.people_outline;
      default:
        return Icons.info_outline;
    }
  }
}
