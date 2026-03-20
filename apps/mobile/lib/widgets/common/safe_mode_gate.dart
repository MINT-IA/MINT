import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class SafeModeGate extends StatelessWidget {
  final bool hasDebt;
  final Widget child;
  final String lockedTitle;
  final String lockedMessage;
  final List<String> reasons;
  final String? ctaRoute;
  final String ctaLabel;

  const SafeModeGate({
    super.key,
    required this.hasDebt,
    required this.child,
    this.lockedTitle = "Concentration Prioritaire",
    this.lockedMessage =
        "Pour ta sécurité financière, nous désactivons les optimisations avancées tant qu'un signal de dette est actif. La priorité est de construire ta sécurité.",
    this.reasons = const [],
    this.ctaRoute = '/debt/repayment',
    this.ctaLabel = 'Voir mon plan de désendettement',
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
              color: MintColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lockedTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  lockedMessage,
                  style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(height: 1.4),
                ),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...reasons.take(3).map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.circle,
                                    size: 6, color: MintColors.textMuted),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 12),
                Semantics(
                  label: 'Pourquoi est-ce bloqué',
                  button: true,
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: MintColors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pourquoi c’est bloqué',
                              style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'En mode protection, MINT priorise la stabilité de trésorerie '
                              'avant les optimisations fiscales et prévoyance.',
                              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
                            ),
                            if (reasons.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...reasons.take(4).map(
                                    (reason) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '• $reason',
                                        style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "Pourquoi est-ce bloqué ?",
                    style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                  ),
                ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed:
                        ctaRoute == null ? null : () => context.push(ctaRoute!),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: MintColors.primary),
                      foregroundColor: MintColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      ctaLabel,
                      style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
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
