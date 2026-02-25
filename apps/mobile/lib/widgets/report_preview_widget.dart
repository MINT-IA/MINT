import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/clarity_state.dart';
import 'package:mint_mobile/theme/colors.dart';

class ReportPreviewWidget extends StatelessWidget {
  final ClarityState state;
  final VoidCallback onComplete;
  final VoidCallback? onViewPartialReport;

  const ReportPreviewWidget({
    super.key,
    required this.state,
    required this.onComplete,
    this.onViewPartialReport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        color: MintColors.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Aperçu de ton Plan Mint',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Indice de précision
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: state.precisionColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.circular(16),
                    border: Border.all(color: state.precisionColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.analytics,
                          color: state.precisionColor, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Précision actuelle',
                              style: TextStyle(
                                fontSize: 14,
                                color: state.precisionColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${state.precisionIndex.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: state.precisionColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  state.precisionLabel,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: state.precisionColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Safe Mode (si actif)
                if (state.safeMode) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: const BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield,
                            color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mode Protection Actif',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Priorité : fonds d\'urgence et remboursement dettes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Actions prêtes
                Text(
                  'Actions prêtes : ${state.actionsReady}/${state.totalActions}',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Liste des actions
                ...state.actions
                    .take(3)
                    .map((action) => _buildActionTile(action)),

                if (state.actions.length > 3) ...[
                  const SizedBox(height: 12),
                  Text(
                    '+ ${state.actions.length - 3} autres actions',
                    style: const TextStyle(
                      fontSize: 14,
                      color: MintColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Prochaine info la plus rentable
                if (state.nextMostValuableInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MintColors.accentPastel,
                      borderRadius: const BorderRadius.circular(12),
                      border: Border.all(
                          color: MintColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            color: MintColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Prochaine info la plus rentable',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: MintColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.nextMostValuableInfo!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: MintColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Badges débloqués
                if (state.unlockedBadges.isNotEmpty) ...[
                  Text(
                    'Badges débloqués',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: state.unlockedBadges.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: MintColors.surface,
                          borderRadius: const BorderRadius.circular(20),
                          border: Border.all(color: MintColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(badge.emoji,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              badge.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Zone du bouton (fixe en bas)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bouton "Compléter"
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: onComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    state.precisionIndex >= 90
                        ? 'Générer le PDF final'
                        : 'Continuer pour compléter (Recommandé)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              if (state.precisionIndex >= 40 && state.precisionIndex < 90) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onViewPartialReport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MintColors.primary,
                      side: const BorderSide(color: MintColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Voir mon plan provisoire (Beta)'),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              Center(
                child: Text(
                  state.precisionIndex >= 90
                      ? 'Ton plan est prêt !'
                      : 'Encore ${(90 - state.precisionIndex).toStringAsFixed(0)}% pour le PDF certifié',
                  style: const TextStyle(
                    fontSize: 13,
                    color: MintColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(ClarityAction action) {
    final icon = _getActionIcon(action.status);
    final color = _getActionColor(action.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.circular(12),
          border: Border.all(color: MintColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  if (action.blockingReason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      action.blockingReason!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(ActionStatus status) {
    switch (status) {
      case ActionStatus.ready:
        return Icons.check_circle;
      case ActionStatus.pending:
        return Icons.schedule;
      case ActionStatus.blocked:
        return Icons.block;
    }
  }

  Color _getActionColor(ActionStatus status) {
    switch (status) {
      case ActionStatus.ready:
        return Colors.green;
      case ActionStatus.pending:
        return Colors.orange;
      case ActionStatus.blocked:
        return Colors.red;
    }
  }
}
