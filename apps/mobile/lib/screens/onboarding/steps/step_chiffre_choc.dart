import 'package:flutter/material.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Step 2 of the Smart Onboarding flow — Chiffre Choc reveal.
///
/// Displays ONE impactful number with:
/// - Animated TweenAnimationBuilder counter from 0 → final value
/// - Confidence bar showing data completeness
/// - Three CTAs: primary action, enrich profile, go to dashboard
///
/// [animTrigger] is a [ValueNotifier<int>] owned by the parent screen.
/// Each time its value increments the reveal animation replays.
/// This avoids cross-file private state access.
///
/// Design: Material 3, GoogleFonts.montserrat headings, GoogleFonts.inter body
/// Compliance: disclaimer visible, no banned terms, French informal "tu"
class StepChiffreChoc extends StatefulWidget {
  final SmartOnboardingViewModel viewModel;

  /// Incrementing counter that triggers the reveal animation.
  final ValueNotifier<int> animTrigger;

  /// Called when the user taps "Qu'est-ce que je peux faire?" → JIT step.
  final VoidCallback onNext;

  /// Called when the user taps "Affiner mon profil".
  final VoidCallback onEnrich;

  /// Called when the user taps "Voir mon dashboard".
  final VoidCallback onDashboard;

  const StepChiffreChoc({
    super.key,
    required this.viewModel,
    required this.animTrigger,
    required this.onNext,
    required this.onEnrich,
    required this.onDashboard,
  });

  @override
  State<StepChiffreChoc> createState() => _StepChiffreChocState();
}

