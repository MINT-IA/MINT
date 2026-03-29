import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/coach/top_cantons_widget.dart';
import 'package:mint_mobile/widgets/coach/avs_gap_widget.dart';
import 'package:mint_mobile/widgets/coach/expat_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/expat_rights_loss_widget.dart';

// ────────────────────────────────────────────────────────────
//  EXPAT SCREEN — Sprint S23 / Expatriation + Frontaliers
// ────────────────────────────────────────────────────────────
//
// Design System: Category C — Life Event.
// Three-tab interactive screen for expatriation planning:
//   Tab 1: "Forfait"  — Lump-sum taxation simulator
//   Tab 2: "Départ"   — Departure planning checklist
//   Tab 3: "AVS"      — Pension gap estimator
//
// Ne constitue pas un conseil fiscal ou juridique (LSFin).
// ────────────────────────────────────────────────────────────

class ExpatScreen extends StatefulWidget {
  const ExpatScreen({super.key});

  @override
  State<ExpatScreen> createState() => _ExpatScreenState();
}

class _ExpatScreenState extends State<ExpatScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Forfait inputs ─────────────────────────────
  String _forfaitCanton = 'VD';
  double _livingExpenses = 1000000;
  double _actualIncome = 5000000;
  Map<String, dynamic>? _forfaitResult;

  // ── Tab 2: Depart inputs ──────────────────────────────
  DateTime _departureDate = DateTime.now().add(const Duration(days: 180));
  String _departCanton = 'VD';
  double _pillar3aBalance = 80000;
  double _lppBalance = 250000;
  Map<String, dynamic>? _departResult;
  final Set<String> _completedChecklist = {};

  // ── Tab 3: AVS inputs ─────────────────────────────────
  int _yearsInCh = 20;
  int _yearsAbroad = 10;
  Map<String, dynamic>? _avsResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _recalculateForfait();
    _recalculateDepart();
    _recalculateAvs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recalculateForfait() {
    setState(() {
      _forfaitResult = ExpatService.simulateForfaitFiscal(
        canton: _forfaitCanton,
        livingExpenses: _livingExpenses,
        actualIncome: _actualIncome,
      );
    });
  }

  void _recalculateDepart() {
    setState(() {
      _departResult = ExpatService.planDeparture(
        departureDate: _departureDate,
        canton: _departCanton,
        pillar3aBalance: _pillar3aBalance,
        lppBalance: _lppBalance,
      );
    });
  }

  void _recalculateAvs() {
    setState(() {
      _avsResult = ExpatService.estimateAvsGap(
        yearsAbroad: _yearsAbroad,
        yearsInCh: _yearsInCh,
      );
    });
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(context, innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTab1Forfait(),
            _buildTab2Depart(),
            _buildTab3Avs(),
          ],
        ),
      ),
    );
  }

  // ── App Bar with Tabs — white standard ──────────────────

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    final l = S.of(context)!;
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Semantics(
        header: true,
        child: Text(
          l.expatTitle,
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
        unselectedLabelStyle: MintTextStyles.bodySmall(),
        tabs: [
          Tab(text: l.expatTabForfait),
          Tab(text: l.expatTabDeparture),
          Tab(text: l.expatTabAvs),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: FORFAIT — Lump-sum Taxation
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Forfait() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, MintSpacing.xxl),
      children: [
        _buildForfaitInputCard(),
        const SizedBox(height: MintSpacing.lg),
        if (_forfaitResult != null) ...[
          _buildForfaitResultCard(),
          const SizedBox(height: MintSpacing.lg),
        ],
        _buildAbolishedWarning(),
        const SizedBox(height: MintSpacing.lg),
        _buildEducationalInsert(
          S.of(context)!.expatForfaitEducation,
        ),
        const SizedBox(height: MintSpacing.lg),
        _buildTopCantonSection(),
        const SizedBox(height: MintSpacing.lg),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildTopCantonSection() {
    final scale = (_actualIncome / 100000).clamp(0.3, 10.0);
    return TopCantonWidget(
      currentCanton: _departCanton,
      rankings: [
        CantonRanking(
          rank: 1,
          canton: 'Schwyz',
          shortCode: 'SZ',
          annualTaxSaving: (8500 * scale).roundToDouble(),
          monthlyLamal: 310,
          monthlyRent: 1800,
          highlight: S.of(context)!.expatHighlightSchwyz,
        ),
        CantonRanking(
          rank: 2,
          canton: 'Zoug',
          shortCode: 'ZG',
          annualTaxSaving: (7200 * scale).roundToDouble(),
          monthlyLamal: 295,
          monthlyRent: 2200,
          highlight: S.of(context)!.expatHighlightZug,
        ),
        CantonRanking(
          rank: 3,
          canton: 'Nidwald',
          shortCode: 'NW',
          annualTaxSaving: (5800 * scale).roundToDouble(),
          monthlyLamal: 288,
          monthlyRent: 1600,
        ),
        CantonRanking(
          rank: 4,
          canton: 'Uri',
          shortCode: 'UR',
          annualTaxSaving: (5100 * scale).roundToDouble(),
          monthlyLamal: 280,
          monthlyRent: 1400,
        ),
        CantonRanking(
          rank: 5,
          canton: 'Appenzell Rh.-Int.',
          shortCode: 'AI',
          annualTaxSaving: (4600 * scale).roundToDouble(),
          monthlyLamal: 285,
          monthlyRent: 1500,
        ),
      ],
    );
  }

  Widget _buildForfaitInputCard() {
    final l = S.of(context)!;
    final eligibleCantons = ExpatService.eligibleForfaitCantons;

    if (!eligibleCantons.contains(_forfaitCanton)) {
      _forfaitCanton = eligibleCantons.first;
    }

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
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
              Expanded(
                child: Text(
                  l.expatCanton,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _forfaitCanton,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary),
                    items: eligibleCantons.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code \u2014 ${ExpatService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _forfaitCanton = v;
                        _recalculateForfait();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),
          MintAmountField(
            label: l.expatLivingExpenses,
            value: _livingExpenses,
            formatValue: (v) => ExpatService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _livingExpenses = v;
                _recalculateForfait();
              });
            },
            min: 250000,
            max: 5000000,
          ),
          const SizedBox(height: MintSpacing.lg),
          MintAmountField(
            label: l.expatActualIncome,
            value: _actualIncome,
            formatValue: (v) => ExpatService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _actualIncome = v;
                _recalculateForfait();
              });
            },
            min: 500000,
            max: 20000000,
          ),
        ],
      ),
    );
  }

  Widget _buildForfaitResultCard() {
    final l = S.of(context)!;
    final result = _forfaitResult!;

    if (result['abolished'] == true) {
      return Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block, size: 20, color: MintColors.error),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                result['note'] as String,
                style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    final forfaitTax = result['forfaitTax'] as double;
    final ordinaryTax = result['ordinaryTax'] as double;
    final savings = result['savings'] as double;
    final savingsPercent = result['savingsPercent'] as double;
    final forfaitBase = result['forfaitBase'] as double;
    final isFavorable = result['isFavorable'] as bool;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatTaxComparison,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          // Side by side
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(MintSpacing.md),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 24, color: MintColors.textSecondary),
                      const SizedBox(height: MintSpacing.sm),
                      Text(
                        l.expatForfaitFiscal,
                        style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MintSpacing.sm),
                      Text(
                        ExpatService.formatChf(forfaitTax),
                        style: MintTextStyles.titleMedium(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        l.expatForfaitBase(
                            ExpatService.formatChf(forfaitBase)),
                        style: MintTextStyles.labelSmall(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(MintSpacing.md),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_outlined,
                          size: 24, color: MintColors.textSecondary),
                      const SizedBox(height: MintSpacing.sm),
                      Text(
                        l.expatOrdinaryTaxation,
                        style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MintSpacing.sm),
                      Text(
                        ExpatService.formatChf(ordinaryTax),
                        style: MintTextStyles.titleMedium(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        l.expatOnActualIncome,
                        style: MintTextStyles.labelSmall(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Savings badge
          Semantics(
            label: isFavorable
                ? l.expatSavingsBadge(ExpatService.formatChf(savings.abs()),
                    savingsPercent.toStringAsFixed(0))
                : l.expatForfaitMoreCostly(
                    ExpatService.formatChf(savings.abs())),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.lg, vertical: MintSpacing.sm),
              decoration: BoxDecoration(
                color: isFavorable
                    ? MintColors.success.withValues(alpha: 0.1)
                    : MintColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFavorable
                      ? MintColors.success.withValues(alpha: 0.3)
                      : MintColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFavorable ? Icons.trending_down : Icons.trending_up,
                    size: 20,
                    color: isFavorable
                        ? MintColors.success
                        : MintColors.warning,
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Flexible(
                    child: Text(
                      isFavorable
                          ? l.expatSavingsBadge(
                              ExpatService.formatChf(savings.abs()),
                              savingsPercent.toStringAsFixed(0))
                          : l.expatForfaitMoreCostly(
                              ExpatService.formatChf(savings.abs())),
                      style: MintTextStyles.titleMedium(
                        color: isFavorable
                            ? MintColors.success
                            : MintColors.warning,
                      ),
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

  Widget _buildAbolishedWarning() {
    final l = S.of(context)!;
    final abolished = ExpatService.forfaitAbolishedCantons.toList()..sort();
    final names =
        abolished.map((c) => ExpatService.cantonNames[c] ?? c).join(', ');

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber,
              size: 18, color: MintColors.warning),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.expatAbolishedCantons,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.warning),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  l.expatAbolishedNote(names),
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: DEPART — Departure Planning
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Depart() {
    final l = S.of(context)!;
    // Chiffre-choc for tab 2: total capital at stake
    final totalCapital = _pillar3aBalance + _lppBalance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, MintSpacing.xxl),
      children: [
        // ── Chiffre-choc hero for Tab 2 ──
        if (totalCapital > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.lg),
            child: Semantics(
              label: l.expatDepartChiffreChoc(
                  ExpatService.formatChf(totalCapital)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(MintSpacing.lg),
                decoration: BoxDecoration(
                  color: MintColors.info.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: MintColors.info.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    Text(
                      ExpatService.formatChf(totalCapital),
                      style: MintTextStyles.displayMedium(
                          color: MintColors.info),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      l.expatDepartChiffreChoc(
                          ExpatService.formatChf(totalCapital)),
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

        _buildDepartInputCard(),
        const SizedBox(height: MintSpacing.lg),
        _buildNoExitTaxBadge(),
        const SizedBox(height: MintSpacing.lg),
        ExpatCountdownWidget(
          departureDate: _departureDate,
          deadlines: const [
            ExpatDeadline(
              label: '3\u00e8me pilier 3a \u2014 cl\u00f4ture ou gel',
              emoji: '\u{1F3E6}',
              daysFromDeparture: -90,
              action:
                  'Contacte ta banque pour planifier la cl\u00f4ture ou le transfert du 3a.',
              legalRef: 'OPP3 art. 1',
              consequence:
                  'Un 3a non g\u00e9r\u00e9 avant le d\u00e9part peut bloquer des fonds pendant des ann\u00e9es.',
            ),
            ExpatDeadline(
              label: 'LPP \u2014 libre passage',
              emoji: '\u{1F4BC}',
              daysFromDeparture: -60,
              action:
                  'Demande le transfert de ton avoir LPP sur un compte de libre passage ou une police.',
              legalRef: 'LPP art. 5 + LFLP art. 4',
            ),
            ExpatDeadline(
              label: 'AVS \u2014 cotisation volontaire',
              emoji: '\u{1F6E1}\uFE0F',
              daysFromDeparture: 0,
              action:
                  'Si tu t\'installes hors EU/AELE, tu peux t\'affilier volontairement \u00e0 l\'AVS pour \u00e9viter des lacunes.',
              legalRef: 'LAVS art. 2',
              isEuOnly: false,
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),
        if (_departResult != null) ...[
          _buildDepartTimeline(),
          const SizedBox(height: MintSpacing.lg),
          _buildDepartChecklist(),
          const SizedBox(height: MintSpacing.lg),
        ],
        _buildEducationalInsert(l.expatTab2EduInsert),
        const SizedBox(height: MintSpacing.lg),
        // ── P13-A : 5 choses que tu perds en partant ───────────
        const ExpatRightsLossWidget(
          destination: 'l\'\u00e9tranger',
          isEuDestination: false,
          rights: [
            ExpatRight(
              label: 'AVS \u2014 cotisation obligatoire',
              emoji: '\u{1F6E1}\uFE0F',
              before: 'Cotisation automatique via employeur',
              after: 'Lacunes AVS \u2192 rente r\u00e9duite',
              legalRef: 'LAVS art. 1a',
              impact:
                  'Chaque ann\u00e9e manquante r\u00e9duit ta rente AVS de ~2.3%. '
                  '10 ans = \u221223% \u00e0 vie.',
              isIrreversible: true,
            ),
            ExpatRight(
              label: 'LPP \u2014 2e pilier',
              emoji: '\u{1F3E6}',
              before: '\u00c9pargne retraite obligatoire',
              after: 'Capital bloqu\u00e9 ou retir\u00e9 sans rendement',
              legalRef: 'LPP art. 5',
              impact:
                  'Tu peux retirer ton avoir LPP, mais tu paies l\'imp\u00f4t '
                  'sur le capital retir\u00e9. La reconstitution est impossible \u00e0 l\'\u00e9tranger.',
            ),
            ExpatRight(
              label: 'Pilier 3a',
              emoji: '\u{1F3DB}\uFE0F',
              before: 'D\u00e9ductions fiscales annuelles',
              after: 'Compte bloqu\u00e9 \u2014 aucun nouveau versement possible',
              legalRef: 'OPP3 art. 1',
              impact:
                  'Tu perds le droit de verser dans le 3a d\u00e8s que tu n\'as '
                  'plus de revenu soumis \u00e0 l\'AVS suisse.',
            ),
            ExpatRight(
              label: 'LAMal \u2014 assurance maladie',
              emoji: '\u{1F3E5}',
              before: 'Couverture universelle en Suisse',
              after: 'L\u2019assurance maladie est \u00e0 souscrire dans le pays de r\u00e9sidence',
              legalRef: 'LAMal art. 3',
              impact:
                  'La couverture internationale est souvent partielle et '
                  'co\u00fbteuse. V\u00e9rifie les conventions bilat\u00e9rales.',
            ),
            ExpatRight(
              label: 'Ch\u00f4mage AC',
              emoji: '\u{1F4BC}',
              before: 'Indemnit\u00e9s AC jusqu\'\u00e0 520 jours',
              after: 'Aucun droit AC suisse si tu travailles \u00e0 l\'\u00e9tranger',
              legalRef: 'LACI art. 8',
              impact:
                  'Si tu perds ton emploi \u00e0 l\'\u00e9tranger, seul le r\u00e9gime '
                  'local s\'applique \u2014 souvent moins g\u00e9n\u00e9reux.',
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildDepartInputCard() {
    final l = S.of(context)!;
    final sortedCodes = ExpatService.sortedCantonCodes;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
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
              Expanded(
                child: Text(
                  l.expatDepartureDate,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              Semantics(
                label: l.expatDepartureDate,
                button: true,
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _departureDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 730)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme:
                                Theme.of(context).colorScheme.copyWith(
                                      primary: MintColors.primary,
                                    ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      _departureDate = picked;
                      _recalculateDepart();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: MintSpacing.md, vertical: MintSpacing.sm),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MintColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: MintColors.textSecondary),
                        const SizedBox(width: MintSpacing.sm),
                        Text(
                          '${_departureDate.day.toString().padLeft(2, '0')}.'
                          '${_departureDate.month.toString().padLeft(2, '0')}.'
                          '${_departureDate.year}',
                          style: MintTextStyles.bodyMedium(
                              color: MintColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.expatCurrentCanton,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _departCanton,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code \u2014 ${ExpatService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _departCanton = v;
                        _recalculateDepart();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),
          MintAmountField(
            label: l.expatPillar3aBalance,
            value: _pillar3aBalance,
            formatValue: (v) => ExpatService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _pillar3aBalance = v;
                _recalculateDepart();
              });
            },
            min: 0,
            max: 500000,
          ),
          const SizedBox(height: MintSpacing.lg),
          MintAmountField(
            label: l.expatLppBalance,
            value: _lppBalance,
            formatValue: (v) => ExpatService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _lppBalance = v;
                _recalculateDepart();
              });
            },
            min: 0,
            max: 1000000,
          ),
        ],
      ),
    );
  }

  Widget _buildNoExitTaxBadge() {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: MintColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle,
              size: 20, color: MintColors.success),
          const SizedBox(width: MintSpacing.sm),
          Flexible(
            child: Text(
              l.expatNoExitTax,
              style: MintTextStyles.titleMedium(color: MintColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartTimeline() {
    final l = S.of(context)!;
    final result = _departResult!;
    final daysUntil = result['daysUntilDeparture'] as int;

    final items = <Map<String, String>>[
      {
        'label': l.expatTimelineToday,
        'desc': l.expatTimelineTodayDesc,
        'timing': l.expatTimelineTodayTiming,
      },
      {
        'label': l.expatTimeline2to3Months,
        'desc': l.expatTimeline2to3MonthsDesc,
        'timing': daysUntil > 90
            ? l.expatTimeline2to3MonthsTiming(
                ((daysUntil - 90) / 30).round())
            : l.expatTimelineUrgent,
      },
      {
        'label': l.expatTimeline1Month,
        'desc': l.expatTimeline1MonthDesc,
        'timing': daysUntil > 30
            ? l.expatTimeline1MonthTiming(
                ((daysUntil - 30) / 30).round())
            : l.expatTimelineUrgent,
      },
      {
        'label': l.expatTimelineDDay,
        'desc': l.expatTimelineDDayDesc,
        'timing': daysUntil > 0
            ? l.expatTimelineDDayTiming(daysUntil)
            : l.expatTimelinePassed,
      },
      {
        'label': l.expatTimeline30After,
        'desc': l.expatTimeline30AfterDesc,
        'timing': l.expatTimeline30AfterTiming,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatRecommendedTimeline,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == items.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: idx == 0
                              ? MintColors.primary
                              : MintColors.border,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: idx == 0
                                ? MintColors.primary
                                : MintColors.textMuted,
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 50,
                          color: MintColors.border,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: isLast ? 0 : MintSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['label']!,
                              style: MintTextStyles.bodySmall(
                                  color: MintColors.textPrimary),
                            ),
                            Text(
                              item['timing']!,
                              style: MintTextStyles.labelSmall(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['desc']!,
                          style: MintTextStyles.labelSmall(
                              color: MintColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDepartChecklist() {
    final l = S.of(context)!;
    final result = _departResult!;
    final checklist = result['checklist'] as List<Map<String, dynamic>>;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatDepartureChecklist,
                style: MintTextStyles.labelSmall(),
              ),
              const Spacer(),
              Text(
                '${_completedChecklist.length}/${checklist.length}',
                style: MintTextStyles.titleMedium(
                    color: MintColors.primary),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...checklist.map((item) {
            final id = item['id'] as String;
            final title = item['title'] as String;
            final subtitle = item['subtitle'] as String;
            final timing = item['timing'] as String;
            final isCompleted = _completedChecklist.contains(id);

            return Semantics(
              label: 'Checklist\u00a0: $title',
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isCompleted) {
                      _completedChecklist.remove(id);
                    } else {
                      _completedChecklist.add(id);
                    }
                  });
                },
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: isCompleted
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _buildChecklistItem(
                    title: title,
                    subtitle: subtitle,
                    timing: timing,
                    isCompleted: false,
                  ),
                  secondChild: _buildChecklistItem(
                    title: title,
                    subtitle: subtitle,
                    timing: timing,
                    isCompleted: true,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required String subtitle,
    required String timing,
    required bool isCompleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color:
                  isCompleted ? MintColors.success : MintColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted
                    ? MintColors.success
                    : MintColors.border,
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(Icons.check,
                    size: 16, color: MintColors.white)
                : null,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCompleted ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: MintTextStyles.labelSmall(
                        color: MintColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timing,
                    style: MintTextStyles.micro(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: AVS — Pension Gap Estimator
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Avs() {
    final l = S.of(context)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, MintSpacing.xxl),
      children: [
        _buildAvsInputCard(),
        const SizedBox(height: MintSpacing.lg),
        if (_avsResult != null) ...[
          // ── Chiffre-choc hero for Tab 3 ──
          if ((_avsResult!['annualLoss'] as double) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.lg),
              child: Semantics(
                label: l.expatAvsChiffreChoc(ExpatService.formatChf(
                    _avsResult!['annualLoss'] as double)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(MintSpacing.lg),
                  decoration: BoxDecoration(
                    color: MintColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: MintColors.error.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '-${ExpatService.formatChf(_avsResult!['annualLoss'] as double)}',
                        style: MintTextStyles.displayMedium(
                            color: MintColors.error),
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        l.expatAvsChiffreChoc(ExpatService.formatChf(
                            _avsResult!['annualLoss'] as double)),
                        style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          _buildAvsRingChart(),
          const SizedBox(height: MintSpacing.lg),
          _buildAvsReductionCard(),
          const SizedBox(height: MintSpacing.lg),
          _buildAvsVoluntarySection(),
          const SizedBox(height: MintSpacing.lg),
          _buildAvsRecommendation(),
          const SizedBox(height: MintSpacing.lg),
        ],
        Builder(builder: (context) {
          final provider = context.read<CoachProfileProvider>();
          final profileAge =
              (provider.hasProfile && provider.profile!.age > 0)
                  ? provider.profile!.age
                  : 40;
          return AvsGapWidget(
            currentContributionYears: _yearsInCh,
            currentAge: profileAge,
          );
        }),
        const SizedBox(height: MintSpacing.lg),
        _buildEducationalInsert(l.expatAvsEducation),
        const SizedBox(height: MintSpacing.lg),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildAvsInputCard() {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintPickerTile(
            label: l.expatYearsInSwitzerland,
            value: _yearsInCh,
            minValue: 0,
            maxValue: 44,
            formatValue: (v) => '$v ans',
            onChanged: (v) {
              setState(() {
                _yearsInCh = v;
                _recalculateAvs();
              });
            },
          ),
          const SizedBox(height: MintSpacing.lg),
          MintPickerTile(
            label: l.expatYearsAbroad,
            value: _yearsAbroad,
            minValue: 0,
            maxValue: 44,
            formatValue: (v) => '$v ans',
            onChanged: (v) {
              setState(() {
                _yearsAbroad = v;
                _recalculateAvs();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvsRingChart() {
    final l = S.of(context)!;
    final result = _avsResult!;
    final completeness = result['completeness'] as double;
    final completenessPercent = result['completenessPercent'] as double;
    final estimatedRente = result['estimatedRente'] as double;

    Color ringColor;
    if (completeness >= 0.90) {
      ringColor = MintColors.success;
    } else if (completeness >= 0.70) {
      ringColor = MintColors.warning;
    } else {
      ringColor = MintColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatAvsCompleteness,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          Semantics(
            label:
                '${completenessPercent.toStringAsFixed(0)}% ${l.expatOfPension}',
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: completeness,
                      strokeWidth: 12,
                      backgroundColor:
                          MintColors.border.withValues(alpha: 0.3),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(ringColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${completenessPercent.toStringAsFixed(0)}%',
                        style: MintTextStyles.displayMedium(
                            color: ringColor),
                      ),
                      Text(
                        l.expatOfPension,
                        style: MintTextStyles.bodySmall(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),

          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.expatEstimatedPension,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary),
                ),
                Text(
                  '${ExpatService.formatChf(estimatedRente)}/mois',
                  style: MintTextStyles.headlineMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsReductionCard() {
    final l = S.of(context)!;
    final result = _avsResult!;
    final missingYears = result['missingYears'] as int;
    final reductionPercent = result['reductionPercent'] as double;
    final monthlyLoss = result['monthlyLoss'] as double;
    final annualLoss = result['annualLoss'] as double;

    if (missingYears == 0) {
      return Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: MintColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                size: 20, color: MintColors.success),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                l.expatAvsComplete,
                style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_down,
                  size: 16, color: MintColors.error),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatPensionImpact,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildResultRow(l.expatMissingYears, '$missingYears ans'),
          const SizedBox(height: MintSpacing.sm),
          _buildResultRow(
            l.expatEstimatedReduction,
            '-${reductionPercent.toStringAsFixed(1)}%',
            color: MintColors.error,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildResultRow(
            l.expatMonthlyLoss,
            '-${ExpatService.formatChf(monthlyLoss)}',
            color: MintColors.error,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildResultRow(
            l.expatAnnualLoss,
            '-${ExpatService.formatChf(annualLoss)}',
            color: MintColors.error,
            bold: true,
          ),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l.expatAvsReductionExplain(
                  (ExpatService.reductionPerMissingYear * 100)
                      .toStringAsFixed(1)),
              style: MintTextStyles.labelSmall(
                  color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsVoluntarySection() {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatVoluntaryContribution,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.expatVoluntaryAvsTitle,
                  style:
                      MintTextStyles.titleMedium(color: MintColors.info),
                ),
                const SizedBox(height: MintSpacing.sm),
                _buildResultRow(
                  l.expatMinContribution,
                  '${ExpatService.formatChf(ExpatService.avsVoluntaryMin)}/an',
                ),
                const SizedBox(height: MintSpacing.xs),
                _buildResultRow(
                  l.expatMaxContribution,
                  '${ExpatService.formatChf(ExpatService.avsVoluntaryMax)}/an',
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l.expatVoluntaryAvsBody,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsRecommendation() {
    final l = S.of(context)!;
    final result = _avsResult!;
    final recommendation = result['recommendation'] as String;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.expatRecommendation,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            recommendation,
            style: MintTextStyles.bodyMedium(
                color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _buildResultRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodyMedium(),
          ),
        ),
        Text(
          value,
          style: MintTextStyles.bodyMedium(
            color: color ?? MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(String text) {
    final l = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.xs),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lightbulb_outline,
                size: 18, color: MintColors.info),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.expatDidYouKnow,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.info),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  text,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Semantics(
      label: ExpatService.disclaimer,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                color: MintColors.textMuted, size: 18),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                ExpatService.disclaimer,
                style: MintTextStyles.micro(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
