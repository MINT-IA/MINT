import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
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
//  LPP VOLONTAIRE SCREEN — Sprint S18 / Independants complet
// ────────────────────────────────────────────────────────────
//
// Voluntary LPP simulator for self-employed workers.
// Ledger facts: revenu net, age.
// Comparison: with vs without LPP volontaire (retirement gap).
// Chiffre choc: lost capitalization without voluntary LPP.
// ────────────────────────────────────────────────────────────

class LppVolontaireScreen extends StatefulWidget {
  const LppVolontaireScreen({super.key});

  @override
  State<LppVolontaireScreen> createState() => _LppVolontaireScreenState();
}

class _LppVolontaireScreenState extends State<LppVolontaireScreen> {
  static const int _ageMin = 25;
  static const int _ageMax = 65;

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
    final income = profile?.selfEmployedNetIncome;
    if (income != null && income > 0) {
      return income.toDouble();
    }
    return null;
  }

  int? _age(CoachProfileProvider? provider) {
    final profile = provider?.profile;
    final age = profile?.ageOrNull;
    if (age != null && age >= _ageMin && age <= _ageMax) {
      return age;
    }
    return null;
  }

  LppVolontaireResult? _computeResult(double? annualIncome, int? age) {
    if (annualIncome == null || age == null) return null;
    return IndependantsService.calculateLppVolontaire(
      annualIncome,
      age,
      _tauxMarginal,
    );
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
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: 20),
                MintEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: _buildLedgerFactsCard(context, s, annualIncome, age),
                ),
                if (result != null) ...[
                  const SizedBox(height: 20),
                  _buildTauxSlider(),
                ],
                const SizedBox(height: 24),
                if (result != null && age != null) ...[
                  // Contribution planning remains gated in SafeMode: ledger
                  // facts unlock understanding, but debt crisis blocks action.
                  SafeModeGate(
                    hasDebt: lookupSafeModeFlag(context),
                    child: Column(
                      children: [
                        MintEntrance(child: _buildPremierEclairage(result)),
                        const SizedBox(height: 24),
                        MintEntrance(
                            delay: const Duration(milliseconds: 100),
                            child: _buildResultCards(result)),
                        const SizedBox(height: 24),
                        MintEntrance(
                            delay: const Duration(milliseconds: 150),
                            child: _buildRetirementComparison(result)),
                        const SizedBox(height: 24),
                        MintEntrance(
                            delay: const Duration(milliseconds: 200),
                            child: _buildAgeTable(age)),
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
      title: Text(S.of(context)!.lppVolontaireTitle,
          style: MintTextStyles.headlineMedium()),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
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
              S.of(context)!.lppVolontaireHeaderInfo,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ledger facts + scenario levers ─────────────────────────

  Widget _buildLedgerFactsCard(
      BuildContext context, S s, double? annualIncome, int? age) {
    final hasMissing = annualIncome == null || age == null;
    final editRoute = annualIncome == null
        ? '/data-block/revenu?inputKey=q_self_employed_income'
        : '/data-block/revenu?inputKey=q_birth_year';

    return Semantics(
      key: const Key('lpp_volontaire_ledger_facts'),
      identifier: 'lpp_volontaire_ledger_facts',
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
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
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
              identifier: 'lpp_volontaire_income_fact',
              label: s.lppVolontaireRevenuLabel,
              value: annualIncome == null
                  ? s.dataBlockStatusMissing
                  : IndependantsService.formatChf(annualIncome),
              isMissing: annualIncome == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'lpp_volontaire_age_fact',
              label: s.lppVolontaireTonAge,
              value: age == null ? s.dataBlockStatusMissing : '$age ans',
              isMissing: age == null,
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
          Text(
            value,
            style: MintTextStyles.bodySmall(
              color: isMissing ? MintColors.warning : MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTauxSlider() {
    return _buildInputCard(
      child: MintPremiumSlider(
        label: S.of(context)!.lppVolontaireTauxMarginal,
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

  Widget _buildInputCard({required Widget child}) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  // ── Premier Éclairage ───────────────────────────────────────────

  Widget _buildPremierEclairage(LppVolontaireResult r) {
    return Semantics(
      label: S.of(context)!.semanticsLppCapitalisation(
          IndependantsService.formatChf(r.capitalisationAnnuelle)),
      child: MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            MintHeroNumber(
              value: IndependantsService.formatChf(r.capitalisationAnnuelle),
              caption: S.of(context)!.lppVolontairePremierEclairageCaption(
                  IndependantsService.formatChf(r.capitalisationAnnuelle)),
              color: MintColors.success,
            ),
          ],
        ),
      ),
    );
  }

  // ── Result Cards ───────────────────────────────────────────

  Widget _buildResultCards(LppVolontaireResult r) {
    return Semantics(
      key: const Key('lpp_volontaire_result_cards'),
      identifier: 'lpp_volontaire_result_cards',
      container: true,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  S.of(context)!.lppVolontaireSalaireCoordLabel,
                  IndependantsService.formatChf(r.salaireCoordonne),
                  Icons.account_balance_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  S.of(context)!.lppVolontaireTauxBonifLabel,
                  '${(r.tauxBonification * 100).toStringAsFixed(0)}\u00a0%',
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  S.of(context)!.lppVolontaireCotisationLabel,
                  IndependantsService.formatChf(r.cotisationAnnuelle),
                  Icons.calendar_month_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  S.of(context)!.lppVolontaireEconomieFiscaleLabel,
                  IndependantsService.formatChf(r.economieFiscale),
                  Icons.savings_outlined,
                  valueColor: MintColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            S.of(context)!.lppVolontaireTrancheAgeLabel,
            r.ageBracketLabel,
            Icons.person_outline,
            small: true,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon, {
    bool small = false,
    Color? valueColor,
    bool fullWidth = false,
  }) {
    final card = Semantics(
      label: S.of(context)!.semanticsMetricLabelValue(label, value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
                child: Icon(icon, size: 18, color: MintColors.textMuted)),
            const SizedBox(height: 8),
            Text(
              value,
              style: (small
                      ? MintTextStyles.bodyMedium(
                          color: valueColor ?? MintColors.textPrimary)
                      : MintTextStyles.headlineMedium(
                          color: valueColor ?? MintColors.textPrimary))
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ],
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: card) : card;
  }

  // ── Retirement Comparison ──────────────────────────────────

  Widget _buildRetirementComparison(LppVolontaireResult r) {
    final maxVal = r.projectionAvecLpp > r.projectionSansLpp
        ? r.projectionAvecLpp
        : r.projectionSansLpp;
    if (maxVal <= 0) return const SizedBox.shrink();

    final sansRatio = r.projectionSansLpp / maxVal;
    final avecRatio = r.projectionAvecLpp / maxVal;
    final gap = r.projectionAvecLpp - r.projectionSansLpp;

    return Semantics(
      key: const Key('lpp_volontaire_retirement_comparison'),
      identifier: 'lpp_volontaire_retirement_comparison',
      container: true,
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
            Row(
              children: [
                const Icon(Icons.bar_chart,
                    size: 16, color: MintColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.lppVolontaireProjectionTitle,
                    style:
                        MintTextStyles.labelSmall(color: MintColors.textMuted)
                            .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sans LPP bar
            _buildProjectionBar(
              label: S.of(context)!.lppVolontaireSansLpp,
              value: r.projectionSansLpp,
              ratio: sansRatio,
              color: MintColors.success,
            ),
            const SizedBox(height: 16),

            // Avec LPP bar
            _buildProjectionBar(
              label: S.of(context)!.lppVolontaireAvecLpp,
              value: r.projectionAvecLpp,
              ratio: avecRatio,
              color: MintColors.success,
            ),
            const SizedBox(height: 16),

            // Gap highlight
            Semantics(
              label: S
                  .of(context)!
                  .semanticsLppGain(IndependantsService.formatChf(gap)),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const ExcludeSemantics(
                        child: Icon(Icons.add_circle_outline,
                            size: 16, color: MintColors.success)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        S.of(context)!.lppVolontaireGapLabel(
                            IndependantsService.formatChf(gap)),
                        style:
                            MintTextStyles.bodySmall(color: MintColors.success)
                                .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionBar({
    required String label,
    required double value,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            ),
            Text(
              '${IndependantsService.formatChf(value)}/an',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 14,
            backgroundColor: MintColors.border.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ── Age Bonification Table ─────────────────────────────────

  Widget _buildAgeTable(int age) {
    final brackets = [
      ('25-34 ans', '7%', age >= 25 && age <= 34),
      ('35-44 ans', '10%', age >= 35 && age <= 44),
      ('45-54 ans', '15%', age >= 45 && age <= 54),
      ('55-65 ans', '18%', age >= 55 && age <= 65),
    ];

    return Semantics(
      key: const Key('lpp_volontaire_age_table'),
      identifier: 'lpp_volontaire_age_table',
      container: true,
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
            Row(
              children: [
                const Icon(Icons.table_chart_outlined,
                    size: 16, color: MintColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.lppVolontaireBonificationTitle,
                    style:
                        MintTextStyles.labelSmall(color: MintColors.textMuted)
                            .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...brackets.map((b) => _buildBracketRow(b.$1, b.$2, b.$3)),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketRow(String age, String taux, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? MintColors.primary.withValues(alpha: 0.06)
            : MintColors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isCurrent
            ? Border.all(color: MintColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isCurrent)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MintColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    S.of(context)!.lppVolontaireToi,
                    style: MintTextStyles.micro(color: MintColors.white)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              Text(
                age,
                style: MintTextStyles.bodyMedium(
                        color: isCurrent
                            ? MintColors.textPrimary
                            : MintColors.textSecondary)
                    .copyWith(
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w400),
              ),
            ],
          ),
          Text(
            taux,
            style: MintTextStyles.titleMedium(
                color:
                    isCurrent ? MintColors.primary : MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Education ──────────────────────────────────────────────

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.lppVolontaireBonASavoir,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                  .copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.lppVolontaireEduAffiliationTitle,
          S.of(context)!.lppVolontaireEduAffiliationBody,
        ),
        _buildEduCard(
          Icons.savings_outlined,
          S.of(context)!.lppVolontaireEduFiscalTitle,
          S.of(context)!.lppVolontaireEduFiscalBody,
        ),
        _buildEduCard(
          Icons.warning_amber_rounded,
          S.of(context)!.lppVolontaireEduImpact3aTitle,
          S.of(context)!.lppVolontaireEduImpact3aBody,
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
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary),
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
              S.of(context)!.lppVolontaireDisclaimer,
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}
