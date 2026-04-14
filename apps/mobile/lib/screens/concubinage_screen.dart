import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/visualizations/concubinage_decision_matrix.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/coach/survivor_pension_widget.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

// ────────────────────────────────────────────────────────────
//  CONCUBINAGE SCREEN — Category C (Life Event)
// ────────────────────────────────────────────────────────────
//
// Three-tab decision-support screen:
//   Tab 1: "Comparateur" — Mariage vs Concubinage matrix + hero chiffre-choc
//   Tab 2: "Protection"  — Survivor benefits gap + comparison table
//   Tab 3: "Checklist"   — Essential protections for concubins
//
// Design System: MintTextStyles + MintSpacing tokens.
// AppBar: white standard (Life Event screen).
// Ne constitue pas un conseil juridique ou fiscal (LSFin).
// ────────────────────────────────────────────────────────────

class ConcubinageScreen extends StatefulWidget {
  const ConcubinageScreen({super.key});

  @override
  State<ConcubinageScreen> createState() => _ConcubinageScreenState();
}

class _ConcubinageScreenState extends State<ConcubinageScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Comparateur inputs ─────────────────────────
  double _revenu1 = 80000;
  double _revenu2 = 60000;
  double _patrimoine = 300000;
  String _canton = 'VD';
  Map<String, dynamic>? _comparisonResult;

  // ── Tab 2: Protection ─────────────────────────────────
  double _renteLpp = 2500;

  // ── Tab 3: Checklist state ────────────────────────────
  final Set<int> _checkedItems = {};
  final Map<int, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _recalculate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _comparisonResult = FamilyService.compareMariageVsConcubinage(
        revenu1: _revenu1,
        revenu2: _revenu2,
        canton: _canton,
        patrimoine: _patrimoine,
      );
    });
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(context, innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTab1Comparateur(),
            _buildTab2Protection(),
            _buildTab3Checklist(),
          ],
        ),
      ),
    );
  }

  // ── App Bar with Tabs (white standard — Life Event) ──

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 120,
      backgroundColor: MintColors.white,
      elevation: 0,
      surfaceTintColor: MintColors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: MintSpacing.md),
        title: Text(
          S.of(context)!.concubinageAppBarTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: MintColors.primary,
        indicatorWeight: 3,
        labelColor: MintColors.textPrimary,
        unselectedLabelColor: MintColors.textMuted,
        labelStyle: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        unselectedLabelStyle: MintTextStyles.bodySmall(color: MintColors.textMuted),
        tabs: [
          Tab(text: S.of(context)!.concubinageTabComparateur),
          Tab(text: S.of(context)!.concubinageTabProtection),
          Tab(text: S.of(context)!.concubinageTabChecklist),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: COMPARATEUR — Mariage vs Concubinage
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Comparateur() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Hero chiffre-choc — patrimoine exposed
        if (_patrimoine > 0) ...[
          MintEntrance(child: _buildHeroPremierEclairage()),
          const SizedBox(height: MintSpacing.lg),
        ],

        // Inputs
        MintEntrance(
          delay: const Duration(milliseconds: 100),
          child: _buildComparateurInputs(),
        ),
        const SizedBox(height: MintSpacing.lg),

        if (_comparisonResult != null) ...[
          // Decision matrix — animated comparison visualization
          MintEntrance(
            delay: const Duration(milliseconds: 150),
            child: ConcubinageDecisionMatrix(
              criteria: _matrixCriteria,
            ),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Score summary
          MintEntrance(
            delay: const Duration(milliseconds: 200),
            child: _buildScoreSummary(),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Fiscal detail
          MintEntrance(
            delay: const Duration(milliseconds: 250),
            child: _buildFiscalDetailCard(),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Inheritance detail
          MintEntrance(
            delay: const Duration(milliseconds: 300),
            child: _buildInheritanceCard(),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],

        // Educational insert — AVS cap 150% (LAVS art. 35)
        MintEntrance(
          delay: const Duration(milliseconds: 350),
          child: _buildEducationalInsert(
            S.of(context)!.concubinageEducationalAvs,
          ),
        ),
        const SizedBox(height: MintSpacing.md),

        // Educational insert — Succession
        MintEntrance(
          delay: const Duration(milliseconds: 400),
          child: _buildEducationalInsert(
            S.of(context)!.concubinageEducationalSuccession,
          ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Neutral conclusion
        MintEntrance(
          delay: const Duration(milliseconds: 450),
          child: _buildNeutralConclusion(),
        ),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildHeroPremierEclairage() {
    return Semantics(
      label: S.of(context)!.concubinageHeroPremierEclairage(
        FamilyService.formatChf(_patrimoine),
      ),
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            MintHeroNumber(
              value: FamilyService.formatChf(_patrimoine),
              caption: S.of(context)!.concubinageHeroPremierEclairageDesc,
              color: MintColors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparateurInputs() {
    final sortedCodes = FamilyService.sortedCantonCodes;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintAmountField(
            label: S.of(context)!.concubinageRevenu1,
            value: _revenu1,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _revenu1 = v;
                _recalculate();
              });
            },
            min: 0,
            max: 300000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            label: S.of(context)!.concubinageRevenu2,
            value: _revenu2,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _revenu2 = v;
                _recalculate();
              });
            },
            min: 0,
            max: 300000,
          ),
          const SizedBox(height: MintSpacing.md),
          MintAmountField(
            label: S.of(context)!.concubinagePatrimoineTotal,
            value: _patrimoine,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _patrimoine = v;
                _recalculate();
              });
            },
            min: 0,
            max: 2000000,
          ),
          const SizedBox(height: MintSpacing.lg),

          // Canton dropdown
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.concubinageCanton,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _canton,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code — ${FamilyService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _canton = v;
                        _recalculate();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<ComparisonCriteria> get _matrixCriteria {
    final isPenalite = _comparisonResult != null
        ? (_comparisonResult!['fiscal'] as Map<String, dynamic>)['isPenalite']
            as bool
        : false;
    return [
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaImpots,
        marriageLabel: isPenalite ? S.of(context)!.concubinageCriteriaPenaliteFiscale : S.of(context)!.concubinageCriteriaBonusFiscal,
        concubinageLabel: isPenalite ? S.of(context)!.concubinageCriteriaAvantageux : S.of(context)!.concubinageCriteriaDesavantageux,
        advantage:
            isPenalite ? Advantage.concubinage : Advantage.marriage,
        icon: Icons.account_balance_outlined,
      ),
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaHeritage,
        marriageLabel: S.of(context)!.concubinageCriteriaHeritageMarriage,
        concubinageLabel: S.of(context)!.concubinageCriteriaHeritageConcubinage,
        advantage: Advantage.marriage,
        icon: Icons.family_restroom,
      ),
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaProtection,
        marriageLabel: S.of(context)!.concubinageCriteriaProtectionMarriage,
        concubinageLabel: S.of(context)!.concubinageCriteriaProtectionConcubinage,
        advantage: Advantage.marriage,
        icon: Icons.shield_outlined,
      ),
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaFlexibilite,
        marriageLabel: S.of(context)!.concubinageCriteriaFlexibiliteMarriage,
        concubinageLabel: S.of(context)!.concubinageCriteriaFlexibiliteConcubinage,
        advantage: Advantage.concubinage,
        icon: Icons.swap_horiz,
      ),
      ComparisonCriteria(
        label: S.of(context)!.concubinageCriteriaPension,
        marriageLabel: S.of(context)!.concubinageCriteriaPensionMarriage,
        concubinageLabel: S.of(context)!.concubinageCriteriaPensionConcubinage,
        advantage: Advantage.marriage,
        icon: Icons.balance,
      ),
    ];
  }

  Widget _buildScoreSummary() {
    final result = _comparisonResult!;
    final scoreMariage = result['scoreMariage'] as int;
    final scoreConcubinage = result['scoreConcubinage'] as int;

    return Semantics(
      label: '${S.of(context)!.concubinageMariage}: $scoreMariage ${S.of(context)!.concubinageAvantages}, ${S.of(context)!.concubinageConcubinage}: $scoreConcubinage ${S.of(context)!.concubinageAvantages}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$scoreMariage',
                    style: MintTextStyles.displayMedium(color: MintColors.white).copyWith(fontSize: 36, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    S.of(context)!.concubinageAvantages,
                    style: MintTextStyles.labelSmall(color: MintColors.white60),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.of(context)!.concubinageMariage,
                    style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: MintColors.white24,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$scoreConcubinage',
                    style: MintTextStyles.displayMedium(color: MintColors.white).copyWith(fontSize: 36, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    S.of(context)!.concubinageAvantages,
                    style: MintTextStyles.labelSmall(color: MintColors.white60),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.of(context)!.concubinageConcubinage,
                    style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiscalDetailCard() {
    final result = _comparisonResult!;
    final fiscal = result['fiscal'] as Map<String, dynamic>;
    final totalCelib = fiscal['totalCelibataires'] as double;
    final totalMarie = fiscal['totalMarie'] as double;
    final difference = fiscal['difference'] as double;
    final isPenalite = fiscal['isPenalite'] as bool;

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.concubinageDetailFiscal,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            S.of(context)!.concubinageImpots2Celibataires,
            FamilyService.formatChf(totalCelib),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.concubinageImpotsMaries,
            FamilyService.formatChf(totalMarie),
          ),
          const SizedBox(height: 8),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPenalite ? S.of(context)!.concubinagePenaliteMariage : S.of(context)!.concubinageBonusMariage,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${isPenalite ? "+" : "-"}${FamilyService.formatChf(difference.abs())}',
                style: MintTextStyles.titleLarge(color: isPenalite ? MintColors.error : MintColors.success).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInheritanceCard() {
    final result = _comparisonResult!;
    final inheritance = result['inheritance'] as Map<String, dynamic>;
    final impot = inheritance['impot'] as double;
    final taux = inheritance['taux'] as double;

    if (impot <= 0) return const SizedBox.shrink();

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.concubinageImpotSuccession,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            S.of(context)!.concubinagePatrimoineTransmis,
            FamilyService.formatChf(_patrimoine),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultRow(S.of(context)!.concubinageMarieExonereLabel, S.of(context)!.concubinageMarieExonere),
                    const SizedBox(height: 8),
                    _buildResultRow(
                      S.of(context)!.concubinageConcubinTaux((taux * 100).toStringAsFixed(0)),
                      FamilyService.formatChf(impot),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber,
                    size: 18, color: MintColors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of(context)!.concubinageWarningSuccession(FamilyService.formatChf(impot), FamilyService.formatChf(_patrimoine)),
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeutralConclusion() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.xs + 2),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.balance, size: 18, color: MintColors.primary),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.concubinageNeutralTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.concubinageNeutralDesc,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: PROTECTION — Survivor benefits gap
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Protection() {
    const avsSurvivor = avsRenteMaxMensuelle * FamilyService.avsSurvivorFactor;
    final lppSurvivor = _renteLpp * FamilyService.lppSurvivorFactor;
    final totalSurvivorMarried = avsSurvivor + lppSurvivor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Intro
        MintEntrance(child: Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  color: MintColors.info, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  S.of(context)!.concubinageProtectionIntro,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // LPP slider
        MintEntrance(
          delay: const Duration(milliseconds: 100),
          child: MintSurface(
          tone: MintSurfaceTone.blanc,
          elevated: true,
          child: MintAmountField(
            label: S.of(context)!.concubinageProtectionLppSlider,
            value: _renteLpp,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _renteLpp = v;
              });
            },
            min: 0,
            max: 8000,
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Side-by-side chiffre-choc: Married vs Concubin survivor total
        MintEntrance(
          delay: const Duration(milliseconds: 150),
          child: Row(
          children: [
            // Married survivor
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      FamilyService.formatChf(totalSurvivorMarried),
                      style: MintTextStyles.headlineSmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      S.of(context)!.concubinageProtectionMaried,
                      style: MintTextStyles.labelSmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            // Concubin survivor
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                decoration: BoxDecoration(
                  color: MintColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'CHF\u00a00',
                      style: MintTextStyles.headlineSmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      S.of(context)!.concubinageProtectionConcubinLabel,
                      style: MintTextStyles.labelSmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
        const SizedBox(height: MintSpacing.sm),
        Text(
          S.of(context)!.concubinageProtectionSurvivorZero,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MintSpacing.lg),

        // Comparison table: married vs concubin
        MintEntrance(
          delay: const Duration(milliseconds: 200),
          child: _buildProtectionComparison(),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Educational insert — LPP survivor
        MintEntrance(
          delay: const Duration(milliseconds: 250),
          child: _buildEducationalInsert(
            S.of(context)!.concubinageEducationalLpp,
          ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Clause 3a widget
        MintEntrance(
          delay: const Duration(milliseconds: 300),
          child: _buildClause3aSection(),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Survivor pension widget (concubin mode)
        MintEntrance(
          delay: const Duration(milliseconds: 350),
          child: SurvivorPensionWidget(
          partnerAvsRente: avsRenteMaxMensuelle,
          partnerLppMonthly: _renteLpp,
          isConcubin: true,
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildClause3aSection() {
    final profile = context.read<CoachProfileProvider>().profile;
    final balance = profile?.prevoyance.totalEpargne3a ?? 0;
    final estimated = balance > 0
        ? balance
        : (_revenu1 + _revenu2) * 0.05 * 10;
    return Clause3aWidget(
      balance3a: estimated,
    );
  }

  Widget _buildProtectionComparison() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                child: Center(
                  child: Text(
                    S.of(context)!.concubinageProtectionMaried,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    S.of(context)!.concubinageProtectionConcubinLabel,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildComparisonRow(S.of(context)!.concubinageProtectionAvsSurvivor, true, false),
          _buildComparisonRow(S.of(context)!.concubinageProtectionLppSurvivor, true, false),
          _buildComparisonRow(S.of(context)!.concubinageProtectionHeritage, true, false),
          _buildComparisonRow(S.of(context)!.concubinageProtectionPension, true, false),
          _buildComparisonRow(S.of(context)!.concubinageProtectionAvsPlafond, false, true),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber,
                    size: 18, color: MintColors.error),
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Text(
                    S.of(context)!.concubinageProtectionWarning,
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, bool married, bool concubin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                married ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: married ? MintColors.success : MintColors.error,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                concubin ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: concubin ? MintColors.success : MintColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: CHECKLIST — Essential steps for concubins
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Checklist() {
    final items = _checklistItems(context);
    final nbChecked = _checkedItems.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Intro
        MintEntrance(child: Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.checklist_rtl,
                  color: MintColors.info, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  S.of(context)!.concubinageChecklistIntro,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Progress bar
        MintEntrance(
          delay: const Duration(milliseconds: 100),
          child: Container(
          padding: const EdgeInsets.all(MintSpacing.lg),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context)!.concubinageProtectionsCount(nbChecked, items.length),
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(nbChecked / items.length * 100).toStringAsFixed(0)}%',
                    style: MintTextStyles.titleMedium(color: nbChecked == items.length ? MintColors.success : MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.sm + 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: LinearProgressIndicator(
                    value: items.isNotEmpty ? nbChecked / items.length : 0,
                    backgroundColor: MintColors.appleSurface,
                    color: nbChecked == items.length
                        ? MintColors.success
                        : MintColors.primary,
                    minHeight: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Checklist items
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildChecklistItem(
            index: index,
            title: item['title'] as String,
            description: item['description'] as String,
          );
        }),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildChecklistItem({
    required int index,
    required String title,
    required String description,
  }) {
    final isChecked = _checkedItems.contains(index);
    final isExpanded = _expandedItems[index] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isChecked
              ? MintColors.success.withValues(alpha: 0.04)
              : MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChecked
                ? MintColors.success.withValues(alpha: 0.3)
                : MintColors.lightBorder,
          ),
        ),
        child: Column(
          children: [
            Semantics(
              label: title,
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedItems[index] = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(MintSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: title,
                        button: true,
                        toggled: isChecked,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (isChecked) {
                                _checkedItems.remove(index);
                              } else {
                                _checkedItems.add(index);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? MintColors.success
                                  : MintColors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: isChecked
                                    ? MintColors.success
                                    : MintColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: isChecked
                                ? const Icon(Icons.check,
                                    size: 15, color: MintColors.white)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: MintSpacing.sm + 4),
                      Expanded(
                        child: Text(
                          title,
                          style: MintTextStyles.bodyMedium(
                            color: isChecked
                                ? MintColors.textMuted
                                : MintColors.textPrimary,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            decoration:
                                isChecked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: MintColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.fromLTRB(52, 0, MintSpacing.md, MintSpacing.md),
                child: Text(
                  description,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  CHECKLIST DATA
  // ════════════════════════════════════════════════════════════

  List<Map<String, String>> _checklistItems(BuildContext context) => [
    {
      'title': S.of(context)!.concubinageChecklist1Title,
      'description': S.of(context)!.concubinageChecklist1Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist2Title,
      'description': S.of(context)!.concubinageChecklist2Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist3Title,
      'description': S.of(context)!.concubinageChecklist3Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist4Title,
      'description': S.of(context)!.concubinageChecklist4Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist5Title,
      'description': S.of(context)!.concubinageChecklist5Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist6Title,
      'description': S.of(context)!.concubinageChecklist6Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist7Title,
      'description': S.of(context)!.concubinageChecklist7Desc,
    },
    {
      'title': S.of(context)!.concubinageChecklist8Title,
      'description': S.of(context)!.concubinageChecklist8Desc,
    },
  ];

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(String text) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.xs + 2),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.lightbulb_outline, size: 18, color: MintColors.info),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.lifeEventDidYouKnow,
                  style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  text,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.concubinageDisclaimer,
              style: MintTextStyles.labelMedium(color: MintColors.deepOrange).copyWith(height: 1.5, fontStyle: FontStyle.normal),
            ),
          ),
        ],
      ),
    );
  }
}
