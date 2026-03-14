import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/retirement/monte_carlo_chart.dart';

/// Toggle section for switching between deterministic 3-scenarios view
/// and probabilistic Monte Carlo fan chart.
///
/// P4 gate: confidence >= 70% required for Monte Carlo display.
/// Includes depletion risk badge and compliance disclaimer.
///
/// Ref: outil educatif (LSFin). Ne constitue pas un conseil.
class MonteCarloToggleSection extends StatefulWidget {
  /// Monte Carlo simulation result (null = not computed yet).
  final MonteCarloResult? monteCarloResult;

  /// Current monthly income for reference line.
  final double? currentMonthlyIncome;

  /// Widget to show in "3 Scenarios" mode (existing TrajectoryCard).
  final Widget scenariosChild;

  /// Whether Monte Carlo is available (confidence >= 70%).
  final bool monteCarloAvailable;

  const MonteCarloToggleSection({
    super.key,
    required this.monteCarloResult,
    required this.scenariosChild,
    this.currentMonthlyIncome,
    this.monteCarloAvailable = true,
  });

  @override
  State<MonteCarloToggleSection> createState() =>
      _MonteCarloToggleSectionState();
}

class _MonteCarloToggleSectionState extends State<MonteCarloToggleSection> {
  bool _showMonteCarlo = false;

  @override
  void didUpdateWidget(covariant MonteCarloToggleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset toggle when MC becomes unavailable (Fix MED: title/content mismatch)
    if (!widget.monteCarloAvailable && oldWidget.monteCarloAvailable) {
      _showMonteCarlo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toggle header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showMonteCarlo
                        ? s.monteCarloProbabilities
                        : s.monteCarlo3Scenarios,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                _buildToggle(s),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Content ────────────────────────────────────
          if (_showMonteCarlo && widget.monteCarloAvailable)
            _buildMonteCarloView(s)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: widget.scenariosChild,
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildToggle(S s) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            label: s.monteCarlo3Scenarios,
            isSelected: !_showMonteCarlo,
            onTap: () => setState(() => _showMonteCarlo = false),
          ),
          _buildToggleButton(
            label: s.monteCarloProbabilities,
            isSelected: _showMonteCarlo,
            onTap: widget.monteCarloAvailable
                ? () => setState(() => _showMonteCarlo = true)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? MintColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? MintColors.white
                    : enabled
                        ? MintColors.textSecondary
                        : MintColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonteCarloView(S s) {
    final result = widget.monteCarloResult;
    if (result == null || result.projection.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          s.monteCarloSimulating,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Depletion risk badge ──────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildDepletionBadge(result.ruinProbability, s),
        ),
        const SizedBox(height: 12),

        // ── Fan chart ────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: MonteCarloChart(
            result: result,
            currentMonthlyIncome: widget.currentMonthlyIncome,
          ),
        ),

        // ── Disclaimer ───────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            s.monteCarloDisclaimer('${result.numSimulations}'),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepletionBadge(double ruinProbability, S s) {
    final pct = (ruinProbability * 100).round();
    final Color badgeColor;
    final String label;

    if (pct <= 10) {
      badgeColor = MintColors.success;
      label = s.monteCarloRiskLow;
    } else if (pct <= 25) {
      badgeColor = MintColors.warning;
      label = s.monteCarloRiskModerate;
    } else {
      badgeColor = MintColors.error;
      label = s.monteCarloRiskHigh;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pct <= 10
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            size: 16,
            color: badgeColor,
          ),
          const SizedBox(width: 6),
          Text(
            '$label\u00a0: $pct\u00a0%',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Teaser version for State B (confidence 40-69%).
///
/// Shows a generic, blurred fan chart with no personal data.
/// 100% non-personnalisé — conformité LSFin appliquée.
class MonteCarloTeaser extends StatelessWidget {
  /// Callback when user taps to enrich profile.
  final VoidCallback? onEnrich;

  /// Category names of the most impactful missing fields (max 3).
  /// Display ONLY the category name (e.g. "LPP", "3a"), never values.
  final List<String> missingCategories;

  const MonteCarloTeaser({
    super.key,
    this.onEnrich,
    this.missingCategories = const [],
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return GestureDetector(
      onTap: onEnrich,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.monteCarloTeaserTitle,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // ── Blurred generic fan chart ─────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                child: CustomPaint(
                  size: const Size(double.infinity, 140),
                  painter: _GenericFanChartPainter(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Educational message ───────────────────
            Text(
              s.monteCarloTeaserMessage,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
            // ── Missing category chips (categories only, no values) ──
            if (missingCategories.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: missingCategories.take(3).map((cat) {
                  final displayName = _categoryDisplayName(cat, s);
                  if (displayName == null) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: MintColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MintColors.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),

            // ── Enrichment CTA ────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: MintColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.monteCarloTeaserCta,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MintColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text(
              s.monteCarloTeaserDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns display name for known pillar/domain categories.
  /// Returns null for internal-only categories (income, retirement_urgency, etc.)
  /// to prevent leaking raw internal labels to the UI.
  static String? _categoryDisplayName(String category, S s) {
    return switch (category) {
      'lpp' => s.monteCarloCatLpp,
      'avs' => s.monteCarloCatAvs,
      '3a' => s.monteCarloCat3a,
      'patrimoine' => s.monteCarloCatPatrimoine,
      'logement' => s.monteCarloCatLogement,
      'foreign_pension' => s.monteCarloCatForeignPension,
      'depenses' => s.monteCarloCatDepenses,
      _ => null,
    };
  }
}

/// Paints a generic, hardcoded fan chart for the teaser.
///
/// Uses FAKE data — no user profile data. Purely decorative.
class _GenericFanChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Hardcoded generic curves (NOT user data)
    const points = 20;
    final p50 = List.generate(points, (i) {
      final t = i / (points - 1);
      return h * 0.35 + h * 0.15 * t + h * 0.05 * (t * t);
    });
    final p25 = List.generate(points, (i) => p50[i] - h * 0.08 - i * 0.3);
    final p75 = List.generate(points, (i) => p50[i] + h * 0.08 + i * 0.3);
    final p10 = List.generate(points, (i) => p25[i] - h * 0.06 - i * 0.4);
    final p90 = List.generate(points, (i) => p75[i] + h * 0.06 + i * 0.4);

    double xFor(int i) => (i / (points - 1)) * w;

    // P10-P90 band
    _drawBand(canvas, points, xFor, p10, p90,
        MintColors.primary.withValues(alpha: 0.12));
    // P25-P75 band
    _drawBand(canvas, points, xFor, p25, p75,
        MintColors.primary.withValues(alpha: 0.25));

    // P50 line
    final linePaint = Paint()
      ..color = MintColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < points; i++) {
      final x = xFor(i);
      final y = p50[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  void _drawBand(Canvas canvas, int count, double Function(int) xFor,
      List<double> upper, List<double> lower, Color color) {
    final path = Path();
    for (int i = 0; i < count; i++) {
      final x = xFor(i);
      if (i == 0) {
        path.moveTo(x, upper[i]);
      } else {
        path.lineTo(x, upper[i]);
      }
    }
    for (int i = count - 1; i >= 0; i--) {
      path.lineTo(xFor(i), lower[i]);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
