import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────────────────────
//  WIZARD SCORE PREVIEW — Progressive Financial Fitness Score
// ────────────────────────────────────────────────────────────────────────────
//
//  Widget persistant (80px) au bas du wizard, montrant le score
//  de forme financiere se construire en temps reel a chaque reponse.
//
//  Inspire de Strava : on voit la courbe monter apres chaque activite.
//  Ici, chaque reponse au wizard = un "data point" qui affine le score.
//
//  Sous-scores : Budget (vert), Prevoyance (bleu), Patrimoine (orange)
//  representes par 3 indicateurs compacts qui se remplissent
//  au fur et a mesure que chaque section du wizard est completee.
//
//  Widget pur — pas de Provider, uniquement des props.
// ────────────────────────────────────────────────────────────────────────────

class WizardScorePreview extends StatefulWidget {
  /// Reponses courantes du wizard (cle → valeur)
  final Map<String, dynamic> answers;

  /// Index de la question courante (0-based)
  final int currentQuestionIndex;

  /// Nombre total de questions
  final int totalQuestions;

  /// Section courante du wizard ('Profil', 'Budget & Protection', etc.)
  final String currentSection;

  const WizardScorePreview({
    super.key,
    required this.answers,
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.currentSection,
  });

  @override
  State<WizardScorePreview> createState() => _WizardScorePreviewState();
}

