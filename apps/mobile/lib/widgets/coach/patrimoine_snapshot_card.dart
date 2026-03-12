import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  PATRIMOINE SNAPSHOT CARD — Phase 5 / Dashboard Assembly
// ────────────────────────────────────────────────────────────
//
// Carte résumé du patrimoine total avec barre empilée 4 segments :
// LPP, 3a, Épargne, Immobilier.
//
// NOTE: AVS excluded — AVS is a pay-as-you-go (répartition) system
// (LAVS art. 18). It's a right to a rente, not owned capital.
// Showing a "capital equivalent" for AVS would be misleading.
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class PatrimoineSnapshotCard extends StatelessWidget {
  final double lppCapital;
  final double lppCapitalConjoint; // conjoint LPP capital (couple support)
  final double threeACapital;
  final double epargne;
  final double immobilier;

  const PatrimoineSnapshotCard({
    super.key,
    required this.lppCapital,
    this.lppCapitalConjoint = 0,
    required this.threeACapital,
    required this.epargne,
    required this.immobilier,
  });

  double get _total => lppCapital + lppCapitalConjoint + threeACapital + epargne + immobilier;

  @override
  Widget build(BuildContext context) {
    final total = _total;
    if (total <= 0) return const SizedBox.shrink();

    final segments = [
      _Segment('LPP', lppCapital, MintColors.primary),
      if (lppCapitalConjoint > 0)
        _Segment('LPP conjoint·e', lppCapitalConjoint, MintColors.indigoMuted),
      _Segment('3a', threeACapital, MintColors.centralScenario),
      _Segment('Épargne', epargne, MintColors.orangeWarm),
      _Segment('Immobilier', immobilier, MintColors.blueSteel),
    ].where((s) => s.value > 0).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: MintColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patrimoine total estimé',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatChf(total),
              style: GoogleFonts.montserrat(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: segments.map((s) {
                    final ratio = s.value / total;
                    return Expanded(
                      flex: (ratio * 1000).round().clamp(1, 1000),
                      child: Container(color: s.color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: segments.map((s) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.label} ${formatChf(s.value)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment {
  final String label;
  final double value;
  final Color color;
  const _Segment(this.label, this.value, this.color);
}
