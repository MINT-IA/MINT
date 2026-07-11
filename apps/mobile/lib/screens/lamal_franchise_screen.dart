import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/assurances_service.dart';
import 'package:mint_mobile/services/financial_core/lamal_premium_normalizer.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

// ────────────────────────────────────────────────────────────
//  LAMAL FRANCHISE OPTIMISER SCREEN — Sprint S13 / Chantier 7
// ────────────────────────────────────────────────────────────
//
// Interactive screen for comparing LAMal franchise levels.
// Category C — Life Event (DESIGN_SYSTEM §2C).
// ────────────────────────────────────────────────────────────

class LamalFranchiseScreen extends StatefulWidget {
  const LamalFranchiseScreen({super.key});

  @override
  State<LamalFranchiseScreen> createState() => _LamalFranchiseScreenState();
}

class _LamalFranchiseScreenState extends State<LamalFranchiseScreen> {
  // ── State ──────────────────────────────────────────────────
  Map<String, dynamic> _ledgerAnswers = const {};
  bool _ledgerLoaded = false;

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('lamal');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ledgerLoaded) {
      _refreshLedgerFacts();
    }
  }

  Future<void> _refreshLedgerFacts() async {
    final answers = await ReportPersistenceService.loadAnswers();
    if (!mounted) return;
    setState(() {
      _ledgerAnswers = Map<String, dynamic>.from(answers);
      _ledgerLoaded = true;
    });
  }

  double? _amountFact(String key) {
    final value = _ledgerAnswers[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.trim().replaceAll(RegExp(r"[' ]"), '');
      if (cleaned.isEmpty) return null;
      return double.tryParse(cleaned);
    }
    return null;
  }

  int? _integerFact(String key) {
    final value = _ledgerAnswers[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final cleaned = value.trim().replaceAll(RegExp(r"[' ]"), '');
      if (cleaned.isEmpty) return null;
      return int.tryParse(cleaned);
    }
    return null;
  }

  double? get _primeMensuelleFact => _amountFact('q_lamal_premium_monthly_chf');

  int? get _currentFranchiseFact => _integerFact('q_lamal_franchise');

  double? get _depensesSanteMensuellesFact =>
      _amountFact('_coach_depenses_frais_medicaux');

  double? get _depensesSanteAnnuellesFact {
    final monthly = _depensesSanteMensuellesFact;
    return monthly == null ? null : monthly * 12;
  }

  bool get _hasRequiredLedgerFacts =>
      _primeMensuelleFact != null &&
      _currentFranchiseFact != null &&
      _depensesSanteAnnuellesFact != null;

  LamalFranchiseResult? _resultFromLedger(S s) {
    final prime = _primeMensuelleFact;
    final currentFranchise = _currentFranchiseFact;
    final depenses = _depensesSanteAnnuellesFact;
    if (prime == null || currentFranchise == null || depenses == null) {
      return null;
    }
    final normalizedPrime = LamalPremiumNormalizer.toFranchise300MonthlyPremium(
      monthlyPremium: prime,
      currentFranchise: currentFranchise,
      isChild: false,
      premiumSavingsVs300: LamalFranchiseService.premiumSavingsVs300,
    );
    return LamalFranchiseService.analyzeAllFranchises(
      normalizedPrime,
      depenses,
      isChild: false,
      l: s,
    );
  }

  Future<void> _openBudgetSetup() async {
    await context.push('/budget/setup?focus=lamal');
    if (!mounted) return;
    await _refreshLedgerFacts();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final result = _resultFromLedger(s);
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                MintSpacing.lg, 0, MintSpacing.lg, MintSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: MintSpacing.md + 4),
                MintEntrance(
                    delay: const Duration(milliseconds: 100),
                    child: _buildIntro()),
                const SizedBox(height: MintSpacing.lg),
                MintEntrance(child: _buildLedgerFacts(s)),
                const SizedBox(height: MintSpacing.lg),

                if (result != null) ...[
                  KeyedSubtree(
                    key: const Key('lamal_result_section'),
                    child: Semantics(
                      identifier: 'lamal_result_section',
                      container: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MintEntrance(child: _buildComparisonCards(result)),
                          const SizedBox(height: MintSpacing.md + 4),
                          MintEntrance(
                            delay: const Duration(milliseconds: 100),
                            child: _buildBreakEvenInfo(result),
                          ),
                          const SizedBox(height: MintSpacing.md + 4),
                          MintEntrance(
                            delay: const Duration(milliseconds: 150),
                            child: _buildRecommendations(result),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: MintSpacing.md + 4),
                ] else if (_ledgerLoaded) ...[
                  _buildMissingFactsCard(s),
                  const SizedBox(height: MintSpacing.md + 4),
                ],

                // Alert card
                _buildAlertCard(),
                const SizedBox(height: MintSpacing.md + 4),

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: MintSpacing.md),

                // Sources
                _buildSourcesFooter(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar (white standard per DESIGN_SYSTEM §4.5) ──────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Semantics(
        label: S.of(context)!.semanticsBack,
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => safePop(context),
        ),
      ),
      title: Text(
        S.of(context)!.lamalFranchiseAppBarTitle,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.health_and_safety,
            color: MintColors.info,
            size: 28,
          ),
        ),
        const SizedBox(width: MintSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.lamalFranchiseHeaderTitle,
                style: MintTextStyles.headlineMedium(),
              ),
              const SizedBox(height: MintSpacing.xs),
              Text(
                S.of(context)!.lamalFranchiseHeaderSubtitle,
                style: MintTextStyles.bodyMedium(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.lamalFranchiseIntro,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ledger facts ─────────────────────────────────────────────

  Widget _buildLedgerFacts(S s) {
    final prime = _primeMensuelleFact;
    final currentFranchise = _currentFranchiseFact;
    final medicalMonthly = _depensesSanteMensuellesFact;
    final medicalAnnual = _depensesSanteAnnuellesFact;
    return Semantics(
      identifier: 'lamal_ledger_facts',
      container: true,
      child: MintSurface(
        key: const Key('lamal_ledger_facts'),
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dataset_outlined,
                    color: MintColors.primary, size: 18),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  s.lamalFranchiseLedgerTitle,
                  style: MintTextStyles.titleMedium(),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.xs + 2),
            Text(
              s.lamalFranchiseLedgerBody,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.md),
            _buildFactRow(
              key: const Key('lamal_premium_fact'),
              semanticsIdentifier: 'lamal_premium_fact',
              label: s.budgetSetupLamal,
              value: prime == null
                  ? s.lamalFranchiseFactMissing
                  : s.lamalFranchiseMonthlyValue(
                      LamalFranchiseService.formatChf(prime),
                    ),
              known: prime != null,
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildFactRow(
              key: const Key('lamal_current_franchise_fact'),
              semanticsIdentifier: 'lamal_current_franchise_fact',
              label: s.lamalFranchiseCurrentFactLabel,
              value: currentFranchise == null
                  ? s.lamalFranchiseFactMissing
                  : LamalFranchiseService.formatChf(
                      currentFranchise.toDouble(),
                    ),
              known: currentFranchise != null,
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildFactRow(
              key: const Key('lamal_medical_fact'),
              semanticsIdentifier: 'lamal_medical_fact',
              label: s.budgetSetupMedical,
              value: medicalMonthly == null || medicalAnnual == null
                  ? s.lamalFranchiseFactMissing
                  : s.lamalFranchiseMedicalFactValue(
                      LamalFranchiseService.formatChf(medicalMonthly),
                      LamalFranchiseService.formatChf(medicalAnnual),
                    ),
              known: medicalMonthly != null,
            ),
            if (_hasRequiredLedgerFacts) ...[
              const SizedBox(height: MintSpacing.md),
              Semantics(
                identifier: 'lamal_enrich_cta',
                container: true,
                button: true,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('lamal_enrich_cta'),
                    onPressed: _openBudgetSetup,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(s.lamalFranchiseModifyCta),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow({
    required Key key,
    required String semanticsIdentifier,
    required String label,
    required String value,
    required bool known,
  }) {
    final color = known ? MintColors.success : MintColors.warning;
    return Semantics(
      identifier: semanticsIdentifier,
      container: true,
      child: Container(
        key: key,
        padding: const EdgeInsets.all(MintSpacing.sm + 2),
        decoration: BoxDecoration(
          color: MintColors.craie,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MintColors.border.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(
              known ? Icons.check_circle_outline : Icons.help_outline,
              color: color,
              size: 18,
            ),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: MintTextStyles.labelSmall()),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style:
                        MintTextStyles.bodySmall(color: MintColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            Text(
              known
                  ? S.of(context)!.lamalFranchiseFactKnown
                  : S.of(context)!.lamalFranchiseFactMissing,
              style: MintTextStyles.micro(color: color)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingFactsCard(S s) {
    return Semantics(
      identifier: 'lamal_missing_facts_card',
      container: true,
      child: MintSurface(
        key: const Key('lamal_missing_facts_card'),
        tone: MintSurfaceTone.bleu,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_task, color: MintColors.info, size: 18),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  s.lamalFranchiseMissingTitle,
                  style: MintTextStyles.titleMedium(),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              s.lamalFranchiseMissingBody,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'lamal_enrich_cta',
              container: true,
              button: true,
              child: FilledButton.icon(
                key: const Key('lamal_enrich_cta'),
                onPressed: _openBudgetSetup,
                icon: const Icon(Icons.arrow_forward),
                label: Text(s.lamalFranchiseEnrichCta),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.background,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Comparison cards ───────────────────────────────────────

  Widget _buildComparisonCards(LamalFranchiseResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.compare_arrows,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.lamalFranchiseComparisonHeader,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        ...result.comparaison.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
              child: _buildFranchiseCard(c),
            )),
      ],
    );
  }

  Widget _buildFranchiseCard(FranchiseComparison c) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.isOptimal
              ? MintColors.success
              : MintColors.border.withValues(alpha: 0.6),
          width: c.isOptimal ? 2 : 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'CHF\u00a0${c.franchiseLevel}',
                    style: MintTextStyles.titleMedium(
                        color: MintColors.textPrimary),
                  ),
                  if (c.isOptimal) ...[
                    const SizedBox(width: MintSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: MintColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        S.of(context)!.lamalFranchiseRecommandee,
                        style:
                            MintTextStyles.labelSmall(color: MintColors.success)
                                .copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                S.of(context)!.lamalFranchiseTotalPrefix(
                    LamalFranchiseService.formatChf(c.coutTotal)),
                style: MintTextStyles.bodyMedium(
                  color:
                      c.isOptimal ? MintColors.success : MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(S.of(context)!.lamalFranchisePrimeAn,
                    LamalFranchiseService.formatChf(c.primeAnnuelle)),
              ),
              Expanded(
                child: _buildMiniStat(S.of(context)!.lamalFranchiseQuotePart,
                    LamalFranchiseService.formatChf(c.quotePart)),
              ),
              Expanded(
                child: _buildMiniStat(
                  S.of(context)!.lamalFranchiseEconomie,
                  c.economieVs300 > 0
                      ? '+${LamalFranchiseService.formatChf(c.economieVs300)}'
                      : LamalFranchiseService.formatChf(c.economieVs300),
                  color: c.economieVs300 > 0 ? MintColors.success : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MintTextStyles.labelSmall()),
        const SizedBox(height: 2),
        Text(
          value,
          style:
              MintTextStyles.bodySmall(color: color ?? MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── Break-even info ────────────────────────────────────────

  Widget _buildBreakEvenInfo(LamalFranchiseResult result) {
    if (result.breakEvenPoints.isEmpty) return const SizedBox.shrink();

    return MintSurface(
      tone: MintSurfaceTone.bleu,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_vert, color: MintColors.info, size: 18),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.lamalFranchiseBreakEvenTitle,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          ...result.breakEvenPoints.take(3).map((bp) => Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: MintColors.info,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: MintSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        S.of(context)!.lamalFranchiseBreakEvenItem(
                              LamalFranchiseService.formatChf(bp.seuilDepenses),
                              bp.franchiseBasse.toString(),
                              bp.franchiseHaute.toString(),
                            ),
                        style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Recommendations ────────────────────────────────────────

  Widget _buildRecommendations(LamalFranchiseResult result) {
    if (result.recommandations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.lamalFranchiseRecommandationsHeader,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        ...result.recommandations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
              child: Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                decoration: BoxDecoration(
                  color: MintColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: MintColors.border.withValues(alpha: 0.6),
                      width: 0.8),
                ),
                child: Text(
                  rec,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
            )),
      ],
    );
  }

  // ── Alert card ─────────────────────────────────────────────

  Widget _buildAlertCard() {
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
          const Icon(Icons.event, color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.lamalFranchiseAlertText,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
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
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.lamalFranchiseDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.lamalFranchiseSourcesHeader,
          style: MintTextStyles.bodySmall(color: MintColors.textMuted)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: MintSpacing.xs + 2),
        Text(
          S.of(context)!.lamalFranchiseSourcesBody,
          style: MintTextStyles.labelSmall(),
        ),
      ],
    );
  }
}
