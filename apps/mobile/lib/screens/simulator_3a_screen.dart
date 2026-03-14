import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/widgets/coach/countdown_3a_widget.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

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
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;
    
    // TODO: Implement PDF export for 3a simulator
    // await PdfService.generateBilanPdf(
    //   title: 'Bilan Optimisation Pilier 3a',
    //   results: results,
    //   recommendations: recommendations,
    // );
  }

  @override
  Widget build(BuildContext context) {
    final hasDebt = context.watch<ProfileProvider>().profile?.hasDebt ?? false;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, color: MintColors.white),
                onPressed: _exportPdf,
                tooltip: S.of(context)!.simulator3aExportTooltip,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                S.of(context)!.simulator3aTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: MintColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCoachSection(),
                  const SizedBox(height: 32),
                  _buildInputSection(),
                  const SizedBox(height: 32),
                  if (_result != null)
                    SafeModeGate(
                      hasDebt: hasDebt,
                      lockedTitle: S.of(context)!.simulator3aSafeModeTitleDebt,
                      lockedMessage: S.of(context)!.simulator3aSafeModeMessageDebt,
                      child: _buildResultSection(),
                    ),
                  const SizedBox(height: 32),
                  SafeModeGate(
                    hasDebt: hasDebt,
                    lockedTitle: S.of(context)!.simulator3aSafeModeTitleStrategy,
                    lockedMessage: S.of(context)!.simulator3aSafeModeMessageStrategy,
                    child: _buildEducationSection(),
                  ),
                  const SizedBox(height: 48),
                  _buildDisclaimer(),
                  const SizedBox(height: 24),
                  _buildCountdown3a(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachSection() {
    final s = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(s.simulator3aCoachTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.simulator3aCoachBody,
            style: const TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(s.simulator3aParamsHeader),
        const SizedBox(height: 24),
        _buildSlider(
          label: _isIndepSansLpp
              ? s.simulator3aContributionIndep
              : s.simulator3aContribution,
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
        const SizedBox(height: 20),
        _buildSlider(
          label: s.simulator3aMarginalTaxRate,
          value: _marginalTaxRate * 100,
          min: 10,
          max: 45,
          divisions: 35,
          format: (v) => '${v.toStringAsFixed(0)}%',
          onChanged: (v) {
            _marginalTaxRate = v / 100;
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: s.simulator3aYearsToRetirement,
          value: _years.toDouble(),
          min: 5,
          max: 45,
          divisions: 40,
          format: (v) => s.simulator3aYearsFormat(v.toInt().toString()),
          onChanged: (v) {
            _years = v.toInt();
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: s.simulator3aExpectedReturn,
          value: _annualReturn,
          min: 0,
          max: 10,
          divisions: 20,
          format: (v) => '${v.toStringAsFixed(1)}%',
          onChanged: (v) {
            _annualReturn = v;
            _calculate();
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: MintColors.textMuted,
        letterSpacing: 1.2,
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: MintColors.textPrimary)),
              Text(
                format(value),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: MintColors.primary),
              ),
            ],
          ),
        const SizedBox(height: 8),
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
    );
  }

  Widget _buildResultSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.appleSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(S.of(context)!.simulator3aAnnualTaxGain, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(_result!['annualTaxSaved']!),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: MintColors.primary),
          ),
          const SizedBox(height: 24),
          const Divider(color: MintColors.border),
          const SizedBox(height: 16),
          _buildImpactRow(S.of(context)!.simulator3aFinalCapital, _result!['potentialFinalValue']!),
          const SizedBox(height: 8),
          _buildImpactRow(S.of(context)!.simulator3aCumulativeTaxSaving, _result!['totalTaxSavedOverPeriod']!, color: MintColors.success),
        ],
      ),
    );
  }

  Widget _buildImpactRow(String label, double value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary)),
        Text(
          _currencyFormat.format(value),
          style: TextStyle(fontWeight: FontWeight.w600, color: color ?? MintColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildEducationSection() {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(s.simulator3aStrategyHeader),
        const SizedBox(height: 24),
        _buildSmartItem(Icons.account_balance_wallet_outlined, s.simulator3aStrategyBankTitle, s.simulator3aStrategyBankBody),
        _buildSmartItem(Icons.layers_outlined, s.simulator3aStrategy5AccountsTitle, s.simulator3aStrategy5AccountsBody),
        _buildSmartItem(Icons.trending_up, s.simulator3aStrategyEquitiesTitle, s.simulator3aStrategyEquitiesBody),
      ],
    );
  }

  Widget _buildSmartItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          S.of(context)!.simulator3aDisclaimer,
          style: const TextStyle(color: MintColors.textMuted, fontSize: 11),
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
