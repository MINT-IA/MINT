import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/financial_core/unemployment_calculator.dart';
import 'package:mint_mobile/services/unemployment_service.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/educational/unemployment_timeline_widget.dart';
import 'package:mint_mobile/widgets/coach/unemployment_counter_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
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

class _UnemploymentLedgerFacts {
  const _UnemploymentLedgerFacts({
    required this.monthlyGain,
    required this.age,
    required this.childrenCount,
  });

  const _UnemploymentLedgerFacts.empty()
      : monthlyGain = null,
        age = null,
        childrenCount = null;

  final double? monthlyGain;
  final int? age;
  final int? childrenCount;

  bool get isComplete =>
      monthlyGain != null && age != null && childrenCount != null;

  bool hasSameValuesAs(_UnemploymentLedgerFacts other) {
    return monthlyGain == other.monthlyGain &&
        age == other.age &&
        childrenCount == other.childrenCount;
  }
}

class _UnemploymentScreenState extends State<UnemploymentScreen> {
  double _gainAssure = 0;
  int _age = 0;
  int _moisCotisation = 18;
  bool _hasConfirmedMoisCotisation = false;
  bool _hasChildren = false;
  bool _hasDisability = false;
  UnemploymentResult? _result;
  _UnemploymentLedgerFacts _facts = const _UnemploymentLedgerFacts.empty();

