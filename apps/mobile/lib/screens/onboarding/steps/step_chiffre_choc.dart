import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

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

  /// Called when the user taps "Affiner mon profil".
  final VoidCallback onEnrich;

  /// Called when the user taps "Voir mon dashboard".
  final VoidCallback onDashboard;

  const StepChiffreChoc({
    super.key,
    required this.viewModel,
    required this.animTrigger,
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
      _ => Icons.insights_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final choc = widget.viewModel.chiffreChoc;
    final vm = widget.viewModel;

    if (choc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
              FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: MintColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: MintColors.lightBorder),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withAlpha(20),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
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
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── CONFIDENCE BAR ───────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                              'Estimation bas\u00e9e sur $infoCount informations. '
                              'Plus tu pr\u00e9cises, plus c\'est fiable.',
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
                            'Precision: ${confidence.round()}%',
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
              ),

              const SizedBox(height: 32),

              // ── PRIMARY CTA — action contextuelle ────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    AnalyticsService().trackCTAClick(
                      'smart_onboarding_action',
                      screenName: 'smart_onboarding_chiffre_choc',
                      data: {'choc_type': choc.type.name},
                    );
                    widget.onDashboard();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Qu\'est-ce que je peux faire ?',
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
                        'Affiner mon profil',
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
                    'Voir mon dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── DISCLAIMER ───────────────────────────────────────────────
              Text(
                'Outil \u00e9ducatif simplifi\u00e9. Ne constitue pas un conseil financier (LSFin). '
                'Sources: LAVS art. 34, LPP art. 14-16, OPP3 art. 7.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
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

    String suffix = '';
    if (raw.endsWith('/mois')) {
      suffix = '/mois';
    } else if (raw.endsWith('/an')) {
      suffix = '/an';
    }

    return 'CHF\u00A0${formatChf(animValue)}$suffix';
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
