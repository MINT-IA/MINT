import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:provider/provider.dart';

// ────────────────────────────────────────────────────────────
//  PILLAR 3A INDEPENDANT SCREEN — Sprint S18
// ────────────────────────────────────────────────────────────
//
// Ledger facts: revenu net indépendant, affiliation LPP.
// Scenario lever: taux marginal. Comparison "petit 3a" vs "grand 3a".
// Chiffre choc: fiscal advantage over salarié.
// ────────────────────────────────────────────────────────────

class Pillar3aIndepScreen extends StatefulWidget {
  const Pillar3aIndepScreen({super.key});

  @override
  State<Pillar3aIndepScreen> createState() => _Pillar3aIndepScreenState();
}

class _Pillar3aIndepScreenState extends State<Pillar3aIndepScreen> {
  double _tauxMarginal = 0.30;

  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  double? _annualIncome(CoachProfileProvider? provider) {
    final profile = provider?.profile;
    if (profile == null) return null;
    if (!profile.userProvidedFields.contains('selfEmployedNetIncome')) {
      return null;
    }
    final income = profile.selfEmployedNetIncome;
    if (income != null && income > 0) {
      return income.toDouble();
    }
    return null;
  }

  bool? _hasPensionFund(CoachProfileProvider? provider) {
    final profile = provider?.profile;
    if (profile == null) return null;
    if (profile.userProvidedFields.contains('hasVoluntaryLpp')) {
      return profile.prevoyance.hasVoluntaryLpp;
    }
    if (profile.userProvidedFields.contains('hasPensionFund') &&
        profile.employmentStatus == 'independant') {
      return profile.prevoyance.hasPensionFund;
    }
    return null;
  }

  double? _liquidSavings(CoachProfileProvider? provider) {
    final profile = provider?.profile;
    if (profile == null) return null;
    if (!profile.userProvidedFields.contains('liquidSavings')) return null;
    return profile.patrimoine.epargneLiquide;
  }

