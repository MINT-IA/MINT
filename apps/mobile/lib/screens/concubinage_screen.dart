import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
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
// All text in French (informal "tu").
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
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 160,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: 16),
        title: Text(
          'Mariage vs Concubinage',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
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
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: 'Comparateur'),
          Tab(text: 'Checklist'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSlider(
            label: 'Revenu 1',
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
            label: 'Revenu 2',
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
            label: 'Patrimoine total',
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
                  'Canton',
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
    final isPenalite = _comparisonResult != null
        ? (_comparisonResult!['fiscal'] as Map<String, dynamic>)['isPenalite']
            as bool
        : false;
    return [
      ComparisonCriteria(
        label: 'Impots',
        marriageLabel: isPenalite ? 'Penalite fiscale' : 'Bonus fiscal',
        concubinageLabel: isPenalite ? 'Avantageux' : 'Desavantageux',
        advantage:
            isPenalite ? Advantage.concubinage : Advantage.marriage,
        icon: Icons.account_balance_outlined,
      ),
      ComparisonCriteria(
        label: 'Heritage',
        marriageLabel: 'Exonere (CC art. 462)',
        concubinageLabel: 'Impot cantonal',
        advantage: Advantage.marriage,
        icon: Icons.family_restroom,
      ),
      ComparisonCriteria(
        label: 'Protection deces',
        marriageLabel: 'AVS + LPP survivant',
        concubinageLabel: 'Aucune rente automatique',
        advantage: Advantage.marriage,
        icon: Icons.shield_outlined,
      ),
      ComparisonCriteria(
        label: 'Flexibilite',
        marriageLabel: 'Procedure judiciaire',
        concubinageLabel: 'Separation simplifiee',
        advantage: Advantage.concubinage,
        icon: Icons.swap_horiz,
      ),
      ComparisonCriteria(
        label: 'Pension alim.',
        marriageLabel: 'Protegee par le juge',
        concubinageLabel: 'Accord prealable',
        advantage: Advantage.marriage,
        icon: Icons.balance,
      ),
    ];
  }

  Widget _buildDecisionMatrix() {
    final result = _comparisonResult!;
    final fiscal = result['fiscal'] as Map<String, dynamic>;
    final isPenalite = fiscal['isPenalite'] as bool;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'MATRICE DE DECISION',
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

          // Headers
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'Mariage',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'Concubinage',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),

          // Rows
          _buildMatrixRow(
            'Impots',
            !isPenalite, // green if bonus
            isPenalite, // green if penalty for married = cheaper for concubin
          ),
          _buildMatrixRow('AVS survivant', true, false),
          _buildMatrixRow('LPP survivant', true, false),
          _buildMatrixRow('Heritage exonere', true, false),
          _buildMatrixRow('Pension alimentaire', true, false),
          _buildMatrixRow('Simplicite separation', false, true),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(String label, bool marriageGood, bool concubinGood) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: marriageGood
                      ? MintColors.success.withValues(alpha: 0.12)
                      : MintColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  marriageGood ? Icons.check : Icons.close,
                  size: 16,
                  color:
                      marriageGood ? MintColors.success : MintColors.error,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: concubinGood
                      ? MintColors.success.withValues(alpha: 0.12)
                      : MintColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  concubinGood ? Icons.check : Icons.close,
                  size: 16,
                  color:
                      concubinGood ? MintColors.success : MintColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                  style: GoogleFonts.montserrat(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'avantages',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mariage',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.white24,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$scoreConcubinage',
                  style: GoogleFonts.montserrat(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'avantages',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Concubinage',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
    final result = _comparisonResult!;
    final fiscal = result['fiscal'] as Map<String, dynamic>;
    final totalCelib = fiscal['totalCelibataires'] as double;
    final totalMarie = fiscal['totalMarie'] as double;
    final difference = fiscal['difference'] as double;
    final isPenalite = fiscal['isPenalite'] as bool;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                'DETAIL FISCAL',
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
            'Impots 2 celibataires',
            FamilyService.formatChf(totalCelib),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Impots maries',
            FamilyService.formatChf(totalMarie),
          ),
          const SizedBox(height: 8),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPenalite ? 'Penalite mariage' : 'Bonus mariage',
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
    final result = _comparisonResult!;
    final inheritance = result['inheritance'] as Map<String, dynamic>;
    final impot = inheritance['impot'] as double;
    final taux = inheritance['taux'] as double;

    if (impot <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                'IMPOT SUR LA SUCCESSION',
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
            'Patrimoine transmis',
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
                    _buildResultRow('Marie-e', 'CHF\u00A00 (exonere)'),
                    const SizedBox(height: 8),
                    _buildResultRow(
                      'Concubin-e (~${(taux * 100).toStringAsFixed(0)}%)',
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
                    'En concubinage, ton partenaire paierait '
                    '${FamilyService.formatChf(impot)} d\'impot successoral '
                    'sur un patrimoine de ${FamilyService.formatChf(_patrimoine)}. '
                    'Marie-e, il/elle serait totalement exonere-e.',
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
              color: Colors.white,
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
                  'Aucune option n\'est universellement meilleure',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Le choix entre mariage et concubinage depend de ta situation : '
                  'revenus, patrimoine, enfants, canton, projet de vie. '
                  'Le mariage offre plus de protections legales automatiques, '
                  'le concubinage plus de flexibilite. '
                  'Un-e specialiste peut t\'aider a y voir plus clair.',
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
    final items = _checklistItems;
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
                  'En concubinage, rien n\'est automatique. '
                  'Voici les protections essentielles a mettre en place '
                  'pour proteger ton/ta partenaire.',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$nbChecked/${items.length} protections en place',
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
              : Colors.white,
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
                                size: 15, color: Colors.white)
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

  static final List<Map<String, String>> _checklistItems = [
    {
      'title': 'Rediger un testament',
      'description':
          'Sans testament, ton partenaire n\'herite de rien — tout va a tes parents '
          'ou a tes freres et soeurs. Un testament olographe (ecrit a la main, date, signe) '
          'suffit. Tu peux leguer la quotite disponible a ton/ta partenaire.',
    },
    {
      'title': 'Clause beneficiaire LPP',
      'description':
          'Contacte ta caisse de pension pour inscrire ton/ta partenaire comme '
          'beneficiaire. Sans cette clause, le capital deces LPP ne lui revient pas. '
          'La plupart des caisses acceptent le concubin sous conditions (menage commun, etc.).',
    },
    {
      'title': 'Convention de concubinage',
      'description':
          'Un contrat ecrit qui regle le partage des frais, la propriete des biens, '
          'et ce qui se passe en cas de separation. Pas obligatoire, mais fortement '
          'recommande — surtout si tu achetes un bien immobilier ensemble.',
    },
    {
      'title': 'Assurance-vie croisee',
      'description':
          'Une assurance-vie ou chacun est beneficiaire de l\'autre permet de '
          'compenser l\'absence de rente AVS/LPP de survivant. '
          'Compare les offres — les primes dependent de l\'age et du capital assure.',
    },
    {
      'title': 'Mandat pour cause d\'inaptitude',
      'description':
          'Si tu deviens incapable de discernement (accident, maladie), ton/ta '
          'partenaire n\'a aucun pouvoir de representation. Un mandat pour cause '
          'd\'inaptitude (CC art. 360 ss) lui donne ce droit.',
    },
    {
      'title': 'Directives anticipees',
      'description':
          'Un document qui precise tes volontes medicales en cas d\'incapacite. '
          'Tu peux y designer ton/ta partenaire comme personne de confiance '
          'pour les decisions medicales (CC art. 370 ss).',
    },
    {
      'title': 'Compte joint pour les depenses communes',
      'description':
          'Un compte commun simplifie la gestion des depenses partagees '
          '(loyer, courses, factures). Definissez clairement la contribution de chacun. '
          'En cas de separation, le solde est partage a 50/50 sauf convention contraire.',
    },
    {
      'title': 'Bail commun ou individuel',
      'description':
          'Si tu es sur le bail avec ton/ta partenaire, vous etes solidairement responsables. '
          'En cas de separation, les deux doivent donner conge. '
          'Si un seul est titulaire, l\'autre n\'a aucun droit sur le logement.',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Informations simplifiees a but educatif — ne constitue pas '
              'un conseil juridique ou fiscal. Les regles dependent du canton, '
              'de la commune et de ta situation personnelle. '
              'Consulte un-e specialiste juridique pour un avis personnalise.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