class _StepChiffreChocState extends State<StepChiffreChoc>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // The rawValue snapshot at the time the animation was triggered.
  double _animatedTarget = 0;
  int _lastTrigger = 0;

  // ── Literacy calibration (3 questions optionnelles post-reveal) ───────────
  bool? _knowsLppBalance;
  bool? _knowsConversionRate;
  bool? _hasDone3a;

  void _onLiteracyChanged() {
    final score = (_knowsLppBalance == true ? 1 : 0) +
        (_knowsConversionRate == true ? 1 : 0) +
        (_hasDone3a == true ? 1 : 0);
    widget.viewModel.setLiteracyScore(score);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    widget.animTrigger.addListener(_onAnimTrigger);

    // Fix race condition: if the trigger already fired before this widget
    // mounted (PageView builds lazily during scroll animation), auto-play
    // the reveal animation on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final choc = widget.viewModel.chiffreChoc;
      if (choc != null && _controller.status == AnimationStatus.dismissed) {
        setState(() {
          _animatedTarget = choc.rawValue;
          _lastTrigger = widget.animTrigger.value;
        });
        _controller.forward(from: 0);
        _trackView(choc);
      }
    });
  }

  @override
  void didUpdateWidget(StepChiffreChoc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animTrigger != widget.animTrigger) {
      oldWidget.animTrigger.removeListener(_onAnimTrigger);
      widget.animTrigger.addListener(_onAnimTrigger);
    }
  }

  void _onAnimTrigger() {
    if (widget.animTrigger.value == _lastTrigger) return;
    _lastTrigger = widget.animTrigger.value;
    final choc = widget.viewModel.chiffreChoc;
    if (choc == null) return;
    setState(() {
      _animatedTarget = choc.rawValue;
    });
    _controller.forward(from: 0);
    _trackView(choc);
  }

  void _trackView(ChiffreChoc choc) {
    AnalyticsService().trackEvent(
      'smart_onboarding_chiffre_choc_viewed',
      category: 'conversion',
      data: {
        'type': choc.type.name,
        'color_key': choc.colorKey,
        'confidence': widget.viewModel.confidenceScore.round(),
      },
      screenName: 'smart_onboarding_chiffre_choc',
    );
  }

  @override
  void dispose() {
    widget.animTrigger.removeListener(_onAnimTrigger);
    _controller.dispose();
    super.dispose();
  }

  Color _colorForKey(String key) {
    return switch (key) {
      'error' => MintColors.error,
      'warning' => MintColors.warning,
      'success' => MintColors.success,
      'info' => MintColors.info,
      _ => MintColors.primary,
    };
  }

  IconData _iconForName(String name) {
    return switch (name) {
      'warning_amber' => Icons.warning_amber_rounded,
      'trending_down' => Icons.trending_down_rounded,
      'savings' => Icons.savings_rounded,
      'account_balance' => Icons.account_balance_rounded,
      'trending_up' => Icons.trending_up_rounded,
      'schedule' => Icons.schedule_rounded,
      'public' => Icons.public_rounded,
      _ => Icons.insights_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final choc = widget.viewModel.chiffreChoc;
    final vm = widget.viewModel;
    final l = S.of(context)!;

    if (choc == null) {
      return const Scaffold(
        body: MintLoadingSkeleton(),
      );
    }

    final accentColor = _colorForKey(choc.colorKey);
    final confidence = vm.confidenceScore;
    final infoCount = vm.profile?.providedFieldsCount ?? 3;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── CHIFFRE CHOC CARD ────────────────────────────────────────
              MintEntrance(child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: MintSurface(
                    padding: const EdgeInsets.all(32),
                    radius: 24,
                    elevated: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon badge
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(22),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForName(choc.iconName),
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title (short label above the number)
                        Text(
                          choc.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: MintColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // THE NUMBER — animated counter from 0 → rawValue
                        TweenAnimationBuilder<double>(
                          key: ValueKey(_animatedTarget),
                          tween: Tween<double>(
                            begin: 0,
                            end: _animatedTarget,
                          ),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, animValue, _) {
                            return Text(
                              _buildAnimatedValueText(choc, animValue),
                              style: GoogleFonts.montserrat(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Subtitle context
                        Text(
                          choc.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: MintColors.textSecondary,
                            height: 1.55,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // Pedagogical caveat when data is estimated
                        if (choc.confidenceMode ==
                            ChiffreChocConfidence.pedagogical) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: MintColors.info.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: MintColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    l.stepChocPedagogicalCaveat,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: MintColors.textMuted,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )),

              const SizedBox(height: 20),

              // ── CONFIDENCE BAR ───────────────────────────────────────────
              MintEntrance(delay: const Duration(milliseconds: 100), child: FadeTransition(
                opacity: _fadeAnim,
                child: MintSurface(
                  tone: MintSurfaceTone.porcelaine,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  radius: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: MintColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.stepChocConfidenceInfo(infoCount),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: MintColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            l.stepChocConfidenceLabel(confidence.round()),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MintColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ConfidenceBar(value: confidence / 100),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),

              const SizedBox(height: 24),

              // ── LITERACY — optionnel, post-reveal ────────────────────────
              MintEntrance(delay: const Duration(milliseconds: 200), child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.stepChocLiteracyTitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.stepChocLiteracySubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LiteracyQuestion(
                      question: l.stepChocLiteracyLpp,
                      value: _knowsLppBalance,
                      onChanged: (v) {
                        setState(() => _knowsLppBalance = v);
                        _onLiteracyChanged();
                      },
                    ),
                    const SizedBox(height: 10),
                    _LiteracyQuestion(
                      question: l.stepChocLiteracyConversion,
                      value: _knowsConversionRate,
                      onChanged: (v) {
                        setState(() => _knowsConversionRate = v);
                        _onLiteracyChanged();
                      },
                    ),
                    const SizedBox(height: 10),
                    _LiteracyQuestion(
                      question: l.stepChocLiteracy3a,
                      value: _hasDone3a,
                      onChanged: (v) {
                        setState(() => _hasDone3a = v);
                        _onLiteracyChanged();
                      },
                    ),
                  ],
                ),
              )),

              const SizedBox(height: 32),

              // ── PRIMARY CTA — "Qu'est-ce que je peux faire?" → JIT step ───
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    AnalyticsService().trackCTAClick(
                      'smart_onboarding_action',
                      screenName: 'smart_onboarding_chiffre_choc',
                      data: {'choc_type': choc.type.name},
                    );
                    widget.onNext();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l.stepChocAction,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── SECONDARY CTA — enrich profile ───────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    AnalyticsService().trackCTAClick(
                      'smart_onboarding_enrich',
                      screenName: 'smart_onboarding_chiffre_choc',
                      data: {'choc_type': choc.type.name},
                    );
                    widget.onEnrich();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MintColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: const BorderSide(
                      color: MintColors.border,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l.stepChocEnrich,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── TERTIARY CTA — go to dashboard ───────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    AnalyticsService().trackCTAClick(
                      'smart_onboarding_dashboard',
                      screenName: 'smart_onboarding_chiffre_choc',
                    );
                    widget.onDashboard();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: MintColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    l.stepChocDashboard,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── DISCLAIMER ───────────────────────────────────────────────
              MintEntrance(delay: const Duration(milliseconds: 300), child: Text(
                l.stepChocDisclaimer,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Rebuilds the displayed value string during counter animation.
  ///
  /// Detects the unit suffix from [choc.value] and replicates
  /// the same formatting during the counter animation.
  String _buildAnimatedValueText(ChiffreChoc choc, double animValue) {
    final raw = choc.value;

    if (raw.endsWith(' mois')) {
      // liquidityAlert: rawValue is months displayed as "X.X mois"
      return '${animValue.toStringAsFixed(1)} mois';
    }

    // A4 fix: detect /h suffix for hourlyRate
    String suffix = '';
    if (raw.endsWith('/mois')) {
      suffix = '/mois';
    } else if (raw.endsWith('/an')) {
      suffix = '/an';
    } else if (raw.endsWith('/h')) {
      suffix = '/h';
    }

    return 'CHF\u00A0${formatChf(animValue)}$suffix';
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LITERACY QUESTION — oui/non toggle (3 questions de calibrage post-reveal)
// ════════════════════════════════════════════════════════════════════════════

class _LiteracyQuestion extends StatelessWidget {
  final String question;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _LiteracyQuestion({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      child: Row(
        children: [
          Expanded(
            child: Text(
              question,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _LiteracyChip(
            label: l.stepChocYes,
            selected: value == true,
            onTap: () => onChanged(value == true ? null : true),
          ),
          const SizedBox(width: 8),
          _LiteracyChip(
            label: l.stepChocNo,
            selected: value == false,
            onTap: () => onChanged(value == false ? null : false),
          ),
        ],
      ),
    );
  }
}

class _LiteracyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LiteracyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? MintColors.primary.withAlpha(24) : MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? MintColors.primary : MintColors.lightBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? MintColors.primary : MintColors.textSecondary,
          ),
        ),
      ),
    ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CONFIDENCE BAR — linear progress bar showing profile data completeness
// ════════════════════════════════════════════════════════════════════════════

class _ConfidenceBar extends StatelessWidget {
  /// Value between 0.0 and 1.0.
  final double value;

  const _ConfidenceBar({required this.value});

  Color _barColor(double v) {
    if (v >= 0.7) return MintColors.success;
    if (v >= 0.4) return MintColors.warning;
    return MintColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor(value);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: MintColors.lightBorder,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
