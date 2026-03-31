import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
  int _birthYear = 1981;
  double _salary = 85000;
  String _canton = 'ZH';
  bool _saving = false;
  bool _consentGranted = false;

  @override
  void initState() {
    super.initState();
    // nLPD art. 6: Show consent BEFORE any data collection or tracking
    _checkAndRequestConsent();

    // Pre-fill from existing profile if editing a specific section
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillFromProfile();
        _showSectionGuidance();
      });
    }
  }

  /// nLPD art. 6: Ensure consent is granted BEFORE any data collection.
  /// Shows a consent dialog on first visit. Data entry is blocked until accepted.
  Future<void> _checkAndRequestConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyConsented = prefs.getBool('onboarding_data_consent') ?? false;
    if (alreadyConsented) {
      if (mounted) setState(() => _consentGranted = true);
      _analytics.trackScreenView('/onboarding/quick');
      return;
    }
    // Show consent dialog — block until user accepts
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context)!.onboardingTrustTransparency),
        content: Text(S.of(context)!.onboardingConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.of(context)!.onboardingConsentDecline),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.of(context)!.onboardingConsentAccept),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await prefs.setBool('onboarding_data_consent', true);
      if (mounted) setState(() => _consentGranted = true);
      _analytics.trackScreenView('/onboarding/quick');
    } else {
      // User declined — go back to landing
      if (mounted) context.go('/');
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
      if (profile.dateOfBirth != null) {
        _birthYear = profile.dateOfBirth!.year;
      } else {
        _birthYear = DateTime.now().year - profile.age;
      }
      if (profile.canton.isNotEmpty) {
        _canton = profile.canton;
      }
      if (profile.revenuBrutAnnuel > 0) {
        _salary = profile.revenuBrutAnnuel.clamp(0, 10000000);
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
    for (int a = 25; a < age && a < avsAgeReferenceHomme; a++) {
      balance *= 1.01;
      balance += coord * getLppBonificationRate(a);
    }
    return balance;
  }

  int get _age => DateTime.now().year - _birthYear;

  Map<String, double> _estimate() {
    final age = _age;
    final gross = _salary;
    final avs = AvsCalculator.renteFromRAMD(gross);
    final lppBalance = _estimateLppBalance(age, gross);
    final lppAnnual = LppCalculator.projectToRetirement(
      currentBalance: lppBalance,
      currentAge: age,
      retirementAge: avsAgeReferenceHomme,
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
      age: _age,
      grossSalary: _salary,
      canton: _canton,
      firstName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
    );

    _analytics.trackCTAClick('quick_start_completed',
        screenName: '/onboarding/quick');

    // P1-Onboarding: Best-effort backend profile sync if user is authenticated.
    // Fire-and-forget — navigation proceeds regardless of outcome.
    try {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        final birthYear = DateTime.now().year - _age;
        // ignore: deprecated_member_use
        ApiService.createProfile(
          birthYear: birthYear,
          canton: _canton,
          householdType: HouseholdType.single,
          incomeGrossYearly: _salary,
        ).then((_) {
          debugPrint('[QuickStart] Backend profile synced');
        }).catchError((Object e) {
          debugPrint('[QuickStart] Backend profile sync failed (best-effort): $e');
          return null;
        });
      }
    } catch (_) {
      // AuthProvider not in tree or not logged in — skip backend sync.
    }

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
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Scrollable form ──
            Expanded(
              child: MintEntrance(child: SingleChildScrollView(
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

                    // ── Birth year picker ──
                    Text(
                      l.quickStartAge,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MintSurface(
                      tone: MintSurfaceTone.porcelaine,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      radius: 12,
                      child: SizedBox(
                        height: 120,
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: _birthYear - 1940,
                          ),
                          itemExtent: 38,
                          diameterRatio: 1.2,
                          magnification: 1.1,
                          squeeze: 1.0,
                          selectionOverlay: Container(
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color: MintColors.primary.withAlpha(38),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          onSelectedItemChanged: (index) {
                            setState(() => _birthYear = 1940 + index);
                          },
                          children: List.generate(
                            DateTime.now().year - 18 - 1940 + 1,
                            (index) {
                              final year = 1940 + index;
                              final age = DateTime.now().year - year;
                              final isSelected = year == _birthYear;
                              return Center(
                                child: Text(
                                  l.quickStartAgeValue('$year ($age ans)'),
                                  style: GoogleFonts.montserrat(
                                    fontSize: isSelected ? 18 : 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? MintColors.textPrimary
                                        : MintColors.textMuted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: MintSpacing.md),

                    // ── Revenu brut annuel slider ──
                    MintPremiumSlider(
                      label: l.quickStartSalary,
                      value: _salary,
                      min: 0,
                      max: 500000,
                      divisions: 100,
                      formatValue: (v) => v == 0
                          ? l.quickStartNoIncome
                          : l.quickStartSalaryValue(
                              formatChfWithPrefix(v)),
                      onChanged: (v) => setState(() => _salary = v),
                    ),
                    const SizedBox(height: MintSpacing.md),

                    // ── Canton dropdown ──
                    _buildSliderLabel(l.quickStartCanton, ''),
                    const SizedBox(height: MintSpacing.xs),
                    Semantics(
                      label: l.quickStartCanton,
                      button: true,
                      child: MintSurface(
                        tone: MintSurfaceTone.porcelaine,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        radius: 12,
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
            )),

            // ── CTA button (sticky) ──
            MintEntrance(delay: const Duration(milliseconds: 100), child: Padding(
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
            )),
          ],
        ),
      ))),
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

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(20),
      radius: 16,
      child: Column(
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.show_chart, size: 18, color: accentColor),
              const SizedBox(width: MintSpacing.sm),
              Flexible(
                child: Text(
                  l.quickStartPreviewTitle,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        Flexible(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

}
