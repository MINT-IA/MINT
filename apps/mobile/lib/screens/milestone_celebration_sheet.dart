/// Milestone Celebration Sheet — Sprint S36.
///
/// Modal bottom sheet displaying a detected milestone with
/// celebratory animation (scale + fade + shimmer effect).
///
/// Design:
///   - Material 3 BottomSheet
///   - Icon matching milestone type
///   - Large celebration text (Montserrat)
///   - Concrete value highlighted
///   - "Continuer" CTA button
///   - No confetti dependency — pure Flutter animations
///
/// COMPLIANCE:
/// - No social comparison
/// - No guarantee language
/// - Factual celebration text only
/// - All French (informal "tu")
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/milestone_detection_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  MILESTONE CELEBRATION SHEET — S36 / Notifications + Milestones
// ────────────────────────────────────────────────────────────
//
// Bottom sheet anime pour celebrer un DetectedMilestone (S36).
// Animations : scale bounce (0.8 -> 1.0, elasticOut) +
//              shimmer sur l'icone (gradient rotatif).
//
// Pas de dependance confetti — tout est en Flutter natif.
// ────────────────────────────────────────────────────────────

/// Bottom sheet de celebration d'un milestone financier (S36).
///
/// Affiche une animation scale + shimmer sur l'icone,
/// le texte de celebration, la valeur concrete mise en avant,
/// et un bouton "Continuer".
class MilestoneCelebrationSheet extends StatefulWidget {
  /// The milestone to celebrate.
  final DetectedMilestone milestone;

  /// Optional callback when sheet is dismissed.
  final VoidCallback? onDismiss;

  const MilestoneCelebrationSheet({
    super.key,
    required this.milestone,
    this.onDismiss,
  });

  /// Show as a modal bottom sheet.
  static Future<void> show(
    BuildContext context,
    DetectedMilestone milestone, {
    VoidCallback? onDismiss,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MilestoneCelebrationSheet(
        milestone: milestone,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<MilestoneCelebrationSheet> createState() =>
      _MilestoneCelebrationSheetState();
}

class _MilestoneCelebrationSheetState extends State<MilestoneCelebrationSheet>
    with TickerProviderStateMixin {
  /// Scale animation: 0.8 -> 1.0 with bounce curve.
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  /// Fade animation: 0.0 -> 1.0.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  /// Shimmer rotation animation for the icon ring.
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // Scale: bounce from 0.8 to 1.0 over 800ms
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Fade: 0.0 to 1.0 over 500ms
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Shimmer: continuous rotation over 2s
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Start animations after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaleController.forward();
      _fadeController.forward();
      _shimmerController.repeat();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestone;
    final milestoneColor = _colorForType(milestone.type);
    final milestoneIcon = _iconForType(milestone.type);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            milestoneColor.withValues(alpha: 0.08),
            Colors.white,
            Colors.white,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle bar ──────────────────────────────────
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
            const SizedBox(height: 32),

            // ── Animated icon with shimmer ring ─────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _ShimmerIcon(
                  icon: milestoneIcon,
                  color: milestoneColor,
                  shimmerController: _shimmerController,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Concrete value (highlighted) ────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: milestoneColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  milestone.concreteValue,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: milestoneColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Celebration text ────────────────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  milestone.celebrationText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: MintColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── CTA Button ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDismiss?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: milestoneColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Continuer',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Icon mapping per milestone type ──────────────────────

  static IconData _iconForType(MilestoneType type) {
    return switch (type) {
      MilestoneType.emergencyFund3Months => Icons.shield_outlined,
      MilestoneType.emergencyFund6Months => Icons.shield_outlined,
      MilestoneType.threeAMaxReached => Icons.savings_outlined,
      MilestoneType.lppBuybackCompleted => Icons.account_balance_outlined,
      MilestoneType.friImproved10Points => Icons.trending_up_rounded,
      MilestoneType.friAbove50 => Icons.star_rounded,
      MilestoneType.friAbove70 => Icons.star_rounded,
      MilestoneType.friAbove85 => Icons.star_rounded,
      MilestoneType.patrimoine50k => Icons.account_balance_wallet_outlined,
      MilestoneType.patrimoine100k => Icons.account_balance_wallet_outlined,
      MilestoneType.patrimoine250k => Icons.account_balance_wallet_outlined,
      MilestoneType.firstArbitrageCompleted => Icons.compare_arrows_rounded,
      MilestoneType.checkInStreak6Months =>
        Icons.local_fire_department_rounded,
      MilestoneType.checkInStreak12Months =>
        Icons.local_fire_department_rounded,
    };
  }

  // ── Color mapping per milestone type ─────────────────────

  static Color _colorForType(MilestoneType type) {
    return switch (type) {
      MilestoneType.emergencyFund3Months => MintColors.success,
      MilestoneType.emergencyFund6Months => MintColors.success,
      MilestoneType.threeAMaxReached => MintColors.purple,
      MilestoneType.lppBuybackCompleted => MintColors.info,
      MilestoneType.friImproved10Points => MintColors.success,
      MilestoneType.friAbove50 => MintColors.amber,
      MilestoneType.friAbove70 => MintColors.amber,
      MilestoneType.friAbove85 => MintColors.amber,
      MilestoneType.patrimoine50k => MintColors.teal,
      MilestoneType.patrimoine100k => MintColors.teal,
      MilestoneType.patrimoine250k => MintColors.teal,
      MilestoneType.firstArbitrageCompleted => MintColors.info,
      MilestoneType.checkInStreak6Months => MintColors.deepOrange,
      MilestoneType.checkInStreak12Months => MintColors.deepOrange,
    };
  }
}

// ════════════════════════════════════════════════════════════
//  SHIMMER ICON — animated gradient ring around the icon
// ════════════════════════════════════════════════════════════

class _ShimmerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final AnimationController shimmerController;

  const _ShimmerIcon({
    required this.icon,
    required this.color,
    required this.shimmerController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ShimmerRingPainter(
            progress: shimmerController.value,
            color: color,
          ),
          child: child,
        );
      },
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 44,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  SHIMMER RING PAINTER — rotating gradient arc
// ════════════════════════════════════════════════════════════

class _ShimmerRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ShimmerRingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 4;
    final startAngle = progress * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + math.pi,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_ShimmerRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
