import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

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
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                )
              : null,
          children: [child],
        ),
      ),
    );
  }
}
