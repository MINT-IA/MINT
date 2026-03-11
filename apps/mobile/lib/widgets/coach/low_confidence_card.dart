import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Card displayed when confidence score < 40%.
///
/// Shows educational message + top 3 enrichment prompts with CTA.
/// Pure presentational widget — computes confidence from profile.
class LowConfidenceCard extends StatelessWidget {
  final CoachProfile profile;

  const LowConfidenceCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final confidence = ConfidenceScorer.score(profile);
    final topPrompts = confidence.prompts.take(3).toList();
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
              Icon(Icons.info_outline,
                  color: MintColors.scoreAttention, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pas assez de donn\u00e9es pour une projection fiable',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'En Suisse, le taux de remplacement moyen est de 60-70% '
            'du dernier salaire. Pour estimer le tien, '
            'compl\u00e8te quelques informations :',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...topPrompts.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                        '+${p.impact}%',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MintColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/document-scan'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Compl\u00e9ter mon profil',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: Colors.white,
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
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
