import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

enum CardStatus { serein, aRenforcer, alerte }

class ThematicCard extends StatelessWidget {
  final String emoji;
  final String title;
  final CardStatus status;
  final String? keyNumber;
  final String? keyNumberLabel;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final String? source;
  final List<Widget> children;

  const ThematicCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.status,
    this.keyNumber,
    this.keyNumberLabel,
    this.actionLabel,
    this.onActionTap,
    this.source,
    this.children = const [],
  });

  Color get statusColor => switch (status) {
    CardStatus.serein => MintColors.success,
    CardStatus.aRenforcer => MintColors.warning,
    CardStatus.alerte => MintColors.error,
  };

  String get statusLabel => switch (status) {
    CardStatus.serein => 'Serein',
    CardStatus.aRenforcer => '\u00c0 renforcer',
    CardStatus.alerte => 'Alerte',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 17),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: MintTextStyles.bodySmall(color: statusColor).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Key number (if provided)
          if (keyNumber != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (keyNumberLabel != null)
                    Text(
                      keyNumberLabel!,
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                    ),
                  Text(
                    keyNumber!,
                    style: MintTextStyles.displayMedium(color: MintColors.textPrimary).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
          // Children (sub-cards, charts, etc.)
          if (children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          // Source (legal reference)
          if (source != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                source!,
                style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          // Action CTA
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onActionTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: statusColor,
                    side: BorderSide(color: statusColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }
}
