import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT HERO ZONE — "L'essentiel en 3 secondes"
// ────────────────────────────────────────────────────────────
//
//  Designed via hermeneutic circles brainstorm (6 experts).
//  Essence: "Combien par mois, et est-ce que ça suffit?"
//
//  Layout (top → bottom):
//    ▸ Delta line (conditional: Δ > 50 CHF since last visit)
//    ▸ Hero CHF/mois (36pt, the single most important number)
//    ▸ Replacement rate bar (% of current income)
//    ▸ Pillar stacked bar (AVS | LPP | 3a | Autre)
//    ▸ Sparkline with scenario band (interactive scrub)
//    ▸ Confidence chip (tappable)
//    ▸ Coach one-liner (narrative)
//
//  States: full (≥70%), approximate (<70%), onboarding (no data)
// ────────────────────────────────────────────────────────────

/// Color zone derived from replacement rate.
enum _HeroColorZone { green, amber, coral }

class RetirementHeroZone extends StatefulWidget {
  /// Monthly retirement income (base scenario).
  final double monthlyIncome;

  /// Replacement rate as percentage (0-100).
  final double replacementRate;

  /// Per-pillar annual breakdown: avs, lpp, 3a, libre/autre.
  final Map<String, double> decomposition;

  /// 3-scenario monthly incomes for the sparkline band.
  final double monthlyPrudent;
  final double monthlyOptimiste;

  /// Confidence score (0-100).
  final double confidenceScore;

  /// Coach one-liner narrative.
  final String? coachOneLiner;

  /// Delta CHF/mois vs previous visit (null = no delta to show).
  final double? deltaSinceLastVisit;

  /// Current age and retirement age for sparkline.
  final int currentAge;
  final int retirementAge;

  /// Whether the projection is approximate (confidence < 70%).
  final bool isApproximate;

  /// Couple mode: show combined household.
  final bool isCouple;
  final String? partnerName;
  final double? partnerMonthlyIncome;

  /// Callbacks.
  final VoidCallback? onConfidenceTap;
  final VoidCallback? onEnrich;

  const RetirementHeroZone({
    super.key,
    required this.monthlyIncome,
    required this.replacementRate,
    required this.decomposition,
    required this.monthlyPrudent,
    required this.monthlyOptimiste,
    required this.confidenceScore,
    this.coachOneLiner,
    this.deltaSinceLastVisit,
    required this.currentAge,
    this.retirementAge = 65,
    this.isApproximate = false,
    this.isCouple = false,
    this.partnerName,
    this.partnerMonthlyIncome,
    this.onConfidenceTap,
    this.onEnrich,
  });

  @override
  State<RetirementHeroZone> createState() => _RetirementHeroZoneState();
}

class _RetirementHeroZoneState extends State<RetirementHeroZone> {
  /// Scrubbed age for sparkline interaction (null = default to retirement age).
  int? _scrubbedAge;

  _HeroColorZone get _colorZone {
    if (widget.replacementRate >= 70) return _HeroColorZone.green;
    if (widget.replacementRate >= 50) return _HeroColorZone.amber;
    return _HeroColorZone.coral;
  }

  Color get _zoneColor => switch (_colorZone) {
        _HeroColorZone.green => MintColors.success,
        _HeroColorZone.amber => MintColors.warning,
        _HeroColorZone.coral => MintColors.error,
      };

  Color get _zoneBgColor => switch (_colorZone) {
        _HeroColorZone.green => MintColors.success.withValues(alpha: 0.05),
        _HeroColorZone.amber => MintColors.warning.withValues(alpha: 0.05),
        _HeroColorZone.coral => MintColors.error.withValues(alpha: 0.05),
      };

  /// Interpolated monthly income at scrubbed age.
  double get _displayedIncome {
    if (_scrubbedAge == null) return widget.monthlyIncome;
    final t = _ageToT(_scrubbedAge!);
    // Linear interpolation: 50% at current age → 100% at retirement.
    // Matches sparkline painter baseAt() for visual consistency.
    final currentImplied = widget.monthlyIncome * 0.5;
    return currentImplied + (widget.monthlyIncome - currentImplied) * t;
  }

