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
//  P1-I: Enriched with thermometer zones + enrichment CTA.
//
//  Widget pur — aucune dependance Provider.
// ────────────────────────────────────────────────────────────

class ConfidenceBar extends StatefulWidget {
  /// Score de confiance entre 0 et 100.
  final double score;

  /// Affiche le label "Precision : X%" si true (defaut).
  final bool showLabel;

  /// P1-I: Enrichment actions to improve confidence.
  /// Each entry: {'label': 'description', 'icon': IconData?}
  final List<Map<String, dynamic>>? enrichmentActions;

  /// P1-I: Callback when user taps an enrichment action.
  final ValueChanged<int>? onEnrichAction;

  const ConfidenceBar({
    super.key,
    required this.score,
    this.showLabel = true,
    this.enrichmentActions,
    this.onEnrichAction,
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

  /// P1-I: Zone description for thermometer.
  String get _zoneDescription {
    if (widget.score >= 95) return 'Photo parfaite';
    if (widget.score >= 70) return 'Bonne estimation';
    if (widget.score >= 40) return 'Estimation large';
    return 'On devine beaucoup';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (widget.score / 100.0).clamp(0.0, 1.0);
    final hasEnrichment = widget.enrichmentActions != null &&
        widget.enrichmentActions!.isNotEmpty;

    return Semantics(
      label: 'Qualit\u00e9 de ta projection\u00a0: ${widget.score.round()}%.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLabel) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qualit\u00e9 de ta projection',
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
                        _zoneDescription,
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
          // ── Thermometer bar with zone markers (P1-I) ──
          AnimatedBuilder(
            animation: _widthAnimation,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  return Column(
                    children: [
                      Stack(
                        children: [
                          // Background track with zones
                          Container(
                            height: 8,
                            width: barWidth,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: [
                                  MintColors.scoreCritique
                                      .withValues(alpha: 0.15),
                                  MintColors.scoreAttention
                                      .withValues(alpha: 0.15),
                                  MintColors.scoreExcellent
                                      .withValues(alpha: 0.15),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                          // Filled progress
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            height: 8,
                            width: barWidth *
                                fraction *
                                _widthAnimation.value,
                            decoration: BoxDecoration(
                              color: _barColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      // Zone labels
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '20%',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: MintColors.textMuted,
                            ),
                          ),
                          Text(
                            '40%',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: MintColors.textMuted,
                            ),
                          ),
                          Text(
                            '70%',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: MintColors.textMuted,
                            ),
                          ),
                          Text(
                            '95%',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: MintColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          // ── P1-I: Enrichment CTA ──
          if (hasEnrichment && widget.score < 80) ...[
            const SizedBox(height: 10),
            _buildEnrichmentActions(),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  P1-I: ENRICHMENT ACTIONS
  // ────────────────────────────────────────────────────────────

  Widget _buildEnrichmentActions() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pour am\u00e9liorer ta projection',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          ...widget.enrichmentActions!
              .take(2)
              .toList()
              .asMap()
              .entries
              .map((entry) {
            final index = entry.key;
            final action = entry.value;
            final icon =
                action['icon'] as IconData? ?? Icons.add_circle_outline;
            return GestureDetector(
              onTap: widget.onEnrichAction != null
                  ? () => widget.onEnrichAction!(index)
                  : null,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: MintColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        action['label'] as String? ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 16, color: MintColors.textMuted),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
