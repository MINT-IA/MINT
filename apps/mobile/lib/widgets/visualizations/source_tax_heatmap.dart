import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  SOURCE TAX HEATMAP — Expatriation & Frontaliers Module
// ────────────────────────────────────────────────────────────
//
//  Gradient heatmap showing source tax rates across 26 Swiss cantons.
//    - Stylised Swiss map grid layout (26 cells)
//    - Color gradient: green (low ~10%) → orange (~13%) → red (high ~16%)
//    - Selected canton highlighted with border + scale-up
//    - Stagger fade-in animation (50ms per cell)
//    - Legend bar at bottom showing gradient scale
// ────────────────────────────────────────────────────────────

/// Data for a single canton cell in the heatmap.
class CantonTaxRate {
  final String abbreviation;
  final String name;
  final double rate; // e.g. 12.5 for 12.5%

  const CantonTaxRate({
    required this.abbreviation,
    required this.name,
    required this.rate,
  });
}

/// Default source tax rates by canton (approximate averages for a
/// single earner, CHF 80k income, no children — illustrative data).
const List<CantonTaxRate> kDefaultCantonTaxRates = [
  CantonTaxRate(abbreviation: 'ZH', name: 'Zurich', rate: 12.2),
  CantonTaxRate(abbreviation: 'BE', name: 'Berne', rate: 14.1),
  CantonTaxRate(abbreviation: 'LU', name: 'Lucerne', rate: 11.8),
  CantonTaxRate(abbreviation: 'UR', name: 'Uri', rate: 10.9),
  CantonTaxRate(abbreviation: 'SZ', name: 'Schwyz', rate: 10.1),
  CantonTaxRate(abbreviation: 'OW', name: 'Obwald', rate: 10.6),
  CantonTaxRate(abbreviation: 'NW', name: 'Nidwald', rate: 10.3),
  CantonTaxRate(abbreviation: 'GL', name: 'Glaris', rate: 12.8),
  CantonTaxRate(abbreviation: 'ZG', name: 'Zoug', rate: 9.8),
  CantonTaxRate(abbreviation: 'FR', name: 'Fribourg', rate: 14.3),
  CantonTaxRate(abbreviation: 'SO', name: 'Soleure', rate: 13.6),
  CantonTaxRate(abbreviation: 'BS', name: 'Bale-Ville', rate: 14.8),
  CantonTaxRate(abbreviation: 'BL', name: 'Bale-Campagne', rate: 13.9),
  CantonTaxRate(abbreviation: 'SH', name: 'Schaffhouse', rate: 12.5),
  CantonTaxRate(abbreviation: 'AR', name: 'Appenzell RE', rate: 11.7),
  CantonTaxRate(abbreviation: 'AI', name: 'Appenzell RI', rate: 10.5),
  CantonTaxRate(abbreviation: 'SG', name: 'Saint-Gall', rate: 13.1),
  CantonTaxRate(abbreviation: 'GR', name: 'Grisons', rate: 12.4),
  CantonTaxRate(abbreviation: 'AG', name: 'Argovie', rate: 12.9),
  CantonTaxRate(abbreviation: 'TG', name: 'Thurgovie', rate: 12.1),
  CantonTaxRate(abbreviation: 'TI', name: 'Tessin', rate: 13.4),
  CantonTaxRate(abbreviation: 'VD', name: 'Vaud', rate: 14.6),
  CantonTaxRate(abbreviation: 'VS', name: 'Valais', rate: 13.0),
  CantonTaxRate(abbreviation: 'NE', name: 'Neuchatel', rate: 14.9),
  CantonTaxRate(abbreviation: 'GE', name: 'Geneve', rate: 15.5),
  CantonTaxRate(abbreviation: 'JU', name: 'Jura', rate: 15.2),
];

/// Format a percentage with one decimal.
String _formatPct(double value) => '${value.toStringAsFixed(1)}%';

class SourceTaxHeatmap extends StatefulWidget {
  /// Canton tax rate data. Defaults to [kDefaultCantonTaxRates].
  final List<CantonTaxRate> cantonRates;

  /// Index of the currently selected canton (-1 for none).
  final int selectedIndex;

  /// Callback when a canton cell is tapped.
  final ValueChanged<int>? onCantonSelected;

  const SourceTaxHeatmap({
    super.key,
    this.cantonRates = kDefaultCantonTaxRates,
    this.selectedIndex = -1,
    this.onCantonSelected,
  });

