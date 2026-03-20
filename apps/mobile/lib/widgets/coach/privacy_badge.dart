import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Privacy badge — "100% on-device" indicator.
///
/// Displayed when the SLM (on-device AI) is active, NOT when using BYOK
/// (cloud-based LLM). Reassures the user that no data leaves their phone.
class PrivacyBadge extends StatelessWidget {
  /// Whether the SLM engine is active (on-device processing).
  /// If false (BYOK mode), the badge is hidden.
  final bool isSlmActive;

  const PrivacyBadge({super.key, required this.isSlmActive});

  @override
  Widget build(BuildContext context) {
    if (!isSlmActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MintColors.scoreGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.scoreGreen.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline,
              size: 14, color: MintColors.scoreGreen),
          const SizedBox(width: 6),
          Text(
            '100% on-device \u2014 aucune donn\u00e9e ne quitte ton t\u00e9l\u00e9phone',
            style: MintTextStyles.labelSmall(color: MintColors.scoreGreen).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
