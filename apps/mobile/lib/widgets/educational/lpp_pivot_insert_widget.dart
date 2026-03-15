import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
    final s = S.of(context)!;
    return EducationalInsertWidget(
      title: s.lppPivotTitle,
      subtitle: s.lppPivotSubtitle,
      disclaimer: s.lppPivotDisclaimer,
      hypotheses: [
        s.lppPivotHypothesisPlafonds,
        s.lppPivotHypothesisSource,
      ],
      onLearnMore: onLearnMore,
      content: Column(
        children: [
          _buildPivotCard(
            isSelected: hasPensionFund == true,
            icon: Icons.business,
            title: s.lppPivotWithLppTitle,
            subtitle: s.lppPivotWithLppSubtitle,
            limit: s.lppPivotWithLppLimit,
            description: s.lppPivotWithLppDescription,
            onTap: () => onChanged?.call(true),
          ),
          const SizedBox(height: 12),
          _buildPivotCard(
            isSelected: hasPensionFund == false,
            icon: Icons.person,
            title: s.lppPivotWithoutLppTitle,
            subtitle: s.lppPivotWithoutLppSubtitle,
            limit: s.lppPivotWithoutLppLimit,
            limitSub: s.lppPivotWithoutLppLimitSub,
            description: s.lppPivotWithoutLppDescription,
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
                    s.lppPivotFooter,
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
              isSelected ? MintColors.primary.withValues(alpha: 0.1) : MintColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.greyBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? MintColors.primary : MintColors.lightBorder,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? MintColors.white : MintColors.textSecondary,
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
                    style: const TextStyle(fontSize: 12, color: MintColors.textSecondary),
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
                          style: const TextStyle(
                              fontSize: 12, color: MintColors.textSecondary),
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
              const Icon(Icons.radio_button_unchecked,
                  color: MintColors.greyBorderLight, size: 24),
          ],
        ),
      ),
    );
  }
}
