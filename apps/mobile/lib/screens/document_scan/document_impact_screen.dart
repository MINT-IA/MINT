import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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
                padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: MintSpacing.xxl),
                    MintEntrance(child: _buildTitle()),
                    const SizedBox(height: MintSpacing.xl + 4),
                    MintEntrance(delay: const Duration(milliseconds: 100), child: _buildConfidenceCircle()),
                    const SizedBox(height: MintSpacing.lg),
                    MintEntrance(delay: const Duration(milliseconds: 200), child: _buildDeltaBadge()),
                    const SizedBox(height: MintSpacing.xl),
                    MintEntrance(delay: const Duration(milliseconds: 300), child: _buildChiffreChoc()),
                    const SizedBox(height: MintSpacing.lg),
                    MintEntrance(delay: const Duration(milliseconds: 400), child: _buildFieldList()),
                    const SizedBox(height: MintSpacing.xl),
                    _buildCtaButton(context),
                    const SizedBox(height: MintSpacing.md),
                    _buildDisclaimer(),
                    const SizedBox(height: MintSpacing.xxl + 12),
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
            S.of(context)!.docImpactTitle,
            textAlign: TextAlign.center,
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.docImpactSubtitle(widget.result.documentType.label),
            textAlign: TextAlign.center,
            style: MintTextStyles.bodyLarge().copyWith(fontSize: 15),
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
                style: MintTextStyles.displayLarge(),
              ),
              Text(
                S.of(context)!.docImpactConfidenceLabel,
                style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w500),
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
          padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md + 4, vertical: MintSpacing.sm + 2),
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
              const SizedBox(width: MintSpacing.sm - 2),
              Text(
                S.of(context)!.docImpactDeltaPoints(_deltaPoints),
                style: MintTextStyles.titleMedium(
                  color: MintColors.success,
                ).copyWith(fontWeight: FontWeight.w700),
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
        padding: const EdgeInsets.all(MintSpacing.md + 4),
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
              S.of(context)!.docImpactChiffreChocTitle,
              style: MintTextStyles.bodySmall().copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: MintSpacing.md - 4),
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
    final convRate = _findField('conversion_rate_suroblig');

    if (lppTotal != null && oblig != null) {
      final total = lppTotal.value as double;
      final obligVal = oblig.value as double;
      final surobligVal =
          suroblig != null ? suroblig.value as double : total - obligVal;
      final rentableAt68 = obligVal * lppTauxConversionMinDecimal;
      final surobligRate = convRate != null ? convRate.value as double : null;
      final renteSuroblig = surobligRate != null
          ? surobligVal * (surobligRate / 100)
          : null;

      return Column(
        children: [
          Text(
            'CHF ${_formatChf(total)}',
            style: MintTextStyles.displayMedium().copyWith(fontSize: 28),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.docImpactLppRealAmount(_formatChf(obligVal)),
            textAlign: TextAlign.center,
            style: MintTextStyles.bodyMedium(),
          ),
          const SizedBox(height: MintSpacing.md - 4),
          Text(
            S.of(context)!.docImpactRenteOblig(_formatChf(rentableAt68)),
            style: MintTextStyles.bodySmall(
              color: MintColors.info,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          if (surobligVal > 0) ...[
            const SizedBox(height: MintSpacing.xs),
            Text(
              renteSuroblig != null
                  ? S.of(context)!.docImpactSurobligWithRate(_formatChf(surobligVal), surobligRate!.toStringAsFixed(1), _formatChf(renteSuroblig))
                  : S.of(context)!.docImpactSurobligNoRate(_formatChf(surobligVal)),
              textAlign: TextAlign.center,
              style: MintTextStyles.bodySmall().copyWith(fontSize: 12, height: 1.4),
            ),
          ],
        ],
      );
    }

    // Fallback for AVS or other doc types
    final avsYears = _findField('avs_contribution_years');
    if (avsYears != null) {
      final years = (avsYears.value as double).round();
      const maxYears = 44;
      final completionPct = ((years / maxYears) * 100).round();
      return Column(
        children: [
          Text(
            S.of(context)!.docImpactAvsYears(years),
            style: MintTextStyles.displayMedium().copyWith(fontSize: 28),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.docImpactAvsCompletion(maxYears, completionPct),
            textAlign: TextAlign.center,
            style: MintTextStyles.bodyMedium(),
          ),
        ],
      );
    }

    return Text(
      S.of(context)!.docImpactGenericMessage,
      textAlign: TextAlign.center,
      style: MintTextStyles.bodyMedium(),
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
              S.of(context)!.docImpactFieldsUpdated,
              style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600, color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.md - 4),
            ...widget.result.fields.map((f) => _buildFieldRow(f)),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(ExtractedField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
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
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ),
          Text(
            _formatShortValue(field),
            style: MintTextStyles.bodyMedium(
              color: MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── CTA button ───────────────────────────────────────────

  Widget _buildCtaButton(BuildContext context) {
    return Opacity(
      opacity: _ctaFadeIn.value,
      child: Semantics(
        button: true,
        label: S.of(context)!.docImpactReturnDashboard,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: () {
            // Navigate back to root dashboard via GoRouter
            context.go('/home');
          },
          icon: const Icon(Icons.dashboard_outlined, size: 22),
          label: Text(
            S.of(context)!.docImpactReturnDashboard,
            style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: MintColors.primary,
            foregroundColor: MintColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
        S.of(context)!.docImpactDisclaimer,
        textAlign: TextAlign.center,
        style: MintTextStyles.labelSmall().copyWith(height: 1.5),
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