  double _ageToT(int age) {
    final range = widget.retirementAge - widget.currentAge;
    if (range <= 0) return 1.0;
    return ((age - widget.currentAge) / range).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _zoneColor.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Delta line (conditional) ──
          if (widget.deltaSinceLastVisit != null &&
              widget.deltaSinceLastVisit!.abs() > 50) ...[
            _buildDeltaLine(),
            const SizedBox(height: 4),
          ],

          // ── Hero number ──
          _buildHeroNumber(),
          const SizedBox(height: 12),

          // ── Replacement rate bar ──
          _buildReplacementRateBar(),
          const SizedBox(height: 16),

          // ── Pillar stacked bar ──
          _buildPillarBar(),
          const SizedBox(height: 16),

          // ── Sparkline with scenario band ──
          _buildSparkline(),
          const SizedBox(height: 14),

          // ── Confidence chip ──
          _buildConfidenceChip(),
          const SizedBox(height: 10),

          // ── Coach one-liner ──
          if (widget.coachOneLiner != null && widget.coachOneLiner!.isNotEmpty)
            _buildCoachOneLiner(),
        ],
      ),
    );
  }

  // ── Delta line ──────────────────────────────────────────

  Widget _buildDeltaLine() {
    final delta = widget.deltaSinceLastVisit!;
    final isPositive = delta > 0;
    final color = isPositive ? MintColors.success : MintColors.error;
    final sign = isPositive ? '+' : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${sign}CHF ${delta.abs().round()}/mois depuis ta dernière visite',
          style: MintTextStyles.labelMedium(color: color).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── Hero number ─────────────────────────────────────────

  Widget _buildHeroNumber() {
    final income = _scrubbedAge != null ? _displayedIncome : widget.monthlyIncome;
    final prefix = widget.isApproximate ? '~' : '';
    final ageLabel = _scrubbedAge != null ? ' à $_scrubbedAge ans' : '';

    // Uncertainty band: ±15% when confidence < 70 (isApproximate).
    final lowBand = (income * 0.85).round();
    final highBand = (income * 1.15).round();

    return Column(
      children: [
        if (_scrubbedAge != null)
          Text(
            'Revenu estimé$ageLabel',
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
          ),
        Center(
          child: Text(
            '${prefix}CHF ${formatChf(income)} / mois',
            style: MintTextStyles.displayMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w800, height: 1.2),
          ),
        ),
        // Uncertainty band — shown when confidence < 70%
        if (widget.isApproximate && income > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              S.of(context)?.projectionUncertaintyBand(
                formatChf(lowBand.toDouble()),
                formatChf(highBand.toDouble()),
              ) ?? 'CHF\u00a0${formatChf(lowBand.toDouble())}\u00a0—\u00a0${formatChf(highBand.toDouble())}\u00a0/\u00a0mois',
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (widget.isCouple && widget.partnerMonthlyIncome != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Ménage combiné${widget.partnerName != null ? ' (toi + ${widget.partnerName})' : ''}',
              style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
            ),
          ),
      ],
    );
  }

  // ── Replacement rate bar ────────────────────────────────

  Widget _buildReplacementRateBar() {
    final rate = widget.replacementRate;
    final barFraction = (rate / 100).clamp(0.0, 1.0);
    return Column(
      children: [
        // Bar (capped at 100% visually)
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: MintColors.border.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: barFraction,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: _zoneColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Label row (shows real rate, not clamped)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${rate.toStringAsFixed(0)}% de ton revenu actuel',
              style: MintTextStyles.labelMedium(color: _zoneColor).copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'Taux de remplacement',
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  // ── Pillar stacked bar ──────────────────────────────────

  Widget _buildPillarBar() {
    final deco = widget.decomposition;
    final avs = (deco['avs'] ?? deco['avs_user'] ?? 0) +
        (deco['avs_conjoint'] ?? 0);
    final lpp = (deco['lpp'] ?? deco['lpp_user'] ?? 0) +
        (deco['lpp_conjoint'] ?? 0);
    final troisA = deco['3a'] ?? deco['pilier3a'] ?? 0;
    final autre = (deco['libre'] ?? 0) + (deco['market'] ?? 0);
    final total = avs + lpp + troisA + autre;
    if (total <= 0) return const SizedBox.shrink();

    final segments = <_PillarSegment>[
      _PillarSegment('AVS', avs, MintColors.retirementAvs),
      _PillarSegment('LPP', lpp, MintColors.retirementLpp),
      _PillarSegment('3a', troisA, MintColors.retirement3a),
      if (autre > 0) _PillarSegment('Autre', autre, MintColors.purple),
    ];

    return Column(
      children: [
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 20,
            child: Row(
              children: segments.map((s) {
                final fraction = s.value / total;
                if (fraction < 0.02) return const SizedBox.shrink();
                return Expanded(
                  flex: (fraction * 1000).round(),
                  child: Container(
                    color: s.color,
                    alignment: Alignment.center,
                    child: fraction > 0.12
                        ? Text(
                            s.label,
                            style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Legend row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: segments.map((s) {
            final monthly = s.value / 12;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  formatChf(monthly),
                  style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Sparkline with scenario band ────────────────────────

  Widget _buildSparkline() {
    // Guard: no meaningful sparkline if already at retirement
    if (widget.currentAge >= widget.retirementAge) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Semantics(
          label: 'Explorer la projection de revenu',
          child: GestureDetector(
            // Use onTapDown + onPanUpdate to avoid conflict with parent vertical scroll.
          // Horizontal pan wins because the sparkline is small and intentional.
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final localX = details.localPosition.dx;
            final width = box.size.width;
            if (width <= 0) return;
            final t = (localX / width).clamp(0.0, 1.0);
            final age = widget.currentAge +
                ((widget.retirementAge + 5 - widget.currentAge) * t).round();
            setState(() => _scrubbedAge = age.clamp(widget.currentAge, widget.retirementAge + 5));
            HapticFeedback.selectionClick();
          },
          onPanEnd: (_) => setState(() => _scrubbedAge = null),
          onTapUp: (_) => setState(() => _scrubbedAge = null),
          child: SizedBox(
            height: 80,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(
                currentAge: widget.currentAge,
                retirementAge: widget.retirementAge,
                monthlyBase: widget.monthlyIncome,
                monthlyPrudent: widget.monthlyPrudent,
                monthlyOptimiste: widget.monthlyOptimiste,
                scrubbedAge: _scrubbedAge,
                bandColor: _zoneColor.withValues(alpha: 0.12),
                lineColor: _zoneColor,
                isApproximate: widget.isApproximate,
              ),
            ),
          ),
        ),
        ),
        const SizedBox(height: 4),
        // Age labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.currentAge} ans',
              style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.normal),
            ),
            Text(
              'Glisse pour explorer →',
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
            Text(
              '${widget.retirementAge + 5} ans',
              style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.normal),
            ),
          ],
        ),
      ],
    );
  }

  // ── Confidence chip ─────────────────────────────────────

  Widget _buildConfidenceChip() {
    final score = widget.confidenceScore;
    final isGood = score >= 70;
    final chipColor = isGood ? MintColors.success : MintColors.warning;

    return Semantics(
      label: 'Score de confiance',
      button: true,
      child: GestureDetector(
        onTap: widget.onConfidenceTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGood ? Icons.verified_outlined : Icons.tune_outlined,
              size: 14,
              color: chipColor,
            ),
            const SizedBox(width: 6),
            Text(
              isGood
                  ? 'Confiance : ${score.round()}%'
                  : 'Confiance : ${score.round()}% — Améliorer',
              style: MintTextStyles.labelMedium(color: chipColor).copyWith(fontWeight: FontWeight.w600),
            ),
            if (!isGood) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 10, color: chipColor),
            ],
          ],
        ),
      ),
    ),
    );
  }

  // ── Coach one-liner ─────────────────────────────────────

  Widget _buildCoachOneLiner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _zoneBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: _zoneColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.coachOneLiner!,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  SPARKLINE PAINTER — 3-scenario band + base line
