/// Coach Tip Card — Sprint S35 (Coach Narrative).
///
/// Dashboard card displaying the daily educational tip from
/// the Coach Narrative Service.
///
/// Design:
///   - Material 3 Card with MintColors
///   - Montserrat heading, Inter body (GoogleFonts)
///   - Lightbulb icon accent
///   - Subtle fade-in animation
///
/// All text in French (informal "tu"). No banned terms.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class CoachTipCard extends StatefulWidget {
  /// Tip narrative from CoachNarrativeService.
  final String tipNarrative;

  /// Callback when card is tapped (navigate to detail).
  final VoidCallback? onTap;

  const CoachTipCard({
    super.key,
    required this.tipNarrative,
    this.onTap,
  });

  @override
  State<CoachTipCard> createState() => _CoachTipCardState();
}

class _CoachTipCardState extends State<CoachTipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: const BorderRadius.circular(20),
            border: Border.all(color: MintColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: MintColors.coachAccent.withAlpha(10),
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
                      color: MintColors.warning.withAlpha(20),
                      borderRadius: const BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: MintColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tip du jour',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Tip text ──
              Text(
                widget.tipNarrative,
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
    );
  }
}
