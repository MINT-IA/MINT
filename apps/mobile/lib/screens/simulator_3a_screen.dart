import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/widgets/coach/countdown_3a_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/collapsible_section.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';

class Simulator3aScreen extends StatefulWidget {
  const Simulator3aScreen({super.key});

  @override
  State<Simulator3aScreen> createState() => _Simulator3aScreenState();
}

class _Simulator3aScreenState extends State<Simulator3aScreen> {
  double _annualContribution = pilier3aPlafondAvecLpp;
  double _plafond3a = pilier3aPlafondAvecLpp;
  bool _isIndepSansLpp = false;
  double _marginalTaxRate = 0.25;
  int _years = 30;
  double _annualReturn = 4.0;

  Map<String, double>? _result;

  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('3a');
    _initializeFromProfile();
    _calculate();
  }

  void _initializeFromProfile() {
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.hasProfile) {
      final profile = profileProvider.profile!;
      if (profile.birthYear != null) {
        final age = DateTime.now().year - profile.birthYear!;
        _years = (65 - age).clamp(5, 45);
      }

      // Independant sans LPP : plafond majore a 36'288 CHF (OPP3 art. 7)
      if (profile.employmentStatus == EmploymentStatus.selfEmployed &&
          profile.has2ndPillar != true) {
        _isIndepSansLpp = true;
        _plafond3a = pilier3aPlafondSansLpp;
        _annualContribution = pilier3aPlafondSansLpp;
      }

      // Rough estimate of marginal tax rate based on income if available
      if (profile.incomeNetMonthly != null) {
        final annualIncome = profile.incomeNetMonthly! * 12;
        if (annualIncome > 150000) {
          _marginalTaxRate = 0.35;
        } else if (annualIncome > 100000) {
          _marginalTaxRate = 0.30;
        } else if (annualIncome > 60000) {
          _marginalTaxRate = 0.25;
        } else {
          _marginalTaxRate = 0.20;
        }
      }
    }
  }

  void _calculate() {
    setState(() {
      _result = calculate3aTaxBenefit(
        annualContribution: _annualContribution,
        marginalTaxRate: _marginalTaxRate,
        years: _years,
        annualReturn: _annualReturn,
      );
    });
    final screenReturn = ScreenReturn.completed(
      route: '/simulator-3a',
      updatedFields: {'simulated3aAmount': _annualContribution},
      confidenceDelta: 0.02,
    );
    ScreenCompletionTracker.markCompletedWithReturn(
      'simulator_3a',
      screenReturn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final hasDebt = context.watch<ProfileProvider>().profile?.hasDebt ?? false;

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        title: Text(l.sim3aTitle, style: MintTextStyles.headlineMedium()),
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCoachSection(),
            const SizedBox(height: MintSpacing.xl),
            _buildInputSection(),
            const SizedBox(height: MintSpacing.xl),
            if (_result != null)
              SafeModeGate(
                hasDebt: hasDebt,
                lockedTitle: l.sim3aDebtLockedTitle,
                lockedMessage: l.sim3aDebtLockedMessage,
                child: _buildResultSection(),
              ),
            const SizedBox(height: MintSpacing.xl),
            SafeModeGate(
              hasDebt: hasDebt,
              lockedTitle: l.sim3aDebtStrategyTitle,
              lockedMessage: l.sim3aDebtStrategyMessage,
              child: _buildEducationSection(),
            ),
            const SizedBox(height: MintSpacing.xl),
            _buildRelatedSections(),
            const SizedBox(height: MintSpacing.xxl),
            _buildDisclaimer(),
            const SizedBox(height: MintSpacing.lg),
            _buildCountdown3a(),
            const SizedBox(height: MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachSection() {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: MintColors.primary, size: 24),
              const SizedBox(width: MintSpacing.sm),
              Text(l.sim3aCoachTitle, style: MintTextStyles.titleMedium()),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.sim3aCoachBody,
            style: MintTextStyles.bodyMedium(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    final l = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.sim3aParamsHeader, style: MintTextStyles.labelSmall()),
        const SizedBox(height: MintSpacing.lg),
        _buildSlider(
          label: _isIndepSansLpp
              ? l.sim3aAnnualContributionIndep
              : l.sim3aAnnualContribution,
          value: _annualContribution,
          min: 1000,
          max: _plafond3a,
          divisions: ((_plafond3a - 1000) / 50).round(),
          format: (v) => _currencyFormat.format(v),
          onChanged: (v) {
            _annualContribution = (v / 50).round() * 50.0;
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: l.sim3aMarginalRate,
          value: _marginalTaxRate * 100,
          min: 10,
          max: 45,
          divisions: 35,
          format: (v) => '${v.toStringAsFixed(0)}\u00a0%',
          onChanged: (v) {
            _marginalTaxRate = v / 100;
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: l.sim3aYearsToRetirement,
          value: _years.toDouble(),
          min: 5,
          max: 45,
          divisions: 40,
          format: (v) => l.sim3aYearsSuffix(v.toInt()),
          onChanged: (v) {
            _years = v.toInt();
            _calculate();
          },
        ),
        const SizedBox(height: MintSpacing.md),
        _buildSlider(
          label: l.sim3aExpectedReturn,
          value: _annualReturn,
          min: 0,
          max: 10,
          divisions: 20,
          format: (v) => '${v.toStringAsFixed(1)}\u00a0%',
          onChanged: (v) {
            _annualReturn = v;
            _calculate();
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required void Function(double) onChanged,
  }) {
    return Semantics(
      label: '$label: ${format(value)}',
      slider: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(label, style: MintTextStyles.bodyMedium(color: MintColors.textPrimary))),
                Text(
                  format(value),
                  style: MintTextStyles.bodyMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          const SizedBox(height: MintSpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(l.sim3aAnnualTaxSaved, style: MintTextStyles.bodyMedium()),
          const SizedBox(height: MintSpacing.sm),
          Text(
            _currencyFormat.format(_result!['annualTaxSaved']!),
            style: MintTextStyles.displayMedium(color: MintColors.primary),
          ),
          const SizedBox(height: MintSpacing.lg),
          const Divider(color: MintColors.border),
          const SizedBox(height: MintSpacing.md),
          _buildImpactRow(l.sim3aFinalCapital, _result!['potentialFinalValue']!),
          const SizedBox(height: MintSpacing.sm),
          _buildImpactRow(l.sim3aCumulativeTaxSaved, _result!['totalTaxSavedOverPeriod']!, color: MintColors.success),
        ],
      ),
    );
  }

  Widget _buildImpactRow(String label, double value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: MintTextStyles.bodyMedium())),
        Text(
          _currencyFormat.format(value),
          style: MintTextStyles.bodyMedium(color: color ?? MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEducationSection() {
    final l = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.sim3aStrategyHeader, style: MintTextStyles.labelSmall()),
        const SizedBox(height: MintSpacing.lg),
        _buildSmartItem(Icons.account_balance_wallet_outlined, l.sim3aStratBankTitle, l.sim3aStratBankBody),
        _buildSmartItem(Icons.layers_outlined, l.sim3aStrat5AccountsTitle, l.sim3aStrat5AccountsBody),
        _buildSmartItem(Icons.trending_up, l.sim3aStrat100ActionsTitle, l.sim3aStrat100ActionsBody),
      ],
    );
  }

  Widget _buildSmartItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: MintColors.primary, size: 20),
          ),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MintTextStyles.titleMedium().copyWith(fontSize: 15)),
                const SizedBox(height: MintSpacing.xs),
                Text(subtitle, style: MintTextStyles.bodyMedium()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedSections() {
    final l = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.sim3aExploreAlso, style: MintTextStyles.titleMedium()),
        const SizedBox(height: MintSpacing.sm),
        CollapsibleSection(
          title: l.sim3aProviderComparator,
          subtitle: l.sim3aProviderComparatorSub,
          icon: Icons.compare,
          child: _buildSectionCta(l.sim3aCtaCompare, '/3a-deep/comparator'),
        ),
        CollapsibleSection(
          title: l.sim3aRealReturn,
          subtitle: l.sim3aRealReturnSub,
          icon: Icons.trending_up,
          child: _buildSectionCta(l.sim3aCtaCalculate, '/3a-deep/real-return'),
        ),
        CollapsibleSection(
          title: l.sim3aStaggeredWithdrawal,
          subtitle: l.sim3aStaggeredWithdrawalSub,
          icon: Icons.calendar_month,
          child: _buildSectionCta(l.sim3aCtaPlan, '/3a-deep/staggered-withdrawal'),
        ),
      ],
    );
  }

  Widget _buildSectionCta(String label, String route) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => context.push(route),
        child: Text(label),
      ),
    );
  }

  Widget _buildDisclaimer() {
    final l = S.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
        child: Text(
          l.sim3aDisclaimer,
          style: MintTextStyles.micro(),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCountdown3a() {
    final now = DateTime.now();
    final endOfYear = DateTime(now.year, 12, 31);
    final daysRemaining = endOfYear.difference(now).inDays;
    final taxSavings = _plafond3a * _marginalTaxRate;

    // Estimate year-to-date contributions from monthly planned versements
    final coachProfile = context.read<CoachProfileProvider>().profile;
    final monthly3a = coachProfile?.total3aMensuel ?? 0;
    final monthsElapsed = now.month; // Jan=1..Dec=12
    final estimatedContributed = (monthly3a * monthsElapsed).clamp(0.0, _plafond3a);

    return Countdown3aWidget(
      annualCeiling: _plafond3a,
      amountContributed: estimatedContributed,
      taxSavingsIfFull: taxSavings,
      daysRemaining: daysRemaining,
      year: now.year,
    );
  }
}