  @override
  State<SourceTaxHeatmap> createState() => _SourceTaxHeatmapState();
}

class _SourceTaxHeatmapState extends State<SourceTaxHeatmap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _staggerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 600 + widget.cantonRates.length * 50,
      ),
    );
    _staggerAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(SourceTaxHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cantonRates != widget.cantonRates) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Min and max rates for color interpolation.
  double get _minRate =>
      widget.cantonRates.map((c) => c.rate).reduce(min);
  double get _maxRate =>
      widget.cantonRates.map((c) => c.rate).reduce(max);

  /// Interpolate color: green → orange → red based on rate.
  Color _colorForRate(double rate) {
    final range = _maxRate - _minRate;
    if (range == 0) return MintColors.success;
    final t = ((rate - _minRate) / range).clamp(0.0, 1.0);
    if (t < 0.5) {
      // Green → Orange
      return Color.lerp(
        MintColors.success,
        MintColors.warning,
        t * 2,
      )!;
    } else {
      // Orange → Red
      return Color.lerp(
        MintColors.warning,
        MintColors.error,
        (t - 0.5) * 2,
      )!;
    }
  }

  // Stylised Swiss map layout: rows of canton indices.
  // Approximation of geographic positions.
  static const List<List<int>> _mapLayout = [
    [13, 0, 19], // SH, ZH, TG
    [11, 12, 18, 14, 15], // BS, BL, AG, AR, AI
    [10, -1, 7, 16, -1], // SO, -, GL, SG, -
    [1, 2, 8, -1, 17], // BE, LU, ZG, -, GR
    [23, 9, 3, 5, 6], // NE, FR, UR, OW, NW
    [24, 22, 4, -1, -1], // GE, VS, SZ, -, -
    [25, 21, 20, -1, -1], // JU, VD, TI, -, -
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Carte thermique des taux d\'imposition a la source par canton suisse',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: MintColors.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildHeatmapGrid(),
                const SizedBox(height: 16),
                _buildLegendBar(),
                if (widget.selectedIndex >= 0 &&
                    widget.selectedIndex < widget.cantonRates.length)
                  _buildSelectedDetail(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MintColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            color: MintColors.warning,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Taux d\'imposition a la source',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                '26 cantons  ·  Celibataire, CHF 80\'000',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapGrid() {
    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        // Flatten to find sequential order for stagger
        int cellOrder = 0;
        final totalCells = widget.cantonRates.length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: _mapLayout.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((cantonIndex) {
                  if (cantonIndex < 0 ||
                      cantonIndex >= widget.cantonRates.length) {
                    // Empty cell placeholder
                    return const SizedBox(width: 58, height: 48);
                  }

                  final canton = widget.cantonRates[cantonIndex];
                  final isSelected = cantonIndex == widget.selectedIndex;
                  final order = cellOrder++;
                  final cellProgress =
                      ((_staggerAnimation.value * totalCells) - order)
                          .clamp(0.0, 1.0);

                  return GestureDetector(
                    onTap: () => widget.onCantonSelected?.call(cantonIndex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: 58,
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      transform: Matrix4.identity()
                        ..scaleByDouble(isSelected ? 1.1 : 1.0),
                      transformAlignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _colorForRate(canton.rate)
                            .withValues(alpha: 0.15 + 0.7 * cellProgress),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? MintColors.primary
                              : _colorForRate(canton.rate)
                                  .withValues(alpha: 0.3),
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: Opacity(
                        opacity: cellProgress,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              canton.abbreviation,
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: MintColors.textPrimary,
                              ),
                            ),
                            Text(
                              _formatPct(canton.rate),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: _colorForRate(canton.rate),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLegendBar() {
    return Column(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: LinearGradient(
              colors: [
                MintColors.success,
                MintColors.warning,
                MintColors.error,
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatPct(_minRate),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: MintColors.success,
              ),
            ),
            Text(
              'Taux moyen',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
              ),
            ),
            Text(
              _formatPct(_maxRate),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: MintColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedDetail() {
    final canton = widget.cantonRates[widget.selectedIndex];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _colorForRate(canton.rate).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _colorForRate(canton.rate).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _colorForRate(canton.rate).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                canton.abbreviation,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _colorForRate(canton.rate),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canton.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  'Taux indicatif d\'imposition a la source',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatPct(canton.rate),
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _colorForRate(canton.rate),
            ),
          ),
        ],
      ),
    );
  }
}
