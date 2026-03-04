import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Banner displayed when projection confidence is below 70%.
///
/// Shows:
/// - Warning icon + "Resultat indicatif" text
/// - Mini confidence gauge (0-100%)
/// - CTA to the most impactful data enrichment block
///
/// Hidden when confidence >= 70%.
class IndicatifBanner extends StatelessWidget {
  final double confidenceScore;

  /// The most impactful enrichment prompt's category, used for the CTA.
  /// Falls back to 'lpp' if null.
  final String? topEnrichmentCategory;

  const IndicatifBanner({
    super.key,
    required this.confidenceScore,
    this.topEnrichmentCategory,
  });

  /// Maps enrichment categories to data block route types.
  static const _categoryToRoute = {
    'income': 'revenu',
    'lpp': 'lpp',
    'avs': 'avs',
    '3a': '3a',
    'patrimoine': 'patrimoine',
    'objectif_retraite': 'objectifRetraite',
    'menage': 'compositionMenage',
  };

  @override
  Widget build(BuildContext context) {
    if (confidenceScore >= 70) return const SizedBox.shrink();

    final route = _categoryToRoute[topEnrichmentCategory] ?? 'lpp';
    final pct = confidenceScore.round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.accent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: MintColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Résultat indicatif ($pct% de fiabilité)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Mini gauge
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: (confidenceScore / 100).clamp(0.0, 1.0),
                backgroundColor: MintColors.lightBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  confidenceScore >= 40 ? MintColors.accent : Colors.redAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Précise tes données pour des projections personnalisées.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/data-block/$route'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                'Préciser',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: MintColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
