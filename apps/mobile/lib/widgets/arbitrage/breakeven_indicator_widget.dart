import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

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
  final bool showCalendarYear;

  const BreakevenIndicatorWidget({
    super.key,
    required this.breakevenYear,
    this.ageRetraite = 65,
    this.horizon = 25,
    this.sensitivity,
    this.showCalendarYear = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasCrossover = breakevenYear != null;
    final crossoverAge = hasCrossover ? ageRetraite + breakevenYear! : 0;
    final crossoverCalendarYear =
        hasCrossover ? DateTime.now().year + breakevenYear! : 0;
    final crossoverText = _buildCrossoverText(
      hasCrossover: hasCrossover,
      crossoverAge: crossoverAge,
      crossoverCalendarYear: crossoverCalendarYear,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
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
            crossoverText,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500, height: 1.4),
            textAlign: TextAlign.center,
          ),

          // Sensitivity
          if (sensitivity != null && sensitivity!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: MintColors.lightBorder, height: 1),
            const SizedBox(height: 12),
            Text(
              'Sensibilité du capital au rendement',
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            if (sensitivity!.containsKey('rendement_plus_1') &&
                sensitivity!.containsKey('rendement_moins_1'))
              Text(
                'Rendement +1 % : ${formatChfWithPrefix(sensitivity!['rendement_plus_1']!)} | '
                'Rendement -1 % : ${formatChfWithPrefix(sensitivity!['rendement_moins_1']!)}',
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                textAlign: TextAlign.center,
              ),
            if (sensitivity!.containsKey('rendement_marche_plus_1') &&
                sensitivity!.containsKey('rendement_marche_moins_1'))
              Text(
                'Marché +1 % : ${formatChfWithPrefix(sensitivity!['rendement_marche_plus_1']!)} | '
                'Marché -1 % : ${formatChfWithPrefix(sensitivity!['rendement_marche_moins_1']!)}',
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                textAlign: TextAlign.center,
              ),
          ],
        ],
      ),
    );
  }

  String _buildCrossoverText({
    required bool hasCrossover,
    required int crossoverAge,
    required int crossoverCalendarYear,
  }) {
    if (!hasCrossover) {
      return 'Les trajectoires ne se croisent pas sur cet horizon de $horizon ans.';
    }
    if (ageRetraite > 0 && showCalendarYear) {
      return 'Les trajectoires se croisent à l\'âge de $crossoverAge ans ($crossoverCalendarYear).';
    }
    if (ageRetraite > 0) {
      return 'Les trajectoires se croisent à l\'âge de $crossoverAge ans.';
    }
    return 'Les trajectoires se croisent vers $crossoverCalendarYear.';
  }

}
