import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/confidence/confidence_breakdown_chart.dart';

// ────────────────────────────────────────────────────────────
//  CONFIDENCE DASHBOARD SCREEN — Sprint S46
// ────────────────────────────────────────────────────────────
//
//  Full-screen confidence dashboard showing:
//    1. SliverAppBar "Precision de ton profil"
//    2. Animated circular gauge (overall score) via CustomPainter
//    3. 3 horizontal bars (completeness / accuracy / freshness)
//    4. Feature gates section (unlocked / locked)
//    5. Top 3 enrichment prompts as tappable cards
//    6. Disclaimer
//
//  Receives a ConfidenceResult as input.
//  Uses MintColors, GoogleFonts (Montserrat + Inter), Material 3.
// ────────────────────────────────────────────────────────────

class ConfidenceDashboardScreen extends StatefulWidget {
  final ConfidenceResult result;

  const ConfidenceDashboardScreen({
    super.key,
    required this.result,
  });

  @override
  State<ConfidenceDashboardScreen> createState() =>
      _ConfidenceDashboardScreenState();
}

class _ConfidenceDashboardScreenState extends State<ConfidenceDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gaugeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────

  Color _colorForScore(double score) {
    if (score >= 70) return MintColors.success;
    if (score >= 40) return MintColors.warning;
    return MintColors.error;
  }

  String _levelLabel(double score) {
    if (score >= 85) return 'Excellente';
    if (score >= 70) return 'Bonne';
    if (score >= 50) return 'Correcte';
    if (score >= 30) return 'A ameliorer';
    return 'Insuffisante';
  }

  IconData _iconForMethod(String method) {
    switch (method) {
      case 'documentScan':
      case 'documentScanVerified':
        return Icons.document_scanner_outlined;
      case 'openBanking':
        return Icons.account_balance_outlined;
      case 'manualEntry':
        return Icons.edit_outlined;
      default:
        return Icons.info_outline;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                _buildOverallGauge(),
                const SizedBox(height: 32),
                _buildBreakdownSection(),
                const SizedBox(height: 32),
                _buildFeatureGatesSection(),
                const SizedBox(height: 32),
                _buildEnrichmentPromptsSection(),
                const SizedBox(height: 32),
                _buildDisclaimer(),
                const SizedBox(height: 16),
                _buildSourcesFooter(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'PRECISION DE TON PROFIL',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  1. OVERALL GAUGE (animated circular painter)
  // ════════════════════════════════════════════════════════════

  Widget _buildOverallGauge() {
    final overall = widget.result.breakdown.overall;
    final scoreColor = _colorForScore(overall);

    return AnimatedBuilder(
      animation: _gaugeAnimation,
      builder: (context, _) {
        final displayScore =
            (overall * _gaugeAnimation.value).round();

        return Column(
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Circular gauge
                  CustomPaint(
                    painter: _ConfidenceGaugePainter(
                      score: overall,
                      progress: _gaugeAnimation.value,
                      scoreColor: scoreColor,
                    ),
                    size: const Size(200, 200),
                  ),
                  // Center content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$displayScore',
                        style: GoogleFonts.montserrat(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: MintColors.textPrimary,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '/100',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: MintColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Level badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scoreColor.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                _levelLabel(overall),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scoreColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  2. BREAKDOWN SECTION (3 horizontal bars)
  // ════════════════════════════════════════════════════════════

  Widget _buildBreakdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detail par axe',
          style: GoogleFonts.montserrat(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ConfidenceBreakdownChart(
          completeness: widget.result.breakdown.completeness,
          accuracy: widget.result.breakdown.accuracy,
          freshness: widget.result.breakdown.freshness,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  3. FEATURE GATES
  // ════════════════════════════════════════════════════════════

  Widget _buildFeatureGatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fonctionnalites debloquees',
          style: GoogleFonts.montserrat(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.result.featureGates.map(_buildFeatureGateRow),
      ],
    );
  }

  Widget _buildFeatureGateRow(FeatureGate gate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Unlocked / locked icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: gate.unlocked
                  ? MintColors.success.withValues(alpha: 0.10)
                  : MintColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              gate.unlocked ? Icons.check_circle : Icons.lock_outline,
              size: 18,
              color: gate.unlocked
                  ? MintColors.success
                  : MintColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          // Gate name
          Expanded(
            child: Text(
              gate.gateName,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: gate.unlocked
                    ? MintColors.textPrimary
                    : MintColors.textMuted,
              ),
            ),
          ),
          // Required %
          if (!gate.unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${gate.minConfidence.round()} % requis',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  4. ENRICHMENT PROMPTS (top 3)
  // ════════════════════════════════════════════════════════════

  Widget _buildEnrichmentPromptsSection() {
    final topPrompts = widget.result.enrichmentPrompts.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ameliore ta precision',
          style: GoogleFonts.montserrat(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...topPrompts.map(_buildEnrichmentCard),
      ],
    );
  }

  Widget _buildEnrichmentCard(EnrichmentPrompt prompt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: prompt.action,
        button: true,
        child: Material(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // Navigation will be wired per method in a future sprint.
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MintColors.info.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _iconForMethod(prompt.method),
                    size: 20,
                    color: MintColors.info,
                  ),
                ),
                const SizedBox(width: 14),
                // Action text
                Expanded(
                  child: Text(
                    prompt.action,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Impact badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: MintColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${prompt.impactPoints} pts',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MintColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  5. DISCLAIMER
  // ════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.result.disclaimer,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: MintColors.textMuted,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  6. SOURCES FOOTER
  // ════════════════════════════════════════════════════════════

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        ...widget.result.sources.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '- $s',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  CONFIDENCE GAUGE PAINTER
// ────────────────────────────────────────────────────────────
//
//  Arc de 270 degres avec track subtil + arc colore.
//  Coherent avec le design system MINT (score_reveal, MintScoreGauge).
// ────────────────────────────────────────────────────────────

class _ConfidenceGaugePainter extends CustomPainter {
  final double score;
  final double progress;
  final Color scoreColor;

  _ConfidenceGaugePainter({
    required this.score,
    required this.progress,
    required this.scoreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;
    const strokeWidth = 10.0;

    // Start angle: bottom-left (135 deg)
    const startAngle = 0.75 * pi;
    const totalSweep = 1.5 * pi; // 270 degrees

    // ── Background track ──
    final trackPaint = Paint()
      ..color = MintColors.border.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // ── Filled arc (animated) ──
    final scoreFraction = (score / 100.0).clamp(0.0, 1.0);
    final valueSweep = totalSweep * scoreFraction * progress;

    if (valueSweep > 0.001) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + valueSweep,
          colors: [
            scoreColor.withValues(alpha: 0.4),
            scoreColor,
          ],
          stops: const [0.0, 1.0],
          transform: const GradientRotation(startAngle),
        ).createShader(arcRect);

      canvas.drawArc(arcRect, startAngle, valueSweep, false, fillPaint);

      // ── Bright tip dot ──
      final endAngle = startAngle + valueSweep;
      final tipCenter = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );

      final tipGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            scoreColor.withValues(alpha: 0.40),
            scoreColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: tipCenter, radius: 14),
        );
      canvas.drawCircle(tipCenter, 14, tipGlow);

      final tipPaint = Paint()..color = scoreColor;
      canvas.drawCircle(tipCenter, 4, tipPaint);

      final corePaint = Paint()
        ..color = MintColors.white.withValues(alpha: 0.85);
      canvas.drawCircle(tipCenter, 2, corePaint);
    }

    // ── Tick marks at 0, 25, 50, 75, 100 ──
    _drawTickMarks(canvas, center, radius, strokeWidth);
  }

  void _drawTickMarks(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
  ) {
    const startAngle = 0.75 * pi;
    const totalSweep = 1.5 * pi;
    final tickRadius = radius + strokeWidth / 2 + 3;

    for (int i = 0; i <= 4; i++) {
      final fraction = i / 4;
      final angle = startAngle + totalSweep * fraction;
      final innerPoint = Offset(
        center.dx + tickRadius * cos(angle),
        center.dy + tickRadius * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + (tickRadius + 3) * cos(angle),
        center.dy + (tickRadius + 3) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = MintColors.textMuted.withValues(alpha: 0.30)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfidenceGaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.progress != progress ||
        oldDelegate.scoreColor != scoreColor;
  }
}
