import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Diagramme Tornado — analyse de sensibilite du revenu de retraite.
///
/// Affiche un graphique en barres horizontales centrees sur le cas de base.
/// Chaque ligne represente une variable : la barre s'etend a gauche
/// (scenario pessimiste) et a droite (scenario optimiste) depuis la ligne
/// centrale.
///
/// Les variables sont triees par impact (swing) decroissant — la variable
/// la plus influente en haut.
///
/// Categories visuelles :
///   - strategy : MintColors.primary
///   - lpp      : indigo
///   - avs      : amber
///   - 3a       : emerald
///   - libre    : purple
///   - depenses : rouge
///
/// References : LIFD, LPP art. 14, LAVS art. 21-29.
class TornadoChart extends StatelessWidget {
  /// Revenu mensuel de base (CHF/mois) — ligne centrale.
  final double baseCase;

  /// Variables de sensibilite, deja triees par swing decroissant.
  final List<TornadoVariable> variables;

  /// Nombre maximum de variables affichees (defaut 10).
  final int maxVariables;

  /// Titre du composant.
  final String title;

  /// Sous-titre du composant.
  final String subtitle;

  /// Suffixe affiche apres la valeur de base (ex: "/mois").
  final String baseCaseSuffix;

  /// Ligne de disclaimer en bas du composant.
  final String disclaimerText;

  const TornadoChart({
    super.key,
    required this.baseCase,
    required this.variables,
    this.maxVariables = 10,
    this.title = 'Analyse de sensibilité',
    this.subtitle = 'Quels paramètres impactent le plus ton revenu de retraite ?',
    this.baseCaseSuffix = '/mois',
    this.disclaimerText =
        'Simulation pédagogique — chaque variable est testée indépendamment (LIFD, LPP, LAVS).',
  });

  @override
  Widget build(BuildContext context) {
    final displayVars = variables.take(maxVariables).toList();
    if (displayVars.isEmpty) return const SizedBox.shrink();

    final chartHeight = displayVars.length * 48.0 + 60.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre ─────────────────────────────────────────────
        Text(
          title,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),

        // ── Chart ─────────────────────────────────────────────
        SizedBox(
          height: chartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Semantics(
                label: 'Sensitivity tornado chart',
                child: CustomPaint(
                  size: Size(constraints.maxWidth, chartHeight),
                  painter: _TornadoPainter(
                    baseCase: baseCase,
                    variables: displayVars,
                    baseCaseSuffix: baseCaseSuffix,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── Legende categories ────────────────────────────────
        _buildCategoryLegend(displayVars),
        const SizedBox(height: 16),

        // ── Disclaimer ────────────────────────────────────────
        Text(
          disclaimerText,
          style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontSize: 10, fontStyle: FontStyle.normal, height: 1.4),
        ),
      ],
    );
  }

  /// Construit la legende par categorie presente.
  Widget _buildCategoryLegend(List<TornadoVariable> vars) {
    final seen = <String>{};
    final items = <Widget>[];
    for (final v in vars) {
      if (seen.add(v.category)) {
        items.add(_legendItem(_categoryLabel(v.category), _categoryColor(v.category)));
      }
    }
    return Wrap(spacing: 14, runSpacing: 6, children: items);
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
        ),
      ],
    );
  }

  static String _categoryLabel(String category) {
    switch (category) {
      case 'strategy':
        return 'Stratégie';
      case 'lpp':
        return 'LPP';
      case 'avs':
        return 'AVS';
      case '3a':
        return '3e pilier';
      case 'libre':
        return 'Patrimoine libre';
      case 'depenses':
        return 'Dépenses';
      default:
        return category;
    }
  }

  static Color _categoryColor(String category) {
    switch (category) {
      case 'strategy':
        return MintColors.primary;
      case 'lpp':
        return MintColors.pillarLpp; // indigo
      case 'avs':
        return MintColors.amber; // amber
      case '3a':
        return MintColors.positive; // emerald
      case 'libre':
        return MintColors.purple; // purple
      case 'depenses':
        return MintColors.danger; // red
      default:
        return MintColors.textMuted;
    }
  }
}

// ════════════════════════════════════════════════════════════════════
//  CUSTOM PAINTER
// ════════════════════════════════════════════════════════════════════

class _TornadoPainter extends CustomPainter {
  final double baseCase;
  final List<TornadoVariable> variables;
  final String baseCaseSuffix;

  _TornadoPainter({
    required this.baseCase,
    required this.variables,
    required this.baseCaseSuffix,
  });

  // ── Layout constants ─────────────────────────────────────────
  static const double _headerHeight = 36.0;
  static const double _rowHeight = 48.0;
  static const double _barHeight = 28.0;
  static const double _labelLeftWidth = 120.0;
  static const double _rightPadding = 10.0;
  static const double _barRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (variables.isEmpty) return;

    const chartLeft = _labelLeftWidth;
    final chartRight = size.width - _rightPadding;
    final chartWidth = chartRight - chartLeft;

