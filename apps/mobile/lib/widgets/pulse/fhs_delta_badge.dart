/// FHS Delta Badge — Sprint S54.
///
/// Compact chip showing the daily score change vs yesterday.
/// "+3 vs hier" in green with up arrow, "-2 vs hier" in red with down arrow,
/// or "= vs hier" in grey for stable.
///
/// Design: 28px height, Montserrat 12px, MintColors palette.
/// Outil educatif — ne constitue pas un conseil financier (LSFin).
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/models/fhs_daily_score.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Compact badge displaying the FHS delta vs yesterday.
///
/// Shows an arrow icon + signed delta + "vs hier" label.
/// Color-coded: green (up), red (down), grey (stable).
class FhsDeltaBadge extends StatelessWidget {
  /// Score change vs yesterday (positive = improvement).
  final double delta;

  /// Trend direction (derived from delta or provided externally).
  final FhsTrend trend;

  const FhsDeltaBadge({
    super.key,
    required this.delta,
    required this.trend,
  });

  /// Badge foreground color based on trend.
  Color get _color {
    switch (trend) {
      case FhsTrend.up:
        return MintColors.scoreExcellent;
      case FhsTrend.down:
        return MintColors.scoreCritique;
      case FhsTrend.stable:
        return MintColors.textMuted;
    }
  }

  /// Badge background color (10% opacity of foreground).
  Color get _bgColor => _color.withValues(alpha: 0.10);

  /// Arrow icon based on trend direction.
  IconData get _icon {
    switch (trend) {
      case FhsTrend.up:
        return Icons.arrow_upward_rounded;
      case FhsTrend.down:
        return Icons.arrow_downward_rounded;
      case FhsTrend.stable:
        return Icons.remove_rounded;
    }
  }

  /// Formatted delta text: "+3", "-2", or "=".
  String get _deltaText {
    if (delta.abs() < 0.5) return '=';
    final rounded = delta.round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.of(context)!.fhsDeltaLabel(_deltaText),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 14, color: _color),
            const SizedBox(width: 3),
            Text(
              S.of(context)!.fhsDeltaText(_deltaText),
              style: MintTextStyles.bodySmall(color: _color).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
