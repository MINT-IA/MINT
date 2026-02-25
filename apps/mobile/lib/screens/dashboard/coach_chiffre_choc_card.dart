/// Coach Chiffre Choc Card — Sprint S35 (Coach Narrative).
///
/// Dashboard card displaying a "shock figure" reframed with
/// confidence context from the Coach Narrative Service.
///
/// Design:
///   - Material 3 Card with MintColors
///   - Montserrat heading, Inter body (GoogleFonts)
///   - Gauge-style confidence indicator
///   - Animated entrance
///
/// All text in French (informal "tu"). No banned terms.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class CoachChiffreChocCard extends StatefulWidget {
  /// Reframed chiffre choc text from CoachNarrativeService.
  final String chiffreChocReframe;

  /// Confidence score (0-100) for the visual indicator.
  final double confidenceScore;

  /// Callback when card is tapped.
  final VoidCallback? onTap;

  const CoachChiffreChocCard({
    super.key,
    required this.chiffreChocReframe,
    this.confidenceScore = 0,
    this.onTap,
  });

  @override
  State<CoachChiffreChocCard> createState() => _CoachChiffreChocCardState();
}

class _CoachChiffreChocCardState extends State<CoachChiffreChocCard>
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
      begin: const Offset(0, 0.06),
      end: const Offset.zero,
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

  Color _confidenceColor(double score) {
    if (score >= 70) return MintColors.success;
    if (score >= 40) return MintColors.warning;
    return MintColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final confColor = _confidenceColor(widget.confidenceScore);

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
              borderRadius: const Borderconst Radius.circular(20),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: MintColors.purple.withAlpha(10),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MintColors.purple.withAlpha(20),
                        borderRadius: const Borderconst Radius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: MintColors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Chiffre choc',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    // ── Confidence badge ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: confColor.withAlpha(15),
                        borderRadius: const Borderconst Radius.circular(8),
                      ),
                      child: Text(
                        '${widget.confidenceScore.toStringAsFixed(0)}% fiable',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: confColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Confidence bar ──
                ClipRRect(
                  borderRadius: const Borderconst Radius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.confidenceScore / 100,
                    minHeight: 4,
                    backgroundColor: MintColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation(confColor),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Reframe text ──
                Text(
                  widget.chiffreChocReframe,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
