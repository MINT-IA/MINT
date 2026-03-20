import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Carte d'action prioritaire pour le dashboard Pulse.
///
/// Chaque carte invite a EXPLORER ou SIMULER (jamais prescriptif).
/// Micro-disclaimer inline obligatoire.
class PulseActionCard extends StatelessWidget {
  final VisibilityAction action;

  const PulseActionCard({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: Semantics(
          label: action.title,
          button: true,
          child: InkWell(
            onTap: () => context.push(action.route),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: MintColors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Icone ──────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _categoryColor(action.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _categoryIcon(action.category),
                    size: 22,
                    color: _categoryColor(action.category),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Texte ──────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle,
                        style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Impact badge + fleche ────────────────
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: MintColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${action.impactPoints} pts',
                        style: MintTextStyles.labelSmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: MintColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  static IconData _categoryIcon(String category) {
    return switch (category) {
      'lpp' => Icons.account_balance,
      'avs' => Icons.verified_user,
      '3a' => Icons.savings,
      'patrimoine' => Icons.trending_up,
      'fiscalite' => Icons.receipt_long,
      'menage' => Icons.family_restroom,
      'income' => Icons.payments,
      'objectif_retraite' => Icons.flag,
      'foreign_pension' => Icons.public,
      'accuracy' => Icons.document_scanner,
      'freshness' => Icons.update,
      _ => Icons.info_outline,
    };
  }

  static Color _categoryColor(String category) {
    return switch (category) {
      'lpp' => MintColors.retirementLpp,
      'avs' => MintColors.retirementAvs,
      '3a' => MintColors.retirement3a,
      'patrimoine' => MintColors.teal,
      'fiscalite' => MintColors.indigo,
      'menage' => MintColors.pink,
      'income' => MintColors.info,
      'objectif_retraite' => MintColors.warning,
      _ => MintColors.textSecondary,
    };
  }
}
