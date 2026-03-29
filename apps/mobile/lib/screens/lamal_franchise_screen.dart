import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/assurances_service.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
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
  double _primeMensuelle = 350;
  double _depensesSante = 2000;
  bool _isChild = false;

  LamalFranchiseResult? _result;

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('lamal');
    _compute();
  }

  void _compute() {
    setState(() {
      _result = LamalFranchiseService.analyzeAllFranchises(
        _primeMensuelle,
        _depensesSante,
        isChild: _isChild,
      );
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                _buildDemoModeBadge(),
                const SizedBox(height: MintSpacing.sm + 4),
                _buildHeader(),
                const SizedBox(height: MintSpacing.md + 4),
                _buildIntro(),
                const SizedBox(height: MintSpacing.lg),

                // Toggle Adult / Child
                _buildToggle(),
                const SizedBox(height: MintSpacing.lg),

                // Input sliders
                _buildPrimeSlider(),
                const SizedBox(height: MintSpacing.md),
                _buildDepensesSlider(),
                const SizedBox(height: MintSpacing.lg),

                // Results
                if (_result != null) ...[
                  _buildComparisonCards(),
                  const SizedBox(height: MintSpacing.md + 4),
                  _buildBreakEvenInfo(),
                  const SizedBox(height: MintSpacing.md + 4),
                  _buildRecommendations(),
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
        label: 'Retour',
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      title: Text(
        S.of(context)!.lamalFranchiseAppBarTitle,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ── Demo mode badge ──────────────────────────────────────

  Widget _buildDemoModeBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.sm + 2, vertical: MintSpacing.xs),
        decoration: BoxDecoration(
          color: MintColors.info.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
        ),
        child: Text(
          S.of(context)!.lamalFranchiseDemoMode,
          style: MintTextStyles.labelSmall(color: MintColors.info),
        ),
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

  // ── Toggle ─────────────────────────────────────────────────

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.xs),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: S.of(context)!.lamalFranchiseSelectAdulte,
              button: true,
              selected: !_isChild,
              child: GestureDetector(
                onTap: () {
                  if (_isChild) {
                    _isChild = false;
                    _compute();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(vertical: MintSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color:
                        !_isChild ? MintColors.white : MintColors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: !_isChild
                        ? [
                            BoxShadow(
                              color:
                                  MintColors.textPrimary.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      S.of(context)!.lamalFranchiseToggleAdulte,
                      style: MintTextStyles.bodyMedium(
                        color: !_isChild
                            ? MintColors.textPrimary
                            : MintColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              label: S.of(context)!.lamalFranchiseSelectEnfant,
              button: true,
              selected: _isChild,
              child: GestureDetector(
                onTap: () {
                  if (!_isChild) {
                    _isChild = true;
                    _compute();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(vertical: MintSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: _isChild ? MintColors.white : MintColors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _isChild
                        ? [
                            BoxShadow(
                              color:
                                  MintColors.textPrimary.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      S.of(context)!.lamalFranchiseToggleEnfant,
                      style: MintTextStyles.bodyMedium(
                        color: _isChild
                            ? MintColors.textPrimary
                            : MintColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Prime slider ───────────────────────────────────────────

  Widget _buildPrimeSlider() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: MintAmountField(
        label: S.of(context)!.lamalFranchisePrimeSliderLabel,
        value: _primeMensuelle,
        formatValue: (v) => LamalFranchiseService.formatChf(v),
        onChanged: (v) {
          setState(() {
            _primeMensuelle = v;
            _compute();
          });
        },
        min: 200,
        max: 600,
      ),
    );
  }

  // ── Depenses input ────────────────────────────────────────

  Widget _buildDepensesSlider() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: MintAmountField(
        label: S.of(context)!.lamalFranchiseDepensesSliderLabel,
        value: _depensesSante,
        formatValue: (v) => LamalFranchiseService.formatChf(v),
        onChanged: (v) {
          setState(() {
            _depensesSante = v;
            _compute();
          });
        },
        min: 0,
        max: 10000,
      ),
    );
  }

  // ── Comparison cards ───────────────────────────────────────

  Widget _buildComparisonCards() {
    final result = _result!;
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
                        style: MintTextStyles.labelSmall(
                                color: MintColors.success)
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
          style: MintTextStyles.bodySmall(color: color ?? MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── Break-even info ────────────────────────────────────────

  Widget _buildBreakEvenInfo() {
    final result = _result!;
    if (result.breakEvenPoints.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_vert, color: MintColors.info, size: 18),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.lamalFranchiseBreakEvenTitle,
                style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary),
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

  Widget _buildRecommendations() {
    final result = _result!;
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
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
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
