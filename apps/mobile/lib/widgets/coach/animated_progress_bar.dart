import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_motion.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  ANIMATED PROGRESS BAR — Swiss-calm fill reveal
// ────────────────────────────────────────────────────────────
//
//  A horizontal progress bar that fills from 0 to [progress] on
//  first build, with an optional text label above the bar.
//
//  Motion principles (MINT_UX_GRAAL_MASTERPLAN §6):
//  - Duration 900 ms — deliberate, readable fill
//  - Curve: easeOutCubic — smooth deceleration
//  - Rounded corners (4 px) — MintSpacing.xs
//  - Height 6 px — non-intrusive, data-driven accent
//
//  Usage:
//  ```dart
//  AnimatedProgressBar(progress: 0.6, label: '3/5 étapes')
//  AnimatedProgressBar(progress: sequence.progressPercent)
//  ```
// ────────────────────────────────────────────────────────────

class AnimatedProgressBar extends StatefulWidget {
  /// Fill ratio from 0.0 to 1.0.
  final double progress;

  /// Optional text label shown above the bar (e.g. "3/10 étapes").
  final String? label;

  /// Bar fill color. Falls back to [MintColors.primary].
  final Color? color;

  /// Animation duration. Defaults to 900 ms.
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.label,
    this.color,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> {
  double _oldProgress = 0;
  double _targetProgress = 0;

  @override
  void initState() {
    super.initState();
    _targetProgress = widget.progress.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _oldProgress = oldWidget.progress.clamp(0.0, 1.0);
      _targetProgress = widget.progress.clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? MintColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.xs),
        ],
        TweenAnimationBuilder<double>(
          key: ValueKey(_targetProgress),
          tween: Tween<double>(begin: _oldProgress, end: _targetProgress),
          duration: widget.duration,
          curve: MintMotion.curveStandard, // easeOutCubic
          builder: (context, animatedValue, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(MintSpacing.xs),
              child: LinearProgressIndicator(
                value: animatedValue,
                backgroundColor: MintColors.lightBorder,
                valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                minHeight: 6,
              ),
            );
          },
        ),
      ],
    );
  }
}
