import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Recovery card shown while no reviewed mobile AVS pension envelope exists.
///
/// The legacy gap/comparison rendering was removed rather than left behind an
/// always-false readiness switch. This widget has one live action: obtain the
/// official future-pension calculation required by MINT.
class HeroGapCard extends StatelessWidget {
  final VoidCallback onRecoveryTap;

  const HeroGapCard({
    super.key,
    required this.onRecoveryTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.85),
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_outlined,
            color: MintColors.white,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            s.avsGuideHeaderTitle,
            style: MintTextStyles.titleMedium(color: MintColors.white)
                .copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.avsGuideHeaderSubtitle,
            style: MintTextStyles.bodySmall(color: MintColors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Semantics(
            label: s.visibilityHintCommandeAvs,
            button: true,
            child: GestureDetector(
              onTap: onRecoveryTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.document_scanner,
                    color: MintColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      s.visibilityHintCommandeAvs,
                      style: MintTextStyles.bodySmall(color: MintColors.white)
                          .copyWith(
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: MintColors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
