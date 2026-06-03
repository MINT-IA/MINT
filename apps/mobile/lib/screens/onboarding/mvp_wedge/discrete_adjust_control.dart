library;

import 'package:flutter/material.dart';

import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class OnboardingDiscreteAdjustControl extends StatelessWidget {
  const OnboardingDiscreteAdjustControl({
    super.key,
    required this.decrementIdentifier,
    required this.incrementIdentifier,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.currentValueLabel,
    required this.visualValue,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String decrementIdentifier;
  final String incrementIdentifier;
  final String decrementLabel;
  final String incrementLabel;
  final String currentValueLabel;
  final String visualValue;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MintColors.craie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          _AdjustButton(
            key: ValueKey(decrementIdentifier),
            semanticsIdentifier: decrementIdentifier,
            semanticsLabel: decrementLabel,
            visualLabel: '-',
            enabled: canDecrement,
            onPressed: onDecrement,
          ),
          Expanded(
            child: Semantics(
              label: currentValueLabel,
              child: ExcludeSemantics(
                child: Text(
                  visualValue,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.titleLarge(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          _AdjustButton(
            key: ValueKey(incrementIdentifier),
            semanticsIdentifier: incrementIdentifier,
            semanticsLabel: incrementLabel,
            visualLabel: '+',
            enabled: canIncrement,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    super.key,
    required this.semanticsIdentifier,
    required this.semanticsLabel,
    required this.visualLabel,
    required this.enabled,
    required this.onPressed,
  });

  final String semanticsIdentifier;
  final String semanticsLabel;
  final String visualLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticsIdentifier,
      label: semanticsLabel,
      button: true,
      enabled: enabled,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 52,
          height: 52,
          child: TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: enabled ? onPressed : null,
            style: TextButton.styleFrom(
              foregroundColor: MintColors.textPrimary,
              disabledForegroundColor:
                  MintColors.textSecondary.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              visualLabel,
              style: MintTextStyles.titleLarge(
                color: enabled
                    ? MintColors.textPrimary
                    : MintColors.textSecondary.withValues(alpha: 0.35),
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
