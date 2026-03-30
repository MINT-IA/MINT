import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// ────────────────────────────────────────────────────────────
//  SCORE REVEAL SCREEN — Post-Wizard "Ta-Da" Moment
// ────────────────────────────────────────────────────────────
//
//  Écran plein écran animé qui révèle le Financial Fitness Score
//  après la complétion du wizard. Inspiré de :
//    - Strava Activity Summary (stats animées, achievements)
//    - TrainerRoad Workout Complete (fitness score update)
//    - Apple Watch closing rings
//
//  5 phases d'animation :
//    Phase 1 (0-800ms)    : Fond gradient + titre "Ton diagnostic est prêt"
//    Phase 2 (800-2000ms) : Jauge circulaire animé de 0 au score
//    Phase 3 (2000-3000ms): 3 barres sous-scores (slide in échelonné)
//    Phase 4 (3000-3500ms): Message coach avec effet machine à écrire
//    Phase 5 (3500ms+)    : Bouton CTA "Voir mon dashboard"
//
//  Widget pur — reçoit FinancialFitnessScore et CoachProfile en props.
// ────────────────────────────────────────────────────────────

class ScoreRevealScreen extends StatefulWidget {
  final FinancialFitnessScore score;
  final CoachProfile profile;
  final Map<String, dynamic> wizardAnswers;

  const ScoreRevealScreen({
    super.key,
    required this.score,
    required this.profile,
    this.wizardAnswers = const {},
  });

  @override
  State<ScoreRevealScreen> createState() => _ScoreRevealScreenState();
}