class _WizardScorePreviewState extends State<WizardScorePreview>
    with TickerProviderStateMixin {
  // --- Score state ---
  int _currentScore = 0;
  int _previousScore = 0;
  int _budgetScore = 0;
  int _prevoyanceScore = 0;
  int _patrimoineScore = 0;

  // --- Animation controllers ---
  late AnimationController _scoreAnimController;
  late Animation<double> _scoreAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // --- Section completion tracking ---
  bool _budgetComplete = false;
  bool _prevoyanceComplete = false;
  bool _patrimoineComplete = false;

  @override
  void initState() {
    super.initState();

    // Score bar animation (smooth fill)
    _scoreAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreAnimation = CurvedAnimation(
      parent: _scoreAnimController,
      curve: Curves.easeOutCubic,
    );

    // Pulse animation (for big score jumps)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ambient glow animation (subtle breathing effect)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.03, end: 0.08).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _recalculateScore();
  }

  @override
  void didUpdateWidget(WizardScorePreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recalculate when answers change
    if (oldWidget.answers.length != widget.answers.length ||
        oldWidget.currentQuestionIndex != widget.currentQuestionIndex) {
      _recalculateScore();
    }
  }

  @override
  void dispose() {
    _scoreAnimController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  SCORE CALCULATION
  // ════════════════════════════════════════════════════════════════════════════

  void _recalculateScore() {
    // Don't calculate until we have at least some basic data
    if (widget.answers.isEmpty) {
      _updateSectionCompletion();
      return;
    }

    try {
      final profile = CoachProfile.fromWizardAnswers(widget.answers);
      final result = FinancialFitnessService.calculate(profile: profile);

      final newScore = result.global;
      final delta = newScore - _currentScore;

      setState(() {
        _previousScore = _currentScore;
        _currentScore = newScore;
        _budgetScore = result.budget.score;
        _prevoyanceScore = result.prevoyance.score;
        _patrimoineScore = result.patrimoine.score;
      });

      // Animate the score bar
      _scoreAnimController.forward(from: 0);

      // Pulse if significant jump (> 5 points)
      if (delta.abs() > 5) {
        _pulseController.forward(from: 0);
      }
    } catch (_) {
      // Partial profiles may fail — silently keep previous score
    }

    _updateSectionCompletion();
  }

  void _updateSectionCompletion() {
    setState(() {
      _budgetComplete = widget.currentQuestionIndex >= 12;
      _prevoyanceComplete = widget.currentQuestionIndex >= 18;
      _patrimoineComplete =
          widget.currentQuestionIndex >= widget.totalQuestions - 1;
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  CONTEXTUAL LABEL (changes per section)
  // ════════════════════════════════════════════════════════════════════════════

  String _contextualLabel(S s) {
    final delta = _currentScore - _previousScore;

    switch (widget.currentSection) {
      case 'Profil':
        if (widget.answers.length <= 1) return s.wizardScoreDrawing;
        return s.wizardScoreProfileDrawing;
      case 'Budget & Protection':
        if (_budgetScore > 0) return s.wizardScoreProtectionScore(_budgetScore);
        return s.wizardScoreProtectionAnalyzing;
      case 'Pr\u00e9voyance':
        if (delta > 0) return s.wizardScorePrevoyancePlus(delta);
        if (_prevoyanceScore > 0) return s.wizardScorePrevoyanceScore(_prevoyanceScore);
        return s.wizardScorePrevoyanceAnalyzing;
      case 'Patrimoine':
        if (_patrimoineScore > 0) return s.wizardScorePatrimoineScore(_patrimoineScore);
        return s.wizardScorePatrimoineBuilding;
      default:
        return s.wizardScoreDefault(_currentScore);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  SCORE COLOR
  // ════════════════════════════════════════════════════════════════════════════

  Color get _scoreColor {
    if (_currentScore >= 80) return MintColors.scoreExcellent;
    if (_currentScore >= 60) return MintColors.scoreBon;
    if (_currentScore >= 40) return MintColors.scoreAttention;
    if (_currentScore > 0) return MintColors.scoreCritique;
    return MintColors.border;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: Listenable.merge([_scoreAnimation, _pulseAnimation, _glowAnimation]),
      builder: (context, child) {
        return ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: MintColors.white,
              border: Border(
                top: BorderSide(
                  color: MintColors.lightBorder.withValues(alpha: 0.8),
                  width: 0.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: _scoreColor.withValues(alpha: _glowAnimation.value),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Label + Score number + Section dots
                  _buildTopRow(s),
                  const SizedBox(height: 10),
                  // Row 2: Progress bar
                  _buildProgressBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  TOP ROW: contextual label + score + section dots
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildTopRow(S s) {
    final label = _contextualLabel(s);
    return Row(
      children: [
        // Contextual label
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              label,
              key: ValueKey(label),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
                height: 1.2,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Section completion dots
        _buildSectionDots(s),

        const SizedBox(width: 12),

        // Score number
        _buildScoreChip(),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  SECTION DOTS: 3 colored dots (Budget/Prevoyance/Patrimoine)
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildSectionDots(S s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(
          color: MintColors.scoreExcellent,
          filled: _budgetComplete,
          active: widget.currentSection == 'Budget & Protection',
          tooltip: s.wizardScoreBudgetTooltip,
        ),
        const SizedBox(width: 4),
        _buildDot(
          color: MintColors.info,
          filled: _prevoyanceComplete,
          active: widget.currentSection == 'Pr\u00e9voyance',
          tooltip: s.wizardScorePrevoyanceTooltip,
        ),
        const SizedBox(width: 4),
        _buildDot(
          color: MintColors.warning,
          filled: _patrimoineComplete,
          active: widget.currentSection == 'Patrimoine',
          tooltip: s.wizardScorePatrimoineTooltip,
        ),
      ],
    );
  }

  Widget _buildDot({
    required Color color,
    required bool filled,
    required bool active,
    required String tooltip,
  }) {
    final double size = active ? 10.0 : 8.0;

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: active
              ? Border.all(color: color, width: 1.5)
              : null,
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  SCORE CHIP: compact score display
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildScoreChip() {
    final displayScore =
        (_previousScore + (_currentScore - _previousScore) * _scoreAnimation.value)
            .round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _currentScore > 0
            ? _scoreColor.withValues(alpha: 0.10)
            : MintColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _currentScore > 0
              ? _scoreColor.withValues(alpha: 0.20)
              : MintColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated score number
          Text(
            '$displayScore',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _currentScore > 0 ? _scoreColor : MintColors.textMuted,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '/100',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: MintColors.textMuted,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  PROGRESS BAR: horizontal score bar with gradient
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    // Animated score ratio for the bar
    final targetRatio = (_currentScore / 100.0).clamp(0.0, 1.0);
    final previousRatio = (_previousScore / 100.0).clamp(0.0, 1.0);
    final animatedRatio =
        previousRatio + (targetRatio - previousRatio) * _scoreAnimation.value;

    return SizedBox(
      height: 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          final filledWidth = max(0.0, barWidth * animatedRatio);

          return Stack(
            children: [
              // Track (background)
              Container(
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Filled portion with gradient
              if (filledWidth > 0)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: filledWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        _scoreColor.withValues(alpha: 0.6),
                        _scoreColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _scoreColor.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),

              // Bright tip (leading edge glow)
              if (filledWidth > 2)
                Positioned(
                  left: filledWidth - 3,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MintColors.white.withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: _scoreColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),

              // Section markers (at 33% and 66% of the bar)
              _buildSectionMarker(barWidth * 0.33, _budgetComplete),
              _buildSectionMarker(barWidth * 0.66, _prevoyanceComplete),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionMarker(double position, bool completed) {
    return Positioned(
      left: position - 0.5,
      top: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 1,
        color: completed
            ? MintColors.white.withValues(alpha: 0.6)
            : MintColors.border.withValues(alpha: 0.3),
      ),
    );
  }
}