    // ── Determine scale ─────────────────────────────────────
    // Find the maximum absolute deviation from baseCase across all variables
    double maxDeviation = 0;
    for (final v in variables) {
      maxDeviation = max(maxDeviation, (v.highValue - baseCase).abs());
      maxDeviation = max(maxDeviation, (v.lowValue - baseCase).abs());
    }
    if (maxDeviation < 1) maxDeviation = 1;

    // Center line x-position
    final centerX = chartLeft + chartWidth / 2;

    // Scale: pixels per CHF deviation
    final halfWidth = chartWidth / 2 - 80; // Leave space for tip labels
    final pxPerChf = halfWidth / maxDeviation;

    // ── Header: base case label ─────────────────────────────
    _drawBaseCaseHeader(canvas, size, centerX);

    // ── Center vertical dashed line ─────────────────────────
    _drawDashedLine(
      canvas,
      Offset(centerX, _headerHeight),
      Offset(centerX, size.height),
      MintColors.textSecondary.withValues(alpha: 0.25),
      1.0,
    );

    // ── Rows ────────────────────────────────────────────────
    for (int i = 0; i < variables.length; i++) {
      final v = variables[i];
      final rowTop = _headerHeight + i * _rowHeight;
      final barCenterY = rowTop + _rowHeight / 2;

      // Variable label (left)
      _drawVariableLabel(canvas, v.label, rowTop, barCenterY);

      // Determine bar positions
      final lowDelta = v.lowValue - baseCase; // negative if pessimistic
      final highDelta = v.highValue - baseCase; // positive if optimistic

      final categoryColor = _categoryColorFor(v.category);

      // Left bar (pessimistic direction)
      _drawBar(
        canvas: canvas,
        centerX: centerX,
        delta: lowDelta,
        pxPerChf: pxPerChf,
        barCenterY: barCenterY,
        color: lowDelta < 0
            ? MintColors.danger.withValues(alpha: 0.70)
            : categoryColor.withValues(alpha: 0.50),
        categoryColor: categoryColor,
      );

      // Right bar (optimistic direction)
      _drawBar(
        canvas: canvas,
        centerX: centerX,
        delta: highDelta,
        pxPerChf: pxPerChf,
        barCenterY: barCenterY,
        color: highDelta >= 0
            ? MintColors.positive.withValues(alpha: 0.70)
            : MintColors.danger.withValues(alpha: 0.50),
        categoryColor: categoryColor,
      );

      // Category indicator (small colored dot before bar area)
      _drawCategoryDot(canvas, categoryColor, chartLeft - 8, barCenterY);

      // Tip labels
      _drawTipLabels(
        canvas: canvas,
        v: v,
        centerX: centerX,
        pxPerChf: pxPerChf,
        barCenterY: barCenterY,
        chartRight: chartRight,
        chartLeft: chartLeft,
        size: size,
      );

      // Subtle horizontal separator
      if (i < variables.length - 1) {
        final separatorY = rowTop + _rowHeight;
        canvas.drawLine(
          Offset(chartLeft, separatorY),
          Offset(chartRight, separatorY),
          Paint()
            ..color = MintColors.lightBorder.withValues(alpha: 0.5)
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  // ── Header ──────────────────────────────────────────────────

  void _drawBaseCaseHeader(Canvas canvas, Size size, double centerX) {
    final suffix = baseCaseSuffix.isEmpty ? '' : baseCaseSuffix;
    final text = '${formatChfWithPrefix(baseCase)}$suffix (base)';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, 4));

    // Small triangle / arrow pointing down at center
    final arrowPaint = Paint()..color = MintColors.textSecondary.withValues(alpha: 0.4);
    final arrowPath = Path()
      ..moveTo(centerX - 4, _headerHeight - 8)
      ..lineTo(centerX + 4, _headerHeight - 8)
      ..lineTo(centerX, _headerHeight - 2)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  // ── Dashed vertical line ────────────────────────────────────

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    const dashLength = 4.0;
    const gapLength = 3.0;
    double currentY = start.dy;
    while (currentY < end.dy) {
      final segEnd = min(currentY + dashLength, end.dy);
      canvas.drawLine(
        Offset(start.dx, currentY),
        Offset(start.dx, segEnd),
        paint,
      );
      currentY = segEnd + gapLength;
    }
  }

  // ── Variable label (left column) ────────────────────────────

  void _drawVariableLabel(
    Canvas canvas,
    String label,
    double rowTop,
    double barCenterY,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '\u2026',
    )..layout(maxWidth: _labelLeftWidth - 16);
    tp.paint(canvas, Offset(6, barCenterY - tp.height / 2));
  }

  // ── Single bar (one direction from center) ──────────────────

