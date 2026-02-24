/// Coach Pulse Card — Sprint S35 (Coach Narrative).
///
/// Dashboard card that replaces the static pulse display with
/// dynamic coach narratives: greeting + FRI score summary.
///
/// Design:
///   - Material 3 Card with MintColors
///   - Montserrat heading, Inter body (GoogleFonts)
///   - Animated reveal effect (fade + slide)
///   - Score gauge with color-coded indicator
///
/// All text in French (informal "tu"). No banned terms.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class CoachPulseCard extends StatefulWidget {
  /// Personalized greeting from CoachNarrativeService.
  final String greeting;

  /// Score summary with trend from CoachNarrativeService.
  final String scoreSummary;

  /// Current FRI score (0-100).
  final double friScore;

  /// FRI delta since last check-in.
  final double friDelta;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  const CoachPulseCard({
    super.key,
    required this.greeting,
    required this.scoreSummary,
    required this.friScore,
    this.friDelta = 0,
    this.onTap,
  });

  @override
  State<CoachPulseCard> createState() => _CoachPulseCardState();
}

class _CoachPulseCardState extends State<CoachPulseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _scoreColor(double score) {
    if (score >= 75) return MintColors.scoreExcellent;
    if (score >= 55) return MintColors.scoreBon;
    if (score >= 35) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(widget.friScore);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: scoreColor.withAlpha(20),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──
                Text(
                  widget.greeting,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Score indicator row ──
                Row(
                  children: [
                    // Score circle
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withAlpha(20),
                        border: Border.all(color: scoreColor, width: 2.5),
                      ),
                      child: Center(
                        child: Text(
                          widget.friScore.toStringAsFixed(0),
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Score summary text
                    Expanded(
                      child: Text(
                        widget.scoreSummary,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: MintColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Delta badge (if non-zero) ──
                if (widget.friDelta != 0) ...[
                  const SizedBox(height: 12),
                  _DeltaBadge(delta: widget.friDelta),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small badge showing the FRI score change.
class _DeltaBadge extends StatelessWidget {
  final double delta;
  const _DeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isPositive = delta > 0;
    final color = isPositive ? MintColors.success : MintColors.error;
    final icon = isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$sign${delta.toStringAsFixed(0)} pts',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
