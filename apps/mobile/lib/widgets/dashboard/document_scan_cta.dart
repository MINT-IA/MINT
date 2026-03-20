import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  DOCUMENT SCAN CTA — Chantier 2 / Retirement Cockpit
// ────────────────────────────────────────────────────────────
//
//  CTA prominent pour State B (confiance 40-69%) :
//    "Scanne ton certificat LPP pour affiner ta projection"
//    Montre la confiance actuelle et l'amelioration estimee.
//
//  Widget pur — aucune dependance Provider.
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class DocumentScanCta extends StatelessWidget {
  /// Score de confiance actuel (0-100).
  final double currentConfidence;

  /// Score de confiance estime apres scan (~+20 pts).
  final double? estimatedConfidenceAfterScan;

  const DocumentScanCta({
    super.key,
    required this.currentConfidence,
    this.estimatedConfidenceAfterScan,
  });

  @override
  Widget build(BuildContext context) {
    final targetScore =
        estimatedConfidenceAfterScan ?? (currentConfidence + 20).clamp(0, 95);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: MintColors.transparent,
        child: Semantics(
          label: 'Scan',
          button: true,
          child: InkWell(
          onTap: () => context.push('/scan'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + Badge
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MintColors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.document_scanner_outlined,
                        color: MintColors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Affine ta projection',
                            style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scanne ton certificat de pr\u00e9voyance LPP',
                            style: MintTextStyles.bodySmall(color: MintColors.white.withValues(alpha: 0.75)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Confidence upgrade preview
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: MintColors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Current confidence
                      _buildConfidencePill(
                        label: 'Maintenant',
                        score: currentConfidence,
                        isActive: false,
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: MintColors.white.withValues(alpha: 0.5),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      // After scan
                      _buildConfidencePill(
                        label: 'Avec tes chiffres',
                        score: targetScore,
                        isActive: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // CTA button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: MintColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: MintColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Scanner mon certificat LPP',
                        style: MintTextStyles.bodyMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),),
      ),
    );
  }

  Widget _buildConfidencePill({
    required String label,
    required double score,
    required bool isActive,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: MintTextStyles.micro(color: MintColors.white.withValues(alpha: 0.6)).copyWith(fontStyle: FontStyle.normal),
          ),
          const SizedBox(height: 4),
          Text(
            '${score.round()}%',
            style: MintTextStyles.headlineMedium(color: isActive ? MintColors.success : MintColors.white.withValues(alpha: 0.7)).copyWith(fontSize: isActive ? 22 : 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
