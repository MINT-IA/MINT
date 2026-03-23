import 'package:flutter/material.dart';
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
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Quick Start — single-screen onboarding that gets the user to the dashboard
/// in under 30 seconds.
///
/// Collects 4 fields: firstName (optional), age, revenu brut annuel, canton.
/// Shows a live retirement preview based on the user's actual inputs.
/// Saves via [CoachProfileProvider.updateFromSmartFlow] and navigates to /home.
///
/// Design System category: D (Form) — progressive disclosure, preview live,
/// validation inline, 1 CTA sticky.
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
  final _nameController = TextEditingController();
  double _age = 45;
  double _salary = 85000;
  String _canton = 'VD';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('/onboarding/quick');

    // Pre-fill from existing profile if editing a specific section
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillFromProfile();
        _showSectionGuidance();
      });
    }
  }

  /// Pre-fill fields from the existing coach profile when editing.
  void _prefillFromProfile() {
    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    setState(() {
      if (profile.firstName != null && profile.firstName!.isNotEmpty) {
        _nameController.text = profile.firstName!;
      }
      _age = profile.age.toDouble().clamp(18, 75);
      if (profile.canton.isNotEmpty) {
        _canton = profile.canton;
      }
      if (profile.revenuBrutAnnuel > 0) {
        _salary = profile.revenuBrutAnnuel.clamp(0, 500000);
      }
    });
  }

  /// Show a guidance snackbar indicating which section the user should edit.
  void _showSectionGuidance() {
    final l = S.of(context)!;
    final sectionLabels = {
      'identity': l.quickStartSectionIdentity,
      'income': l.quickStartSectionIncome,
      'pension': l.quickStartSectionPension,
      'property': l.quickStartSectionProperty,
    };
    final label = sectionLabels[widget.initialSection];
    if (label == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.quickStartSectionGuidance(label)),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Live estimation (same formulas as landing page, via financial_core) ──

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
    final age = _age.round();
    final gross = _salary;
    final avs = AvsCalculator.renteFromRAMD(gross);
    final lppBalance = _estimateLppBalance(age, gross);
    final lppAnnual = LppCalculator.projectToRetirement(
      currentBalance: lppBalance,
      currentAge: age,
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

  Future<void> _onContinue() async {
    if (_saving) return;
    setState(() => _saving = true);

    final provider = context.read<CoachProfileProvider>();
    provider.updateFromSmartFlow(
      age: _age.round(),
      grossSalary: _salary,
      canton: _canton,
      firstName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
    );

    _analytics.trackCTAClick('quick_start_completed',
        screenName: '/onboarding/quick');

    if (mounted) {
      context.go('/home?tab=0');
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final est = _estimate();
    final total = est['total']!;
    final current = est['current']!;
    final ratio = est['ratio']!;
    final gap = (current - total).clamp(0.0, double.infinity);
    final dropPctRaw =
        current > 0 ? ((current - total) / current * 100).round() : 0;
    // Clamp to 0: if projection > current, no drop to show
    final dropPct = dropPctRaw.clamp(0, 100);

    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.transparent,
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Scrollable form ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MintSpacing.lg,
                  MintSpacing.md,
                  MintSpacing.lg,
                  MintSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      l.quickStartTitle,
                      style: MintTextStyles.headlineLarge(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.quickStartSubtitle,
                      style: MintTextStyles.bodyMedium(),
                    ),
                    const SizedBox(height: 28),

                    // ── Prenom ──
                    Text(
                      l.quickStartFirstName,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: l.quickStartFirstName,
                      textField: true,
                      child: TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: l.quickStartFirstNameHint,
                          hintStyle: MintTextStyles.bodyMedium(
                            color: MintColors.textMuted,
                          ),
                          filled: true,
                          fillColor: MintColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: MintColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: MintColors.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Age slider ──
                    _buildSliderLabel(
                      l.quickStartAge,
                      l.quickStartAgeValue(_age.round().toString()),
                    ),
                    Semantics(
                      label: l.quickStartAge,
                      slider: true,
                      value:
                          l.quickStartAgeValue(_age.round().toString()),
                      child: SliderTheme(
                        data: _sliderTheme(),
                        child: Slider(
                          value: _age,
                          min: 18,
                          max: 75,
                          divisions: 57,
                          onChanged: (v) => setState(() => _age = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: MintSpacing.md),

                    // ── Revenu brut annuel slider ──
                    _buildSliderLabel(
                      l.quickStartSalary,
                      _salary == 0
                          ? l.quickStartNoIncome
                          : l.quickStartSalaryValue(
                              formatChfWithPrefix(_salary)),
                    ),
                    Semantics(
                      label: l.quickStartSalary,
                      slider: true,
                      value: _salary == 0
                          ? l.quickStartNoIncome
                          : l.quickStartSalaryValue(
                              formatChfWithPrefix(_salary)),
                      child: SliderTheme(
                        data: _sliderTheme(),
                        child: Slider(
                          value: _salary,
                          min: 0,
                          max: 500000,
                          divisions: 100,
                          onChanged: (v) => setState(() => _salary = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: MintSpacing.md),

                    // ── Canton dropdown ──
                    _buildSliderLabel(l.quickStartCanton, ''),
                    const SizedBox(height: MintSpacing.xs),
                    Semantics(
                      label: l.quickStartCanton,
                      button: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: MintColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MintColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _canton,
                            isExpanded: true,
                            style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary,
                            ),
                            items: sortedCantonCodes.map((code) {
                              final name = cantonFullNames[code] ?? code;
                              return DropdownMenuItem(
                                value: code,
                                child: Text('$code — $name'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _canton = v);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Live preview card ──
                    _buildPreviewCard(l, total, current, ratio, gap, dropPct),

                    const SizedBox(height: 12),
                    Text(
                      l.quickStartDisclaimer,
                      style: MintTextStyles.micro(),
                    ),
                    const SizedBox(height: MintSpacing.md),
                  ],
                ),
              ),
            ),

            // ── CTA button (sticky) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MintSpacing.lg,
                MintSpacing.sm,
                MintSpacing.lg,
                MintSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: Semantics(
                  button: true,
                  label: l.quickStartCta,
                  child: FilledButton(
                    onPressed: _saving ? null : _onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MintColors.white,
                            ),
                          )
                        : Text(
                            l.quickStartCta,
                            style: MintTextStyles.titleMedium(
                              color: MintColors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview card with live numbers ──

  Widget _buildPreviewCard(
    S l,
    double total,
    double current,
    double ratio,
    double gap,
    int dropPct,
  ) {
    final Color accentColor;
    final String verdict;
    if (ratio >= 0.7) {
      accentColor = MintColors.success;
      verdict = l.quickStartVerdictGood;
    } else if (ratio >= 0.5) {
      accentColor = MintColors.warning;
      verdict = l.quickStartVerdictWatch;
    } else {
      accentColor = MintColors.scoreAttention;
      verdict = l.quickStartVerdictGap;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.show_chart, size: 18, color: accentColor),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.quickStartPreviewTitle,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  verdict,
                  style: MintTextStyles.labelSmall(color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Avant / Apres
          Row(
            children: [
              Expanded(
                child: _buildAmountColumn(
                  l.quickStartToday,
                  current,
                  MintColors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: MintColors.border,
              ),
              Expanded(
                child: _buildAmountColumn(
                  l.quickStartAtRetirement,
                  total,
                  accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Gap bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: MintColors.border,
              valueColor: AlwaysStoppedAnimation(accentColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: MintSpacing.sm),

          // Drop percentage
          TweenAnimationBuilder<double>(
            tween: Tween(end: dropPct.toDouble()),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => Text(
              l.quickStartDropPct(
                value.round().toString(),
                formatChfWithPrefix(gap),
              ),
              style: MintTextStyles.bodySmall(color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: MintSpacing.xs),
        TweenAnimationBuilder<double>(
          tween: Tween(end: amount),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => Text(
            '${formatChf(value)} CHF',
            style: MintTextStyles.displayMedium(color: color).copyWith(
              fontSize: 20,
            ),
          ),
        ),
        Text(
          S.of(context)!.quickStartPerMonth,
          style: MintTextStyles.labelSmall(),
        ),
      ],
    );
  }

  Widget _buildSliderLabel(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
        Text(
          value,
          style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  SliderThemeData _sliderTheme() {
    return SliderThemeData(
      activeTrackColor: MintColors.primary,
      inactiveTrackColor: MintColors.border,
      thumbColor: MintColors.primary,
      overlayColor: MintColors.primary.withValues(alpha: 0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    );
  }
}