// ────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final int currentAge;
  final int retirementAge;
  final double monthlyBase;
  final double monthlyPrudent;
  final double monthlyOptimiste;
  final int? scrubbedAge;
  final Color bandColor;
  final Color lineColor;
  final bool isApproximate;

  _SparklinePainter({
    required this.currentAge,
    required this.retirementAge,
    required this.monthlyBase,
    required this.monthlyPrudent,
    required this.monthlyOptimiste,
    this.scrubbedAge,
    required this.bandColor,
    required this.lineColor,
    this.isApproximate = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final endAge = retirementAge + 5;
    final ageRange = endAge - currentAge;
    if (ageRange <= 0) return;

    // Guard: already at or past retirement age — draw flat line
    final retirementSpan = retirementAge - currentAge;
    if (retirementSpan <= 0) {
      // Flat line at retirement income level
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, h * 0.4), Offset(w, h * 0.4), linePaint);
      return;
    }

    // Band width multiplier for low confidence
    final bandMultiplier = isApproximate ? 1.5 : 1.0;

    // Compute Y range with division-by-zero guard
    final maxIncome = monthlyOptimiste * bandMultiplier;
    final minIncome = (monthlyPrudent * (2 - bandMultiplier)).clamp(0.0, monthlyPrudent);
    var yRange = maxIncome - minIncome;
    if (yRange <= 0) yRange = 1.0; // Prevent NaN from division by zero
    final effectiveMin = minIncome;

    double ageToX(int age) => ((age - currentAge) / ageRange) * w;
    double incomeToY(double income) =>
        h - ((income - effectiveMin) / yRange * h).clamp(0.0, h);

    // Income curve: grows from 50% at current age to full at retirement, flat after.
    double baseAt(int age) {
      if (age >= retirementAge) return monthlyBase;
      final t = (age - currentAge) / retirementSpan;
      return monthlyBase * (0.5 + 0.5 * t);
    }

    double prudentAt(int age) {
      if (age >= retirementAge) return monthlyPrudent;
      final t = (age - currentAge) / retirementSpan;
      return monthlyPrudent * (0.5 + 0.5 * t);
    }

    double optimisteAt(int age) {
      if (age >= retirementAge) return monthlyOptimiste;
      final t = (age - currentAge) / retirementSpan;
      return monthlyOptimiste * (0.5 + 0.5 * t);
    }

    // Draw band (filled area between prudent and optimiste)
    final bandPath = Path();
    for (int age = currentAge; age <= endAge; age++) {
      final x = ageToX(age);
      final y = incomeToY(optimisteAt(age));
      if (age == currentAge) {
        bandPath.moveTo(x, y);
      } else {
        bandPath.lineTo(x, y);
      }
    }
    for (int age = endAge; age >= currentAge; age--) {
      bandPath.lineTo(ageToX(age), incomeToY(prudentAt(age)));
    }
    bandPath.close();
    canvas.drawPath(bandPath, Paint()..color = bandColor);

    // Draw base line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    for (int age = currentAge; age <= endAge; age++) {
      final x = ageToX(age);
      final y = incomeToY(baseAt(age));
      if (age == currentAge) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // Draw retirement age marker (dashed vertical line)
    final retX = ageToX(retirementAge);
    final dashPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(retX, 0), Offset(retX, h), dashPaint);

    // Draw position dot (scrubbed age or retirement age)
    final dotAge = scrubbedAge ?? retirementAge;
    final dotX = ageToX(dotAge);
    final dotY = incomeToY(baseAt(dotAge));
    canvas.drawCircle(
      Offset(dotX, dotY),
      5,
      Paint()..color = lineColor,
    );
    canvas.drawCircle(
      Offset(dotX, dotY),
      3,
      Paint()..color = MintColors.white,
    );

    // Retirement age label
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$retirementAge',
        style: TextStyle(fontSize: 9, color: lineColor.withValues(alpha: 0.6)),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(retX - textPainter.width / 2, h - 12));
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.scrubbedAge != scrubbedAge ||
      old.monthlyBase != monthlyBase ||
      old.isApproximate != isApproximate;
}

// ────────────────────────────────────────────────────────────
//  PILLAR SEGMENT MODEL
// ────────────────────────────────────────────────────────────

class _PillarSegment {
  final String label;
  final double value;
  final Color color;
  const _PillarSegment(this.label, this.value, this.color);
}
