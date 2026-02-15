import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  MINT SCORE GAUGE — Sprint C4 / MINT Coach
// ────────────────────────────────────────────────────────────
//
//  Jauge circulaire animee du Financial Fitness Score (0-100).
//
//  - Arc anime de 0 au score avec gradient de couleur
//  - Centre : score en grand + "/100" + indicateur tendance
//  - Sous la jauge : 3 barres horizontales (Budget, Prevoyance, Patrimoine)
//  - Carte : fond blanc, coins arrondis (20), bordure legere, ombre
//  - Accessibility via Semantics
//
//  Widget pur — pas de Provider, uniquement des props.
// ────────────────────────────────────────────────────────────

class MintScoreGauge extends StatefulWidget {
  /// Score global (0-100)
  final int score;

  /// Sous-score Budget (0-100)
  final int budgetScore;

  /// Sous-score Prevoyance (0-100)
  final int prevoyanceScore;

  /// Sous-score Patrimoine (0-100)
  final int patrimoineScore;

  /// Tendance : 'up', 'stable', 'down'
  final String trend;

  /// Score du mois precedent (pour afficher le delta)
  final int? previousScore;

  /// Callback au tap
  final VoidCallback? onTap;

  const MintScoreGauge({
    super.key,
    required this.score,
    required this.budgetScore,
    required this.prevoyanceScore,
    required this.patrimoineScore,
    this.trend = 'stable',
    this.previousScore,
    this.onTap,
  });

  @override
  State<MintScoreGauge> createState() => _MintScoreGaugeState();
}

class _MintScoreGaugeState extends State<MintScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fillAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(MintScoreGauge oldWidget) {
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

