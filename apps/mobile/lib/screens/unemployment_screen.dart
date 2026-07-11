import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/avs_reference_age.dart';
import 'package:mint_mobile/services/financial_core/unemployment_budget_estimator.dart';
import 'package:mint_mobile/services/financial_core/unemployment_financial_facts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/unemployment_service.dart';
import 'package:mint_mobile/widgets/educational/unemployment_timeline_widget.dart';
import 'package:mint_mobile/widgets/coach/unemployment_counter_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:provider/provider.dart';

// ────────────────────────────────────────────────────────────
//  UNEMPLOYMENT SCREEN — Sprint S19 / Chomage (LACI)
// ────────────────────────────────────────────────────────────
//
// Interactive LACI benefits calculator.
// Inputs: gain assure mensuel, age, months of contribution,
//         children toggle, disability toggle.
// Outputs: taux, indemnite, duration, timeline, checklist.
// ────────────────────────────────────────────────────────────

class UnemploymentScreen extends StatefulWidget {
  const UnemploymentScreen({super.key});

  @override
  State<UnemploymentScreen> createState() => _UnemploymentScreenState();
}

class _UnemploymentScreenState extends State<UnemploymentScreen> {
  bool? _hasChildrenOverride;
  bool _hasDisability = false;

  // Checklist tracking
  final Set<int> _checkedItems = {};

  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  double? _monthlyInsuredEarnings(CoachProfile? profile) {
    if (profile == null ||
        !profile.userProvidedFields.contains('grossSalaryAnnual')) {
      return null;
    }
    return UnemploymentFinancialFacts.monthlyInsuredEarningsFromAnnual(
      profile.revenuBrutAnnuel,
    );
  }

  int? _ledgerAge(CoachProfile? profile) {
    if (profile == null || !profile.userProvidedFields.contains('age')) {
      return null;
    }
    final age = profile.ageOrNull;
    if (age == null || age < 18 || age > 120) return null;
    return age;
  }

  int? _contributionMonths(CoachProfile? profile) {
    if (profile == null ||
        !profile.userProvidedFields
            .contains('unemploymentContributionMonths')) {
      return null;
    }
    final months = profile.unemploymentContributionMonths;
    if (months == null || months < 0 || months > 24) return null;
    return months;
  }

  bool _hasReachedAvsReferenceAge(CoachProfile? profile) {
    if (profile == null) return false;
    return AvsReferenceAge.hasReachedReferenceAge(
          dateOfBirth: profile.dateOfBirth,
          birthYear: profile.birthYear,
          gender: profile.gender,
        ) ??
        (profile.ageOrNull ?? 0) >= 65;
  }

  bool _isWithinFourYearsOfAvsReferenceAge(CoachProfile? profile) {
    if (profile == null) return false;
    return AvsReferenceAge.isWithinFourYearsBeforeReferenceAge(
          dateOfBirth: profile.dateOfBirth,
          birthYear: profile.birthYear,
          gender: profile.gender,
        ) ??
        false;
  }

  bool _hasChildren(CoachProfile? profile) {
    if (_hasChildrenOverride != null) return _hasChildrenOverride!;
    if (profile == null || !profile.userProvidedFields.contains('children')) {
      return false;
    }
    return profile.nombreEnfants > 0;
  }