  void _drawBar({
    required Canvas canvas,
    required double centerX,
    required double delta,
    required double pxPerChf,
    required double barCenterY,
    required Color color,
    required Color categoryColor,
  }) {
    if (delta.abs() < 0.5) return;

    final barPx = delta * pxPerChf;
    final left = delta >= 0 ? centerX : centerX + barPx;
    final right = delta >= 0 ? centerX + barPx : centerX;
    final barTop = barCenterY - _barHeight / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, barTop, right, barTop + _barHeight),
      const Radius.circular(_barRadius),
    );

    // Fill
    canvas.drawRRect(rect, Paint()..color = color);

    // Subtle category-colored left/right edge
    final edgeRect = delta >= 0
        ? RRect.fromRectAndCorners(
            Rect.fromLTRB(right - 3, barTop, right, barTop + _barHeight),
            topRight: const Radius.circular(_barRadius),
            bottomRight: const Radius.circular(_barRadius),
          )
        : RRect.fromRectAndCorners(
            Rect.fromLTRB(left, barTop, left + 3, barTop + _barHeight),
            topLeft: const Radius.circular(_barRadius),
            bottomLeft: const Radius.circular(_barRadius),
          );
    canvas.drawRRect(edgeRect, Paint()..color = categoryColor);
  }

  // ── Category dot ────────────────────────────────────────────

  void _drawCategoryDot(Canvas canvas, Color color, double x, double y) {
    canvas.drawCircle(
      Offset(x, y),
      3.5,
      Paint()..color = color,
    );
  }

  // ── Tip labels (scenario text + delta CHF) ──────────────────

  void _drawTipLabels({
    required Canvas canvas,
    required TornadoVariable v,
    required double centerX,
    required double pxPerChf,
    required double barCenterY,
    required double chartRight,
    required double chartLeft,
    required Size size,
  }) {
    final lowDelta = v.lowValue - baseCase;
    final highDelta = v.highValue - baseCase;

    final lowBarEnd = centerX + lowDelta * pxPerChf;
    final highBarEnd = centerX + highDelta * pxPerChf;

    // ── Low label (left side typically) ─────────────────────
    final lowDeltaText = _formatChfCompact(lowDelta);
    final lowTp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: v.lowLabel,
            style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontSize: 10, fontStyle: FontStyle.normal),
          ),
          TextSpan(
            text: '  $lowDeltaText',
            style: MintTextStyles.micro(color: lowDelta < 0 ? MintColors.danger : MintColors.success).copyWith(fontSize: 10, fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Position: outside the bar end
    if (lowDelta <= 0) {
      // Bar goes left: label to the left of bar tip
      final labelX = lowBarEnd - lowTp.width - 4;
      final clampedX = max(0.0, labelX);
      lowTp.paint(canvas, Offset(clampedX, barCenterY - lowTp.height / 2));
    } else {
      // Low scenario is still positive: label to the right of bar tip
      final labelX = lowBarEnd + 4;
      lowTp.paint(canvas, Offset(labelX, barCenterY - lowTp.height / 2));
    }

    // ── High label (right side typically) ───────────────────
    final highDeltaText = _formatChfCompact(highDelta);
    final highTp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: highDeltaText,
            style: MintTextStyles.micro(color: highDelta >= 0 ? MintColors.success : MintColors.danger).copyWith(fontSize: 10, fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
          ),
          TextSpan(
            text: '  ${v.highLabel}',
            style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontSize: 10, fontStyle: FontStyle.normal),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (highDelta >= 0) {
      // Bar goes right: label to the right of bar tip
      final labelX = highBarEnd + 4;
      final clampedX = min(labelX, size.width - highTp.width);
      highTp.paint(canvas, Offset(clampedX, barCenterY - highTp.height / 2));
    } else {
      // High scenario is still negative: label to the left of bar tip
      final labelX = highBarEnd - highTp.width - 4;
      highTp.paint(canvas, Offset(labelX, barCenterY - highTp.height / 2));
    }
  }

  // ── Category color mapping ──────────────────────────────────

  static Color _categoryColorFor(String category) {
    switch (category) {
      case 'strategy':
        return MintColors.primary;
      case 'lpp':
        return MintColors.pillarLpp;
      case 'avs':
        return MintColors.amber;
      case '3a':
        return MintColors.positive;
      case 'libre':
        return MintColors.purple;
      case 'depenses':
        return MintColors.danger;
      default:
        return MintColors.textMuted;
    }
  }

  // ── Number formatting ───────────────────────────────────────

  /// Format a delta with sign prefix: "+CHF 800" or "-CHF 400".
  static String _formatDelta(double delta) {
    final abs = delta.abs().round();
    final formatted = abs.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => "${m[1]}'",
    );
    final sign = delta >= 0 ? '+' : '-';
    return '${sign}CHF\u00A0$formatted';
  }

  /// Format large amounts compactly: 272'821 → "+272k", 1'234'000 → "+1.2M".
  static String _formatChfCompact(double delta) {
    final abs = delta.abs();
    final sign = delta >= 0 ? '+' : '-';
    if (abs >= 1000000) return '$sign${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 10000) return '$sign${(abs / 1000).round()}k';
    return _formatDelta(delta);
  }

  @override
  bool shouldRepaint(covariant _TornadoPainter old) =>
      old.baseCase != baseCase || old.variables != variables;
}