  Pillar3aIndepResult? _computeResult(
    double? annualIncome,
    bool? hasLpp,
    double? liquidSavings,
  ) {
    if (annualIncome == null || hasLpp == null || liquidSavings == null) {
      return null;
    }
    return IndependantsService.calculate3aIndependant(
      annualIncome,
      hasLpp,
      _tauxMarginal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final provider = _profileProvider(context);
    final annualIncome = _annualIncome(provider);
    final hasLpp = _hasPensionFund(provider);
    final liquidSavings = _liquidSavings(provider);
    final result = _computeResult(annualIncome, hasLpp, liquidSavings);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                MintEntrance(child: _buildHeader(hasLpp)),
                const SizedBox(height: 20),
                MintEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: _buildLedgerFactsCard(
                    context,
                    s,
                    annualIncome,
                    hasLpp,
                    liquidSavings,
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 20),
                  _buildTauxSlider(),
                ],
                const SizedBox(height: 24),
                if (result != null && hasLpp != null) ...[
                  // Plafond/strategy section — gated in SafeMode.
                  SafeModeGate(
                    hasDebt: lookupSafeModeFlag(context),
                    child: Column(
                      children: [
                        MintEntrance(child: _buildPremierEclairage(result)),
                        const SizedBox(height: 24),
                        MintEntrance(
                          delay: const Duration(milliseconds: 100),
                          child: _buildResultSection(result),
                        ),
                        const SizedBox(height: 24),
                        MintEntrance(
                          delay: const Duration(milliseconds: 150),
                          child: _buildComparisonBars(result, hasLpp),
                        ),
                        const SizedBox(height: 24),
                        _buildEducation(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
                _buildDisclaimer(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      foregroundColor: MintColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      title: Text(
        S.of(context)!.pillar3aIndepTitle,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(bool? hasLpp) {
    final s = S.of(context)!;
    final body = hasLpp == false
        ? s.pillar3aIndepHeaderInfo
        : s.pillar3aIndepEduConditionBody;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              body,
              key: const Key('pillar3a_indep_header_info'),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ledger facts + scenario levers ─────────────────────────

  Widget _buildLedgerFactsCard(
    BuildContext context,
    S s,
    double? annualIncome,
    bool? hasLpp,
    double? liquidSavings,
  ) {
    final hasMissing =
        annualIncome == null || hasLpp == null || liquidSavings == null;
    final editRoute = annualIncome == null
        ? '/data-block/revenu?inputKey=q_self_employed_income'
        : hasLpp == null
            ? '/data-block/revenu?inputKey=q_has_pension_fund'
            : liquidSavings == null
                ? '/data-block/patrimoine?inputKey=q_cash_total'
                : '/data-block/revenu?inputKey=q_self_employed_income';

    return Semantics(
      key: const Key('pillar3a_indep_ledger_facts'),
      identifier: 'pillar3a_indep_ledger_facts',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
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
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push(editRoute),
                  icon: Icon(
                    hasMissing ? Icons.add_circle_outline : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildFactRow(
              identifier: 'pillar3a_indep_income_fact',
              label: s.pillar3aIndepRevenuLabel,
              value: annualIncome == null
                  ? s.dataBlockStatusMissing
                  : IndependantsService.formatChf(annualIncome),
              isMissing: annualIncome == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'pillar3a_indep_lpp_fact',
              label: s.pillar3aIndepLppToggle,
              value: hasLpp == null
                  ? s.dataBlockStatusMissing
                  : hasLpp
                      ? s.pillar3aIndepPlafondPetit
                      : s.pillar3aIndepPlafondGrand,
              isMissing: hasLpp == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'pillar3a_indep_liquidity_fact',
              label: s.financialSummaryEpargneLiquide,
              value: liquidSavings == null
                  ? s.dataBlockStatusMissing
                  : IndependantsService.formatChf(liquidSavings),
              isMissing: liquidSavings == null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow({
    required String identifier,
    required String label,
    required String value,
    required bool isMissing,
  }) {
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
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: MintTextStyles.bodySmall(
                color: isMissing ? MintColors.warning : MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Taux Marginal Slider ───────────────────────────────────

  Widget _buildTauxSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.border.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: MintPremiumSlider(
        label: S.of(context)!.pillar3aIndepTauxLabel,
        value: _tauxMarginal * 100,
        min: 10,
        max: 45,
        divisions: 35,
        formatValue: (v) => '${v.toStringAsFixed(0)}\u00a0%',
        onChanged: (v) {
          setState(() {
            _tauxMarginal = v / 100;
          });
        },
      ),
    );
  }

  // ── Premier Éclairage ───────────────────────────────────────────

  Widget _buildPremierEclairage(Pillar3aIndepResult r) {
    if (r.avantageSurSalarie <= 0) {
      return Semantics(
        label: S.of(context)!.semantics3aEconomieFiscale(
              IndependantsService.formatChf(r.economieFiscale),
            ),
        child: MintSurface(
          tone: MintSurfaceTone.porcelaine,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              MintHeroNumber(
                value: IndependantsService.formatChf(r.economieFiscale),
                caption: S.of(context)!.pillar3aIndepPremierEclairageCaption,
                color: MintColors.primary,
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: S.of(context)!.semantics3aAvantageSalarie(
            IndependantsService.formatChf(r.avantageSurSalarie),
          ),
      child: MintSurface(
        tone: MintSurfaceTone.sauge,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            MintHeroNumber(
              value: IndependantsService.formatChf(r.avantageSurSalarie),
              caption:
                  S.of(context)!.pillar3aIndepPremierEclairageAvantageSalarie(
                        IndependantsService.formatChf(r.avantageSurSalarie),
                      ),
              color: MintColors.success,
            ),
          ],
        ),
      ),
    );
  }

  // ── Result Section ─────────────────────────────────────────

  Widget _buildResultSection(Pillar3aIndepResult r) {
    return Semantics(
      key: const Key('pillar3a_indep_result_section'),
      identifier: 'pillar3a_indep_result_container',
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          children: [
            _buildResultRow(
              S.of(context)!.pillar3aIndepPlafondApplicableLabel,
              IndependantsService.formatChf(r.plafond),
              identifier: 'pillar3a_indep_plafond_row',
            ),
            const SizedBox(height: 12),
            _buildResultRow(
              S.of(context)!.pillar3aIndepEconomieFiscaleAnLabel,
              IndependantsService.formatChf(r.economieFiscale),
            ),
            const Divider(height: 24),
            _buildResultRow(
              S.of(context)!.pillar3aIndepPlafondSalarieLabel,
              IndependantsService.formatChf(r.plafondSalarie),
              color: MintColors.textMuted,
            ),
            const SizedBox(height: 8),
            _buildResultRow(
              S.of(context)!.pillar3aIndepEconomieSalarieLabel,
              IndependantsService.formatChf(r.economieSalarie),
              color: MintColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value, {
    Color? color,
    String? identifier,
  }) {
    return Semantics(
      identifier: identifier,
      label: S.of(context)!.semanticsMetricLabelValue(label, value),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodyMedium(
                color: color ?? MintColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Text(
            value,
            style: MintTextStyles.bodyMedium(
              color: color ?? MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Comparison Stacked Bars ────────────────────────────────

  Widget _buildComparisonBars(Pillar3aIndepResult r, bool hasLpp) {
    final petit = r.plafondSalarie;
    final grand = IndependantsService.plafond3aGrand;
    final plafondIndep = r.plafond;
    final multiplier = (plafondIndep / petit).round();

    final projection = IndependantsService.project3aIndependant20Years(r);
    final hasProjectionUpside = !hasLpp && projection.difference > 0;

    return Semantics(
      key: const Key('pillar3a_indep_comparison_bars'),
      identifier: 'pillar3a_indep_comparison_container',
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header with ×5 badge (P6-E / S42) ──
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    identifier: 'pillar3a_indep_comparison_bars',
                    child: Text(
                      S.of(context)!.pillar3aIndepPlafondsCompares,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMuted,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (hasProjectionUpside && multiplier > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      S.of(context)!.pillar3aIndepSuperPouvoir(multiplier),
                      style: MintTextStyles.labelSmall(
                        color: MintColors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Salarie bar
            _buildPlafondBar(
              label: S.of(context)!.pillar3aIndepSalarie,
              value: petit,
              maxValue: grand,
              color: MintColors.info,
            ),
            const SizedBox(height: 16),

            // Independant bar
            _buildPlafondBar(
              label: S.of(context)!.pillar3aIndepIndependantToi,
              value: plafondIndep,
              maxValue: grand,
              color: MintColors.success,
              highlight: true,
            ),
            const SizedBox(height: 16),

            // Max bar
            _buildPlafondBar(
              label: S.of(context)!.pillar3aIndepGrand3aMax,
              value: grand,
              maxValue: grand,
              color: MintColors.textMuted.withValues(alpha: 0.3),
            ),

            // ── 20-year projection (P6-E chiffre-choc) ──
            if (hasProjectionUpside) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: MintColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      S.of(context)!.pillar3aIndepEn20ans,
                      style: MintTextStyles.micro(color: MintColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildProjectionColumn(
                            S.of(context)!.pillar3aIndepSalarie,
                            projection.projectionSalarie,
                            MintColors.info,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.sm,
                          ),
                          child: Text(
                            S.of(context)!.pillar3aIndepVs,
                            style: MintTextStyles.bodyMedium(
                              color: MintColors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _buildProjectionColumn(
                            S.of(context)!.pillar3aIndepToi,
                            projection.projectionIndependant,
                            MintColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      S.of(context)!.pillar3aIndepDifference(
                            IndependantsService.formatChf(
                              projection.difference,
                            ),
                          ),
                      style: MintTextStyles.bodySmall(
                        color: MintColors.success,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionColumn(String label, double amount, Color color) {
    final millions = amount >= 1000000;
    final display = millions
        ? '${(amount / 1000000).toStringAsFixed(2)}M'
        : '${(amount / 1000).toStringAsFixed(0)}k';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'CHF\u00a0$display',
            textAlign: TextAlign.center,
            style: MintTextStyles.headlineMedium(
              color: color,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: MintTextStyles.micro(color: MintColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildPlafondBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    bool highlight = false,
  }) {
    final ratio = (value / maxValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: MintTextStyles.bodySmall(
                  color: highlight
                      ? MintColors.textPrimary
                      : MintColors.textSecondary,
                ).copyWith(
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            Text(
              IndependantsService.formatChf(value),
              style: MintTextStyles.bodySmall(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: highlight ? 14 : 10,
            backgroundColor: MintColors.border.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ── Education ──────────────────────────────────────────────

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 16,
              color: MintColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.pillar3aIndepBonASavoir,
              style: MintTextStyles.labelSmall(
                color: MintColors.textMuted,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEduCard(
          Icons.layers_outlined,
          S.of(context)!.pillar3aIndepEduComptesTitle,
          S.of(context)!.pillar3aIndepEduComptesBody,
        ),
        _buildEduCard(
          Icons.warning_amber_rounded,
          S.of(context)!.pillar3aIndepEduConditionTitle,
          S.of(context)!.pillar3aIndepEduConditionBody,
        ),
        _buildEduCard(
          Icons.trending_up,
          S.of(context)!.pillar3aIndepEduInvestirTitle,
          S.of(context)!.pillar3aIndepEduInvestirBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
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

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.pillar3aIndepDisclaimer,
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}