  UnemploymentResult? _computeResult({
    required CoachProfile? profile,
    required double? monthlyInsuredEarnings,
    required int? age,
    required int? contributionMonths,
    required bool hasChildren,
  }) {
    if (monthlyInsuredEarnings == null ||
        age == null ||
        contributionMonths == null) {
      return null;
    }
    return UnemploymentService.calculateBenefits(
      gainAssureMensuel: monthlyInsuredEarnings,
      age: age,
      moisCotisation: contributionMonths,
      hasChildren: hasChildren,
      hasDisability: _hasDisability,
      hasReachedAvsReferenceAge: _hasReachedAvsReferenceAge(profile),
      isWithinFourYearsOfAvsReferenceAge:
          _isWithinFourYearsOfAvsReferenceAge(profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profileProvider(context)?.profile;
    final monthlyInsuredEarnings = _monthlyInsuredEarnings(profile);
    final age = _ledgerAge(profile);
    final contributionMonths = _contributionMonths(profile);
    final hasChildren = _hasChildren(profile);
    final hasRequiredFacts = monthlyInsuredEarnings != null &&
        age != null &&
        contributionMonths != null;
    final result = _computeResult(
      profile: profile,
      monthlyInsuredEarnings: monthlyInsuredEarnings,
      age: age,
      contributionMonths: contributionMonths,
      hasChildren: hasChildren,
    );

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: MintColors.porcelaine,
        foregroundColor: MintColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safePop(context),
        ),
        title: Text(
          S.of(context)!.unemploymentTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg,
          MintSpacing.md,
          MintSpacing.lg,
          MintSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Narrative intro
            MintNarrativeCard(
              headline: S.of(context)!.narrativeUnemploymentHeadline,
              body: S.of(context)!.narrativeUnemploymentBody,
              tone: MintSurfaceTone.bleu,
              badge: S.of(context)!.narrativeUnemploymentBadge,
            ),
            const SizedBox(height: MintSpacing.xl),

            // Hero: chute de revenu (shown when eligible)
            if (result != null && result.eligible) ...[
              _buildPremierEclairage(result),
              const SizedBox(height: MintSpacing.xl),
            ] else if (result != null && !result.eligible) ...[
              _buildNotEligible(result),
              const SizedBox(height: MintSpacing.xl),
            ] else ...[
              _buildHeader(),
              const SizedBox(height: MintSpacing.xl),
            ],
            _buildLedgerFactsCard(
              context,
              S.of(context)!,
              monthlyInsuredEarnings,
              age,
              contributionMonths,
            ),
            if (hasRequiredFacts) ...[
              const SizedBox(height: MintSpacing.md),
              _buildToggles(hasChildren),
              const SizedBox(height: MintSpacing.xl),
            ],
            if (result != null && result.eligible) ...[
              _buildTauxCard(result),
              const SizedBox(height: MintSpacing.xl),
              _buildResultCards(result),
              const SizedBox(height: MintSpacing.xl),
              _buildDurationCard(
                result,
                age!,
                contributionMonths!,
                hasChildren,
                _hasDisability,
              ),
              const SizedBox(height: MintSpacing.xl),
              UnemploymentCounterWidget(
                age: age,
                monthlyBenefit: result.indemniteMensuelle,
                maxDays: result.nombreIndemnites,
              ),
              const SizedBox(height: MintSpacing.xl),
              _buildTroisVagues(),
              const SizedBox(height: MintSpacing.xl),
            ],
            if (result != null) ...[
              UnemploymentTimelineWidget(items: result.timeline),
              const SizedBox(height: MintSpacing.xl),
              _buildChecklist(),
              const SizedBox(height: MintSpacing.xl),
              _buildEducation(),
              const SizedBox(height: MintSpacing.xl),
              if (monthlyInsuredEarnings != null)
                _buildMintCrashTestSection(
                  profile,
                  result,
                ),
              const SizedBox(height: MintSpacing.xl),
            ],
            _buildDisclaimer(),
            const SizedBox(height: MintSpacing.xxl + MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Semantics(
      header: true,
      child: MintSurface(
        tone: MintSurfaceTone.bleu,
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: MintColors.info, size: 20),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Text(
                S.of(context)!.unemploymentHeaderDesc,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ).copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Inputs ────────────────────────────────────────────────

  Widget _buildLedgerFactsCard(
    BuildContext context,
    S l10n,
    double? monthlyInsuredEarnings,
    int? age,
    int? contributionMonths,
  ) {
    final hasMissing = monthlyInsuredEarnings == null ||
        age == null ||
        contributionMonths == null;
    final editRoute = monthlyInsuredEarnings == null
        ? '/data-block/revenu?inputKey=q_gross_salary_annual'
        : age == null
            ? '/data-block/revenu?inputKey=q_birth_year'
            : contributionMonths == null
                ? '/data-block/revenu?inputKey=q_unemployment_contribution_months'
                : '/data-block/revenu?inputKey=q_gross_salary_annual';

    return Semantics(
      key: const Key('unemployment_ledger_facts'),
      identifier: 'unemployment_ledger_facts',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
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
                        ? l10n.dataQualityMissingSection
                        : l10n.dataQualityKnownSection,
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
                  label: Text(
                    hasMissing ? l10n.dataQualityEnrich : l10n.commonEdit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildFactRow(
              identifier: 'unemployment_income_fact',
              label: l10n.unemploymentGainSliderTitle,
              value: monthlyInsuredEarnings == null
                  ? l10n.dataBlockStatusMissing
                  : UnemploymentService.formatChf(monthlyInsuredEarnings),
              isMissing: monthlyInsuredEarnings == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'unemployment_age_fact',
              label: l10n.unemploymentAgeSliderTitle,
              value: age == null
                  ? l10n.dataBlockStatusMissing
                  : l10n.unemploymentAgeValue(age),
              isMissing: age == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'unemployment_contribution_months_fact',
              label: l10n.unemploymentContribTitle,
              value: contributionMonths == null
                  ? l10n.dataBlockStatusMissing
                  : l10n.unemploymentContribValue(contributionMonths),
              isMissing: contributionMonths == null,
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
      key: Key(identifier),
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

  // ── Toggles ────────────────────────────────────────────────

  Widget _buildToggles(bool hasChildren) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.unemploymentSituationTitle,
            style: MintTextStyles.titleMedium(
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.unemploymentSituationSubtitle,
            style: MintTextStyles.labelMedium(
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildToggleRow(
            icon: Icons.child_care,
            label: S.of(context)!.unemploymentChildrenToggle,
            value: hasChildren,
            onChanged: (v) {
              setState(() => _hasChildrenOverride = v);
            },
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          _buildToggleRow(
            icon: Icons.accessible,
            label: S.of(context)!.unemploymentDisabilityToggle,
            value: _hasDisability,
            onChanged: (v) {
              setState(() => _hasDisability = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      label: label,
      toggled: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: MintColors.textMuted),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodyMedium(
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: MintColors.primary,
          ),
        ],
      ),
    );
  }

  // ── Not Eligible ───────────────────────────────────────────

  Widget _buildNotEligible(UnemploymentResult result) {
    return MintSurface(
      tone: MintSurfaceTone.peche,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.warning, size: 24),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.unemploymentNotEligible,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  result.raisonNonEligible ?? '',
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Premier Éclairage ───────────────────────────────────────────

  Widget _buildPremierEclairage(UnemploymentResult r) {
    return MintResultHeroCard(
      eyebrow: S.of(context)!.unemploymentTitle,
      primaryValue: UnemploymentService.formatChf(r.indemniteMensuelle),
      primaryLabel: S.of(context)!.unemploymentMonthlyBenefit,
      secondaryValue: UnemploymentService.formatChf(r.gainAssureRetenu),
      secondaryLabel: S.of(context)!.unemploymentInsuredEarnings,
      narrative: r.premierEclairage,
      accentColor: MintColors.error,
      tone: MintSurfaceTone.peche,
    );
  }

  // ── Taux Card ──────────────────────────────────────────────

  Widget _buildTauxCard(UnemploymentResult r) {
    final tauxPct = (r.tauxIndemnite * 100).toStringAsFixed(0);
    final isEnhanced = r.tauxIndemnite == 0.80;

    return Semantics(
      label: '${S.of(context)!.unemploymentCompensationRate}\u00a0: $tauxPct%',
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isEnhanced
                    ? MintColors.success.withValues(alpha: 0.1)
                    : MintColors.info.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$tauxPct\u00a0%',
                style: MintTextStyles.headlineMedium(
                  color: isEnhanced ? MintColors.success : MintColors.info,
                ),
              ),
            ),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.unemploymentCompensationRate,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    isEnhanced
                        ? S.of(context)!.unemploymentRateEnhanced
                        : S.of(context)!.unemploymentRateStandard,
                    style: MintTextStyles.labelMedium(
                      color: MintColors.textSecondary,
                    ).copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result Cards ───────────────────────────────────────────

  Widget _buildResultCards(UnemploymentResult r) {
    return Column(
      key: const Key('unemployment_result_cards'),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentDailyBenefit,
                UnemploymentService.formatChf(r.indemniteJournaliere),
                Icons.today_outlined,
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentMonthlyBenefit,
                UnemploymentService.formatChf(r.indemniteMensuelle),
                Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentInsuredEarnings,
                UnemploymentService.formatChf(r.gainAssureRetenu),
                Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentWaitingPeriod,
                S.of(context)!.unemploymentWaitingDays(r.delaiCarenceJours),
                Icons.hourglass_empty,
                small: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon,
      {bool small = false}) {
    return Semantics(
      label: '$label\u00a0: $value',
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: MintColors.textMuted),
            const SizedBox(height: MintSpacing.sm),
            Text(
              value,
              style: MintTextStyles.headlineMedium(
                color: MintColors.textPrimary,
              ).copyWith(fontSize: small ? 14 : 18),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              label,
              style: MintTextStyles.labelMedium(
                color: MintColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Duration Card ──────────────────────────────────────────

  Widget _buildDurationCard(
    UnemploymentResult r,
    int age,
    int contributionMonths,
    bool hasChildren,
    bool hasDisability,
  ) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.unemploymentDurationHeader,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label:
                      '${r.nombreIndemnites} ${S.of(context)!.unemploymentDailyBenefits}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.nombreIndemnites}',
                        style: MintTextStyles.displayMedium(
                          color: MintColors.primary,
                        ),
                      ),
                      Text(
                        S.of(context)!.unemploymentDailyBenefits,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: MintColors.border,
              ),
              const SizedBox(width: MintSpacing.md + 4),
              Expanded(
                child: Semantics(
                  label:
                      '~${r.dureeMois.toStringAsFixed(0)} ${S.of(context)!.unemploymentCoverageMonths}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '~${r.dureeMois.toStringAsFixed(0)}',
                        style: MintTextStyles.displayMedium(
                          color: MintColors.primary,
                        ),
                      ),
                      Text(
                        S.of(context)!.unemploymentCoverageMonths,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildDurationTable(
            age,
            contributionMonths,
            hasChildren,
            hasDisability,
            r.nombreIndemnites,
          ),
        ],
      ),
    );
  }

  Widget _buildDurationTable(
    int age,
    int contributionMonths,
    bool hasChildren,
    bool hasDisability,
    int effectiveDays,
  ) {
    // Source : LACI art. 27 al. 2 — durées maximales d'indemnités
    // Miroir de social_insurance.dart (acJoursMinCotisation, acJoursStandard, acJoursSenior)
    final l10n = S.of(context)!;
    final isUnder25WithoutMaintenance = age < 25 && !hasChildren;
    final isSeniorOrDisability = age >= acAgeSeuillSenior || hasDisability;
    final hasSeniorOrDisabilityBand =
        contributionMonths >= 22 && isSeniorOrDisability;
    final hasNearAvsSupplement = effectiveDays > acJoursSenior;
    final brackets = [
      (
        l10n.unemploymentBracket1,
        l10n.unemploymentBracket1Value,
        contributionMonths >= 12 &&
            isUnder25WithoutMaintenance &&
            !hasSeniorOrDisabilityBand,
      ),
      (
        l10n.unemploymentBracket2,
        l10n.unemploymentBracket2Value,
        contributionMonths >= 12 &&
            contributionMonths < 18 &&
            !isUnder25WithoutMaintenance,
      ),
      (
        l10n.unemploymentBracket3(acAgeSeuillSenior),
        l10n.unemploymentBracket3Value,
        contributionMonths >= 18 &&
            !(contributionMonths >= 22 && isSeniorOrDisability) &&
            !isUnder25WithoutMaintenance,
      ),
      (
        l10n.unemploymentBracket4(acAgeSeuillSenior),
        l10n.unemploymentBracket4Value,
        hasSeniorOrDisabilityBand && !hasNearAvsSupplement,
      ),
      if (hasNearAvsSupplement)
        (
          l10n.unemploymentBracketNearAvs,
          l10n.unemploymentWaitingDays(effectiveDays),
          true,
        ),
    ];

    return Column(
      children: brackets.map((b) {
        final isCurrent = b.$3;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.sm + 4, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? MintColors.primary.withValues(alpha: 0.06)
                : MintColors.transparent,
            borderRadius: BorderRadius.circular(8),
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
                      margin: const EdgeInsets.only(right: MintSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context)!.unemploymentYouTag,
                        style: MintTextStyles.labelTiny(
                          color: MintColors.white,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  Text(
                    b.$1,
                    style: MintTextStyles.labelSmall(
                      color: isCurrent
                          ? MintColors.textPrimary
                          : MintColors.textSecondary,
                    ).copyWith(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Text(
                b.$2,
                style: MintTextStyles.labelMedium(
                  color:
                      isCurrent ? MintColors.primary : MintColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final l10n = S.of(context)!;
    final items = [
      l10n.unemploymentCheckItem1,
      l10n.unemploymentCheckItem2,
      l10n.unemploymentCheckItem3,
      l10n.unemploymentCheckItem4,
      l10n.unemploymentCheckItem5,
      l10n.unemploymentCheckItem6,
    ];

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.unemploymentChecklistHeader,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          ...List.generate(items.length, (index) {
            final checked = _checkedItems.contains(index);
            return Semantics(
              label: items[index],
              toggled: checked,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (checked) {
                      _checkedItems.remove(index);
                    } else {
                      _checkedItems.add(index);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: checked
                              ? MintColors.success
                              : MintColors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: checked
                                ? MintColors.success
                                : MintColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: checked
                            ? const Icon(Icons.check,
                                size: 14, color: MintColors.white)
                            : null,
                      ),
                      const SizedBox(width: MintSpacing.sm + 4),
                      Expanded(
                        child: Text(
                          items[index],
                          style: MintTextStyles.bodyMedium(
                            color: checked
                                ? MintColors.textMuted
                                : MintColors.textPrimary,
                          ).copyWith(
                            decoration:
                                checked ? TextDecoration.lineThrough : null,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
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
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.unemploymentGoodToKnow,
              style: MintTextStyles.labelSmall(
                color: MintColors.textMuted,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildEduCard(
          Icons.timer_outlined,
          S.of(context)!.unemploymentEduFastTitle,
          S.of(context)!.unemploymentEduFastBody,
        ),
        _buildEduCard(
          Icons.savings_outlined,
          S.of(context)!.unemploymentEdu3aTitle,
          S.of(context)!.unemploymentEdu3aBody,
        ),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.unemploymentEduLppTitle,
          S.of(context)!.unemploymentEduLppBody,
        ),
        _buildEduCard(
          Icons.health_and_safety_outlined,
          S.of(context)!.unemploymentEduLamalTitle,
          S.of(context)!.unemploymentEduLamalBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: MintSurface(
        tone: MintSurfaceTone.bleu,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: MintColors.primary),
            const SizedBox(width: MintSpacing.sm + 4),
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
                    ).copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── P7-A : Les 3 vagues — Ton tsunami financier ────────────

  Widget _buildTroisVagues() {
    final l10n = S.of(context)!;
    final vagues = [
      (
        label: l10n.unemploymentVague1Label,
        color: MintColors.info,
        text: l10n.unemploymentVague1Text,
      ),
      (
        label: l10n.unemploymentVague2Label,
        color: MintColors.warning,
        text: l10n.unemploymentVague2Text,
      ),
      (
        label: l10n.unemploymentVague3Label,
        color: MintColors.error,
        text: l10n.unemploymentVague3Text,
      ),
    ];

    return MintSurface(
      tone: MintSurfaceTone.bleu,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MintSpacing.md, MintSpacing.md,
                MintSpacing.md, MintSpacing.sm + 4),
            child: Row(
              children: [
                const Icon(Icons.waves, size: 22, color: MintColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.unemploymentTsunamiTitle,
                    style: MintTextStyles.labelLarge(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...vagues.map(
            (v) => Padding(
              padding: const EdgeInsets.fromLTRB(MintSpacing.md,
                  MintSpacing.sm + 4, MintSpacing.md, MintSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: v.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.label,
                          style: MintTextStyles.bodySmall(
                            color: v.color,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: MintSpacing.xs),
                        Text(
                          v.text,
                          style: MintTextStyles.labelMedium(
                            color: MintColors.textSecondary,
                          ).copyWith(height: 1.5),
                        ),
                        const SizedBox(height: MintSpacing.sm),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MINT Coach Widget: Crash Test Budget ───────────────────

  Widget _buildMintCrashTestSection(
    CoachProfile? profile,
    UnemploymentResult result,
  ) {
    final l10n = S.of(context)!;
    final estimate = UnemploymentBudgetEstimator.fromLedger(
      profile: profile,
      grossMonthlyBenefit: result.indemniteMensuelle,
    );

    if (estimate == null) {
      return _buildBudgetMissingCard(l10n);
    }

    final lines = <BudgetLine>[
      BudgetLine(
        label: l10n.unemploymentBudgetLoyer,
        emoji: '🏠',
        normalAmount: estimate.housing,
        survivalAmount: estimate.housing,
        status: BudgetLineStatus.locked,
      ),
      BudgetLine(
        label: l10n.unemploymentBudgetLamal,
        emoji: '🏥',
        normalAmount: estimate.lamal,
        survivalAmount: estimate.lamal,
        status: BudgetLineStatus.locked,
      ),
      if (estimate.transport != null)
        BudgetLine(
          label: l10n.unemploymentBudgetTransport,
          emoji: '🚌',
          normalAmount: estimate.transport!,
          survivalAmount: estimate.transport!,
          status: BudgetLineStatus.locked,
        ),
    ];

    return CrashTestBudgetWidget(
      monthlyIncome: estimate.normalIncome,
      survivalIncome: estimate.survivalIncome,
      survivalIncomeLabel: l10n.unemploymentSurvivalEstimatedLabel,
      incomeFootnote: l10n.unemploymentNetBenefitFootnote,
      lines: lines,
    );
  }

  Widget _buildBudgetMissingCard(S l10n) {
    return Semantics(
      key: const Key('unemployment_budget_missing'),
      identifier: 'unemployment_budget_missing',
      container: true,
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: MintColors.warning,
              size: 22,
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.budgetCardEmptyTitle,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    l10n.budgetCardEmptyBody,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ).copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/budget/setup'),
              child: Text(l10n.budgetCardEmptyAction),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Semantics(
      label: S.of(context)!.unemploymentDisclaimer,
      child: MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                color: MintColors.corailDiscret, size: 18),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Text(
                S.of(context)!.unemploymentDisclaimer,
                style: MintTextStyles.labelSmall(
                  color: MintColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
