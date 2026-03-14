import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/widgets/visualizations/concubinage_decision_matrix.dart';

// ────────────────────────────────────────────────────────────
//  CONCUBINAGE SCREEN — Sprint S22 / Famille & Concubinage
// ────────────────────────────────────────────────────────────
//
// Two-tab decision-support screen:
//   Tab 1: "Comparateur" — Mariage vs Concubinage matrix
//   Tab 2: "Checklist"   — Essential protections for concubins
//
// All text via S (i18n).
// Material 3, MintColors theme, GoogleFonts.
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
    final s = S.of(context)!;
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 160,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: 16),
        title: Text(
          s.concubinageTitle,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: MintColors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: MintColors.white,
        indicatorWeight: 3,
        labelColor: MintColors.white,
        unselectedLabelColor: MintColors.white60,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        tabs: [
          Tab(text: s.concubinageTabComparateur),
          Tab(text: s.concubinageTabChecklist),
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
    final s = S.of(context)!;

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
            label: s.concubinageRevenu1,
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
            label: s.concubinageRevenu2,
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
            label: s.concubinagePatrimoineTotal,
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
                  s.concubinageCanton,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
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
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textPrimary,
                    ),
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
    final s = S.of(context)!;
    final isPenalite = _comparisonResult != null
        ? (_comparisonResult!['fiscal'] as Map<String, dynamic>)['isPenalite']
            as bool
        : false;
    return [
      ComparisonCriteria(
        label: s.concubinageCriteriaImpots,
        marriageLabel: isPenalite ? s.concubinagePenaliteFiscale : s.concubinageBonusFiscal,
        concubinageLabel: isPenalite ? s.concubinageAvantageux : s.concubinageDesavantageux,
        advantage:
            isPenalite ? Advantage.concubinage : Advantage.marriage,
        icon: Icons.account_balance_outlined,
      ),
      ComparisonCriteria(
        label: s.concubinageCriteriaHeritage,
        marriageLabel: s.concubinageExonereCc462,
        concubinageLabel: s.concubinageImpotCantonal,
        advantage: Advantage.marriage,
        icon: Icons.family_restroom,
      ),
      ComparisonCriteria(
        label: s.concubinageCriteriaProtectionDeces,
        marriageLabel: s.concubinageAvsSurvivor,
        concubinageLabel: s.concubinageAucuneRenteAuto,
        advantage: Advantage.marriage,
        icon: Icons.shield_outlined,
      ),
      ComparisonCriteria(
        label: s.concubinageCriteriaFlexibilite,
        marriageLabel: s.concubinageProcedureJudiciaire,
        concubinageLabel: s.concubinageSeparationSimplifiee,
        advantage: Advantage.concubinage,
        icon: Icons.swap_horiz,
      ),
      ComparisonCriteria(
        label: s.concubinageCriteriaPensionAlim,
        marriageLabel: s.concubinageProtegeeParJuge,
        concubinageLabel: s.concubinageAccordPrealable,
        advantage: Advantage.marriage,
        icon: Icons.balance,
      ),
    ];
  }

  Widget _buildScoreSummary() {
    final s = S.of(context)!;
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
                  style: GoogleFonts.montserrat(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: MintColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.concubinageAvantages,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.white60,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.concubinageMariage,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.white,
                  ),
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
                  style: GoogleFonts.montserrat(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: MintColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.concubinageAvantages,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.white60,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.concubinageConcubinage,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiscalDetailCard() {
    final s = S.of(context)!;
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
                s.concubinageDetailFiscal,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            s.concubinageImpots2Celibataires,
            FamilyService.formatChf(totalCelib),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            s.concubinageImpotsMaries,
            FamilyService.formatChf(totalMarie),
          ),
          const SizedBox(height: 8),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPenalite ? s.concubinagePenaliteMariage : s.concubinageBonusMariage,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                '${isPenalite ? "+" : "-"}${FamilyService.formatChf(difference.abs())}',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isPenalite ? MintColors.error : MintColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInheritanceCard() {
    final s = S.of(context)!;
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
                s.concubinageImpotSuccession,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            s.concubinagePatrimoineTransmis,
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
                    _buildResultRow(s.concubinageMarieE, s.concubinageExonereZero),
                    const SizedBox(height: 8),
                    _buildResultRow(
                      s.concubinageConcubinTaux((taux * 100).toStringAsFixed(0)),
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
                    s.concubinageWarningSuccession(
                      FamilyService.formatChf(impot),
                      FamilyService.formatChf(_patrimoine),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textPrimary,
                      height: 1.4,
                    ),
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
    final s = S.of(context)!;
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
                  s.concubinageNeutralTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.concubinageNeutralBody,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
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
    final s = S.of(context)!;
    final items = _getChecklistItems(s);
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
                  s.concubinageChecklistIntro,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
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
                    s.concubinageProtectionsEnPlace(
                      '$nbChecked',
                      '${items.length}',
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${(nbChecked / items.length * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: nbChecked == items.length
                          ? MintColors.success
                          : MintColors.primary,
                    ),
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
            GestureDetector(
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
                    GestureDetector(
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
                              : Colors.transparent,
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
                    const SizedBox(width: 12),

                    // Title
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isChecked
                              ? MintColors.textMuted
                              : MintColors.textPrimary,
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
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

            // Expandable description
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.fromLTRB(52, 0, 16, 16),
                child: Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
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

  List<Map<String, String>> _getChecklistItems(S s) {
    return [
      {
        'title': s.concubinageChecklistTitle1,
        'description': s.concubinageChecklistDesc1,
      },
      {
        'title': s.concubinageChecklistTitle2,
        'description': s.concubinageChecklistDesc2,
      },
      {
        'title': s.concubinageChecklistTitle3,
        'description': s.concubinageChecklistDesc3,
      },
      {
        'title': s.concubinageChecklistTitle4,
        'description': s.concubinageChecklistDesc4,
      },
      {
        'title': s.concubinageChecklistTitle5,
        'description': s.concubinageChecklistDesc5,
      },
      {
        'title': s.concubinageChecklistTitle6,
        'description': s.concubinageChecklistDesc6,
      },
      {
        'title': s.concubinageChecklistTitle7,
        'description': s.concubinageChecklistDesc7,
      },
      {
        'title': s.concubinageChecklistTitle8,
        'description': s.concubinageChecklistDesc8,
      },
    ];
  }

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
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textSecondary,
                ),
              ),
            ),
            Text(
              FamilyService.formatChf(value),
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.primary,
              ),
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
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    final s = S.of(context)!;
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
              s.concubinageDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.deepOrange,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
