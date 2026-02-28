import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  CONFIDENCE BAR — LOT 4 / Retirement Dashboard
// ────────────────────────────────────────────────────────────
//
//  Barre de progression animee indiquant le score de confiance
//  de la projection (0-100%).
//
//  Couleurs :
//    >= 70  → vert   (projection fiable)
//    >= 40  → orange (projection partielle)
//    < 40   → rouge  (donnees insuffisantes)
//
//  Widget pur — aucune dependance Provider.
// ────────────────────────────────────────────────────────────

class ConfidenceBar extends StatefulWidget {
  /// Score de confiance entre 0 et 100.
  final double score;

  /// Affiche le label "Precision : X%" si true (defaut).
  final bool showLabel;

  const ConfidenceBar({
    super.key,
    required this.score,
    this.showLabel = true,
  });

  @override
  State<ConfidenceBar> createState() => _ConfidenceBarState();
}

class _ConfidenceBarState extends State<ConfidenceBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _widthAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ConfidenceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Couleur de la barre selon le niveau de confiance.
  Color get _barColor {
    if (widget.score >= 70) return MintColors.scoreExcellent;
    if (widget.score >= 40) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  /// Label du niveau de confiance.
  String get _levelLabel {
    if (widget.score >= 70) return 'Fiable';
    if (widget.score >= 40) return 'Partielle';
    return 'Faible';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (widget.score / 100.0).clamp(0.0, 1.0);

    return Semantics(
      label: 'Pr\u00e9cision de la projection\u00a0: ${widget.score.round()}%.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLabel) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pr\u00e9cision de la projection',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _barColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _levelLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _barColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.score.round()}%',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _barColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          AnimatedBuilder(
            animation: _widthAnimation,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: 6,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        height: 6,
                        width:
                            constraints.maxWidth * fraction * _widthAnimation.value,
                        decoration: BoxDecoration(
                          color: _barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
