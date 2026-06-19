import 'package:flutter/material.dart';

import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class OnboardingChoiceButton extends StatelessWidget {
  const OnboardingChoiceButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: MintColors.craie,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: MintTextStyles.labelLarge(
              color: MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
}