class _ScoreRevealScreenState extends State<ScoreRevealScreen>
    with TickerProviderStateMixin {
  // ── Master timeline controller (0.0 → 1.0 over 4200ms) ──
  late AnimationController _masterController;

  // ── Phase animations (driven by Interval on master) ──
  late Animation<double> _backgroundOpacity;
  late Animation<double> _titleScale;
  late Animation<double> _titleOpacity;
  late Animation<double> _gaugeProgress;
  late Animation<double> _gaugeOpacity;
  late Animation<double> _subScoreBudgetSlide;
  late Animation<double> _subScorePrevoyanceSlide;
  late Animation<double> _subScorePatrimoineSlide;
  late Animation<double> _subScoreOpacity;
  late Animation<double> _coachMessageOpacity;
  late Animation<double> _ctaOpacity;

  // ── Typing effect controller ──
  late AnimationController _typingController;
  String _displayedMessage = '';

  // ── Particle / glow pulse controller ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Computed values ──
  late String _coachMessage;
  late Color _scoreColor;
  late String _firstName;

  @override
  void initState() {
    super.initState();

    _computeDisplayValues();
    _initAnimations();
  }

  void _computeDisplayValues() {
    final score = widget.score;
    _firstName = widget.profile.firstName ?? 'toi';

    // Score color
    if (score.global >= friThresholdExcellent) {
      _scoreColor = MintColors.scoreExcellent;
    } else if (score.global >= friThresholdBon) {
      _scoreColor = MintColors.scoreBon;
    } else if (score.global >= friThresholdAttention) {
      _scoreColor = MintColors.scoreAttention;
    } else {
      _scoreColor = MintColors.scoreCritique;
    }

    // Coach message (personalized)
    _coachMessage = score.coachMessage;
  }

  void _initAnimations() {
    // ── Master: 4200ms total ──
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    // Phase 1: Background + Title (0-800ms → 0.0-0.19)
    _backgroundOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.12, curve: Curves.easeOut),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.05, 0.19, curve: Curves.easeOut),
      ),
    );

    _titleScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.05, 0.19, curve: Curves.easeOutBack),
      ),
    );

    // Phase 2: Gauge (800-2000ms → 0.19-0.48)
    _gaugeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.17, 0.24, curve: Curves.easeOut),
      ),
    );

    _gaugeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.19, 0.48, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 3: Sub-scores (2000-3000ms → 0.48-0.71)
    _subScoreOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.48, 0.55, curve: Curves.easeOut),
      ),
    );

    _subScoreBudgetSlide = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.48, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _subScorePrevoyanceSlide = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.52, 0.64, curve: Curves.easeOutCubic),
      ),
    );

    _subScorePatrimoineSlide = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.56, 0.68, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 4: Coach message (3000-3500ms → 0.71-0.83)
    _coachMessageOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.71, 0.78, curve: Curves.easeOut),
      ),
    );

    // Phase 5: CTA button (3500ms+ → 0.83-1.0)
    _ctaOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.83, 0.95, curve: Curves.easeOut),
      ),
    );

    // ── Typing controller (starts at phase 4) ──
    _typingController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _coachMessage.length * 30),
    );

    _typingController.addListener(() {
      final charCount =
          (_typingController.value * _coachMessage.length).round();
      if (charCount != _displayedMessage.length) {
        setState(() {
          _displayedMessage = _coachMessage.substring(0, charCount);
        });
      }
    });

    // ── Pulse controller (infinite gentle glow after gauge reveals) ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Listen to master to trigger sub-animations ──
    _masterController.addListener(() {
      // Start typing effect at ~71% (phase 4 start)
      if (_masterController.value >= 0.71 &&
          !_typingController.isAnimating &&
          _typingController.value == 0) {
        _typingController.forward();
      }

      // Start pulse after gauge is done
      if (_masterController.value >= 0.48 && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    });

    // Start the show
    _masterController.forward();
  }

  @override
  void dispose() {
    _masterController.dispose();
    _typingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _masterController,
          _pulseController,
        ]),
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    MintColors.white,
                    MintColors.nearBlack,
                    _backgroundOpacity.value,
                  )!,
                  Color.lerp(
                    MintColors.white,
                    MintColors.darkNight,
                    _backgroundOpacity.value,
                  )!,
                  Color.lerp(
                    MintColors.white,
                    MintColors.darkDeep,
                    _backgroundOpacity.value,
                  )!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: MintSpacing.xxl),
                        MintEntrance(child: _buildPhase1Title()),
                        const SizedBox(height: MintSpacing.xl + 4),
                        MintEntrance(delay: const Duration(milliseconds: 100), child: _buildPhase2Gauge()),
                        const SizedBox(height: MintSpacing.xl),
                        MintEntrance(delay: const Duration(milliseconds: 200), child: _buildPhase3SubScores()),
                        const SizedBox(height: MintSpacing.lg + 4),
                        MintEntrance(delay: const Duration(milliseconds: 300), child: _buildPhase4CoachMessage()),
                        const SizedBox(height: MintSpacing.xl),
                        MintEntrance(delay: const Duration(milliseconds: 400), child: _buildPhase5Cta()),
                        const SizedBox(height: MintSpacing.xxl),
                        _buildDisclaimer(),
                        const SizedBox(height: MintSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PHASE 1: Title "Ton diagnostic est prêt"
  // ════════════════════════════════════════════════════════════════

  Widget _buildPhase1Title() {
    return Opacity(
      opacity: _titleOpacity.value,
      child: Transform.scale(
        scale: _titleScale.value,
        child: Column(
          children: [
            // Greeting with first name
            Text(
              S.of(context)!.scoreRevealGreeting(_firstName),
              style: MintTextStyles.titleMedium(
                color: MintColors.white.withValues(alpha: 0.6),
              ).copyWith(letterSpacing: 0.5),
            ),
            const SizedBox(height: MintSpacing.sm),
            // Main title
            Text(
              S.of(context)!.scoreRevealTitle,
              textAlign: TextAlign.center,
              style: MintTextStyles.headlineLarge(
                color: MintColors.white,
              ).copyWith(fontSize: 34, letterSpacing: -0.8),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PHASE 2: Circular Score Gauge
  // ════════════════════════════════════════════════════════════════

  Widget _buildPhase2Gauge() {
    final displayScore =
        (widget.score.global * _gaugeProgress.value).round();

    return Opacity(
      opacity: _gaugeOpacity.value,
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Subtle glow behind the gauge
            if (_pulseAnimation.value > 0)
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _scoreColor.withValues(
                        alpha: 0.12 + 0.08 * _pulseAnimation.value,
                      ),
                      blurRadius: 40 + 20 * _pulseAnimation.value,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            // The gauge arc
            CustomPaint(
              painter: _RevealGaugePainter(
                score: widget.score.global,
                progress: _gaugeProgress.value,
                scoreColor: _scoreColor,
              ),
              size: const Size(220, 220),
            ),
            // Center content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated score number
                Text(
                  '$displayScore',
                  style: MintTextStyles.displayLarge(
                    color: MintColors.white,
                  ).copyWith(height: 1.0),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  '/100',
                  style: MintTextStyles.labelLarge(
                    color: MintColors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                // Level badge
                AnimatedOpacity(
                  opacity: _gaugeProgress.value > 0.8 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.md - 4,
                      vertical: MintSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: _scoreColor.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _scoreColor.withValues(alpha: 0.40),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _localizedLevelLabel(context),
                      style: MintTextStyles.labelMedium(
                        color: _scoreColor,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PHASE 3: Sub-Score Bars (staggered slide-in)
  // ════════════════════════════════════════════════════════════════

  Widget _buildPhase3SubScores() {
    return Opacity(
      opacity: _subScoreOpacity.value,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        decoration: BoxDecoration(
          color: MintColors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MintColors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            _buildSubScoreRow(
              label: S.of(context)!.scoreRevealBudget,
              score: widget.score.budget.score,
              icon: Icons.account_balance_wallet_outlined,
              slideOffset: _subScoreBudgetSlide.value,
            ),
            const SizedBox(height: MintSpacing.md - 2),
            _buildSubScoreRow(
              label: S.of(context)!.scoreRevealPrevoyance,
              score: widget.score.prevoyance.score,
              icon: Icons.shield_outlined,
              slideOffset: _subScorePrevoyanceSlide.value,
            ),
            const SizedBox(height: MintSpacing.md - 2),
            _buildSubScoreRow(
              label: S.of(context)!.scoreRevealPatrimoine,
              score: widget.score.patrimoine.score,
              icon: Icons.trending_up,
              slideOffset: _subScorePatrimoineSlide.value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubScoreRow({
    required String label,
    required int score,
    required IconData icon,
    required double slideOffset,
  }) {
    final barColor = _colorForScore(score);
    // Animate bar fill in sync with the slide
    final normalizedSlide =
        ((60 + slideOffset) / 60).clamp(0.0, 1.0); // 0 when offset=-60, 1 when 0
    final barProgress = normalizedSlide;
    final displayScore = (score * barProgress).round();
    final ratio = (score / 100.0).clamp(0.0, 1.0) * barProgress;

    return Transform.translate(
      offset: Offset(slideOffset, 0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MintColors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: MintTextStyles.bodySmall(
                color: MintColors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    // Track
                    Container(
                      decoration: BoxDecoration(
                        color: MintColors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Filled bar
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              barColor.withValues(alpha: 0.6),
                              barColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '$displayScore',
              textAlign: TextAlign.right,
              style: MintTextStyles.bodyMedium(
                color: barColor,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForScore(int score) {
    if (score >= friThresholdExcellent) return MintColors.scoreExcellent;
    if (score >= friThresholdBon) return MintColors.scoreBon;
    if (score >= friThresholdAttention) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  String _localizedLevelLabel(BuildContext context) {
    final score = widget.score.global;
    if (score >= friThresholdExcellent) return S.of(context)!.scoreRevealLevelExcellent;
    if (score >= friThresholdBon) return S.of(context)!.scoreRevealLevelGood;
    if (score >= friThresholdAttention) return S.of(context)!.scoreRevealLevelWarning;
    return S.of(context)!.scoreRevealLevelCritical;
  }

  // ════════════════════════════════════════════════════════════════
  //  PHASE 4: Coach Message (typing effect)
  // ════════════════════════════════════════════════════════════════

  Widget _buildPhase4CoachMessage() {
    return Opacity(
      opacity: _coachMessageOpacity.value,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        decoration: BoxDecoration(
          color: MintColors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coach avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _scoreColor.withValues(alpha: 0.8),
                    _scoreColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 18,
                color: MintColors.white,
              ),
            ),
            const SizedBox(width: MintSpacing.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.scoreRevealCoachLabel,
                    style: MintTextStyles.micro(
                      color: _scoreColor.withValues(alpha: 0.8),
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: MintSpacing.sm - 2),
                  Text(
                    _displayedMessage.isEmpty ? ' ' : _displayedMessage,
                    style: MintTextStyles.labelLarge(
                    color: MintColors.white.withValues(alpha: 0.85),
                  ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PHASE 5: CTA Button
  // ════════════════════════════════════════════════════════════════

  Widget _buildPhase5Cta() {
    return Opacity(
      opacity: _ctaOpacity.value,
      child: Column(
        children: [
          Semantics(
            button: true,
            label: S.of(context)!.scoreRevealCtaDashboard,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
              onPressed: _ctaOpacity.value > 0.5
                  ? () => context.go('/home')
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: _scoreColor,
                foregroundColor: MintColors.white,
                padding: const EdgeInsets.symmetric(vertical: MintSpacing.md + 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                S.of(context)!.scoreRevealCtaDashboard,
                style: MintTextStyles.titleMedium(
                  color: MintColors.white,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ),
          const SizedBox(height: MintSpacing.md - 4),
          // Secondary action
          TextButton(
            onPressed: _ctaOpacity.value > 0.5
                ? () => context.push('/rapport', extra: widget.wizardAnswers)
                : null,
            child: Text(
              S.of(context)!.scoreRevealCtaReport,
              style: MintTextStyles.bodyMedium(
                color: MintColors.white.withValues(alpha: 0.5),
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DISCLAIMER
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    return Opacity(
      opacity: _ctaOpacity.value * 0.8,
      child: Text(
        S.of(context)!.scoreRevealDisclaimer,
        textAlign: TextAlign.center,
        style: MintTextStyles.micro(
          color: MintColors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  REVEAL GAUGE PAINTER
// ────────────────────────────────────────────────────────────
//
//  Arc de 270 degrés sur fond sombre.
//  Track très subtil + arc coloré avec gradient + glow au bout.
//  Cohérent avec _ScoreGaugePainter de MintScoreGauge.
// ────────────────────────────────────────────────────────────

class _RevealGaugePainter extends CustomPainter {
  final int score;
  final double progress;
  final Color scoreColor;

  _RevealGaugePainter({
    required this.score,
    required this.progress,
    required this.scoreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 18;
    const strokeWidth = 12.0;

    // Start angle: bottom-left (consistent with MintScoreGauge)
    const startAngle = 0.75 * pi; // 135 degrees
    const totalSweep = 1.5 * pi; // 270 degrees

    // ── Background track (very subtle on dark bg) ──
    final trackPaint = Paint()
      ..color = MintColors.white.withValues(alpha: 0.06)
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

    // ── Tick marks at 0, 25, 50, 75, 100 ──
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
            scoreColor.withValues(alpha: 0.3),
            scoreColor.withValues(alpha: 0.7),
            scoreColor,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(startAngle),
        ).createShader(arcRect);

      canvas.drawArc(arcRect, startAngle, valueSweep, false, fillPaint);

      // ── Glow at endpoint ──
      final endAngle = startAngle + valueSweep;
      final glowCenter = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );

      // Outer glow
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            scoreColor.withValues(alpha: 0.5),
            scoreColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: glowCenter, radius: 18),
        );
      canvas.drawCircle(glowCenter, 18, glowPaint);

      // Bright tip dot
      final tipPaint = Paint()..color = scoreColor;
      canvas.drawCircle(glowCenter, 5, tipPaint);

      // Inner bright core
      final corePaint = Paint()
        ..color = MintColors.white.withValues(alpha: 0.8);
      canvas.drawCircle(glowCenter, 2.5, corePaint);
    }
  }

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
        center.dx + tickRadius * cos(angle),
        center.dy + tickRadius * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + (tickRadius + 4) * cos(angle),
        center.dy + (tickRadius + 4) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = MintColors.white.withValues(alpha: 0.15)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RevealGaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.progress != progress ||
        oldDelegate.scoreColor != scoreColor;
  }
}
