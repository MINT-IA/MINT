import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/financial_core/income_conversion_calculator.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class IjmScreen extends StatefulWidget {
  const IjmScreen({super.key});

  @override
  State<IjmScreen> createState() => _IjmScreenState();
}

class _IjmScreenState extends State<IjmScreen> {
  static const int _ageMin = 18;
  static const int _ageMax = avsAgeReferenceHomme;

  int _delaiCarence = 30;

  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  double? _annualIncome(CoachProfileProvider? provider) {
    final annualIncome = provider?.profile?.selfEmployedNetIncome;
    if (annualIncome != null && annualIncome > 0) {
      return annualIncome.toDouble();
    }
    return null;
  }

  int? _age(CoachProfileProvider? provider) {
    final age = provider?.profile?.ageOrNull;
    if (age != null && age >= _ageMin && age <= _ageMax) {
      return age;
    }
    return null;
  }

  IjmResult? _computeResult(double? annualIncome, int? age) {
    if (annualIncome == null || age == null) return null;
    // IJM uses declared independent net income; this only periodizes it.
    final monthlyIncome = IncomeConversionCalculator.monthlyGrossFromAnnualGross(annualIncome);
    return IndependantsService.calculateIjm(monthlyIncome, age, _delaiCarence);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final provider = _profileProvider(context);
    final annualIncome = _annualIncome(provider);
    final age = _age(provider);
    final result = _computeResult(annualIncome, age);

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(s.ijmTitle, style: MintTextStyles.headlineMedium()),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintEntrance(child: _buildHeader(s)),
            const SizedBox(height: MintSpacing.xl),
            MintEntrance(delay: const Duration(milliseconds: 100), child: _buildLedgerFactsCard(context, s, annualIncome, age)),
            if (result != null) ...[
              const SizedBox(height: MintSpacing.lg),
              MintEntrance(delay: const Duration(milliseconds: 200), child: _buildCarenceToggle(s)),
              const SizedBox(height: MintSpacing.lg),
              _buildPremierEclairage(s, result),
              const SizedBox(height: MintSpacing.lg),
              if (result.isHighRisk) ...[
                _buildHighRiskWarning(s),
                const SizedBox(height: MintSpacing.md + 4),
              ],
              _buildResultCards(s, result),
              const SizedBox(height: MintSpacing.lg),
              _buildCoverageTimeline(s, result),
              const SizedBox(height: MintSpacing.lg),
              _buildEducation(s),
              const SizedBox(height: MintSpacing.lg),
            ],
            MintEntrance(delay: const Duration(milliseconds: 400), child: _buildDisclaimer(s)),
            const SizedBox(height: 100),
          ],
        ),
      ))),
    );
  }

  Widget _buildHeader(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(child: Text(s.ijmHeaderInfo, style: MintTextStyles.bodySmall(color: MintColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildLedgerFactsCard(BuildContext context, S s, double? annualIncome, int? age) {
    final hasMissing = annualIncome == null || age == null;
    final editRoute = annualIncome == null
        ? '/data-block/revenu?inputKey=q_self_employed_income'
        : '/data-block/revenu?inputKey=q_birth_year';

    return Semantics(
      key: const Key('ijm_ledger_facts'),
      identifier: 'ijm_ledger_facts',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasMissing ? Icons.manage_search_outlined : Icons.check_circle_outline,
                  color: hasMissing ? MintColors.warning : MintColors.success,
                  size: 20,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    hasMissing ? s.dataQualityMissingSection : s.dataQualityKnownSection,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push(editRoute),
                  icon: Icon(hasMissing ? Icons.add_circle_outline : Icons.edit_outlined, size: 18),
                  label: Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildFactRow(
              identifier: 'ijm_income_fact',
              label: s.independantRevenueTitle,
              value: annualIncome == null
                  ? s.dataBlockStatusMissing
                  : IndependantsService.formatChf(annualIncome),
              isMissing: annualIncome == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'ijm_age_fact',
              label: s.ijmTonAge,
              value: age == null ? s.dataBlockStatusMissing : '$age ans',
              isMissing: age == null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow({required String identifier, required String label, required String value, required bool isMissing}) {
    return Semantics(
      identifier: identifier,
      label: '$label, $value',
      container: true,
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.help_outline : Icons.check_circle_outline,
            color: isMissing ? MintColors.warning : MintColors.success,
            size: 16,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(child: Text(label, style: MintTextStyles.bodySmall(color: MintColors.textSecondary))),
          Text(
            value,
            style: MintTextStyles.bodySmall(color: isMissing ? MintColors.warning : MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildCarenceToggle(S s) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.ijmDelaiCarence, style: MintTextStyles.titleMedium()),
          const SizedBox(height: MintSpacing.xs),
          Text(s.ijmDelaiCarenceDesc, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              _buildCarenceChip(s, 30),
              const SizedBox(width: MintSpacing.sm),
              _buildCarenceChip(s, 60),
              const SizedBox(width: MintSpacing.sm),
              _buildCarenceChip(s, 90),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarenceChip(S s, int jours) {
    final isSelected = _delaiCarence == jours;
    return Expanded(
      child: Semantics(
        label: s.ijmJoursCarenceLabel(jours),
        button: true,
        selected: isSelected,
        child: GestureDetector(
          onTap: () => setState(() => _delaiCarence = jours),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? MintColors.primary : MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? MintColors.primary : MintColors.border, width: isSelected ? 2 : 1),
            ),
            child: Column(
              children: [
                Text('$jours j', style: MintTextStyles.titleLarge(color: isSelected ? MintColors.white : MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: MintSpacing.xs / 2),
                Text(s.ijmJours, style: MintTextStyles.labelSmall(color: isSelected ? MintColors.white.withValues(alpha: 0.8) : MintColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremierEclairage(S s, IjmResult r) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(color: MintColors.error, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(IndependantsService.formatChf(r.perteCarence), style: MintTextStyles.displayMedium(color: MintColors.white)),
          const SizedBox(height: MintSpacing.sm),
          Text(s.ijmPremierEclairageCaption(IndependantsService.formatChf(r.perteCarence), r.delaiCarence), style: MintTextStyles.bodyMedium(color: MintColors.white.withValues(alpha: 0.9)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHighRiskWarning(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: MintColors.warning, size: 22),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.ijmHighRiskTitle, style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: MintSpacing.xs),
                Text(s.ijmHighRiskBody, style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCards(S s, IjmResult r) {
    return Semantics(
      key: const Key('ijm_result_cards'),
      identifier: 'ijm_result_cards',
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _buildResultCard(s.ijmPrimeMois, IndependantsService.formatChf(r.primeMensuelle), Icons.payment_outlined)),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(child: _buildResultCard(s.ijmPrimeAn, IndependantsService.formatChf(r.primeAnnuelle), Icons.calendar_month_outlined)),
          ]),
          const SizedBox(height: MintSpacing.sm + 4),
          Row(children: [
            Expanded(child: _buildResultCard(s.ijmIndemniteJour, IndependantsService.formatChf(r.indemniteJournaliere), Icons.today_outlined)),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(child: _buildResultCard(s.ijmTrancheAge, r.ageBandLabel, Icons.person_outline, small: true)),
          ]),
        ],
      ),
    );
  }

  Widget _buildResultCard(String label, String value, IconData icon, {bool small = false}) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MintColors.textMuted),
          const SizedBox(height: MintSpacing.sm),
          Text(value, style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: small ? 14 : 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: MintSpacing.xs),
          Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCoverageTimeline(S s, IjmResult r) {
    const totalDays = 180;
    final carenceRatio = r.delaiCarence / totalDays;
    return Semantics(
      key: const Key('ijm_coverage_timeline'),
      identifier: 'ijm_coverage_timeline',
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.ijmTimelineTitle, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: MintSpacing.md + 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(children: [
                Expanded(
                  flex: (carenceRatio * 100).toInt().clamp(1, 99),
                  child: Container(height: 32, color: MintColors.error.withValues(alpha: 0.2), alignment: Alignment.center, child: Text('${r.delaiCarence}j', style: MintTextStyles.labelSmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w600))),
                ),
                Expanded(
                  flex: (100 - carenceRatio * 100).toInt().clamp(1, 99),
                  child: Container(height: 32, color: MintColors.success.withValues(alpha: 0.2), alignment: Alignment.center, child: Text(s.ijmTimelineCouvert, style: MintTextStyles.labelSmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600))),
                ),
              ]),
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            Row(children: [
              _buildLegendDot(MintColors.error, s.ijmTimelineNoCoverage),
              const SizedBox(width: MintSpacing.md),
              _buildLegendDot(MintColors.success, s.ijmTimelineCoverageIjm),
            ]),
            const SizedBox(height: MintSpacing.md),
            MintSurface(
              tone: MintSurfaceTone.porcelaine,
              padding: const EdgeInsets.all(MintSpacing.sm + 4),
              radius: 12,
              child: Text(s.ijmTimelineSummary(r.delaiCarence, IndependantsService.formatChf(r.indemniteJournaliere)), style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color.withValues(alpha: 0.3), shape: BoxShape.circle, border: Border.all(color: color, width: 1.5))),
      const SizedBox(width: MintSpacing.xs + 2),
      Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
    ]);
  }

  Widget _buildEducation(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.ijmStrategies, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildEduCard(Icons.savings_outlined, s.ijmEduFondsTitle, s.ijmEduFondsBody),
        _buildEduCard(Icons.compare_arrows, s.ijmEduComparerTitle, s.ijmEduComparerBody),
        _buildEduCard(Icons.shield_outlined, s.ijmEduLamalTitle, s.ijmEduLamalBody),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintSurface(
            padding: const EdgeInsets.all(MintSpacing.sm),
            radius: 10,
            child: Icon(icon, size: 18, color: MintColors.primary)),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: MintSpacing.xs),
                Text(body, style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(s.ijmDisclaimer, style: MintTextStyles.micro());
  }
}
