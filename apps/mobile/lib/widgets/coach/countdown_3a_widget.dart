import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  COUNTDOWN 3A WIDGET — P5-F / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Barre de progression du plafond 3a + jours restants
//  avant le 31 décembre. Widget d'urgence.
//
//  Widget pur — aucune dépendance Provider.
//  Lois : L5 (une action) + L6 (chiffre-choc)
// ────────────────────────────────────────────────────────────

class Countdown3aWidget extends StatelessWidget {
  /// Annual 3a ceiling (e.g. 7258 for 2026).
  final double annualCeiling;

  /// Amount already contributed this year.
  final double amountContributed;

  /// Estimated tax savings if ceiling is filled.
  final double taxSavingsIfFull;

  /// Days remaining until Dec 31.
  final int daysRemaining;

  /// Year for display.
  final int year;

  const Countdown3aWidget({
    super.key,
    required this.annualCeiling,
    required this.amountContributed,
    required this.taxSavingsIfFull,
    required this.daysRemaining,
    this.year = 2026,
  });

  double get _remaining => (annualCeiling - amountContributed).clamp(0, annualCeiling);
  double get _progress => annualCeiling > 0 ? (amountContributed / annualCeiling).clamp(0, 1) : 0;

  Color get _urgencyColor {
    if (daysRemaining <= 30) return MintColors.scoreCritique;
    if (daysRemaining <= 90) return MintColors.scoreAttention;
    return MintColors.scoreExcellent;
  }

  String get _urgencyLabel {
    if (daysRemaining <= 30) return 'Urgent';
    if (daysRemaining <= 90) return 'Bient\u00f4t';
    return 'Confortable';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Compte \u00e0 rebours 3a. '
          '${formatChfWithPrefix(_remaining)} restant en $daysRemaining jours.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Compte \u00e0 rebours 3a',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _urgencyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$daysRemaining j \u2014 $_urgencyLabel',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _urgencyColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Progress bar ──
            _buildProgressBar(),

            const SizedBox(height: 10),

            // ── Numbers ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat(
                    'Vers\u00e9', formatChfWithPrefix(amountContributed)),
                _buildStat('Reste', formatChfWithPrefix(_remaining)),
                _buildStat(
                    'Plafond $year', formatChfWithPrefix(annualCeiling)),
              ],
            ),

            const SizedBox(height: 14),

            // ── Chiffre-choc ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _remaining > 0
                    ? MintColors.scoreCritique.withValues(alpha: 0.08)
                    : MintColors.scoreExcellent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _remaining > 0
                    ? 'Si tu compl\u00e8tes\u00a0: ${formatChfWithPrefix(taxSavingsIfFull)} '
                        'd\u2019imp\u00f4ts en moins.\n'
                        'Si tu ne fais rien\u00a0: ${formatChfWithPrefix(taxSavingsIfFull)} '
                        'laiss\u00e9s sur la table. Chaque ann\u00e9e.'
                    : 'Bravo\u00a0! Tu as rempli ton 3a $year. '
                        '\u00c9conomie fiscale\u00a0: ${formatChfWithPrefix(taxSavingsIfFull)}.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _remaining > 0
                      ? MintColors.scoreCritique
                      : MintColors.scoreExcellent,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Plafond 3a $year\u00a0: salari\u00e9\u00b7e affili\u00e9\u00b7e LPP (OPP3 art. 7). '
              'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 16,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  color: MintColors.surface,
                ),
                FractionallySizedBox(
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _progress >= 1.0
                          ? MintColors.scoreExcellent
                          : MintColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _urgencyColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }
}
