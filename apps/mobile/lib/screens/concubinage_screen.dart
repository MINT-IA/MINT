import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/visualizations/concubinage_decision_matrix.dart';

// ────────────────────────────────────────────────────────────
//  CONCUBINAGE SCREEN — Sprint S22 / Famille & Concubinage
// ────────────────────────────────────────────────────────────
//
// Two-tab decision-support screen:
//   Tab 1: "Comparateur" — Mariage vs Concubinage matrix
//   Tab 2: "Checklist"   — Essential protections for concubins
//
// All text in French (informal "tu").
// Material 3, MintColors theme, MintTextStyles.
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

  // ── Tab 2: Checklist state ────────────────────────────
  final Set<int> _checkedItems = {};
  final Map<int, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
            _buildTab2Checklist(),
          ],
        ),
      ),
    );
  }

  // ── App Bar with Tabs ──────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 110,
      backgroundColor: MintColors.white,
      foregroundColor: MintColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: 16),
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
        labelStyle: MintTextStyles.bodySmall().copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: MintTextStyles.bodySmall(),
        tabs: [
          Tab(text: S.of(context)!.concubinageTabComparateur),
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Inputs
        _buildComparateurInputs(),
        const SizedBox(height: 20),

        if (_comparisonResult != null) ...[
          // Decision matrix — animated comparison visualization
          ConcubinageDecisionMatrix(
            criteria: _matrixCriteria,
          ),
          const SizedBox(height: 20),

          // Score summary
          _buildScoreSummary(),
          const SizedBox(height: 20),

          // Fiscal detail
          _buildFiscalDetailCard(),
          const SizedBox(height: 20),

          // Inheritance detail
          _buildInheritanceCard(),
          const SizedBox(height: 20),
        ],

        // Neutral conclusion
        _buildNeutralConclusion(),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildComparateurInputs() {
    final sortedCodes = FamilyService.sortedCantonCodes;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSlider(
            label: S.of(context)!.concubinageRevenu1,
            value: _revenu1,
            min: 0,
            max: 300000,
            step: 5000,
            onChanged: (v) {
              _revenu1 = v;
              _recalculate();
            },
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.concubinageRevenu2,
            value: _revenu2,
            min: 0,
            max: 300000,
            step: 5000,
            onChanged: (v) {
              _revenu2 = v;
              _recalculate();
            },
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.concubinagePatrimoineTotal,
            value: _patrimoine,
            min: 0,
            max: 2000000,
            step: 50000,
            onChanged: (v) {
              _patrimoine = v;
              _recalculate();
            },
          ),
          const SizedBox(height: 20),

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
                padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
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
    );
  }

  Widget _buildFiscalDetailCard() {
    final result = _comparisonResult!;
    final fiscal = result['fiscal'] as Map<String, dynamic>;
    final totalCelib = fiscal['totalCelibataires'] as double;
    final totalMarie = fiscal['totalMarie'] as double;
    final difference = fiscal['difference'] as double;
    final isPenalite = fiscal['isPenalite'] as bool;

    return Container(
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
                style: MintTextStyles.titleMedium(color: isPenalite ? MintColors.error : MintColors.success).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
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

    return Container(
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
            child: const Icon(Icons.balance, size: 18, color: MintColors.primary),
          ),
          const SizedBox(width: 12),
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
  //  TAB 2: CHECKLIST — Essential steps for concubins
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Checklist() {
    final items = _checklistItems(context);
    final nbChecked = _checkedItems.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Intro
        Container(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.of(context)!.concubinageChecklistIntro,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Progress bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(20),
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
              const SizedBox(height: 12),
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
        const SizedBox(height: 20),

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
        const SizedBox(height: 20),

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
      padding: const EdgeInsets.only(bottom: 10),
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
            // Header row (checkbox + title + expand)
            Semantics(
              label: 'Développer : $title',
              button: true,
              child: GestureDetector(
              onTap: () {
                setState(() {
                  _expandedItems[index] = !isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    Semantics(
                      label: 'Cocher : $title',
                      button: true,
                      child: GestureDetector(
                      onTap: () {
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
                    const SizedBox(width: 12),

                    // Title
                    Expanded(
                      child: Text(
                        title,
                        style: MintTextStyles.bodyMedium(color: isChecked ? MintColors.textMuted : MintColors.textPrimary).copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),

                    // Expand icon
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

            // Expandable description
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.fromLTRB(52, 0, 16, 16),
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

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
  }) {
    final divisions = ((max - min) / step).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              FamilyService.formatChf(value),
              style: MintTextStyles.titleMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
            overlayColor: MintColors.primary.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : 1,
            onChanged: (v) {
              setState(() {
                onChanged((v / step).round() * step);
              });
            },
          ),
        ),
      ],
    );
  }

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
              S.of(context)!.concubinageDisclaimer,
              style: MintTextStyles.labelSmall(color: MintColors.deepOrange).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
