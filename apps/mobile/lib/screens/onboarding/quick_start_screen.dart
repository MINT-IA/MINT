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
import 'package:mint_mobile/screens/pulse/pulse_screen.dart'
    show NavigationShellState;
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_inline_input_chip.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Quick Start V2 — revelation-first onboarding.
///
/// The result dominates. Inputs are compact chips that open bottom sheets.
/// Structure: Hero intro > Result hero card > Input chips > Micro proof > CTA.
///
/// Collects 4 fields: firstName (secondary), age, revenu brut annuel, canton.
/// Shows a live retirement preview based on the user's actual inputs.
/// Saves via [CoachProfileProvider.updateFromSmartFlow] and navigates to /home.
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
      _age = profile.age.toDouble().clamp(22, 67);
      if (profile.canton.isNotEmpty) {
        _canton = profile.canton;
      }
      if (profile.revenuBrutAnnuel > 0) {
        _salary = profile.revenuBrutAnnuel.clamp(20000, 300000);
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
      context.go('/home');
      NavigationShellState.switchTab(0);
    }
  }

  // ── Bottom sheets for editing ──

  void _showAgeSheet() {
    final l = S.of(context)!;
    double tempAge = _age;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(
            MintSpacing.lg,
            MintSpacing.xl,
            MintSpacing.lg,
            MintSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MintPremiumSlider(
                label: l.quickStartAge,
                value: tempAge,
                min: 22,
                max: 67,
                divisions: 45,
                formatValue: (v) =>
                    l.quickStartAgeValue(v.round().toString()),
                onChanged: (v) => setSheetState(() => tempAge = v),
              ),
              const SizedBox(height: MintSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    setState(() => _age = tempAge);
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style:
                        MintTextStyles.titleMedium(color: MintColors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSalarySheet() {
    final l = S.of(context)!;
    double tempSalary = _salary;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(
            MintSpacing.lg,
            MintSpacing.xl,
            MintSpacing.lg,
            MintSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MintPremiumSlider(
                label: l.quickStartSalary,
                value: tempSalary,
                min: 20000,
                max: 300000,
                divisions: 56,
                formatValue: (v) => formatChfWithPrefix(v),
                onChanged: (v) => setSheetState(() => tempSalary = v),
              ),
              const SizedBox(height: MintSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    setState(() => _salary = tempSalary);
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style:
                        MintTextStyles.titleMedium(color: MintColors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCantonSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        builder: (ctx, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: MintSpacing.md),
          itemCount: sortedCantonCodes.length,
          itemBuilder: (ctx, i) {
            final code = sortedCantonCodes[i];
            final name = cantonFullNames[code] ?? code;
            final selected = code == _canton;
            return ListTile(
              title: Text(
                '$code \u2014 $name',
                style: MintTextStyles.bodyMedium(
                  color: selected
                      ? MintColors.primary
                      : MintColors.textPrimary,
                ).copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_rounded,
                      size: 20, color: MintColors.primary)
                  : null,
              onTap: () {
                setState(() => _canton = code);
                Navigator.pop(ctx);
              },
            );
          },
        ),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final est = _estimate();
    final total = est['total']!;
    final current = est['current']!;
    final ratio = est['ratio']!;
    final ratioPct = (ratio * 100).round();

    // Accent color for hero
    final Color accentColor;
    if (ratio >= 0.7) {
      accentColor = MintColors.success;
    } else if (ratio >= 0.5) {
      accentColor = MintColors.warning;
    } else {
      accentColor = MintColors.error;
    }

    // Narrative text
    final narrative = ratio >= 0.3
        ? l.quickStartNarrative(ratioPct.toString())
        : l.quickStartNarrativeLow;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: Colors.transparent,
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
            // ── Scrollable content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MintSpacing.lg,
                  MintSpacing.sm,
                  MintSpacing.lg,
                  MintSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Bloc 1: Hero intro ──
                    Text(
                      l.quickStartTitle,
                      style: MintTextStyles.headlineLarge(),
                    ),
                    const SizedBox(height: MintSpacing.sm),
                    Text(
                      l.quickStartSubtitle,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: MintSpacing.xxl),

                    // ── Bloc 3: Result hero card (THE STAR) ──
                    MintResultHeroCard(
                      eyebrow: l.quickStartPreviewTitle,
                      primaryValue:
                          '${formatChfWithPrefix(total)}${l.quickStartPerMonth}',
                      primaryLabel: l.quickStartHeroLabel,
                      secondaryValue:
                          '${formatChfWithPrefix(current)}${l.quickStartPerMonth}',
                      secondaryLabel: l.quickStartHeroSecondaryLabel,
                      narrative: narrative,
                      accentColor: accentColor,
                      tone: MintSurfaceTone.porcelaine,
                    ),
                    const SizedBox(height: MintSpacing.xl),

                    // ── Bloc 2: Input chips (compact) ──
                    Wrap(
                      spacing: MintSpacing.sm,
                      runSpacing: MintSpacing.sm,
                      children: [
                        MintInlineInputChip(
                          label: l.quickStartAge,
                          value: l.quickStartAgeValue(
                              _age.round().toString()),
                          onTap: _showAgeSheet,
                          icon: Icons.cake_outlined,
                        ),
                        MintInlineInputChip(
                          label: l.quickStartSalary,
                          value: formatChfWithPrefix(_salary),
                          onTap: _showSalarySheet,
                          icon: Icons.work_outline,
                        ),
                        MintInlineInputChip(
                          label: l.quickStartCanton,
                          value: _canton,
                          onTap: _showCantonSheet,
                          icon: Icons.location_on_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: MintSpacing.lg),

                    // ── Prenom (secondary, discrete) ──
                    Semantics(
                      label: l.quickStartFirstName,
                      textField: true,
                      child: TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: l.quickStartFirstNameHint,
                          labelText: l.quickStartFirstName,
                          labelStyle: MintTextStyles.bodySmall(
                            color: MintColors.textMuted,
                          ),
                          hintStyle: MintTextStyles.bodyMedium(
                            color: MintColors.textMuted,
                          ),
                          filled: true,
                          fillColor: MintColors.craie,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
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
                    const SizedBox(height: MintSpacing.xl),

                    // ── Bloc 4: Confidence notice ──
                    MintConfidenceNotice(
                      percent: 30,
                      message: l.quickStartConfidenceMsg,
                    ),
                    const SizedBox(height: MintSpacing.md),

                    // ── Bloc 5: Micro proof ──
                    Text(
                      l.quickStartDisclaimer,
                      style: MintTextStyles.micro(),
                    ),
                    const SizedBox(height: MintSpacing.md),
                  ],
                ),
              ),
            ),

            // ── Bloc 6 + 7: CTA pill + secondary link (sticky) ──
            MintSurface(
              tone: MintSurfaceTone.porcelaine,
              radius: 0,
              padding: const EdgeInsets.fromLTRB(
                MintSpacing.lg,
                MintSpacing.md,
                MintSpacing.lg,
                MintSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Semantics(
                      button: true,
                      label: l.quickStartCta,
                      child: FilledButton(
                        onPressed: _saving ? null : _onContinue,
                        style: FilledButton.styleFrom(
                          backgroundColor: MintColors.primary,
                          shape: const StadiumBorder(),
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
                  const SizedBox(height: MintSpacing.sm),
                  TextButton(
                    onPressed: _saving ? null : _onContinue,
                    child: Text(
                      l.quickStartCtaSecondary,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textMuted,
                      ),
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
}