  // Checklist tracking
  final Set<int> _checkedItems = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facts = _ledgerFactsFromProfile(_profileProvider(context));
    final factsChanged = !_facts.hasSameValuesAs(facts);
    _facts = facts;
    if (!facts.isComplete) {
      _result = null;
      return;
    }
    if (factsChanged) {
      _gainAssure = facts.monthlyGain!;
      _age = facts.age!;
      _hasChildren = facts.childrenCount! > 0;
    }
    _result = _hasConfirmedMoisCotisation ? _calculateCurrentFacts() : null;
  }

  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  _UnemploymentLedgerFacts _ledgerFactsFromProfile(
    CoachProfileProvider? provider,
  ) {
    final profile = provider?.profile;
    if (profile == null) return const _UnemploymentLedgerFacts.empty();
    final provided = profile.userProvidedFields;
    final monthlyGain =
        provided.contains('salary') && profile.revenuBrutAnnuel > 0
            ? profile.revenuBrutAnnuel / 12
            : null;
    final age =
        provided.contains('age') && profile.age > 0 ? profile.age : null;
    final childrenCount =
        provided.contains('children') ? profile.nombreEnfants : null;
    return _UnemploymentLedgerFacts(
      monthlyGain: monthlyGain,
      age: age,
      childrenCount: childrenCount,
    );
  }

  UnemploymentResult _calculateCurrentFacts() {
    return UnemploymentService.calculateBenefits(
      gainAssureMensuel: _gainAssure,
      age: _age,
      moisCotisation: _moisCotisation,
      hasChildren: _hasChildren,
      hasDisability: _hasDisability,
    );
  }

  void _calculate() {
    if (!_facts.isComplete || !_hasConfirmedMoisCotisation) {
      setState(() => _result = null);
      return;
    }
    setState(() {
      _result = _calculateCurrentFacts();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            if (_result != null && _result!.eligible) ...[
              _buildPremierEclairage(),
              const SizedBox(height: MintSpacing.xl),
            ] else if (_result != null && !_result!.eligible) ...[
              _buildNotEligible(),
              const SizedBox(height: MintSpacing.xl),
            ] else ...[
              _buildHeader(),
              const SizedBox(height: MintSpacing.xl),
            ],
            _buildLedgerFactsCard(context),
            const SizedBox(height: MintSpacing.md),
            if (_facts.isComplete) ...[
              _buildMoisCotisationSlider(),
              const SizedBox(height: MintSpacing.md),
              _buildToggles(),
              const SizedBox(height: MintSpacing.xl),
            ],
            if (_result != null && _result!.eligible) ...[
              _buildTauxCard(),
              const SizedBox(height: MintSpacing.xl),
              _buildResultCards(),
              const SizedBox(height: MintSpacing.xl),
              _buildDurationCard(),
              const SizedBox(height: MintSpacing.xl),
              UnemploymentCounterWidget(
                age: _age,
                monthlyBenefit: _result!.indemniteMensuelle,
                totalBenefitDays: _result!.nombreIndemnites,
                coverageMonths: _result!.dureeMois,
              ),
              const SizedBox(height: MintSpacing.xl),
              _buildTroisVagues(),
              const SizedBox(height: MintSpacing.xl),
            ],
            if (_result != null) ...[
              UnemploymentTimelineWidget(items: _result!.timeline),
              const SizedBox(height: MintSpacing.xl),
              _buildChecklist(),
              const SizedBox(height: MintSpacing.xl),
              _buildEducation(),
              const SizedBox(height: MintSpacing.xl),
              _buildMintCrashTestSection(),
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

  Widget _buildLedgerFactsCard(BuildContext context) {
    final s = S.of(context)!;
    final hasMissing = !_facts.isComplete;
    final editRoute = _facts.monthlyGain == null
        ? '/data-block/revenu?inputKey=q_gross_salary_annual'
        : _facts.age == null
            ? '/data-block/revenu?inputKey=q_birth_year'
            : _facts.childrenCount == null
                ? '/data-block/compositionMenage?inputKey=q_children'
                : '/data-block/revenu';

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Semantics(
        key: const Key('unemployment_ledger_facts'),
        identifier: 'unemployment_ledger_facts',
        container: true,
        explicitChildNodes: true,
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
                  key: const Key('unemployment_enrich_profile_cta'),
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
              identifier: 'unemployment_gain_fact',
              label: s.unemploymentGainSliderTitle,
              value: _facts.monthlyGain == null
                  ? s.dataBlockStatusMissing
                  : UnemploymentService.formatChf(_facts.monthlyGain!),
              isMissing: _facts.monthlyGain == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'unemployment_age_fact',
              label: s.unemploymentAgeSliderTitle,
              value: _facts.age == null
                  ? s.dataBlockStatusMissing
                  : s.unemploymentAgeValue(_facts.age!),
              isMissing: _facts.age == null,
            ),
            const SizedBox(height: MintSpacing.xs),
            _buildFactRow(
              identifier: 'unemployment_children_fact',
              label: s.unemploymentChildrenToggle,
              value: _facts.childrenCount == null
                  ? s.dataBlockStatusMissing
                  : '${_facts.childrenCount}',
              isMissing: _facts.childrenCount == null,
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

  Widget _buildMoisCotisationSlider() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MintPickerTile(
            label: S.of(context)!.unemploymentContribTitle,
            value: _moisCotisation,
            minValue: 0,
            maxValue: 24,
            formatValue: (v) => S.of(context)!.unemploymentContribValue(v),
            onChanged: (v) {
              setState(() {
                _moisCotisation = v;
                _hasConfirmedMoisCotisation = true;
                _result = _calculateCurrentFacts();
              });
            },
          ),
          if (!_hasConfirmedMoisCotisation) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              S.of(context)!.unemploymentContribConfirmHint,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ).copyWith(height: 1.4),
            ),
            const SizedBox(height: MintSpacing.sm),
            FilledButton(
              key: const Key('unemployment_confirm_contribution_months_cta'),
              onPressed: () {
                setState(() {
                  _hasConfirmedMoisCotisation = true;
                  _result = _calculateCurrentFacts();
                });
              },
              child: Text(S.of(context)!.unemploymentContribConfirmCta),
            ),
          ],
        ],
      ),
    );
  }

  // ── Toggles ────────────────────────────────────────────────

  Widget _buildToggles() {
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
            icon: Icons.accessible,
            label: S.of(context)!.unemploymentDisabilityToggle,
            value: _hasDisability,
            onChanged: (v) {
              _hasDisability = v;
              _calculate();
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

  Widget _buildNotEligible() {
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
                  _notEligibleReason(S.of(context)!, _result!),
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

  Widget _buildPremierEclairage() {
    final r = _result!;
    final l10n = S.of(context)!;
    final referenceMonthlyIncome =
        _gainAssure > 0 ? _gainAssure : r.gainAssureRetenu;
    final lossPct = referenceMonthlyIncome > 0
        ? ((r.perteMensuelle / referenceMonthlyIncome) * 100)
            .clamp(0, 1000)
            .toStringAsFixed(0)
        : '0';
    return MintResultHeroCard(
      eyebrow: l10n.unemploymentTitle,
      primaryValue: UnemploymentService.formatChf(r.perteMensuelle),
      primaryLabel: l10n.unemploymentMonthlyLoss,
      secondaryValue: UnemploymentService.formatChf(r.indemniteMensuelle),
      secondaryLabel: l10n.unemploymentMonthlyBenefit,
      narrative: l10n.unemploymentPremierEclairageLoss(
        UnemploymentService.formatChf(r.perteMensuelle),
        lossPct,
      ),
      accentColor: MintColors.error,
      tone: MintSurfaceTone.peche,
    );
  }

  String _notEligibleReason(S l10n, UnemploymentResult result) {
    switch (result.ineligibilityReason) {
      case UnemploymentIneligibilityReason.invalidMonthlyEarnings:
        return l10n.unemploymentInvalidMonthlyEarningsReason;
      case UnemploymentIneligibilityReason.insufficientContributions:
        return l10n.unemploymentInsufficientContributionsReason(
          _moisCotisation,
        );
      case null:
        return '';
    }
  }

  // ── Taux Card ──────────────────────────────────────────────

  Widget _buildTauxCard() {
    final r = _result!;
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

  Widget _buildResultCards() {
    final r = _result!;
    return Column(
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

  Widget _buildDurationCard() {
    final r = _result!;
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
          _buildDurationTable(),
        ],
      ),
    );
  }

  Widget _buildDurationTable() {
    // Source : LACI art. 27 al. 2 — durées maximales d'indemnités
    // Miroir de social_insurance.dart.
    final l10n = S.of(context)!;
    final activeDays = _result?.nombreIndemnites;
    final brackets = [
      (
        l10n.unemploymentBracket1,
        l10n.unemploymentBracket1Value,
        activeDays == acJoursMinCotisation
      ),
      (
        l10n.unemploymentBracket2,
        l10n.unemploymentBracket2Value,
        activeDays == acJoursIntermediaireCotisation
      ),
      (
        l10n.unemploymentBracket3(acAgeSeuillSenior),
        l10n.unemploymentBracket3Value,
        activeDays == acJoursStandard
      ),
      (
        l10n.unemploymentBracket4(acAgeSeuillSenior),
        l10n.unemploymentBracket4Value,
        activeDays == acJoursSenior
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

  Widget _buildMintCrashTestSection() {
    final l10n = S.of(context)!;
    final survivalIncome = _gainAssure *
        acIndemniteTaux; // taux LACI standard (LACI art. 22) — from social_insurance.dart

    // Derive budget lines proportionally from gainAssure
    final loyer = (_gainAssure * 0.30).roundToDouble(); // ~30% du revenu
    final lamal = (_gainAssure * 0.075).roundToDouble(); // ~7.5%
    final transport = (_gainAssure * 0.033).roundToDouble(); // ~3.3%
    final loisirs = (_gainAssure * 0.067).roundToDouble(); // ~6.7%
    final epargne3a =
        (pilier3aPlafondAvecLpp / 12).roundToDouble(); // plafond mensuel

    return CrashTestBudgetWidget(
      monthlyIncome: _gainAssure,
      survivalIncome: survivalIncome,
      lines: [
        BudgetLine(
          label: l10n.unemploymentBudgetLoyer,
          emoji: '🏠',
          normalAmount: loyer,
          survivalAmount: loyer, // incompressible
          status: BudgetLineStatus.locked,
        ),
        BudgetLine(
          label: l10n.unemploymentBudgetLamal,
          emoji: '🏥',
          normalAmount: lamal,
          survivalAmount: lamal, // incompressible
          status: BudgetLineStatus.locked,
        ),
        BudgetLine(
          label: l10n.unemploymentBudgetTransport,
          emoji: '🚌',
          normalAmount: transport,
          survivalAmount: (transport * 0.50).roundToDouble(),
          status: BudgetLineStatus.cut,
        ),
        BudgetLine(
          label: l10n.unemploymentBudgetLoisirs,
          emoji: '🎭',
          normalAmount: loisirs,
          survivalAmount: (loisirs * 0.125).roundToDouble(),
          status: BudgetLineStatus.cut,
        ),
        BudgetLine(
          label: l10n.unemploymentBudgetEpargne3a,
          emoji: '🏦',
          normalAmount: epargne3a,
          survivalAmount: 0,
          status: BudgetLineStatus.paused,
        ),
      ],
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
