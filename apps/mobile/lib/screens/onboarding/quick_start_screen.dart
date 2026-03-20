import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/screens/pulse/pulse_screen.dart'
    show NavigationShellState;
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';

/// Quick Start V3 — Premium 3-step onboarding (15 seconds, 3 taps).
///
/// Structure: Age (picker) → Revenu (numeric) → Canton (grid) → Result reveal.
/// Each step is a full-screen page with generous whitespace and smooth transitions.
/// No firstName — the coach will ask later.
///
/// Design System category: D (Form) — progressive disclosure, preview live.
class QuickStartScreen extends StatefulWidget {
  /// Optional section to highlight when navigating from profile edit buttons.
  /// Values: 'identity', 'income', 'pension', 'property'.
  final String? initialSection;

  const QuickStartScreen({super.key, this.initialSection});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  final _analytics = AnalyticsService();

  // ── State ──
  int _step = 0; // 0=age, 1=revenu, 2=canton, 3=result
  int _age = 45;
  String _salaryText = '';
  double _salary = 0;
  String _canton = '';
  bool _saving = false;

  // Controllers
  late final FixedExtentScrollController _pickerController;
  final _salaryFocus = FocusNode();
  final _salaryController = TextEditingController();

  // Constants
  static const int _minAge = 18;
  static const int _maxAge = 75;

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('/onboarding/quick');
    _pickerController = FixedExtentScrollController(
      initialItem: _age - _minAge,
    );

