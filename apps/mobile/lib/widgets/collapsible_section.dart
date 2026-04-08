import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Reusable collapsible section for consolidated hub screens (Phase 4).
///
/// Used to inline sub-screen content within a parent dedicated screen.
/// Example: `/hypotheque` hub contains sections for amortissement,
/// SARON vs fixe, valeur locative, and EPL.
class CollapsibleSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  const CollapsibleSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: MintColors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(icon, color: MintColors.primary, size: 20),
          title: Text(
            title,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
                )
              : null,
          children: [child],
        ),
      ),
    );
  }
}
