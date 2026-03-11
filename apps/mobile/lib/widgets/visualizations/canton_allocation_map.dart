import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  CANTON FAMILY ALLOCATIONS HEATMAP (BUBBLE TREEMAP)
// ────────────────────────────────────────────────────────────
//
//  Each Swiss canton displayed as a proportional bubble:
//    - Size = population proportion
//    - Color intensity = allocation generosity (emerald gradient)
//    - Tap to select: pulsing highlight + detail card
//    - Top ranking bar
//    - Sort by amount or alphabetical
// ────────────────────────────────────────────────────────────

/// Data for one canton's family allocations.
class CantonAllocation {
  final String code; // e.g. "ZH", "BE"
  final String name; // e.g. "Zurich", "Berne"
  final double allocationPerChild; // CHF per child per month
  final int population; // approximate population

  const CantonAllocation({
    required this.code,
    required this.name,
    required this.allocationPerChild,
    required this.population,
  });
}

/// Sort mode for canton display.
enum CantonSortMode { byAmount, alphabetical }

/// Format a number with Swiss apostrophe thousands separator.
String _formatChf(double value) {
  final abs = value.abs().round();
  final str = abs.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
    buffer.write(str[i]);
  }
  return 'CHF $buffer';
}

class CantonAllocationMap extends StatefulWidget {
  final List<CantonAllocation> cantons;

  /// Initially selected canton code (optional).
  final String? initialSelection;

  /// Callback when a canton is tapped.
  final ValueChanged<CantonAllocation>? onCantonSelected;

  const CantonAllocationMap({
    super.key,
    required this.cantons,
    this.initialSelection,
    this.onCantonSelected,
  });

  @override
  State<CantonAllocationMap> createState() => _CantonAllocationMapState();
}

class _CantonAllocationMapState extends State<CantonAllocationMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _selectedCode;
  CantonSortMode _sortMode = CantonSortMode.byAmount;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.initialSelection;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<CantonAllocation> get _sortedCantons {
    final list = List<CantonAllocation>.from(widget.cantons);
    switch (_sortMode) {
      case CantonSortMode.byAmount:
        list.sort((a, b) => b.allocationPerChild.compareTo(a.allocationPerChild));
      case CantonSortMode.alphabetical:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  double get _minAllocation {
    if (widget.cantons.isEmpty) return 200;
    return widget.cantons
        .map((c) => c.allocationPerChild)
        .reduce(min);
  }

  double get _maxAllocation {
    if (widget.cantons.isEmpty) return 305;
    return widget.cantons
        .map((c) => c.allocationPerChild)
        .reduce(max);
  }

  int get _totalPopulation {
    return widget.cantons.fold(0, (sum, c) => sum + c.population);
  }

  /// Emerald color from light (low) to dark (high).
  Color _allocationColor(double amount) {
    final range = _maxAllocation - _minAllocation;
    final t = range > 0
        ? ((amount - _minAllocation) / range).clamp(0.0, 1.0)
        : 0.5;
    return Color.lerp(
      MintColors.greenLight, // light emerald
      MintColors.greenForest, // dark emerald
      t,
    )!;
  }

  CantonAllocation? get _selectedCanton {
    if (_selectedCode == null) return null;
    try {
      return widget.cantons.firstWhere((c) => c.code == _selectedCode);
    } catch (_) {
      return null;
    }
  }

  int _rankOf(String code) {
    final sorted = List<CantonAllocation>.from(widget.cantons)
      ..sort((a, b) => b.allocationPerChild.compareTo(a.allocationPerChild));
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].code == code) return i + 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Carte des allocations familiales par canton. ${widget.cantons.length} cantons affiches.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
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
                if (_selectedCanton != null) _buildSelectionDetail(),
                _buildColorScale(),
                _buildBubbleGrid(constraints.maxWidth),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MintColors.successDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.map_outlined,
              color: MintColors.successDeep,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allocations familiales',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  'par canton (par enfant/mois)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Sort toggle
          _buildSortToggle(),
        ],
      ),
    );
  }

  Widget _buildSortToggle() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSortButton(
            icon: Icons.sort,
            label: 'CHF',
            mode: CantonSortMode.byAmount,
          ),
          _buildSortButton(
            icon: Icons.sort_by_alpha,
            label: 'A-Z',
            mode: CantonSortMode.alphabetical,
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton({
    required IconData icon,
    required String label,
    required CantonSortMode mode,
  }) {
    final isActive = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? MintColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : MintColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionDetail() {
    final canton = _selectedCanton!;
    final rank = _rankOf(canton.code);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _allocationColor(canton.allocationPerChild)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _allocationColor(canton.allocationPerChild)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _allocationColor(canton.allocationPerChild),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
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
                  '${canton.name} (${canton.code})',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rang $rank sur ${widget.cantons.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatChf(canton.allocationPerChild),
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _allocationColor(canton.allocationPerChild),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorScale() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(
            _formatChf(_minAllocation),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [
                    MintColors.greenLight,
                    MintColors.greenPastel,
                    MintColors.greenDark,
                    MintColors.greenForest,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatChf(_maxAllocation),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleGrid(double availableWidth) {
    final sorted = _sortedCantons;
    final contentWidth = availableWidth - 40; // padding

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: sorted.map((canton) {
          final isSelected = canton.code == _selectedCode;
          // Size proportional to population
          final popRatio = _totalPopulation > 0
              ? (canton.population / _totalPopulation)
              : 1.0 / sorted.length;
          // Clamp bubble size to reasonable range
          final bubbleSize =
              (contentWidth * popRatio * 3).clamp(36.0, 80.0);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCode =
                    _selectedCode == canton.code ? null : canton.code;
              });
              if (widget.onCantonSelected != null) {
                widget.onCantonSelected!(canton);
              }
            },
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = isSelected
                    ? 1.0 + (_pulseAnimation.value * 0.08)
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: bubbleSize,
                height: bubbleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _allocationColor(canton.allocationPerChild)
                      .withValues(alpha: isSelected ? 1.0 : 0.75),
                  border: isSelected
                      ? Border.all(color: MintColors.primary, width: 2.5)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _allocationColor(
                                    canton.allocationPerChild)
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        canton.code,
                        style: GoogleFonts.montserrat(
                          fontSize: bubbleSize > 50 ? 13 : 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (bubbleSize > 50)
                        Text(
                          '${canton.allocationPerChild.round()}',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
