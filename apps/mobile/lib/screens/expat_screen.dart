import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/widgets/coach/top_cantons_widget.dart';
import 'package:mint_mobile/widgets/coach/avs_gap_widget.dart';
import 'package:mint_mobile/widgets/coach/expat_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/expat_rights_loss_widget.dart';

// ────────────────────────────────────────────────────────────
//  EXPAT SCREEN — Sprint S23 / Expatriation + Frontaliers
// ────────────────────────────────────────────────────────────
//
// Three-tab interactive screen for expatriation planning:
//   Tab 1: "Forfait"  — Lump-sum taxation simulator
//   Tab 2: "Depart"   — Departure planning checklist
//   Tab 3: "AVS"      — Pension gap estimator
//
// All text in French (informal "tu").
// Material 3, MintColors theme, GoogleFonts.
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
      backgroundColor: MintColors.background,
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

  // ── App Bar with Tabs ──────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
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
          S.of(context)!.expatTitle,
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
          Tab(text: S.of(context)!.expatTabForfait),
          Tab(text: S.of(context)!.expatTabDeparture),
          Tab(text: S.of(context)!.expatTabAvs),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: FORFAIT — Lump-sum Taxation
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Forfait() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildForfaitInputCard(),
        const SizedBox(height: 20),
        if (_forfaitResult != null) ...[
          _buildForfaitResultCard(),
          const SizedBox(height: 20),
        ],
        _buildAbolishedWarning(),
        const SizedBox(height: 20),
        _buildEducationalInsert(
          S.of(context)!.expatForfaitEducation,
        ),
        const SizedBox(height: 20),
        _buildTopCantonSection(),
        const SizedBox(height: 24),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildTopCantonSection() {
    // Scale tax savings relative to user income (base = 100k reference)
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
    final eligibleCantons = ExpatService.eligibleForfaitCantons;

    // Ensure selected canton is still eligible
    if (!eligibleCantons.contains(_forfaitCanton)) {
      _forfaitCanton = eligibleCantons.first;
    }

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
          // Canton dropdown (eligible only)
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.expatCanton,
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
                    value: _forfaitCanton,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textPrimary,
                    ),
                    items: eligibleCantons.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code — ${ExpatService.cantonNames[code]}'),
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
          const SizedBox(height: 20),

          // Living expenses slider
          _buildSlider(
            label: S.of(context)!.expatLivingExpenses,
            value: _livingExpenses,
            min: 250000,
            max: 5000000,
            step: 50000,
            onChanged: (v) {
              _livingExpenses = v;
              _recalculateForfait();
            },
          ),
          const SizedBox(height: 20),

          // Actual income slider
          _buildSlider(
            label: S.of(context)!.expatActualIncome,
            value: _actualIncome,
            min: 500000,
            max: 20000000,
            step: 100000,
            onChanged: (v) {
              _actualIncome = v;
              _recalculateForfait();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForfaitResultCard() {
    final result = _forfaitResult!;

    if (result['abolished'] == true) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block, size: 20, color: MintColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result['note'] as String,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textPrimary,
                  height: 1.5,
                ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.expatTaxComparison,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Side by side
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MintColors.appleSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 24, color: MintColors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        S.of(context)!.expatForfaitFiscal,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ExpatService.formatChf(forfaitTax),
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: MintColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Base: ${ExpatService.formatChf(forfaitBase)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MintColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MintColors.appleSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_outlined,
                          size: 24, color: MintColors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        S.of(context)!.expatOrdinaryTaxation,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ExpatService.formatChf(ordinaryTax),
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: MintColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.of(context)!.expatOnActualIncome,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MintColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Savings badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  color: isFavorable ? MintColors.success : MintColors.warning,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isFavorable
                        ? 'Économie: ${ExpatService.formatChf(savings.abs())} (-${savingsPercent.toStringAsFixed(0)}%)'
                        : 'Forfait plus coûteux: +${ExpatService.formatChf(savings.abs())}',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isFavorable
                          ? MintColors.success
                          : MintColors.warning,
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

  Widget _buildAbolishedWarning() {
    final abolished = ExpatService.forfaitAbolishedCantons.toList()..sort();
    final names = abolished
        .map((c) => ExpatService.cantonNames[c] ?? c)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, size: 18, color: MintColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.expatAbolishedCantons,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.expatAbolishedNote(names),
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
  //  TAB 2: DEPART — Departure Planning
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Depart() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildDepartInputCard(),
        const SizedBox(height: 20),
        _buildNoExitTaxBadge(),
        const SizedBox(height: 20),
        ExpatCountdownWidget(
          departureDate: _departureDate,
          deadlines: const [
            ExpatDeadline(
              label: '3ème pilier 3a — clôture ou gel',
              emoji: '🏦',
              daysFromDeparture: -90,
              action: 'Contacte ta banque pour planifier la clôture ou le transfert du 3a.',
              legalRef: 'OPP3 art. 1',
              consequence: 'Un 3a non géré avant le départ peut bloquer des fonds pendant des années.',
            ),
            ExpatDeadline(
              label: 'LPP — libre passage',
              emoji: '💼',
              daysFromDeparture: -60,
              action: 'Demande le transfert de ton avoir LPP sur un compte de libre passage ou une police.',
              legalRef: 'LPP art. 5 + LFLP art. 4',
            ),
            ExpatDeadline(
              label: 'AVS — cotisation volontaire',
              emoji: '🛡️',
              daysFromDeparture: 0,
              action: 'Si tu t\'installes hors EU/AELE, tu peux t\'affilier volontairement à l\'AVS pour éviter des lacunes.',
              legalRef: 'LAVS art. 2',
              isEuOnly: false,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_departResult != null) ...[
          _buildDepartTimeline(),
          const SizedBox(height: 20),
          _buildDepartChecklist(),
          const SizedBox(height: 20),
        ],
        _buildEducationalInsert(
          'La Suisse ne prélève pas de taxe de sortie (exit tax) — '
          'contrairement aux États-Unis ou à la France. '
          'Tes gains en capital latents ne sont pas imposés au moment du départ. '
          'C\'est un avantage majeur pour les expatriés.',
        ),
        const SizedBox(height: 20),
        // ── P13-A : 5 choses que tu perds en partant ───────────
        ExpatRightsLossWidget(
          destination: 'l\'étranger',
          isEuDestination: false,
          rights: const [
            ExpatRight(
              label: 'AVS — cotisation obligatoire',
              emoji: '🛡️',
              before: 'Cotisation automatique via employeur',
              after: 'Lacunes AVS → rente réduite',
              legalRef: 'LAVS art. 1a',
              impact:
                  'Chaque année manquante réduit ta rente AVS de ~2.3%. '
                  '10 ans = −23% à vie.',
              isIrreversible: true,
            ),
            ExpatRight(
              label: 'LPP — 2e pilier',
              emoji: '🏦',
              before: 'Épargne retraite obligatoire',
              after: 'Capital bloqué ou retiré sans rendement',
              legalRef: 'LPP art. 5',
              impact:
                  'Tu peux retirer ton avoir LPP, mais tu paies l\'impôt '
                  'sur le capital retiré. La reconstitution est impossible à l\'étranger.',
            ),
            ExpatRight(
              label: 'Pilier 3a',
              emoji: '🏛️',
              before: 'Déductions fiscales annuelles',
              after: 'Compte bloqué — aucun nouveau versement possible',
              legalRef: 'OPP3 art. 1',
              impact:
                  'Tu perds le droit de verser dans le 3a dès que tu n\'as '
                  'plus de revenu soumis à l\'AVS suisse.',
            ),
            ExpatRight(
              label: 'LAMal — assurance maladie',
              emoji: '🏥',
              before: 'Couverture universelle en Suisse',
              after: 'Tu dois t\'assurer dans le pays de résidence',
              legalRef: 'LAMal art. 3',
              impact:
                  'La couverture internationale est souvent partielle et '
                  'coûteuse. Vérifie les conventions bilatérales.',
            ),
            ExpatRight(
              label: 'Chômage AC',
              emoji: '💼',
              before: 'Indemnités AC jusqu\'à 520 jours',
              after: 'Aucun droit AC suisse si tu travailles à l\'étranger',
              legalRef: 'LACI art. 8',
              impact:
                  'Si tu perds ton emploi à l\'étranger, seul le régime '
                  'local s\'applique — souvent moins généreux.',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildDepartInputCard() {
    final sortedCodes = ExpatService.sortedCantonCodes;

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
          // Departure date picker
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.expatDepartureDate,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _departureDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: MintColors.appleSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MintColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: MintColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${_departureDate.day.toString().padLeft(2, '0')}.'
                        '${_departureDate.month.toString().padLeft(2, '0')}.'
                        '${_departureDate.year}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Canton dropdown
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.expatCurrentCanton,
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
                    value: _departCanton,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textPrimary,
                    ),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code — ${ExpatService.cantonNames[code]}'),
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
          const SizedBox(height: 20),

          // Pillar 3a balance
          _buildSlider(
            label: S.of(context)!.expatPillar3aBalance,
            value: _pillar3aBalance,
            min: 0,
            max: 500000,
            step: 5000,
            onChanged: (v) {
              _pillar3aBalance = v;
              _recalculateDepart();
            },
          ),
          const SizedBox(height: 20),

          // LPP balance
          _buildSlider(
            label: S.of(context)!.expatLppBalance,
            value: _lppBalance,
            min: 0,
            max: 1000000,
            step: 10000,
            onChanged: (v) {
              _lppBalance = v;
              _recalculateDepart();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoExitTaxBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 20, color: MintColors.success),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              S.of(context)!.expatNoExitTax,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MintColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartTimeline() {
    final result = _departResult!;
    final daysUntil = result['daysUntilDeparture'] as int;

    // Simple timeline with key dates
    final items = <Map<String, String>>[
      {
        'label': 'Aujourd\'hui',
        'desc': 'Commence à planifier',
        'timing': 'Maintenant',
      },
      {
        'label': '2-3 mois avant',
        'desc': 'Annoncer à la commune, résilier LAMal',
        'timing': daysUntil > 90
            ? 'Dans ~${((daysUntil - 90) / 30).round()} mois'
            : 'Urgent !',
      },
      {
        'label': '1 mois avant',
        'desc': 'Retirer 3a, transférer LPP',
        'timing': daysUntil > 30
            ? 'Dans ~${((daysUntil - 30) / 30).round()} mois'
            : 'Urgent !',
      },
      {
        'label': 'Jour J',
        'desc': 'Départ effectif',
        'timing': daysUntil > 0
            ? 'Dans $daysUntil jours'
            : 'Passé',
      },
      {
        'label': '30 jours après',
        'desc': 'Déclarer impôts prorata temporis',
        'timing': 'Après le départ',
      },
    ];

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
              const Icon(Icons.timeline, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.expatRecommendedTimeline,
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
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == items.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline dot + line
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
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['label']!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MintColors.textPrimary,
                              ),
                            ),
                            Text(
                              item['timing']!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: MintColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['desc']!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textSecondary,
                            height: 1.4,
                          ),
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
    final result = _departResult!;
    final checklist = result['checklist'] as List<Map<String, dynamic>>;

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
              const Icon(Icons.checklist, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.expatDepartureChecklist,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${_completedChecklist.length}/${checklist.length}',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...checklist.map((item) {
            final id = item['id'] as String;
            final title = item['title'] as String;
            final subtitle = item['subtitle'] as String;
            final timing = item['timing'] as String;
            final isCompleted = _completedChecklist.contains(id);

            return GestureDetector(
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isCompleted
                  ? MintColors.success
                  : MintColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted
                    ? MintColors.success
                    : MintColors.border,
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: MintColors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCompleted ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timing,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      fontStyle: FontStyle.italic,
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

  // ════════════════════════════════════════════════════════════
  //  TAB 3: AVS — Pension Gap Estimator
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Avs() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildAvsInputCard(),
        const SizedBox(height: 20),
        if (_avsResult != null) ...[
          _buildAvsRingChart(),
          const SizedBox(height: 20),
          _buildAvsReductionCard(),
          const SizedBox(height: 20),
          _buildAvsVoluntarySection(),
          const SizedBox(height: 20),
          _buildAvsRecommendation(),
          const SizedBox(height: 20),
        ],
        Builder(builder: (context) {
          final provider = context.read<CoachProfileProvider>();
          final profileAge = (provider.hasProfile && provider.profile!.age > 0)
              ? provider.profile!.age
              : 40;
          return AvsGapWidget(
            currentContributionYears: _yearsInCh,
            currentAge: profileAge,
          );
        }),
        const SizedBox(height: 20),
        _buildEducationalInsert(
          S.of(context)!.expatAvsEducation,
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildAvsInputCard() {
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
            label: S.of(context)!.expatYearsInSwitzerland,
            value: _yearsInCh.toDouble(),
            min: 0,
            max: 44,
            step: 1,
            onChanged: (v) {
              _yearsInCh = v.round();
              _recalculateAvs();
            },
            formatAsInt: true,
            suffix: 'ans',
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: S.of(context)!.expatYearsAbroad,
            value: _yearsAbroad.toDouble(),
            min: 0,
            max: 44,
            step: 1,
            onChanged: (v) {
              _yearsAbroad = v.round();
              _recalculateAvs();
            },
            formatAsInt: true,
            suffix: 'ans',
          ),
        ],
      ),
    );
  }

  Widget _buildAvsRingChart() {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.expatAvsCompleteness,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Animated ring chart
          SizedBox(
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
                    backgroundColor: MintColors.border.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${completenessPercent.toStringAsFixed(0)}%',
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: ringColor,
                      ),
                    ),
                    Text(
                      S.of(context)!.expatOfPension,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Estimated rente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context)!.expatEstimatedPension,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
                Text(
                  '${ExpatService.formatChf(estimatedRente)}/mois',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsReductionCard() {
    final result = _avsResult!;
    final missingYears = result['missingYears'] as int;
    final reductionPercent = result['reductionPercent'] as double;
    final monthlyLoss = result['monthlyLoss'] as double;
    final annualLoss = result['annualLoss'] as double;

    if (missingYears == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 20, color: MintColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                S.of(context)!.expatAvsComplete,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
              const Icon(Icons.trending_down, size: 16, color: MintColors.error),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.expatPensionImpact,
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
            S.of(context)!.expatMissingYears,
            '$missingYears ans',
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.expatEstimatedReduction,
            '-${reductionPercent.toStringAsFixed(1)}%',
            color: MintColors.error,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.expatMonthlyLoss,
            '-${ExpatService.formatChf(monthlyLoss)}',
            color: MintColors.error,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.expatAnnualLoss,
            '-${ExpatService.formatChf(annualLoss)}',
            color: MintColors.error,
            bold: true,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Chaque année manquante réduit ta rente d\'environ '
              '${(ExpatService.reductionPerMissingYear * 100).toStringAsFixed(1)}%. '
              'La réduction est définitive et s\'applique à vie.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsVoluntarySection() {
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
              const Icon(Icons.savings_outlined, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.expatVoluntaryContribution,
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.expatVoluntaryAvsTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.info,
                  ),
                ),
                const SizedBox(height: 8),
                _buildResultRow(
                  S.of(context)!.expatMinContribution,
                  '${ExpatService.formatChf(ExpatService.avsVoluntaryMin)}/an',
                ),
                const SizedBox(height: 6),
                _buildResultRow(
                  S.of(context)!.expatMaxContribution,
                  '${ExpatService.formatChf(ExpatService.avsVoluntaryMax)}/an',
                ),
                const SizedBox(height: 12),
                Text(
                  S.of(context)!.expatVoluntaryAvsBody,
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

  Widget _buildAvsRecommendation() {
    final result = _avsResult!;
    final recommendation = result['recommendation'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.expatRecommendation,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recommendation,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
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
    bool formatAsInt = false,
    String? suffix,
  }) {
    final divisions = ((max - min) / step).round();

    String displayValue;
    if (formatAsInt) {
      displayValue = '${value.round()}${suffix != null ? ' $suffix' : ''}';
    } else {
      displayValue = ExpatService.formatChf(value);
    }

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
              displayValue,
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

  Widget _buildResultRow(String label, String value,
      {bool bold = false, Color? color}) {
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
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lightbulb_outline,
                size: 18, color: MintColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.expatDidYouKnow,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.info,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
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
          Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ExpatService.disclaimer,
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

