import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';

/// Insert didactique pour q_has_pension_fund
/// Explique le pivot LPP et son impact sur le plafond 3a
class LppPivotInsertWidget extends StatelessWidget {
  final bool? hasPensionFund;
  final VoidCallback? onLearnMore;
  final ValueChanged<bool>? onChanged;

  const LppPivotInsertWidget({
    super.key,
    this.hasPensionFund,
    this.onLearnMore,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return EducationalInsertWidget(
      title: 'Le pivot LPP : comprendre ton plafond 3a',
      subtitle:
          'Ton affiliation au 2e pilier détermine combien tu peux verser au 3a',
      disclaimer:
          'Information pédagogique. Ta situation peut varier selon ton employeur et ta caisse de pension.',
      hypotheses: const [
        'Plafonds 2026 : CHF 7\'258 (avec LPP) ou 20% du revenu (sans LPP, max 36\'288)',
        'Source : VIAC, UBS, ch.ch',
      ],
      onLearnMore: onLearnMore,
      content: Column(
        children: [
          _buildPivotCard(
            isSelected: hasPensionFund == true,
            icon: Icons.business,
            title: 'Avec LPP (salarié)',
            subtitle: 'Affilié à une caisse de pension',
            limit: 'CHF 7\'258 / an',
            description: 'Tu travailles comme salarié avec un 2e pilier.',
            onTap: () => onChanged?.call(true),
          ),
          const SizedBox(height: 12),
          _buildPivotCard(
            isSelected: hasPensionFund == false,
            icon: Icons.person,
            title: 'Sans LPP',
            subtitle: 'Indépendant ou temps partiel sans caisse',
            limit: '20% du revenu net',
            limitSub: '(max CHF 36\'288)',
            description: 'Tu peux verser jusqu\'à 5x plus au 3a !',
            onTap: () => onChanged?.call(false),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: MintColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Le 3a reste l\'un des outils les plus efficaces de défiscalisation en Suisse, quel que soit ton statut.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPivotCard({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required String limit,
    String? limitSub,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? MintColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? MintColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? MintColors.primary : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: MintColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          limit,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: MintColors.primary,
                          ),
                        ),
                      ),
                      if (limitSub != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          limitSub,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: MintColors.primary, size: 24)
            else
              Icon(Icons.radio_button_unchecked,
                  color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }
}
