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
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/widgets/collapsible_section.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
  bool _hasUserInteracted = false;

  /// Sequence IDs read from GoRouter.extra (Tier A when present).
  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);
  late final TextEditingController _contributionCtrl;

  /// True if values were pre-filled from CoachProfile.
  bool _isPreFilled = false;
  /// Canton used for estimated marginal rate display.
  String _profileCanton = '';

  @override
  void initState() {
    super.initState();
    _contributionCtrl = TextEditingController();
    _initializeFromProfile();
    _contributionCtrl.text = _annualContribution.round().toString();
    _calculate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
      if (_seqRunId == null) {
        ReportPersistenceService.markSimulatorExplored('3a');
      }
    });
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {}
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    if (!_hasUserInteracted) {
      ScreenCompletionTracker.markCompletedWithReturn('simulator_3a',
        ScreenReturn.abandoned(
          route: '/pilier-3a',
          runId: _seqRunId, stepId: _seqStepId,
          eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
        ));
      return;
    }

    final economieFiscale = _result?['annualTaxSaved'] ?? 0.0;
    ScreenCompletionTracker.markCompletedWithReturn('simulator_3a',
      ScreenReturn.completed(
        route: '/pilier-3a',
        stepOutputs: {
          'contribution_annuelle': _annualContribution,
          'economie_fiscale': economieFiscale,
        },
        runId: _seqRunId, stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      ));
  }

  @override
  void dispose() {
    _contributionCtrl.dispose();
    super.dispose();
  }

  void _initializeFromProfile() {
    // Try CoachProfileProvider first (richer data), fall back to ProfileProvider.
    bool filled = false;
    try {
      final coachProvider = context.read<CoachProfileProvider>();
      final coachProfile = coachProvider.profile;
      if (coachProfile != null) {
        filled = true;
        _isPreFilled = true;

        // Age + years to retirement
        _years = coachProfile.anneesAvantRetraite.clamp(1, 45);

        // Canton
        _profileCanton = coachProfile.canton.isNotEmpty
            ? coachProfile.canton
            : '';

        // Independent sans LPP
        if (coachProfile.archetype == FinancialArchetype.independentNoLpp) {
          _isIndepSansLpp = true;
          _plafond3a = pilier3aPlafondSansLpp;
          _annualContribution = pilier3aPlafondSansLpp;
        }

        // Marginal tax rate from TaxCalculator (precise, canton-aware)
        final grossAnnual = coachProfile.salaireBrutMensuel * 12;
        if (grossAnnual > 0 && _profileCanton.isNotEmpty) {
          final isMarried =
              coachProfile.etatCivil == CoachCivilStatus.marie;
          _marginalTaxRate = RetirementTaxCalculator.estimateMarginalRate(
            grossAnnual,
            _profileCanton,
            isMarried: isMarried,
            children: coachProfile.nombreEnfants,
          );
        }
      }
    } catch (_) {
      // CoachProfileProvider not in tree — fall back below.
    }

    if (!filled) {
      // Legacy fallback: ProfileProvider.
      try {
        final profileProvider = context.read<ProfileProvider>();
        if (profileProvider.hasProfile) {
          final profile = profileProvider.profile!;
          if (profile.birthYear != null) {
            final age = DateTime.now().year - profile.birthYear!;
            _years = (avsAgeReferenceHomme - age).clamp(5, 45);
          }

          if (profile.employmentStatus == EmploymentStatus.selfEmployed &&
              profile.has2ndPillar != true) {
            _isIndepSansLpp = true;
            _plafond3a = pilier3aPlafondSansLpp;
            _annualContribution = pilier3aPlafondSansLpp;
          }

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
      } catch (_) {
        // No profile provider available.
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
    if (!_hasUserInteracted) return;
    if (_seqRunId != null) return; // Sequence mode: terminal only on pop
    final screenReturn = ScreenReturn.completed(
      route: '/pilier-3a',
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

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        title: Text(l.sim3aTitle, style: MintTextStyles.headlineMedium()),
        actions: const [],
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MintEntrance(child: _buildCoachSection()),
            const SizedBox(height: MintSpacing.xl),
            MintEntrance(delay: const Duration(milliseconds: 100), child: _buildInputSection()),
            const SizedBox(height: MintSpacing.xl),
            if (_result != null)
              SafeModeGate(
                hasDebt: hasDebt,
                lockedTitle: l.sim3aDebtLockedTitle,
                lockedMessage: l.sim3aDebtLockedMessage,
                child: _buildResultSection(),
              ),
            const SizedBox(height: MintSpacing.xl),
            MintEntrance(delay: const Duration(milliseconds: 200), child: SafeModeGate(
              hasDebt: hasDebt,
              lockedTitle: l.sim3aDebtStrategyTitle,
              lockedMessage: l.sim3aDebtStrategyMessage,
              child: _buildEducationSection(),
            )),
            const SizedBox(height: MintSpacing.xl),
            MintEntrance(delay: const Duration(milliseconds: 300), child: _buildRelatedSections()),
            const SizedBox(height: MintSpacing.xxl),
            MintEntrance(delay: const Duration(milliseconds: 400), child: _buildDisclaimer()),
            const SizedBox(height: MintSpacing.lg),
            _buildCountdown3a(),
            const SizedBox(height: MintSpacing.xl),
          ],
        ),
      )))),
    );
  }

  Widget _buildCoachSection() {
    final l = S.of(context)!;
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
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

    // Tax rate chips: common Swiss marginal rates.
    const taxRateOptions = [0.10, 0.20, 0.25, 0.30, 0.35, 0.40];

    // Return rate chips.
    const returnOptions = [1.0, 3.0, 5.0, 7.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.sim3aParamsHeader, style: MintTextStyles.labelSmall()),

        // Pre-filled indicator.
        if (_isPreFilled) ...[
          const SizedBox(height: MintSpacing.xs),
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14,
                  color: MintColors.success.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                l.sim3aProfilePreFilled,
                style: MintTextStyles.labelSmall(color: MintColors.success)
                    .copyWith(fontSize: 11),
              ),
            ],
          ),
        ],

        const SizedBox(height: MintSpacing.lg),

        // ── 1. Annual contribution: tap-to-type CHF field ──
        Text(
          _isIndepSansLpp
              ? l.sim3aAnnualContributionIndep
              : l.sim3aContributionFieldLabel,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.xs),
        TextField(
          controller: _contributionCtrl,
          keyboardType: TextInputType.number,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            suffixText: 'CHF',
            suffixStyle: MintTextStyles.bodySmall(color: MintColors.textMuted),
            hintText: _currencyFormat.format(_plafond3a),
            hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md, vertical: MintSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.primary, width: 1.5),
            ),
          ),
          onChanged: (text) {
            final parsed = double.tryParse(text.replaceAll(RegExp(r"[^0-9.]"), ''));
            if (parsed != null) {
              _hasUserInteracted = true;
              _annualContribution = parsed.clamp(0, _plafond3a);
              _calculate();
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Max: ${_currencyFormat.format(_plafond3a)}',
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
        ),

        const SizedBox(height: MintSpacing.lg),

        // ── 2. Marginal tax rate: chips ──
        Text(
          l.sim3aTaxRateChipsLabel,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
        ),
        if (_isPreFilled && _profileCanton.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            l.sim3aProfileEstimatedRate(
              (_marginalTaxRate * 100).round().toString(),
              _profileCanton,
            ),
            style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                .copyWith(fontSize: 11),
          ),
        ],
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.xs,
          children: taxRateOptions.map((rate) {
            final isSelected = (_marginalTaxRate - rate).abs() < 0.01;
            return ChoiceChip(
              label: Text('${(rate * 100).round()}\u00a0%'),
              selected: isSelected,
              onSelected: (_) {
                _hasUserInteracted = true;
                setState(() => _marginalTaxRate = rate);
                _calculate();
              },
              selectedColor: MintColors.primary.withValues(alpha: 0.15),
              backgroundColor: MintColors.surface,
              labelStyle: MintTextStyles.bodySmall(
                color: isSelected ? MintColors.primary : MintColors.textPrimary,
              ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
              side: BorderSide(
                color: isSelected ? MintColors.primary : MintColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: MintSpacing.lg),

        // ── 3. Years to retirement: read-only (computed from age) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                l.sim3aYearsAutoLabel,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            MintSurface(
              tone: MintSurfaceTone.porcelaine,
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md, vertical: MintSpacing.xs),
              radius: 12,
              child: Text(
                l.sim3aYearsReadOnly(_years),
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),

        const SizedBox(height: MintSpacing.lg),

        // ── 4. Expected return: chips ──
        Text(
          l.sim3aReturnChipsLabel,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.xs,
          children: returnOptions.map((rate) {
            final isSelected = (_annualReturn - rate).abs() < 0.01;
            return ChoiceChip(
              label: Text('${rate.toStringAsFixed(0)}\u00a0%'),
              selected: isSelected,
              onSelected: (_) {
                _hasUserInteracted = true;
                setState(() => _annualReturn = rate);
                _calculate();
              },
              selectedColor: MintColors.primary.withValues(alpha: 0.15),
              backgroundColor: MintColors.surface,
              labelStyle: MintTextStyles.bodySmall(
                color: isSelected ? MintColors.primary : MintColors.textPrimary,
              ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
              side: BorderSide(
                color: isSelected ? MintColors.primary : MintColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    final l = S.of(context)!;
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        children: [
          Text(l.sim3aAnnualTaxSaved, style: MintTextStyles.bodyMedium()),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            label: '${l.sim3aAnnualTaxSaved}: ${_currencyFormat.format(_result!['annualTaxSaved']!)}',
            child: Text(
              _currencyFormat.format(_result!['annualTaxSaved']!),
              style: MintTextStyles.displayMedium(color: MintColors.primary),
            ),
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
          MintSurface(
            tone: MintSurfaceTone.porcelaine,
            padding: const EdgeInsets.all(10),
            radius: 12,
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