    // Pre-fill from existing profile if editing a specific section
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillFromProfile();
      });
    }
  }

  void _prefillFromProfile() {
    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    setState(() {
      _age = profile.age.clamp(_minAge, _maxAge);
      _pickerController.jumpToItem(_age - _minAge);
      if (profile.canton.isNotEmpty) {
        _canton = profile.canton;
      }
      if (profile.revenuBrutAnnuel > 0) {
        _salary = profile.revenuBrutAnnuel.clamp(20000, 500000);
        _salaryText = _formatSalaryDisplay(_salary.round());
        _salaryController.text = _salary.round().toString();
      }
    });
  }

  @override
  void dispose() {
    _pickerController.dispose();
    _salaryFocus.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  // ── Formatting ──

  String _formatSalaryDisplay(int amount) {
    if (amount == 0) return '';
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('\u2019'); // right single quotation mark (Swiss thousands)
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  // ── Estimation (same formulas as before, via financial_core) ──

  double _estimateLppBalance(int age, double gross) {
    if (gross < lppSeuilEntree) return 0.0;
    final coord = (gross - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    double balance = 0;
    for (int a = 25; a < age && a < 65; a++) {
      balance *= 1.01;
      balance += coord * getLppBonificationRate(a);
    }
    return balance;
  }

  Map<String, double> _estimate() {
    final gross = _salary;
    final avs = AvsCalculator.renteFromRAMD(gross);
    final lppBalance = _estimateLppBalance(_age, gross);
    final lppAnnual = LppCalculator.projectToRetirement(
      currentBalance: lppBalance,
      currentAge: _age,
      retirementAge: 65,
      grossAnnualSalary: gross,
      caisseReturn: 0.01,
      conversionRate: lppTauxConversionMinDecimal,
    );
    final lppMonthly = lppAnnual / 12;
    final total = avs + lppMonthly;
    final current = gross / 12;
    final ratio = current > 0 ? total / current : 0.0;
    return {'total': total, 'current': current, 'ratio': ratio};
  }

  // ── Navigation ──

  void _nextStep() {
    if (_step < 3) {
      setState(() => _step++);
      if (_step == 1) {
        // Focus salary field after transition
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _salaryFocus.requestFocus();
        });
      }
    }
  }

  void _onCantonSelected(String code) {
    setState(() {
      _canton = code;
    });
    // Canton selected = go directly to chat (no result screen)
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _onCtaCoach();
    });
  }

  Future<void> _onCtaCoach() async {
    if (_saving) return;
    setState(() => _saving = true);

    final provider = context.read<CoachProfileProvider>();
    provider.updateFromSmartFlow(
      age: _age,
      grossSalary: _salary,
      canton: _canton,
    );

    _analytics.trackCTAClick('quick_start_coach',
        screenName: '/onboarding/quick');

    if (mounted) {
      context.go('/home');
      // Wait for shell to mount before switching tab
      Future.delayed(const Duration(milliseconds: 300), () {
        NavigationShellState.switchTab(1); // Coach tab
      });
    }
  }

  Future<void> _onCtaExplore() async {
    if (_saving) return;
    setState(() => _saving = true);

    final provider = context.read<CoachProfileProvider>();
    provider.updateFromSmartFlow(
      age: _age,
      grossSalary: _salary,
      canton: _canton,
    );

    _analytics.trackCTAClick('quick_start_explore',
        screenName: '/onboarding/quick');

    if (mounted) {
      context.go('/home');
      NavigationShellState.switchTab(0); // Aujourd'hui tab
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _StepAge(
          key: const ValueKey('step_age'),
          age: _age,
          pickerController: _pickerController,
          onAgeChanged: (v) => setState(() => _age = v),
          onNext: _nextStep,
        );
      case 1:
        return _StepRevenu(
          key: const ValueKey('step_revenu'),
          salaryText: _salaryText,
          salaryFocus: _salaryFocus,
          salaryController: _salaryController,
          onSalaryChanged: (text, value) {
            setState(() {
              _salaryText = text;
              _salary = value;
            });
          },
          onNext: _salary > 0 ? _nextStep : null,
        );
      case 2:
        return _StepCanton(
          key: const ValueKey('step_canton'),
          selectedCanton: _canton,
          onCantonSelected: _onCantonSelected,
        );
      case 3:
        final est = _estimate();
        return _StepResult(
          key: const ValueKey('step_result'),
          total: est['total']!,
          ratio: est['ratio']!,
          saving: _saving,
          onCtaCoach: _onCtaCoach,
          onCtaExplore: _onCtaExplore,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 1 — Age
// ═══════════════════════════════════════════════════════════════════════════════

class _StepAge extends StatelessWidget {
  final int age;
  final FixedExtentScrollController pickerController;
  final ValueChanged<int> onAgeChanged;
  final VoidCallback onNext;

  const _StepAge({
    super.key,
    required this.age,
    required this.pickerController,
    required this.onAgeChanged,
    required this.onNext,
  });

  static const int _minAge = 18;
  static const int _maxAge = 75;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Column(
      children: [
        const SizedBox(height: MintSpacing.xxl + MintSpacing.xl),

        // Title
        Text(
          l.quickStartAgeTitle,
          style: MintTextStyles.headlineLarge(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MintSpacing.sm),

        // Subtitle
        Text(
          l.quickStartAgeSubtitle,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          textAlign: TextAlign.center,
        ),

        // Picker
        Expanded(
          child: Center(
            child: SizedBox(
              height: 260,
              child: CupertinoPicker(
                scrollController: pickerController,
                itemExtent: 56,
                diameterRatio: 1.3,
                squeeze: 0.95,
                magnification: 1.15,
                useMagnifier: true,
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: MintColors.bleuAir.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  onAgeChanged(_minAge + index);
                },
                children: List.generate(
                  _maxAge - _minAge + 1,
                  (index) {
                    final value = _minAge + index;
                    final isSelected = value == age;
                    return Center(
                      child: Text(
                        l.quickStartAgeValue(value.toString()),
                        style: MintTextStyles.displayMedium(
                          color: isSelected
                              ? MintColors.textPrimary
                              : MintColors.textMuted,
                        ).copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Next button
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MintSpacing.lg,
            0,
            MintSpacing.lg,
            MintSpacing.xl,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                shape: const StadiumBorder(),
              ),
              child: Text(
                l.quickStartNext,
                style: MintTextStyles.titleMedium(color: MintColors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 2 — Revenu
// ═══════════════════════════════════════════════════════════════════════════════

class _StepRevenu extends StatelessWidget {
  final String salaryText;
  final FocusNode salaryFocus;
  final TextEditingController salaryController;
  final void Function(String display, double value) onSalaryChanged;
  final VoidCallback? onNext;

  const _StepRevenu({
    super.key,
    required this.salaryText,
    required this.salaryFocus,
    required this.salaryController,
    required this.onSalaryChanged,
    required this.onNext,
  });

  String _formatLive(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final num = int.tryParse(digits) ?? 0;
    if (num == 0) return '';
    final str = num.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('\u2019');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Column(
      children: [
        const SizedBox(height: MintSpacing.xxl + MintSpacing.xl),

        // Title
        Text(
          l.quickStartRevenueTitle,
          style: MintTextStyles.headlineLarge(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MintSpacing.sm),

        // Subtitle
        Text(
          l.quickStartRevenueSubtitle,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          textAlign: TextAlign.center,
        ),

        // Input area
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.lg,
                  vertical: MintSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: MintColors.craie,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'CHF',
                      style: MintTextStyles.headlineMedium(
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: MintSpacing.md),
                    Expanded(
                      child: TextField(
                        focusNode: salaryFocus,
                        controller: salaryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(7),
                        ],
                        style: MintTextStyles.displayMedium(
                          color: MintColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: '85\u2019000',
                          hintStyle: MintTextStyles.displayMedium(
                            color: MintColors.textMuted.withValues(alpha: 0.4),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (raw) {
                          final digits =
                              raw.replaceAll(RegExp(r'[^0-9]'), '');
                          final num = int.tryParse(digits) ?? 0;
                          final display = _formatLive(raw);
                          onSalaryChanged(display, num.toDouble());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Next button
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MintSpacing.lg,
            0,
            MintSpacing.lg,
            MintSpacing.xl,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: AnimatedOpacity(
              opacity: onNext != null ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  l.quickStartNext,
                  style: MintTextStyles.titleMedium(color: MintColors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 3 — Canton
// ═══════════════════════════════════════════════════════════════════════════════

class _StepCanton extends StatelessWidget {
  final String selectedCanton;
  final ValueChanged<String> onCantonSelected;

  const _StepCanton({
    super.key,
    required this.selectedCanton,
    required this.onCantonSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Column(
      children: [
        const SizedBox(height: MintSpacing.xxl + MintSpacing.xl),

        // Title
        Text(
          l.quickStartCantonTitle,
          style: MintTextStyles.headlineLarge(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MintSpacing.sm),

        // Subtitle
        Text(
          l.quickStartCantonSubtitle,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MintSpacing.xl),

        // Canton grid — 4 columns, clean squares
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemCount: sortedCantonCodes.length,
            itemBuilder: (context, index) {
              final code = sortedCantonCodes[index];
              final isSelected = code == selectedCanton;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onCantonSelected(code);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MintColors.primary
                        : MintColors.porcelaine,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: MintColors.border.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    code,
                    style: MintTextStyles.titleMedium(
                      color: isSelected
                          ? MintColors.white
                          : MintColors.textPrimary,
                    ).copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: MintSpacing.lg),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 4 — Result reveal
// ═══════════════════════════════════════════════════════════════════════════════

class _StepResult extends StatelessWidget {
  final double total;
  final double ratio;
  final bool saving;
  final VoidCallback onCtaCoach;
  final VoidCallback onCtaExplore;

  const _StepResult({
    super.key,
    required this.total,
    required this.ratio,
    required this.saving,
    required this.onCtaCoach,
    required this.onCtaExplore,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final ratioPct = (ratio * 100).round();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MintColors.porcelaine,
            MintColors.pecheDouce.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Column(
        children: [
          // Hero content
          Expanded(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hero number
                    MintHeroNumber(
                      value: formatChfWithPrefix(total),
                      caption: l.quickStartPerMonth,
                      semanticsLabel:
                          '${formatChfWithPrefix(total)} ${l.quickStartPerMonth}',
                    ),
                    const SizedBox(height: MintSpacing.xl),

                    // Narrative
                    Text(
                      l.quickStartNarrative(ratioPct.toString()),
                      style: MintTextStyles.bodyLarge(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: MintSpacing.xl),

                    // Confidence notice
                    MintConfidenceNotice(
                      percent: 30,
                      message: l.quickStartResultConfidence,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // CTAs
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MintSpacing.lg,
              0,
              MintSpacing.lg,
              MintSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary CTA
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: saving ? null : onCtaCoach,
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      shape: const StadiumBorder(),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MintColors.white,
                            ),
                          )
                        : Text(
                            l.quickStartCtaCoach,
                            style: MintTextStyles.titleMedium(
                              color: MintColors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),

                // Secondary CTA
                TextButton(
                  onPressed: saving ? null : onCtaExplore,
                  child: Text(
                    l.quickStartCtaExplore,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