  /// Couleur principale basee sur le score
  Color get _scoreColor {
    if (widget.score >= 80) return MintColors.scoreExcellent;
    if (widget.score >= 60) return MintColors.scoreBon;
    if (widget.score >= 40) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  /// Label du niveau
  String get _levelLabel {
    if (widget.score >= 80) return 'Excellent';
    if (widget.score >= 60) return 'Bon';
    if (widget.score >= 40) return 'Attention';
    return 'Critique';
  }

  /// Symbole de tendance
  String get _trendSymbol {
    switch (widget.trend) {
      case 'up':
        return '\u2191'; // ↑
      case 'down':
        return '\u2193'; // ↓
      default:
        return '\u2192'; // →
    }
  }

  /// Couleur de la tendance
  Color get _trendColor {
    switch (widget.trend) {
      case 'up':
        return MintColors.scoreExcellent;
      case 'down':
        return MintColors.scoreCritique;
      default:
        return MintColors.textMuted;
    }
  }

  /// Delta affiche (ex: "+3", "-2", "0")
  String get _deltaText {
    if (widget.previousScore == null) return '';
    final delta = widget.score - widget.previousScore!;
    if (delta > 0) return '+$delta';
    if (delta < 0) return '$delta';
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Score de forme financiere. ${ widget.score} sur 100. '
          'Niveau $_levelLabel. '
          'Budget ${widget.budgetScore}, Prevoyance ${widget.prevoyanceScore}, '
          'Patrimoine ${widget.patrimoineScore}.',
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MintColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: MintColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildGauge(constraints.maxWidth),
                  const SizedBox(height: 24),
                  _buildSubScores(),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HEADER
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _scoreColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.fitness_center,
            color: _scoreColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forme financiere',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                'Score composite  ·  3 piliers',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Level badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _scoreColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _levelLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _scoreColor,
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  CIRCULAR GAUGE (animated arc)
  // ────────────────────────────────────────────────────────────

  Widget _buildGauge(double cardWidth) {
    final gaugeSize = min(cardWidth - 48, 220.0);

    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, _) {
        final displayScore =
            (widget.score * _fillAnimation.value).round();

        return SizedBox(
          width: gaugeSize,
          height: gaugeSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Custom painted arc
              CustomPaint(
                painter: _ScoreGaugePainter(
                  score: widget.score,
                  progress: _fillAnimation.value,
                  scoreColor: _scoreColor,
                ),
                size: Size(gaugeSize, gaugeSize),
              ),
              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Score number
                  Text(
                    '$displayScore',
                    style: GoogleFonts.montserrat(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: _scoreColor,
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
                  // Trend indicator
                  if (widget.previousScore != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _trendColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$_trendSymbol $_deltaText',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _trendColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  //  SUB-SCORE BARS
  // ────────────────────────────────────────────────────────────

  Widget _buildSubScores() {
    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, _) {
        final show = _fillAnimation.value > 0.5;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildSubScoreBar(
                  label: 'Budget',
                  score: widget.budgetScore,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 12),
                _buildSubScoreBar(
                  label: 'Prevoyance',
                  score: widget.prevoyanceScore,
                  icon: Icons.shield_outlined,
                ),
                const SizedBox(height: 12),
                _buildSubScoreBar(
                  label: 'Patrimoine',
                  score: widget.patrimoineScore,
                  icon: Icons.trending_up,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubScoreBar({
    required String label,
    required int score,
    required IconData icon,
  }) {
    final barColor = _colorForScore(score);
    final animatedScore = (score * _fillAnimation.value).round();
    final ratio = (score / 100.0).clamp(0.0, 1.0) * _fillAnimation.value;

    return Row(
      children: [
        Icon(icon, size: 16, color: MintColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: MintColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: MintColors.lightBorder,
                color: barColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            '$animatedScore',
            textAlign: TextAlign.right,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: barColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Couleur par niveau pour les sous-scores
  Color _colorForScore(int score) {
    if (score >= 80) return MintColors.scoreExcellent;
    if (score >= 60) return MintColors.scoreBon;
    if (score >= 40) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Text(
      'Estimations educatives \u2014 ne constitue pas un conseil financier.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  SCORE GAUGE CUSTOM PAINTER
// ────────────────────────────────────────────────────────────
//
//  Arc de 270 degres, depart en bas a gauche (comme BudgetGaugeWidget).
//  Track gris + arc colore anime + glow au bout.
// ────────────────────────────────────────────────────────────

class _ScoreGaugePainter extends CustomPainter {
  final int score;
  final double progress;
  final Color scoreColor;

  _ScoreGaugePainter({
    required this.score,
    required this.progress,
    required this.scoreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;
    const strokeWidth = 14.0;

    // ── Start angle: bottom-left (225 degrees = 0.75 * pi from 3 o'clock) ──
    const startAngle = 0.75 * pi; // 135 degrees
    const totalSweep = 1.5 * pi; // 270 degrees

    // ── Background track ──
    final trackPaint = Paint()
      ..color = MintColors.surface
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

    // ── Score tick marks (at 0, 25, 50, 75, 100) ──
    _drawTickMarks(canvas, center, radius, strokeWidth);

    // ── Filled arc (animated) ──
    final scoreFraction = (score / 100.0).clamp(0.0, 1.0);
    final valueSweep = totalSweep * scoreFraction * progress;

    if (valueSweep > 0.001) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      // Gradient arc
      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + valueSweep,
          colors: [
            scoreColor.withValues(alpha: 0.5),
            scoreColor.withValues(alpha: 0.8),
            scoreColor,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(startAngle),
        ).createShader(arcRect);

      canvas.drawArc(arcRect, startAngle, valueSweep, false, fillPaint);

      // ── Glow at endpoint ──
      final endAngle = startAngle + valueSweep;
      final glowCenter = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            scoreColor.withValues(alpha: 0.35),
            scoreColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: glowCenter, radius: 14),
        );
      canvas.drawCircle(glowCenter, 14, glowPaint);

      // Bright tip dot
      final tipPaint = Paint()..color = scoreColor;
      canvas.drawCircle(glowCenter, 4.5, tipPaint);
    }
  }

  /// Petits reperes sur l'arc (0%, 25%, 50%, 75%, 100%)
  void _drawTickMarks(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
  ) {
    const startAngle = 0.75 * pi;
    const totalSweep = 1.5 * pi;
    final tickRadius = radius + strokeWidth / 2 + 4;

    for (int i = 0; i <= 4; i++) {
      final fraction = i / 4;
      final angle = startAngle + totalSweep * fraction;
      final innerPoint = Offset(
        center.dx + (tickRadius) * cos(angle),
        center.dy + (tickRadius) * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + (tickRadius + 5) * cos(angle),
        center.dy + (tickRadius + 5) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = MintColors.border.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      // Label
      final labelValue = i * 25;
      final labelTp = TextPainter(
        text: TextSpan(
          text: '$labelValue',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: MintColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelTp.layout();
      final labelCenter = Offset(
        center.dx + (tickRadius + 14) * cos(angle),
        center.dy + (tickRadius + 14) * sin(angle),
      );
      labelTp.paint(
        canvas,
        Offset(
          labelCenter.dx - labelTp.width / 2,
          labelCenter.dy - labelTp.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.progress != progress ||
        oldDelegate.scoreColor != scoreColor;
  }
}
