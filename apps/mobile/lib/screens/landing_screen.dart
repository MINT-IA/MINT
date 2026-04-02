import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/widgets/analytics_consent_banner.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  final AnalyticsService _analytics = AnalyticsService();

  late final AnimationController _heroController;
  late final AnimationController _translatorController;
  late final AnimationController _footerController;

  // Quick calc fields
  int? _birthYear;
  double? _grossSalary;
  String? _canton;
  final TextEditingController _salaryController = TextEditingController();

  static const List<String> _cantons = [
    'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
    'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
    'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
  ];

  bool get _canCalculate =>
      _birthYear != null && _grossSalary != null && _canton != null;

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('/');

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _translatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _footerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _translatorController.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _footerController.forward();
    });
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _heroController.dispose();
    _translatorController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _onCtaTap() async {
    _analytics.trackCTAClick('cta_commencer_clicked', screenName: '/');
    final isCompleted = await ReportPersistenceService.isCompleted();
    final isMiniCompleted =
        await ReportPersistenceService.isMiniOnboardingCompleted();
    if (mounted) {
      if (isCompleted || isMiniCompleted) {
        context.go('/home');
      } else {
        context.go('/onboarding/quick');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: Stack(
        children: [
          MintEntrance(child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MintSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: MintSpacing.xxxxl),
                        _buildHeroPunchline(),
                        const SizedBox(height: MintSpacing.xxxl),
                        _buildTranslator(),
                        const SizedBox(height: MintSpacing.xxxl),
                        _buildHiddenNumber(),
                        const SizedBox(height: MintSpacing.xxxl),
                        _buildQuickCalc(),
                        const SizedBox(height: MintSpacing.xl),
                        _buildCouplePreview(),
                        const SizedBox(height: MintSpacing.xxl),
                        _buildCta(),
                        const SizedBox(height: MintSpacing.xxl),
                        _buildTrustBar(),
                        const SizedBox(height: MintSpacing.sm),
                        _buildLegalFooter(),
                        const SizedBox(height: MintSpacing.xxxxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )),

          // Analytics consent
          const AnalyticsConsentBanner(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header — MINT wordmark + ghost login
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: MintSpacing.sm, bottom: MintSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MINT',
            style: MintTextStyles.brandLogo(),
          ),
          TextButton(
            onPressed: () {
              _analytics.trackCTAClick('cta_login_clicked', screenName: '/');
              context.go('/auth/login');
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: MintSpacing.sm),
            ),
            child: Text(
              S.of(context)!.authLogin,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Hero — two-line punchline, warm coral on line 2
  // ---------------------------------------------------------------------------
  Widget _buildHeroPunchline() {
    final l10n = S.of(context)!;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _heroController,
          curve: Curves.easeOut,
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.landingPunchline1,
              style: MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l10n.landingPunchline2,
              style: MintTextStyles.headlineLarge(color: MintColors.corailDiscret),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Translator — 3 jargon/clear pairs in individual MintSurface cards
  // ---------------------------------------------------------------------------
  Widget _buildTranslator() {
    final l10n = S.of(context)!;

    // Indices 0, 3, 2 from original list:
    // "Deduction de coordination", "Lacune de prevoyance", "Taux marginal"
    final pairs = [
      (l10n.landingJargon1, l10n.landingClear1),
      (l10n.landingJargon4, l10n.landingClear4),
      (l10n.landingJargon3, l10n.landingClear3),
    ];

    return AnimatedBuilder(
      animation: _translatorController,
      builder: (context, _) {
        return Column(
          children: [
            for (int i = 0; i < pairs.length; i++) ...[
              _buildTranslatorCard(pairs[i].$1, pairs[i].$2, i),
              if (i < pairs.length - 1)
                const SizedBox(height: MintSpacing.md),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTranslatorCard(String jargon, String clear, int index) {
    // Stagger: each card appears 150ms after the previous
    final staggerDelay = index * 0.25; // 0.25 of total animation = ~150ms
    final begin = staggerDelay;
    final end = (staggerDelay + 0.75).clamp(0.0, 1.0);

    final opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _translatorController,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );

    final offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _translatorController,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: offset,
        child: MintSurface(
          tone: MintSurfaceTone.sauge,
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Jargon — struck through, muted
              Expanded(
                child: Text(
                  jargon,
                  style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: MintColors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ),
              // Arrow — coral
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: MintColors.corailDiscret,
                ),
              ),
              // Clear translation — bold, primary
              Expanded(
                child: Text(
                  clear,
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Hidden number — CHF ···· teaser
  // ---------------------------------------------------------------------------
  Widget _buildHiddenNumber() {
    final l10n = S.of(context)!;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _footerController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _footerController,
          curve: Curves.easeOut,
        )),
        child: MintSurface(
          tone: MintSurfaceTone.peche,
          child: Column(
            children: [
              Text(
                l10n.landingHiddenAmount,
                style: MintTextStyles.displayMedium(color: MintColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                l10n.landingHiddenSubtitle,
                style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3b: Quick Calc — "Ton chiffre en 30 secondes"
  // ---------------------------------------------------------------------------
  Widget _buildQuickCalc() {
    final l10n = S.of(context)!;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _footerController,
        curve: Curves.easeOut,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            l10n.landingQuickCalcTitle,
            style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            l10n.landingQuickCalcSubtitle,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Field 1: Birth year
          _QuickCalcTile(
            icon: Icons.cake_outlined,
            label: l10n.landingBirthYear,
            value: _birthYear?.toString(),
            onTap: () => _showBirthYearPicker(),
          ),
          const SizedBox(height: MintSpacing.md),

          // Field 2: Gross salary
          MintSurface(
            tone: MintSurfaceTone.craie,
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: MintSpacing.xs,
            ),
            radius: 12,
            child: TextField(
              controller: _salaryController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: 'CHF\u00a0',
                prefixStyle: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
                hintText: '85\u2019000',
                hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
                labelText: l10n.landingSalary,
                labelStyle: MintTextStyles.labelSmall(color: MintColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: MintSpacing.sm),
              ),
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
              onChanged: (value) {
                final parsed = double.tryParse(value.replaceAll("'", '').replaceAll('\u2019', ''));
                setState(() => _grossSalary = parsed);
              },
            ),
          ),
          const SizedBox(height: MintSpacing.md),

          // Field 3: Canton
          _QuickCalcTile(
            icon: Icons.location_on_outlined,
            label: l10n.landingCanton,
            value: _canton,
            onTap: () => _showCantonPicker(),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Transparency disclosure
          Text(
            l10n.landingTransparency,
            style: MintTextStyles.bodySmall(
              color: MintColors.textMuted,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Calculate button
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: l10n.landingCalculate,
              button: true,
              child: FilledButton(
                onPressed: _canCalculate ? _onCalculate : null,
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.corailDiscret,
                  disabledBackgroundColor: MintColors.textMuted.withValues(alpha: 0.15),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    vertical: MintSpacing.md + 2,
                    horizontal: MintSpacing.xl,
                  ),
                ),
                child: Text(
                  l10n.landingCalculate,
                  style: MintTextStyles.titleMedium(
                    color: _canCalculate ? MintColors.white : MintColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),

          // VZ comparison
          Center(
            child: Text(
              l10n.landingVzComparison,
              style: MintTextStyles.micro(
                color: MintColors.textMuted.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _onCalculate() {
    if (!_canCalculate) return;

    _analytics.trackCTAClick('cta_quick_calc', screenName: '/');

    final currentYear = DateTime.now().year;
    final age = currentYear - _birthYear!;
    const retirementAge = 65;

    // AVS estimate
    final avsMonthly = AvsCalculator.computeMonthlyRente(
      currentAge: age,
      retirementAge: retirementAge,
      grossAnnualSalary: _grossSalary!,
    );

    // LPP simplified estimate (no existing balance — ephemeral)
    // Use coordinated salary + age-based bonification rates
    final salaireCoord = LppCalculator.computeSalaireCoordonne(_grossSalary!);
    double lppBalance = 0;
    for (int a = 25; a < age && a <= 65; a++) {
      lppBalance *= 1.01; // ~1% caisse return
      lppBalance += salaireCoord * getLppBonificationRate(a);
    }
    // Project to retirement
    for (int a = age; a < retirementAge && a <= 65; a++) {
      lppBalance *= 1.01;
      lppBalance += salaireCoord * getLppBonificationRate(a);
    }
    final lppAnnualRente = lppBalance * lppTauxConversionMinDecimal;
    final lppMonthly = lppAnnualRente / 12;

    final totalMonthly = avsMonthly + lppMonthly;
    final netMonthly = _grossSalary! / 12 * 0.85;
    final replacementPercent =
        netMonthly > 0 ? ((totalMonthly / netMonthly) * 100).round() : 0;

    context.push(
      '/chiffre-choc-instant',
      extra: {
        'monthlyTotal': totalMonthly,
        'replacementPercent': replacementPercent,
        'canton': _canton!,
        'grossSalary': _grossSalary!,
      },
    );
  }

  void _showBirthYearPicker() {
    final currentYear = DateTime.now().year;
    final initialIndex = _birthYear != null
        ? _birthYear! - 1940
        : (currentYear - 1980 - 1940).clamp(0, 70);

    // Set initial value immediately (no scroll needed)
    if (_birthYear == null) setState(() => _birthYear = 1940 + initialIndex);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return Container(
          height: 250,
          color: MintColors.white,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex,
            ),
            itemExtent: 40,
            onSelectedItemChanged: (index) {
              setState(() => _birthYear = 1940 + index);
            },
            children: List.generate(
              71, // 1940 to 2010
              (i) => Center(
                child: Text(
                  '${1940 + i}',
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCantonPicker() {
    final initialIndex =
        _canton != null ? _cantons.indexOf(_canton!) : 0;

    // Set initial value immediately (no scroll needed)
    if (_canton == null) setState(() => _canton = _cantons[initialIndex]);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return Container(
          height: 250,
          color: MintColors.white,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex.clamp(0, _cantons.length - 1),
            ),
            itemExtent: 40,
            onSelectedItemChanged: (index) {
              setState(() => _canton = _cantons[index]);
            },
            children: _cantons
                .map((c) => Center(
                      child: Text(
                        c,
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4: Couple preview — personalized or generic teaser
  // ---------------------------------------------------------------------------
  Widget _buildCouplePreview() {
    final l10n = S.of(context)!;

    if (_grossSalary != null && _canton != null) {
      // Simplified marriage penalty estimate using RetirementTaxCalculator:
      // Compare joint filing vs two singles for a dual-income estimate.
      // We assume a fictional partner earning 60% of the user's salary.
      final userIncome = _grossSalary!;
      final conjointIncome = userIncome * 0.6;
      final combined = userIncome + conjointIncome;

      final taxMarried = RetirementTaxCalculator.estimateMonthlyIncomeTax(
        revenuAnnuelImposable: combined,
        canton: _canton!,
        etatCivil: 'marie',
        nombreEnfants: 0,
      ) * 12;

      final taxUserSingle = RetirementTaxCalculator.estimateMonthlyIncomeTax(
        revenuAnnuelImposable: userIncome,
        canton: _canton!,
        etatCivil: 'celibataire',
        nombreEnfants: 0,
      ) * 12;

      final taxConjointSingle = RetirementTaxCalculator.estimateMonthlyIncomeTax(
        revenuAnnuelImposable: conjointIncome,
        canton: _canton!,
        etatCivil: 'celibataire',
        nombreEnfants: 0,
      ) * 12;

      final penalty = (taxMarried - (taxUserSingle + taxConjointSingle))
          .clamp(0, double.infinity)
          .round();

      final penaltyStr = penalty >= 1000
          ? "${penalty ~/ 1000}\u2019${(penalty % 1000).toString().padLeft(3, '0')}"
          : '$penalty';

      return MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.landingCoupleTitle,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            if (penalty > 0)
              Text(
                l10n.landingCouplePersonalized(penaltyStr),
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
              )
            else
              Text(
                l10n.landingCoupleGeneric,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            const SizedBox(height: MintSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/auth/register?intent=couple'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: MintColors.primary),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm),
                ),
                child: Text(
                  l10n.landingCoupleAction,
                  style: MintTextStyles.bodySmall(color: MintColors.primary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Generic teaser when no salary entered yet
    return MintSurface(
      tone: MintSurfaceTone.peche,
      padding: const EdgeInsets.all(MintSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.landingCoupleTitle,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l10n.landingCoupleGeneric,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CTA — pill-shaped filled button
  // ---------------------------------------------------------------------------
  Widget _buildCta() {
    final l10n = S.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        label: l10n.landingCtaCommencer,
        button: true,
        child: FilledButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _onCtaTap();
          },
          style: FilledButton.styleFrom(
            backgroundColor: MintColors.primary,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: MintSpacing.md + 2, horizontal: MintSpacing.xl),
          ),
          child: Text(
            l10n.landingCtaCommencer,
            style: MintTextStyles.titleMedium(color: MintColors.white),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trust bar
  // ---------------------------------------------------------------------------
  Widget _buildTrustBar() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTrustChip(
              Icons.shield_outlined, S.of(context)!.landingTrustSwiss),
          _trustDot(),
          _buildTrustChip(
              Icons.lock_outline_rounded, S.of(context)!.landingTrustPrivate),
          _trustDot(),
          _buildTrustChip(Icons.check_circle_outline_rounded,
              S.of(context)!.landingTrustNoCommitment),
        ],
      ),
    );
  }

  Widget _buildTrustChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: MintColors.textMuted.withValues(alpha: 0.6)),
        const SizedBox(width: MintSpacing.xs),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _trustDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: MintColors.textMuted.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Legal footer
  // ---------------------------------------------------------------------------
  Widget _buildLegalFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
        child: Text(
          S.of(context)!.landingLegalFooterShort,
          textAlign: TextAlign.center,
          style: MintTextStyles.micro(color: MintColors.textMuted.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

/// Tappable tile for birth year / canton selection in quick calc.
class _QuickCalcTile extends StatelessWidget {
  const _QuickCalcTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MintSurface(
        tone: MintSurfaceTone.craie,
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md,
          vertical: MintSpacing.md,
        ),
        radius: 12,
        child: Row(
          children: [
            Icon(icon, size: 20, color: MintColors.textSecondary),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Text(
                value ?? label,
                style: value != null
                    ? MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                    : MintTextStyles.bodyMedium(color: MintColors.textMuted),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: MintColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
