// Phase 28-04 — Inline third-party attribution chip.
//
// When backend's silent-attribution detection (28-01) flags a document
// as belonging to a profile partner (`third_party_detected=true`), this
// chip is rendered ABOVE the rendering bubble:
//
//   "C'est bien Lauren ?  [Oui]  [Non]"
//
// Tapping a choice fires the callback. No backend call is made here —
// Phase 29 will gate the consent flow.

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class ThirdPartyChip extends StatelessWidget {
  /// Detected name (e.g. "Lauren"). If null, falls back to a generic
  /// "quelqu'un d'autre" wording.
  final String? name;

  /// Called when user taps "Oui".
  final VoidCallback onYes;

  /// Called when user taps "Non".
  final VoidCallback onNo;

  const ThirdPartyChip({
    super.key,
    required this.name,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final displayName = (name == null || name!.trim().isEmpty)
        ? s.documentThirdPartySomeoneElse
        : name!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              s.documentThirdPartyQuestion(displayName),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          _MiniChip(
            label: s.documentThirdPartyYes,
            onTap: onYes,
            primary: true,
          ),
          const SizedBox(width: 6),
          _MiniChip(
            label: s.documentThirdPartyNo,
            onTap: onNo,
            primary: false,
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _MiniChip({
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? MintColors.primary : MintColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? MintColors.primary : MintColors.border,
          ),
        ),
        child: Text(
          label,
          style: MintTextStyles.bodySmall(
            color: primary ? MintColors.background : MintColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
