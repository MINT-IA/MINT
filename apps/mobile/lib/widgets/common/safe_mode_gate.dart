import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class SafeModeGate extends StatelessWidget {
  final bool hasDebt;
  final Widget child;
  final String lockedTitle;
  final String lockedMessage;

  const SafeModeGate({
    super.key,
    required this.hasDebt,
    required this.child,
    this.lockedTitle = "Concentration Prioritaire",
    this.lockedMessage =
        "Pour votre sécurité financière, nous désactivons les optimisations avancées tant qu'un signal de dette est actif. La priorité est de construire votre sécurité.",
  });

  @override
  Widget build(BuildContext context) {
    if (!hasDebt) {
      return child;
    }

    // Locked State visualization
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person,
              color: MintColors.textSecondary.withOpacity(0.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lockedTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lockedMessage,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    // Could show a bottom sheet with educational content about "Why Debt First?"
                    // For now, simple pedagogic link style
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              "Règle d'or : On ne construit pas de richesse sur des fondations instables (Dettes).")),
                    );
                  },
                  child: Text(
                    "Pourquoi est-ce bloqué ?",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MintColors.primary,
                      decoration: TextDecoration.underline,
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
}
