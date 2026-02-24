import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';

// ────────────────────────────────────────────────────────────
//  DOCUMENT IMPACT SCREEN — Sprint S42-S43
// ────────────────────────────────────────────────────────────
//
//  Post-confirmation celebration screen.
//  "Ton profil est plus precis" — animated confidence circle
//  that goes from oldConfidence to newConfidence.
//
//  Inspired by ScoreRevealScreen (Apple Watch ring close).
//
//  Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1
//  User flow step 6: impact reveal.
// ────────────────────────────────────────────────────────────

class DocumentImpactScreen extends StatefulWidget {
  final ExtractionResult result;
  final int previousConfidence; // 0-100

  const DocumentImpactScreen({
    super.key,
    required this.result,
    required this.previousConfidence,
  });

  @override
  State<DocumentImpactScreen> createState() => _DocumentImpactScreenState();
}

class _DocumentImpactScreenState extends State<DocumentImpactScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────
  late AnimationController _masterController;
  late Animation<double> _circleProgress;
  late Animation<double> _fadeIn;
  late Animation<double> _badgeFadeIn;
  late Animation<double> _listFadeIn;
  late Animation<double> _ctaFadeIn;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late int _newConfidence;
  late int _deltaPoints;

  @override
  void initState() {
    super.initState();

    _deltaPoints = widget.result.confidenceDelta.round();
    _newConfidence =
        (widget.previousConfidence + _deltaPoints).clamp(0, 100);

    _initAnimations();
  }

  void _initAnimations() {
    // Master: 3000ms total
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Phase 1: Title fade in (0-15%)
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );

    // Phase 2: Circle progress (10-60%)
    _circleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.10, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 3: Badge fade in (55-70%)
    _badgeFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.55, 0.70, curve: Curves.easeOut),
      ),
    );

    // Phase 4: Field list fade in (65-85%)
    _listFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
      ),
    );

    // Phase 5: CTA button (80-100%)
    _ctaFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
      ),
    );

    // Pulse (infinite, starts after circle completes)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _masterController.addListener(() {
      if (_masterController.value >= 0.60 && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    });

    // Start
    _masterController.forward();
  }

  @override
  void dispose() {
    _masterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_masterController, _pulseController]),
        builder: (context, _) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildTitle(),
                    const SizedBox(height: 36),
                    _buildConfidenceCircle(),
                    const SizedBox(height: 24),
                    _buildDeltaBadge(),
                    const SizedBox(height: 32),
                    _buildChiffreChoc(),
                    const SizedBox(height: 24),
                    _buildFieldList(),
                    const SizedBox(height: 32),
                    _buildCtaButton(context),
                    const SizedBox(height: 16),
                    _buildDisclaimer(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Title ────────────────────────────────────────────────

  Widget _buildTitle() {
    return Opacity(
      opacity: _fadeIn.value,
      child: Column(
        children: [
          Text(
            'Ton profil est plus precis',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les valeurs de ton ${widget.result.documentType.label} '
            'ont ete integrees.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Confidence circle (animated gauge) ───────────────────

  Widget _buildConfidenceCircle() {
    // Interpolate from previous to new confidence
    final displayedConfidence = widget.previousConfidence +
        ((_newConfidence - widget.previousConfidence) *
                _circleProgress.value)
            .round();

    final pulseGlow = _pulseAnimation.value * 0.15;

    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: _ConfidenceCirclePainter(
          progress: displayedConfidence / 100.0,
          oldProgress: widget.previousConfidence / 100.0,
          animationProgress: _circleProgress.value,
          glowIntensity: pulseGlow,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$displayedConfidence',
                style: GoogleFonts.montserrat(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                '% confiance',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delta badge ──────────────────────────────────────────

  Widget _buildDeltaBadge() {
    return Opacity(
      opacity: _badgeFadeIn.value,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - _badgeFadeIn.value)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: MintColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: MintColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_upward,
                  size: 20, color: MintColors.success),
              const SizedBox(width: 6),
              Text(
                '+$_deltaPoints points de confiance',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chiffre choc (recalculated with real values) ─────────

  Widget _buildChiffreChoc() {
    return Opacity(
      opacity: _badgeFadeIn.value,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MintColors.primary.withValues(alpha: 0.04),
              MintColors.info.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          children: [
            Text(
              'Chiffre choc recalcule',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: MintColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            // Example: show LPP total from extraction if available
            _buildChiffreChocContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildChiffreChocContent() {
    // Find key fields for the chiffre choc
    final lppTotal = _findField('lpp_total');
    final oblig = _findField('lpp_obligatoire');
    final suroblig = _findField('lpp_surobligatoire');

    if (lppTotal != null && oblig != null) {
      final total = lppTotal.value as double;
      final obligVal = oblig.value as double;
      final surobligVal =
          suroblig != null ? suroblig.value as double : total - obligVal;
      final rentableAt68 = obligVal * 0.068;

      return Column(
        children: [
          Text(
            'CHF ${_formatChf(total)}',
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'd\'avoir LPP (dont ${_formatChf(obligVal)} obligatoire)',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rente minimum a 6.8% : CHF ${_formatChf(rentableAt68)}/an',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.info,
            ),
          ),
          if (surobligVal > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Part surobligatoire (${_formatChf(surobligVal)}) = taux de '
              'conversion libre de la caisse',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      );
    }

    // Fallback
    return Text(
      'Tes projections sont maintenant basees sur des valeurs reelles.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: MintColors.textSecondary,
        height: 1.5,
      ),
    );
  }

  // ── Field list (what was added/updated) ──────────────────

  Widget _buildFieldList() {
    return Opacity(
      opacity: _listFadeIn.value,
      child: Transform.translate(
        offset: Offset(0, 30 * (1 - _listFadeIn.value)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Champs mis a jour',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.result.fields.map((f) => _buildFieldRow(f)),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(ExtractedField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.check, size: 14, color: MintColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              field.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Text(
            _formatShortValue(field),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA button ───────────────────────────────────────────

  Widget _buildCtaButton(BuildContext context) {
    return Opacity(
      opacity: _ctaFadeIn.value,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: () {
            // Pop all the way back to root or profile
            if (context.canPop()) {
              // Pop back to wherever we came from
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          icon: const Icon(Icons.person_outline, size: 22),
          label: Text(
            'Voir mon profil mis a jour',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: MintColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // ── Disclaimer ───────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Opacity(
      opacity: _ctaFadeIn.value,
      child: Text(
        'Outil educatif — ne constitue pas un conseil en prevoyance. '
        'Verifie toujours avec ton certificat original (LSFin).',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: MintColors.textMuted,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  ExtractedField? _findField(String name) {
    try {
      return widget.result.fields.firstWhere((f) => f.fieldName == name);
    } catch (_) {
      return null;
    }
  }

  String _formatChf(double amount) {
    final intPart = amount.truncate();
    final formatted = intPart.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => "${m[1]}'",
        );
    return formatted;
  }

  String _formatShortValue(ExtractedField field) {
    final value = field.value;
    if (value is double) {
      if (field.fieldName.contains('rate') ||
          field.fieldName.contains('conversion') ||
          field.fieldName.contains('bonification')) {
        return '${value.toStringAsFixed(1)}%';
      }
      return 'CHF ${_formatChf(value)}';
    }
    return value.toString();
  }
}

// ────────────────────────────────────────────────────────────
//  CONFIDENCE CIRCLE PAINTER (CustomPainter)
// ────────────────────────────────────────────────────────────

class _ConfidenceCirclePainter extends CustomPainter {
  final double progress; // Current confidence (0.0-1.0)
  final double oldProgress; // Previous confidence (0.0-1.0)
  final double animationProgress; // 0.0-1.0 animation timeline
  final double glowIntensity; // 0.0-0.15 pulse glow

  _ConfidenceCirclePainter({
    required this.progress,
    required this.oldProgress,
    required this.animationProgress,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    const strokeWidth = 12.0;

    // Background track
    final trackPaint = Paint()
      ..color = MintColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Old progress arc (faded)
    if (oldProgress > 0) {
      final oldPaint = Paint()
        ..color = MintColors.textMuted.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * oldProgress,
        false,
        oldPaint,
      );
    }

    // Current progress arc (animated)
    final displayProgress =
        oldProgress + (progress - oldProgress) * animationProgress;
    if (displayProgress > 0) {
      // Determine color based on progress level
      final Color arcColor;
      if (displayProgress >= 0.70) {
        arcColor = MintColors.success;
      } else if (displayProgress >= 0.40) {
        arcColor = MintColors.info;
      } else {
        arcColor = MintColors.warning;
      }

      // Glow effect
      if (glowIntensity > 0) {
        final glowPaint = Paint()
          ..color = arcColor.withValues(alpha: glowIntensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -pi / 2,
          2 * pi * displayProgress,
          false,
          glowPaint,
        );
      }

      // Main arc
      final arcPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * displayProgress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfidenceCirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}
