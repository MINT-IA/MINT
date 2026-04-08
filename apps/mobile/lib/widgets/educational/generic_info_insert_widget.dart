import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/educational/educational_insert_widget.dart';

/// Widget generique pour les inserts educatifs informationnels.
/// Affiche un premier éclairage, des objectifs d'apprentissage, des sources
/// et un bouton d'action optionnel. Utilise [EducationalInsertWidget] comme base.
class GenericInfoInsertWidget extends StatelessWidget {
  /// Titre de l'insert
  final String title;

  /// Sous-titre optionnel
  final String? subtitle;

  /// Fait marquant / premier éclairage
  final String premierEclairage;

  /// Points d'apprentissage (bullets)
  final List<String> learningGoals;

  /// Disclaimer legal obligatoire
  final String disclaimer;

  /// References juridiques
  final List<String> sources;

  /// Texte du bouton d'action (optionnel)
  final String? actionLabel;

  /// Route GoRouter pour le bouton d'action (optionnel)
  final String? actionRoute;

  /// Callback "En savoir plus"
  final VoidCallback? onLearnMore;

  const GenericInfoInsertWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.premierEclairage,
    required this.learningGoals,
    required this.disclaimer,
    required this.sources,
    this.actionLabel,
    this.actionRoute,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return EducationalInsertWidget(
      title: title,
      subtitle: subtitle,
      disclaimer: disclaimer,
      hypotheses: sources,
      onLearnMore: onLearnMore,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premier Éclairage card
          _buildPremierEclairageCard(),
          const SizedBox(height: 16),

          // Learning goals
          Text(
            'Ce que tu vas comprendre',
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...learningGoals.map(_buildLearningGoalItem),

          // Action button
          if (actionLabel != null && actionRoute != null) ...[
            const SizedBox(height: 16),
            _buildActionButton(context),
          ],
        ],
      ),
    );
  }

  /// Carte mise en avant pour le premier éclairage
  Widget _buildPremierEclairageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.info.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: MintColors.info,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              premierEclairage,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Un point d'apprentissage avec bullet
  Widget _buildLearningGoalItem(String goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: MintColors.info,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              goal,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton d'action (CTA) vers un simulateur ou ecran
  Widget _buildActionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          if (actionRoute != null) {
            context.push(actionRoute!);
          }
        },
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: Text(
          actionLabel!,
          style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.primary,
          side: const BorderSide(color: MintColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
    );
  }
}
