import 'package:flutter/material.dart';
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
    return EducationalInsertWidget(
      title: 'Fixe vs SARON : comprendre les options',
      subtitle: 'Chaque type d\'hypothèque a ses avantages',
      disclaimer: 'Comparaison simplifiée à titre pédagogique. Les conditions varient selon les prêteurs et votre profil. Ne constitue pas un conseil hypothécaire.',
      hypotheses: const [
        'Comparaison basée sur conditions marché 2024-2026',
        'SARON = Swiss Average Rate Overnight',
        'Historique ne garantit pas l\'avenir',
      ],
      onLearnMore: onLearnMore,
      content: Column(
        children: [
          // Tableau comparatif
          _buildComparisonTable(),
          
          const SizedBox(height: 20),
          
          // Message neutre
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
                    Text(
                      'Aucune option n\'est universellement meilleure',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNeutralPoint(Icons.check, 'Fixe si tu préfères la prévisibilité'),
                _buildNeutralPoint(Icons.check, 'SARON si tu acceptes le risque pour potentiellement payer moins'),
                _buildNeutralPoint(Icons.check, 'Mix possible pour diversifier'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      children: [
        _buildTableRow(
          isHeader: true,
          cells: ['Critère', 'Fixe', 'SARON'],
        ),
        _buildTableRow(
          cells: ['Mensualités', 'Stables', 'Variables'],
          colors: [null, MintColors.appleSurface, null],
        ),
        _buildTableRow(
          cells: ['Coût historique', 'Plus élevé', 'Plus bas'],
          colors: [null, null, MintColors.appleSurface],
        ),
        _buildTableRow(
          cells: ['Risque taux', 'Aucun', 'Exposition'],
          colors: [null, MintColors.appleSurface, null],
        ),
        _buildTableRow(
          cells: ['Flexibilité', 'Pénalités', 'Souple'],
          colors: [null, null, MintColors.appleSurface],
        ),
        _buildTableRow(
          cells: ['Planification', 'Budgétable', 'Incertain'],
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
          ? BoxDecoration(color: MintColors.primary.withOpacity(0.1))
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
          Icon(icon, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
