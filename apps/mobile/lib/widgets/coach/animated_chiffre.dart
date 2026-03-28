import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_motion.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  ANIMATED CHIFFRE — Swiss-calm number roll-up
// ────────────────────────────────────────────────────────────
//
//  A CHF number that counts up from 0 to [value] on first build.
//
//  Motion principles (MINT_UX_GRAAL_MASTERPLAN §6):
//  - Duration 800 ms (MintMotion.slow baseline)
//  - Curve: easeOutCubic — decelerates smoothly, no bounce
//  - Formats with Swiss thousand-separator apostrophe
//
//  Usage:
//  ```dart
//  AnimatedChiffre(value: 677847, prefix: 'CHF\u00a0', suffix: '')
//  AnimatedChiffre(value: 65.5, prefix: '', suffix: '\u00a0%')
//  ```
// ────────────────────────────────────────────────────────────

class AnimatedChiffre extends StatefulWidget {
  /// The numeric value to animate towards.
  final double value;

  /// Text prepended to the formatted number. Defaults to 'CHF\u00a0'.
  final String prefix;

  /// Text appended to the formatted number. Defaults to ''.
  final String suffix;

  /// Override text color. Falls back to [MintColors.textPrimary].
  final Color? color;

  /// Override the entire text style. When provided, [color] is ignored.
  final TextStyle? textStyle;

  /// Animation duration. Defaults to 800 ms.
  final Duration duration;

  const AnimatedChiffre({
    super.key,
    required this.value,
    this.prefix = 'CHF\u00a0',
    this.suffix = '',
    this.color,
    this.textStyle,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedChiffre> createState() => _AnimatedChiffreState();

  /// Returns the effective [TextStyle] for the number text.
  TextStyle resolveTextStyle() =>
      textStyle ?? MintTextStyles.titleMedium(color: color ?? MintColors.textPrimary);
}

class _AnimatedChiffreState extends State<AnimatedChiffre> {
  double _oldValue = 0;
  double _targetValue = 0;

  @override
  void initState() {
    super.initState();
    _targetValue = widget.value;
  }

  @override
  void didUpdateWidget(AnimatedChiffre oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _targetValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = widget.resolveTextStyle();

    return TweenAnimationBuilder<double>(
      key: ValueKey(_targetValue),
      tween: Tween<double>(begin: _oldValue, end: _targetValue),
      duration: widget.duration,
      curve: MintMotion.curveStandard, // easeOutCubic
      builder: (context, animatedValue, _) {
        return Text(
          '${widget.prefix}${_formatNumber(animatedValue)}${widget.suffix}',
          style: resolvedStyle,
        );
      },
    );
  }

  /// Formats [n] with Swiss thousand-separator (apostrophe).
  ///
  /// Examples: 677847 → "677'847", 1000 → "1'000", 42.5 → "42"
  String _formatNumber(double n) {
    final formatted = n.toStringAsFixed(0);
    if (n < 1000) return formatted;

    final buffer = StringBuffer();
    int count = 0;
    for (int i = formatted.length - 1; i >= 0; i--) {
      buffer.write(formatted[i]);
      count++;
      if (count % 3 == 0 && i > 0) buffer.write("'");
    }
    return buffer.toString().split('').reversed.join();
  }
}
