import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/independent_ledger_facts.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class AvsCotisationsScreen extends StatefulWidget {
  const AvsCotisationsScreen({super.key});

  @override
  State<AvsCotisationsScreen> createState() => _AvsCotisationsScreenState();
}

class _AvsCotisationsScreenState extends State<AvsCotisationsScreen> {
  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  double? _annualIncome(CoachProfileProvider? provider) {
    return IndependentLedgerFacts.selfEmployedAnnualIncome(provider?.profile);
  }

  AvsCotisationResult? _computeResult(double? annualIncome) {
    if (annualIncome == null) return null;
    return IndependantsService.calculateAvsCotisations(annualIncome);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final provider = _profileProvider(context);
    final annualIncome = _annualIncome(provider);
    final result = _computeResult(annualIncome);

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title:
            Text(s.avsCotisationsTitle, style: MintTextStyles.headlineMedium()),
      ),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.lg, vertical: MintSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MintEntrance(child: _buildHeader(s)),
                    const SizedBox(height: MintSpacing.xl),
                    MintEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: _buildLedgerFactsCard(context, s, annualIncome)),
                    if (result != null) ...[
                      const SizedBox(height: MintSpacing.lg),
                      _buildPremierEclairage(s, result),
                      const SizedBox(height: MintSpacing.lg),
                      _buildResultCards(s, result),
                      const SizedBox(height: MintSpacing.lg),
                      _buildComparisonChart(s, result),
                      const SizedBox(height: MintSpacing.lg),
                      _buildBaremeGauge(s, result),
                      const SizedBox(height: MintSpacing.lg),
                      _buildEducation(s),
                      const SizedBox(height: MintSpacing.lg),
                    ],
                    MintEntrance(
                        delay: const Duration(milliseconds: 200),
                        child: _buildDisclaimer(s)),
                    const SizedBox(height: MintSpacing.xxl),
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
          Expanded(
            child: Text(s.avsCotisationsHeaderInfo,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerFactsCard(
      BuildContext context, S s, double? annualIncome) {
    final hasMissing = annualIncome == null;
    return Semantics(
      key: const Key('avs_ledger_facts'),
      identifier: 'avs_ledger_facts',
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
                  hasMissing
                      ? Icons.manage_search_outlined
                      : Icons.check_circle_outline,
                  color: hasMissing ? MintColors.warning : MintColors.success,
                  size: 20,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    hasMissing
                        ? s.dataQualityMissingSection
                        : s.dataQualityKnownSection,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push(
                      '/data-block/revenu?inputKey=q_self_employed_income'),
                  icon: Icon(
                      hasMissing
                          ? Icons.add_circle_outline
                          : Icons.edit_outlined,
                      size: 18),
                  label: Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            Semantics(
              key: const Key('avs_income_fact'),
              identifier: 'avs_income_fact',
              label:
                  '${s.independantRevenueTitle}, ${annualIncome == null ? s.dataBlockStatusMissing : IndependantsService.formatChf(annualIncome)}',
              container: true,
              child: Row(
                children: [
                  Icon(
                    hasMissing
                        ? Icons.help_outline
                        : Icons.check_circle_outline,
                    color: hasMissing ? MintColors.warning : MintColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                      child: Text(s.independantRevenueTitle,
                          style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary))),
                  Text(
                    annualIncome == null
                        ? s.dataBlockStatusMissing
                        : IndependantsService.formatChf(annualIncome),
                    style: MintTextStyles.bodySmall(
                            color: hasMissing
                                ? MintColors.warning
                                : MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremierEclairage(S s, AvsCotisationResult r) {
    if (r.differenceAnnuelle <= 0) return const SizedBox.shrink();
    return Semantics(
      label: S.of(context)!.semanticsAvsDifference(
          IndependantsService.formatChf(r.differenceAnnuelle)),
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              IndependantsService.formatChf(r.differenceAnnuelle),
              style: MintTextStyles.displayMedium(color: MintColors.white),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              s.avsCotisationsPremierEclairageCaption(
                  IndependantsService.formatChf(r.differenceAnnuelle)),
              style: MintTextStyles.bodyMedium(
                  color: MintColors.white.withValues(alpha: 0.9)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCards(S s, AvsCotisationResult r) {
    return Semantics(
      key: const Key('avs_result_cards'),
      identifier: 'avs_result_cards',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildMetricCard(
                      s.avsCotisationsTauxEffectif,
                      '${r.tauxEffectif.toStringAsFixed(2)}\u00a0%',
                      Icons.percent)),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                  child: _buildMetricCard(
                      s.avsCotisationsCotisationAn,
                      IndependantsService.formatChf(r.cotisationAnnuelle),
                      Icons.calendar_month_outlined)),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Row(
            children: [
              Expanded(
                  child: _buildMetricCard(
                      s.avsCotisationsCotisationMois,
                      IndependantsService.formatChf(r.cotisationMensuelle),
                      Icons.today_outlined)),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                  child: _buildMetricCard(s.avsCotisationsTranche,
                      r.tranchLabel, Icons.format_list_numbered,
                      small: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon,
      {bool small = false}) {
    return Semantics(
      label: S.of(context)!.semanticsMetricLabelValue(label, value),
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
                child: Icon(icon, size: 18, color: MintColors.textMuted)),
            const SizedBox(height: MintSpacing.sm),
            Text(value,
                style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                    .copyWith(
                        fontSize: small ? 13 : 18,
                        fontWeight: FontWeight.w700)),
            const SizedBox(height: MintSpacing.xs),
            Text(label,
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonChart(S s, AvsCotisationResult r) {
    final maxVal = r.cotisationAnnuelle > r.cotisationSalarie
        ? r.cotisationAnnuelle
        : r.cotisationSalarie;
    if (maxVal <= 0) return const SizedBox.shrink();
    final indepRatio = r.cotisationAnnuelle / maxVal;
    final salarieRatio = r.cotisationSalarie / maxVal;
    return Semantics(
      key: const Key('avs_comparison_chart'),
      identifier: 'avs_comparison_chart',
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.avsCotisationsComparaisonTitle,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted)
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: MintSpacing.md + 4),
            _buildComparisonBar(
                label: s.avsCotisationsIndependant,
                value: r.cotisationAnnuelle,
                ratio: indepRatio,
                color: MintColors.error),
            const SizedBox(height: MintSpacing.md),
            _buildComparisonBar(
                label: s.avsCotisationsSalarie,
                value: r.cotisationSalarie,
                ratio: salarieRatio,
                color: MintColors.success),
            const SizedBox(height: MintSpacing.md),
            Container(
              padding: const EdgeInsets.all(MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_upward,
                      size: 16, color: MintColors.error),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      s.avsCotisationsSurcout(
                          IndependantsService.formatChf(r.differenceAnnuelle)),
                      style: MintTextStyles.bodySmall(color: MintColors.error)
                          .copyWith(fontWeight: FontWeight.w600),
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

  Widget _buildComparisonBar(
      {required String label,
      required double value,
      required double ratio,
      required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            Text(IndependantsService.formatChf(value),
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: MintSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: MintColors.border.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildBaremeGauge(S s, AvsCotisationResult r) {
    final position =
        AvsCalculator.selfEmployedCotisationGaugePosition(r.revenuNet);
    return Semantics(
      key: const Key('avs_bareme_gauge'),
      identifier: 'avs_bareme_gauge',
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.avsCotisationsBaremeTitle,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted)
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: MintSpacing.md + 4),
            Stack(
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [
                      MintColors.success.withValues(alpha: 0.5),
                      MintColors.warning.withValues(alpha: 0.7),
                      MintColors.error.withValues(alpha: 0.7),
                    ]),
                  ),
                ),
                Positioned(
                  left: (MediaQuery.of(context).size.width - 88) *
                      position.clamp(0.02, 0.95),
                  top: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: MintColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: MintColors.primary, width: 3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5.37\u00a0%', style: MintTextStyles.labelSmall()),
                Text('10.6\u00a0%', style: MintTextStyles.labelSmall()),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            Semantics(
              label: S
                  .of(context)!
                  .semanticsAvsTauxEffectif(r.tauxEffectif.toStringAsFixed(2)),
              child: Text(
                s.avsCotisationsTauxEffectifLabel(
                    r.tauxEffectif.toStringAsFixed(2)),
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducation(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.avsCotisationsBonASavoir,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted)
                .copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildEduCard(Icons.trending_down, s.avsCotisationsEduDegressifTitle,
            s.avsCotisationsEduDegressifBody),
        _buildEduCard(
            Icons.people_outline,
            s.avsCotisationsEduDoubleChargeTitle,
            s.avsCotisationsEduDoubleChargeBody),
        _buildEduCard(Icons.calendar_today_outlined,
            s.avsCotisationsEduMinTitle, s.avsCotisationsEduMinBody),
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
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: MintSpacing.xs),
                  Text(body,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(s.avsCotisationsDisclaimer, style: MintTextStyles.micro());
  }
}
