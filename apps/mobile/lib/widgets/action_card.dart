import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Carte d'action réutilisable
///
/// Widget standardisé pour afficher une action recommandée avec :
/// - Icône colorée dans un container arrondi
/// - Titre et subtitle
/// - Chevron de navigation
/// - Accessibilité complète (Semantics)
///
/// Utilisé dans :
/// - CoachDashboardScreen (actions recommandées)
/// - ExploreTab (objectifs)
/// - Mentor modal (actions rapides)
class ActionCard extends StatelessWidget {
  /// Icône de l'action
  final IconData icon;

  /// Titre principal de l'action
  final String title;

  /// Description courte de l'action
  final String subtitle;

  /// Couleur thématique (icône + background)
  final Color color;

  /// Callback appelé au tap
  final VoidCallback onTap;

  /// Padding personnalisé (optionnel)
  final EdgeInsets? padding;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      child: Container(
        margin: padding != null
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const Borderconst Radius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: MintColors.border.withValues(alpha: 0.6)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: const Borderconst Radius.circular(20),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildIconContainer(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextContent(),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: const Borderconst Radius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        color: MintColors.textSecondary, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
