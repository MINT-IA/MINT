import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Breakeven indicator card — shows when/if trajectories cross.
///
/// Sprint S32 — Arbitrage Phase 1.
/// If [breakevenYear] is not null, displays the crossing year and age.
/// If null, informs the user trajectories don't cross within the horizon.
/// Also shows sensitivity summary if provided.
class BreakevenIndicatorWidget extends StatelessWidget {
  final int? breakevenYear;
  final int ageRetraite;
  final int horizon;
  final Map<String, double>? sensitivity;

  const BreakevenIndicatorWidget({
    super.key,
    required this.breakevenYear,
    this.ageRetraite = 65,
    this.horizon = 25,
    this.sensitivity,
  });

  @override
  Widget build(BuildContext context) {
    final hasCrossover = breakevenYear != null;
    final crossoverAge = hasCrossover ? ageRetraite + breakevenYear! : 0;
    final crossoverCalendarYear =
        hasCrossover ? DateTime.now().year + breakevenYear! : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasCrossover
                  ? MintColors.info.withAlpha(25)
                  : MintColors.warning.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasCrossover
                  ? Icons.swap_vert_rounded
                  : Icons.trending_flat_rounded,
              color: hasCrossover ? MintColors.info : MintColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),

          // Main text
          Text(
            hasCrossover
                ? 'Les trajectoires se croisent a l\'age de $crossoverAge ans ($crossoverCalendarYear).'
                : 'Les trajectoires ne se croisent pas sur cet horizon de $horizon ans.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          // Sensitivity
          if (sensitivity != null && sensitivity!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: MintColors.lightBorder, height: 1),
            const SizedBox(height: 12),
            Text(
              'Sensibilite du capital au rendement',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            if (sensitivity!.containsKey('rendement_plus_1') &&
                sensitivity!.containsKey('rendement_moins_1'))
              Text(
                'Rendement +1 % : ${_formatChf(sensitivity!['rendement_plus_1']!)} | '
                'Rendement -1 % : ${_formatChf(sensitivity!['rendement_moins_1']!)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            if (sensitivity!.containsKey('rendement_marche_plus_1') &&
                sensitivity!.containsKey('rendement_marche_moins_1'))
              Text(
                'Marche +1 % : ${_formatChf(sensitivity!['rendement_marche_plus_1']!)} | '
                'Marche -1 % : ${_formatChf(sensitivity!['rendement_marche_moins_1']!)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ],
      ),
    );
  }

  static String _formatChf(double value) {
    final intVal = value.round().abs();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${value < 0 ? '-' : ''}${buffer.toString()}';
  }
}
