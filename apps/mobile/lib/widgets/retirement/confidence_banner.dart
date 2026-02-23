import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

          // Top enrichment prompts (max 2)
          if (confidence.prompts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Ameliore ta projection :',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...confidence.prompts.take(2).map(_buildPromptChip),
          ],
        ],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E0E0)),
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
        return const Color(0xFF2E7D32); // Green
      case 'medium':
        return const Color(0xFFF57F17); // Amber
      default:
        return const Color(0xFFC62828); // Red
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
      default:
        return Icons.info_outline;
    }
  }
}
