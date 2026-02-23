import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Comparaison visuelle de deux strategies de retrait en capital :
/// naive (tout d'un coup a la retraite) vs echelonnee (sur plusieurs annees).
///
/// Affiche un hero de l'economie fiscale, une timeline horizontale avec les
/// evenements de retrait, et un tableau detaille de la sequence optimale.
///
/// References :
///   - LIFD art. 38 (imposition prestations en capital)
///   - OPP3 art. 3 (retrait 3e pilier)
///   - LPP art. 37 (prestation en capital)
class WithdrawalSequenceChart extends StatelessWidget {
  final WithdrawalSequencingResult result;

  const WithdrawalSequenceChart({
    super.key,
    required this.result,
  });

  // ── Source colors ───────────────────────────────────────────────
  static const _color3a = Color(0xFF10B981); // emerald
  static const _colorLpp = Color(0xFF6366F1); // indigo
  static const _colorLibre = Color(0xFF8B5CF6); // purple

  /// Slight shade variation for multiple 3a accounts.
  static Color _colorForSource(String source) {
    if (source.startsWith('3a')) {
      // Parse account index for shade variation
      final parts = source.split('_');
      final idx = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
      final hsl = HSLColor.fromColor(_color3a);
      final shift = (idx - 1) * 12.0; // slightly rotate hue per account
      return hsl
          .withHue((hsl.hue + shift) % 360)
          .withLightness((hsl.lightness + (idx - 1) * 0.04).clamp(0.0, 0.85))
          .toColor();
    }
    if (source.startsWith('lpp')) return _colorLpp;
    if (source.startsWith('libre')) return _colorLibre;
    return MintColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    // Guard: nothing to show
    if (result.optimizedSequence.isEmpty || result.naiveSequence.isEmpty) {
      return _buildEmptyState(hasCapital: false);
    }
    if (result.taxSavings <= 0) {
      return _buildEmptyState(hasCapital: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre ─────────────────────────────────────────────
        Text(
          'Sequence de retrait optimale',
          style: GoogleFonts.montserrat(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Echelonner les retraits en capital pour reduire '
          'la charge fiscale',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // ── Part 1 : Hero economie fiscale ────────────────────
        _buildHeroCard(),
        const SizedBox(height: 24),

        // ── Part 2 : Timeline chart ──────────────────────────
        _buildTimelineChart(),
        const SizedBox(height: 24),

        // ── Part 3 : Detail table ────────────────────────────
        _buildDetailTable(),
        const SizedBox(height: 20),

        // ── Legend ────────────────────────────────────────────
        _buildLegend(),
        const SizedBox(height: 16),

        // ── Disclaimer + Sources ─────────────────────────────
        _buildDisclaimer(),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ════════════════════════════════════════════════════════════════

  Widget _buildEmptyState({required bool hasCapital}) {
    final message = hasCapital
        ? "Avec un seul compte, l'echelonnement n'apporte pas d'economie "
            "supplementaire. Ouvrir un 2e compte 3a permet de repartir les "
            "retraits sur plusieurs annees fiscales."
        : "Aucun capital a retirer \u2014 pas d'optimisation possible.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: MintColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PART 1 — HERO CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Economie fiscale estimee',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Big green number
          Text(
            _formatChf(result.taxSavings),
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: MintColors.success,
            ),
          ),
          const SizedBox(height: 4),

          // Percentage badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "soit ${(result.savingsPercent * 100).toStringAsFixed(0)}% d'impots en moins",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.success,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Comparison: naive
          _buildComparisonLine(
            label: 'Retrait unique',
            amount: result.totalTaxNaive,
            muted: true,
          ),
          const SizedBox(height: 6),

          // Comparison: optimized
          _buildComparisonLine(
            label: 'Retrait echelonne',
            amount: result.totalTaxOptimized,
            muted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonLine({
    required String label,
    required double amount,
    required bool muted,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: muted
                ? MintColors.textMuted.withValues(alpha: 0.5)
                : MintColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: muted ? MintColors.textMuted : MintColors.textPrimary,
              decoration: muted ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        Text(
          "${_formatChf(amount)} d'impots",
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted ? MintColors.textMuted : MintColors.success,
            decoration: muted ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PART 2 — TIMELINE CHART
  // ════════════════════════════════════════════════════════════════

  Widget _buildTimelineChart() {
    // Compute year range across both sequences
    final allEvents = [
      ...result.optimizedSequence,
      ...result.naiveSequence,
    ];
    if (allEvents.isEmpty) return const SizedBox.shrink();

    final minYear = allEvents.map((e) => e.year).reduce(min);
    final maxYear = allEvents.map((e) => e.year).reduce(max);
    final maxAmount = allEvents.map((e) => e.amount).reduce(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year axis labels
        _buildYearAxis(minYear, maxYear),
        const SizedBox(height: 8),

        // Optimized row
        _buildTimelineRow(
          label: 'Echelonne',
          events: result.optimizedSequence,
          minYear: minYear,
          maxYear: maxYear,
          maxAmount: maxAmount,
          isOptimal: true,
        ),
        const SizedBox(height: 12),

        // Naive row
        _buildTimelineRow(
          label: 'Unique',
          events: result.naiveSequence,
          minYear: minYear,
          maxYear: maxYear,
          maxAmount: maxAmount,
          isOptimal: false,
        ),
      ],
    );
  }

  Widget _buildYearAxis(int minYear, int maxYear) {
    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    return Padding(
      padding: const EdgeInsets.only(left: 80),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final span = max(maxYear - minYear, 1);
          return SizedBox(
            height: 20,
            child: Stack(
              children: years.map((year) {
                final fraction = (year - minYear) / span;
                final x = fraction * (availableWidth - 40);
                return Positioned(
                  left: x,
                  child: Text(
                    '$year',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: MintColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineRow({
    required String label,
    required List<WithdrawalEvent> events,
    required int minYear,
    required int maxYear,
    required double maxAmount,
    required bool isOptimal,
  }) {
    final span = max(maxYear - minYear, 1);
    // Total amount for naive (sum of amounts) — for proportional block width
    final naiveTotal =
        result.naiveSequence.fold<double>(0, (s, e) => s + e.amount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row label
        SizedBox(
          width: 80,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOptimal ? MintColors.success : MintColors.textMuted,
              ),
            ),
          ),
        ),

        // Timeline area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;

              final eventsByYear = <int, List<WithdrawalEvent>>{};
              for (final event in events) {
                eventsByYear.putIfAbsent(event.year, () => []).add(event);
              }
              final maxPerYear = eventsByYear.values
                  .fold<int>(1, (m, list) => max(m, list.length));
              const blockHeight = 36.0;
              const blockGap = 2.0;
              final totalHeight = maxPerYear * (blockHeight + blockGap) + 20;

              final yearIndex = <int, int>{};

              return SizedBox(
                height: totalHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 18,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: MintColors.lightBorder,
                      ),
                    ),
                    ...events.map((event) {
                      final yearFraction = (event.year - minYear) / span;
                      final x = yearFraction * (availableWidth - 40);
                      final widthFraction = event.amount / naiveTotal;
                      final blockWidth =
                          (widthFraction * (availableWidth - 40)).clamp(48.0, availableWidth * 0.8);

                      final idx = yearIndex[event.year] ?? 0;
                      yearIndex[event.year] = idx + 1;
                      final top = idx * (blockHeight + blockGap);

                      return Positioned(
                        left: x,
                        top: top,
                        child: _buildEventBlock(event, blockWidth),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventBlock(WithdrawalEvent event, double blockWidth) {
    final color = _colorForSource(event.source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Colored block
        Container(
          width: blockWidth,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: 0.40),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatChfCompact(event.amount),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (blockWidth > 64)
                Text(
                  event.label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Effective rate below
        Text(
          'taux: ${(event.effectiveRate * 100).toStringAsFixed(1)}%',
          style: GoogleFonts.inter(
            fontSize: 9,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PART 3 — DETAIL TABLE
  // ════════════════════════════════════════════════════════════════

  Widget _buildDetailTable() {
    final events = result.optimizedSequence;
    final totalAmount = events.fold<double>(0, (s, e) => s + e.amount);
    final totalTax = result.totalTaxOptimized;
    final totalRate = totalAmount > 0 ? (totalTax / totalAmount * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sequence optimale',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            children: [
              // Event rows
              ...events.asMap().entries.map((entry) {
                final i = entry.key;
                final event = entry.value;
                return _buildEventRow(
                  event,
                  isLast: i == events.length - 1,
                  showDivider: true,
                );
              }),

              // Separator
              Container(
                height: 1,
                color: MintColors.border,
              ),

              // Total row
              _buildTotalRow(totalAmount, totalTax, totalRate),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventRow(
    WithdrawalEvent event, {
    required bool isLast,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Color dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorForSource(event.source),
                ),
              ),
              const SizedBox(width: 10),

              // Year + age
              SizedBox(
                width: 72,
                child: Text(
                  '${event.year} (${event.age} ans)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ),

              // Source label
              Expanded(
                child: Text(
                  event.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),

              // Amount
              SizedBox(
                width: 80,
                child: Text(
                  _formatChf(event.amount),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tax detail line
        Padding(
          padding: const EdgeInsets.only(left: 32, right: 14, bottom: 8),
          child: Row(
            children: [
              const Spacer(),
              Text(
                'impot: ${_formatChf(event.tax)} '
                '(${(event.effectiveRate * 100).toStringAsFixed(1)}%)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
        ),

        // Divider
        if (showDivider && !isLast)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: MintColors.lightBorder,
          ),
      ],
    );
  }

  Widget _buildTotalRow(double totalAmount, double totalTax, double totalRate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18), // align with dots
          Text(
            'Total',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatChf(totalAmount),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'impot: ${_formatChf(totalTax)} '
                '(${totalRate.toStringAsFixed(1)}%)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MintColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  LEGEND
  // ════════════════════════════════════════════════════════════════

  Widget _buildLegend() {
    // Collect unique source categories from the optimized sequence
    final seen = <String>{};
    final items = <Widget>[];
    for (final event in result.optimizedSequence) {
      final category = _sourceCategory(event.source);
      if (seen.add(category)) {
        items.add(_legendItem(
          _sourceCategoryLabel(category),
          _colorForSource(event.source),
        ));
      }
    }
    return Wrap(spacing: 14, runSpacing: 6, children: items);
  }

  static String _sourceCategory(String source) {
    if (source.startsWith('3a')) return '3a';
    if (source.startsWith('lpp')) return 'lpp';
    if (source.startsWith('libre')) return 'libre';
    return source;
  }

  static String _sourceCategoryLabel(String category) {
    switch (category) {
      case '3a':
        return '3e pilier';
      case 'lpp':
        return 'LPP capital';
      case 'libre':
        return 'Patrimoine libre';
      default:
        return category;
    }
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
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DISCLAIMER + SOURCES
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.disclaimer,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted,
            height: 1.4,
          ),
        ),
        if (result.sources.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            result.sources.join(' \u2022 '),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  NUMBER FORMATTING (Swiss style: CHF 12'400)
  // ════════════════════════════════════════════════════════════════

  /// Format a CHF amount with Swiss apostrophe thousands separator.
  static String _formatChf(double amount) {
    final rounded = amount.round();
    final abs = rounded.abs();
    final formatted = abs.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => "${m[1]}'",
    );
    return rounded >= 0 ? "CHF\u00A0$formatted" : "-CHF\u00A0$formatted";
  }

  /// Compact format: "CHF 80k" for timeline blocks.
  static String _formatChfCompact(double amount) {
    final rounded = amount.round();
    if (rounded.abs() >= 1000) {
      final k = (rounded / 1000).round();
      return 'CHF\u00A0${k}k';
    }
    return _formatChf(amount);
  }
}
