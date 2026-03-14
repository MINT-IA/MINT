import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';
import 'package:google_fonts/google_fonts.dart';

/// Insert didactique pour q_mortgage_type
/// Comparateur neutre Fixe vs SARON
class MortgageComparisonInsertWidget extends StatelessWidget {
  final String? currentType;
  final VoidCallback? onLearnMore;

  const MortgageComparisonInsertWidget({
    super.key,
    this.currentType,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return EducationalInsertWidget(
      title: s.mortgageComparisonTitle,
      subtitle: s.mortgageComparisonSubtitle,
      disclaimer: s.mortgageComparisonDisclaimer,
      hypotheses: [
        s.mortgageComparisonHypo1,
        s.mortgageComparisonHypo2,
        s.mortgageComparisonHypo3,
      ],
      onLearnMore: onLearnMore,
      content: Column(
        children: [
          _buildComparisonTable(s),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.balance, color: MintColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.mortgageComparisonNoUniversalBest,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNeutralPoint(Icons.check, s.mortgageComparisonFixeAdvice),
                _buildNeutralPoint(Icons.check, s.mortgageComparisonSaronAdvice),
                _buildNeutralPoint(Icons.check, s.mortgageComparisonMixAdvice),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(S s) {
    return Table(
      border: TableBorder.all(
        color: MintColors.greyBorder,
        borderRadius: BorderRadius.circular(12),
      ),
      children: [
        _buildTableRow(
          isHeader: true,
          cells: [s.mortgageComparisonCritere, s.mortgageComparisonFixe, s.mortgageComparisonSaron],
        ),
        _buildTableRow(
          cells: [s.mortgageComparisonMensualites, s.mortgageComparisonStables, s.mortgageComparisonVariables],
          colors: [null, MintColors.appleSurface, null],
        ),
        _buildTableRow(
          cells: [s.mortgageComparisonCoutHistorique, s.mortgageComparisonPlusEleve, s.mortgageComparisonPlusBas],
          colors: [null, null, MintColors.appleSurface],
        ),
        _buildTableRow(
          cells: [s.mortgageComparisonRisqueTaux, s.mortgageComparisonAucun, s.mortgageComparisonExposition],
          colors: [null, MintColors.appleSurface, null],
        ),
        _buildTableRow(
          cells: [s.mortgageComparisonFlexibilite, s.mortgageComparisonPenalites, s.mortgageComparisonSouple],
          colors: [null, null, MintColors.appleSurface],
        ),
        _buildTableRow(
          cells: [s.mortgageComparisonPlanification, s.mortgageComparisonBudgetable, s.mortgageComparisonIncertain],
          colors: [null, MintColors.appleSurface, null],
        ),
      ],
    );
  }

  TableRow _buildTableRow({
    required List<String> cells,
    bool isHeader = false,
    List<Color?>? colors,
  }) {
    return TableRow(
      decoration: isHeader
          ? BoxDecoration(color: MintColors.primary.withValues(alpha: 0.1))
          : null,
      children: cells.asMap().entries.map((entry) {
        final index = entry.key;
        final text = entry.value;
        final bgColor = colors != null && index < colors.length ? colors[index] : null;
        
        return TableCell(
          child: Container(
            color: bgColor,
            padding: const EdgeInsets.all(12),
            child: Text(
              text,
              style: TextStyle(
                fontSize: isHeader ? 13 : 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? MintColors.primary : MintColors.textPrimary,
              ),
              textAlign: index == 0 ? TextAlign.left : TextAlign.center,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNeutralPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: MintColors.warningText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: MintColors.amberDark),
            ),
          ),
        ],
      ),
    );
  }
}
