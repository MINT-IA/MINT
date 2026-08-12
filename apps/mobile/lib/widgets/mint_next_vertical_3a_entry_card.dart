import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Lego 7 — entrée du vertical 3a attesté (Aujourd'hui + Ma situation).
///
/// Pure navigation : aucun chiffre, aucun calculateur — le vertical est
/// l'unique surface du calcul.
class MintNextVertical3aEntryCard extends StatelessWidget {
  const MintNextVertical3aEntryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: FeatureFlags.mintNextVertical3aListenable,
      builder: (context, enabled, child) =>
          enabled ? child! : const SizedBox.shrink(),
      child: Semantics(
      identifier: 'action:vertical_3a.entry',
      button: true,
      child: Material(
        color: MintColors.porcelaine,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md, vertical: MintSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.mintNextVertical3aEntryTitle,
                          style: MintTextStyles.titleLarge(
                              color: MintColors.textPrimary)),
                      const SizedBox(height: MintSpacing.xs),
                      Text(l10n.mintNextVertical3aEntrySubtitle,
                          style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: MintColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
