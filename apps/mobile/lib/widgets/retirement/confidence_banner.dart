import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/bayesian_enricher.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Confidence score banner for retirement projections.
///
/// Shows a progress bar (green/amber/red), the score percentage,
/// and the top 2 enrichment prompts with "+X%" impact badges.
class ConfidenceBanner extends StatelessWidget {
  final ProjectionConfidence confidence;

  const ConfidenceBanner({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final color = _levelColor(confidence.level);
    final label = _levelLabel(confidence.level, s);

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
                  s.retirementConfidenceTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
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
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
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
              s.retirementConfidenceImprove,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      prompt.action,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                      ),
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
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptChip(EnrichmentPrompt prompt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      prompt.action,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                      ),
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
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  String _levelLabel(String level, S s) {
    switch (level) {
      case 'high':
        return s.retirementConfidenceHigh;
      case 'medium':
        return s.retirementConfidenceMedium;
      default:
        return s.retirementConfidenceLow;
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
