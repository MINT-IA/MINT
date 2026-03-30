import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/milestone_detection_service.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  MILESTONE CELEBRATION SHEET — T5 / Coach AI Layer
// ────────────────────────────────────────────────────────────
//
// Bottom sheet anime avec confetti pour celebrer un milestone
// financier. Affiche apres un check-in quand
// MilestoneDetectionService.detectNew() retourne des resultats.
//
// Design : premium fintech, celebratoire sans etre enfantin.
// Animations : confetti burst (3s), icon scale (elasticOut 800ms).
// Dispose : ConfettiController et AnimationController propres.
// ────────────────────────────────────────────────────────────

/// Bottom sheet de celebration d'un milestone financier.
///
/// Affiche un confetti burst, une icone animee, le titre et la
/// description du milestone, et un bouton "Continuer".
///
/// Usage :
/// ```dart
/// await showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: MintColors.transparent,
///   builder: (_) => MilestoneCelebrationSheet(milestone: milestone),
/// );
/// ```
class MilestoneCelebrationSheet extends StatefulWidget {
  /// Le milestone a celebrer.
  final MilestoneEvent milestone;

  const MilestoneCelebrationSheet({
    super.key,
    required this.milestone,
  });

  @override
  State<MilestoneCelebrationSheet> createState() =>
      _MilestoneCelebrationSheetState();
}

class _MilestoneCelebrationSheetState extends State<MilestoneCelebrationSheet>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _iconAnimController;
  late final Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Confetti: blast for 3 seconds
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Icon animation: scale up with elasticOut, 800ms
    _iconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _iconScaleAnimation = CurvedAnimation(
      parent: _iconAnimController,
      curve: Curves.elasticOut,
    );

    // Auto-play confetti and icon animation on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
      _iconAnimController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _iconAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestone;
    final milestoneColor = milestone.color;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // ── Bottom sheet content ───────────────────────────
        Container(
          margin: const EdgeInsets.only(top: 40),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                milestoneColor.withValues(alpha: 0.08),
                MintColors.white,
                MintColors.white,
              ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MintColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Animated icon ───────────────────────────
                AnimatedBuilder(
                  animation: _iconScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _iconScaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: milestoneColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: milestoneColor.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      milestone.icon,
                      color: milestoneColor,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Title ───────────────────────────────────
                Text(
                  milestone.title,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),

                // ── Description (or narrative message if BYOK)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    milestone.narrativeMessage ?? milestone.description,
                    textAlign: TextAlign.center,
                    style: MintTextStyles.labelLarge(color: MintColors.textSecondary).copyWith(height: 1.55),
                  ),
                ),
                const SizedBox(height: 32),

                // ── CTA Button ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: milestoneColor,
                      foregroundColor: MintColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      S.of(context)!.milestoneContinueBtn,
                      style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Confetti widget (overlay, centered) ───────────
        Positioned(
          top: 60,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -pi / 2, // upward
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.15,
            emissionFrequency: 0.05,
            colors: [
              milestoneColor,
              milestoneColor.withValues(alpha: 0.7),
              MintColors.success,
              MintColors.warning,
              MintColors.info,
              MintColors.purple,
            ],
            shouldLoop: false,
          ),
        ),
      ],
    );
  }
}
