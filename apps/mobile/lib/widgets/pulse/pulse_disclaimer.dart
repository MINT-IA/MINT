import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Micro-disclaimer inline pour le dashboard Pulse.
///
/// TOUJOURS visible, jamais scrolle hors ecran.
/// Conforme audit compliance : LSFin art. 3.
class PulseDisclaimer extends StatelessWidget {
  const PulseDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 14,
            color: MintColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.pulseDisclaimer,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
