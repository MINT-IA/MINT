import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/family_service.dart';

// ────────────────────────────────────────────────────────────
//  NAISSANCE SCREEN — Sprint S22 / Famille & Concubinage
// ────────────────────────────────────────────────────────────
//
// Three-tab interactive screen:
//   Tab 1: "Conge"       — Parental leave APG calculator
//   Tab 2: "Allocations" — Family allowances by canton
//   Tab 3: "Impact"      — Financial impact of having children
//
// All text in French (informal "tu").
// Material 3, MintColors theme, GoogleFonts.
// Ne constitue pas un conseil en prevoyance (LSFin).
// ────────────────────────────────────────────────────────────

class NaissanceScreen extends StatefulWidget {
  const NaissanceScreen({super.key});

  @override
  State<NaissanceScreen> createState() => _NaissanceScreenState();
}

class _NaissanceScreenState extends State<NaissanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Conge inputs ───────────────────────────────
  bool _isMother = true;
  double _salaireMensuel = 6000;
  Map<String, dynamic>? _congeResult;

  // ── Tab 2: Allocations inputs ─────────────────────────
  String _cantonAlloc = 'VD';
  int _nbEnfantsAlloc = 1;
  Map<String, dynamic>? _allocResult;
  List<Map<String, dynamic>> _allocRanking = [];

  // ── Tab 3: Impact inputs ──────────────────────────────
  double _revenuImpact = 80000;
  int _nbEnfantsImpact = 1;
  double _fraisGarde = 1500;

  // ── Tab 4: Checklist state ──────────────────────────────
  final Set<int> _checkedItems = {};
  final Map<int, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _recalculateAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recalculateAll() {
    setState(() {
      _recalculateConge();
      _recalculateAlloc();
    });
  }

  void _recalculateConge() {
    _congeResult = FamilyService.simulateCongeParental(
      salaireMensuel: _salaireMensuel,
      isMother: _isMother,
    );
  }

  void _recalculateAlloc() {
    _allocResult = FamilyService.estimateAllocations(
      canton: _cantonAlloc,
      nbEnfants: _nbEnfantsAlloc,
    );
    _allocRanking = FamilyService.getAllocationsRanking(
      nbEnfants: _nbEnfantsAlloc,
    );
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
            _buildTab1Conge(),
            _buildTab2Allocations(),
            _buildTab3Impact(),
            _buildTab4Checklist(),
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
          'Naissance & famille',
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
          Tab(text: 'Conge'),
          Tab(text: 'Allocations'),
          Tab(text: 'Impact'),
          Tab(text: 'Checklist'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: CONGE — Parental leave calculator
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Conge() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Toggle + salary
        _buildCongeInputsCard(),
        const SizedBox(height: 20),

        if (_congeResult != null) ...[
          // Hero timeline
          _buildCongeTimeline(),
          const SizedBox(height: 20),

          // Daily breakdown
          _buildCongeBreakdown(),
          const SizedBox(height: 20),

          // Chiffre choc
          _buildCongeChiffreChoc(),
          const SizedBox(height: 20),
        ],

        _buildEducationalInsert(
          'La Suisse a introduit le conge paternite en 2021 seulement. '
          'A 2 semaines, il reste l\'un des plus courts d\'Europe. '
          'Le conge maternite (14 semaines) existe depuis 2005.',
        ),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildCongeInputsCard() {
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
          // Mother/Father toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Type de conge',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: MintColors.primary,
                  selectedForegroundColor: Colors.white,
                  textStyle: GoogleFonts.inter(fontSize: 12),
                ),
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Mere'),
                    icon: Icon(Icons.woman, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Pere'),
                    icon: Icon(Icons.man, size: 16),
                  ),
                ],
                selected: {_isMother},
                onSelectionChanged: (v) {
                  setState(() {
                    _isMother = v.first;
                    _recalculateConge();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Salary slider
          _buildSlider(
            label: 'Salaire mensuel brut',
            value: _salaireMensuel,
            min: 2000,
            max: 15000,
            step: 250,
            onChanged: (v) {
              _salaireMensuel = v;
              _recalculateConge();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCongeTimeline() {
    final result = _congeResult!;
    final weeks = result['dureeSemaines'] as int;
    final apgDaily = result['apgJournalier'] as double;
    final totalApg = result['totalApg'] as double;
    final isCapped = result['isCapped'] as bool;
    final type = result['type'] as String;

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
              const Icon(Icons.timeline, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'CONGE $type'.toUpperCase(),
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

          // Timeline bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _isMother
                    ? MintColors.info.withValues(alpha: 0.15)
                    : MintColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isMother ? MintColors.info : MintColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$weeks semaines',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Details
          _buildResultRow(
            'APG par jour',
            FamilyService.formatChf(apgDaily),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Total APG',
            FamilyService.formatChf(totalApg),
          ),
          if (isCapped) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Plafonne a CHF\u00A0${FamilyService.apgDailyMax.toStringAsFixed(0)}/jour',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCongeBreakdown() {
    final result = _congeResult!;
    final salaireJour = result['salaireJournalier'] as double;
    final apgJour = result['apgJournalier'] as double;
    final perte = result['perteSalaire'] as double;
    final diffJour = salaireJour - apgJour;

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
                'DETAIL QUOTIDIEN',
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
          _buildBarComparison(
            label: 'Salaire/jour',
            value: salaireJour,
            maxValue: max(salaireJour, apgJour),
            color: MintColors.primary,
          ),
          const SizedBox(height: 12),
          _buildBarComparison(
            label: 'APG/jour',
            value: apgJour,
            maxValue: max(salaireJour, apgJour),
            color: MintColors.success,
          ),
          const SizedBox(height: 12),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                diffJour > 0 ? 'Difference/jour' : 'Aucune perte',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              if (diffJour > 0)
                Text(
                  '-${FamilyService.formatChf(diffJour)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.error,
                  ),
                ),
            ],
          ),
          if (perte > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Perte totale estimee sur le conge : ${FamilyService.formatChf(perte)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCongeChiffreChoc() {
    final result = _congeResult!;
    final totalApg = result['totalApg'] as double;
    final weeks = result['dureeSemaines'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            FamilyService.formatChf(totalApg),
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ton conge ${_isMother ? "maternite" : "paternite"} '
            'represente ${FamilyService.formatChf(totalApg)} d\'APG '
            'sur $weeks semaines',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: ALLOCATIONS — Family allowances by canton
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Allocations() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Inputs
        _buildAllocInputsCard(),
        const SizedBox(height: 20),

        if (_allocResult != null) ...[
          // Hero card
          _buildAllocHeroCard(),
          const SizedBox(height: 20),

          // Canton ranking
          _buildAllocRanking(),
          const SizedBox(height: 20),

          // Chiffre choc
          _buildAllocChiffreChoc(),
          const SizedBox(height: 20),
        ],

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildAllocInputsCard() {
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
        children: [
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
                    value: _cantonAlloc,
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
                        setState(() {
                          _cantonAlloc = v;
                          _recalculateAlloc();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Children stepper
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nombre d\'enfants',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              _buildStepper(
                value: _nbEnfantsAlloc,
                minVal: 1,
                maxVal: 5,
                onChanged: (v) {
                  _nbEnfantsAlloc = v;
                  _recalculateAlloc();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocHeroCard() {
    final result = _allocResult!;
    final mensuel = result['mensuelTotal'] as double;
    final annuel = result['annuelTotal'] as double;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '${FamilyService.formatChf(mensuel)}/mois',
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${FamilyService.formatChf(annuel)}/an',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Allocations familiales a ${FamilyService.cantonNames[_cantonAlloc]} '
            'pour $_nbEnfantsAlloc enfant${_nbEnfantsAlloc > 1 ? "s" : ""}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white60,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAllocRanking() {
    if (_allocRanking.isEmpty) return const SizedBox.shrink();

    final maxMensuel = _allocRanking.first['mensuelTotal'] as double;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.leaderboard_outlined,
                    size: 16, color: MintColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  'CLASSEMENT 26 CANTONS',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          ..._allocRanking.map((c) {
            final canton = c['canton'] as String;
            final mensuel = c['mensuelTotal'] as double;
            final isHighlighted = canton == _cantonAlloc;
            final ratio = maxMensuel > 0 ? mensuel / maxMensuel : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              color: isHighlighted
                  ? MintColors.primary.withValues(alpha: 0.06)
                  : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${c['rank']}',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      canton,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isHighlighted ? FontWeight.w700 : FontWeight.w500,
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: MintColors.appleSurface,
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.border,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    child: Text(
                      FamilyService.formatChf(mensuel),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllocChiffreChoc() {
    final result = _allocResult!;
    final diff = result['differenceVsBest'] as double;
    final bestCanton = result['bestCantonNom'] as String;
    final cantonNom = result['cantonNom'] as String;

    if (diff <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: MintColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 20, color: MintColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$cantonNom offre les meilleures allocations familiales de Suisse !',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.success,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildEducationalInsert(
      'En habitant a $bestCanton au lieu de $cantonNom, '
      'tu recevrais ${FamilyService.formatChf(diff)} de plus par an en allocations familiales.',
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: IMPACT — Financial impact of having children
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Impact() {
    final tauxMarginal = 0.15 + (_revenuImpact / 1000000);
    final fiscalResult = FamilyService.calculateImpactFiscalEnfant(
      revenuImposable: _revenuImpact,
      tauxMarginal: tauxMarginal,
      nbEnfants: _nbEnfantsImpact,
      fraisGarde: _fraisGarde,
    );

    final allocResult = FamilyService.estimateAllocations(
      canton: _cantonAlloc,
      nbEnfants: _nbEnfantsImpact,
    );
    final allocAnnuel = allocResult['annuelTotal'] as double;

    final economieFiscale = fiscalResult['economieFiscale'] as double;
    final coutEstime = 1500.0 * _nbEnfantsImpact * 12;
    final fraisGardeAnnuel = _fraisGarde * 12 * _nbEnfantsImpact;
    final coutTotal = coutEstime + fraisGardeAnnuel;
    final netImpact = economieFiscale + allocAnnuel - coutTotal;

    // Career gap LPP projection
    final interruptionMois = _isMother ? 12 : 2;
    final lppPerteEstimee = _revenuImpact * 0.07 * interruptionMois / 12;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Inputs
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
          ),
          child: Column(
            children: [
              _buildSlider(
                label: 'Revenu annuel brut',
                value: _revenuImpact,
                min: 30000,
                max: 200000,
                step: 5000,
                onChanged: (v) {
                  setState(() {
                    _revenuImpact = v;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nombre d\'enfants',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  _buildStepper(
                    value: _nbEnfantsImpact,
                    minVal: 1,
                    maxVal: 5,
                    onChanged: (v) {
                      setState(() {
                        _nbEnfantsImpact = v;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSlider(
                label: 'Frais de garde mensuel/enfant',
                value: _fraisGarde,
                min: 0,
                max: 3000,
                step: 100,
                onChanged: (v) {
                  setState(() {
                    _fraisGarde = v;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 1. Tax savings
        _buildImpactSection(
          icon: Icons.savings_outlined,
          title: 'Economies fiscales',
          color: MintColors.success,
          children: [
            _buildResultRow(
              'Deduction par enfant',
              '$_nbEnfantsImpact x ${FamilyService.formatChf(FamilyService.deductionParEnfant)}',
            ),
            const SizedBox(height: 6),
            _buildResultRow(
              'Deduction frais de garde',
              FamilyService.formatChf(
                  fiscalResult['deductionGarde'] as double),
            ),
            const SizedBox(height: 6),
            _buildResultRow(
              'Economie fiscale estimee',
              FamilyService.formatChf(economieFiscale),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Allocations income
        _buildImpactSection(
          icon: Icons.child_care,
          title: 'Revenu allocations',
          color: MintColors.success,
          children: [
            _buildResultRow(
              'Allocations annuelles',
              FamilyService.formatChf(allocAnnuel),
            ),
            const SizedBox(height: 4),
            Text(
              '(${FamilyService.cantonNames[_cantonAlloc]}, '
              '$_nbEnfantsImpact enfant${_nbEnfantsImpact > 1 ? "s" : ""})',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Career gap warning
        _buildImpactSection(
          icon: Icons.warning_amber_outlined,
          title: 'Impact carriere (LPP)',
          color: MintColors.warning,
          children: [
            _buildResultRow(
              'Interruption estimee',
              '$interruptionMois mois',
            ),
            const SizedBox(height: 6),
            _buildResultRow(
              'Perte LPP estimee',
              '-${FamilyService.formatChf(lppPerteEstimee)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Moins de cotisations LPP = moins de capital a la retraite',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Net impact
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: netImpact >= 0
                ? MintColors.success.withValues(alpha: 0.08)
                : MintColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: netImpact >= 0
                  ? MintColors.success.withValues(alpha: 0.3)
                  : MintColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Impact net annuel estime',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '${netImpact >= 0 ? "+" : ""}${FamilyService.formatChf(netImpact)}',
                  key: ValueKey(netImpact),
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: netImpact >= 0
                        ? MintColors.success
                        : MintColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Economies fiscales + allocations - cout estime',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildEducationalInsert(
          'Un enfant coute en moyenne CHF\u00A01\'500/mois en Suisse '
          '(alimentation, vetements, activites, assurance). '
          'Mais les allocations et deductions fiscales reduisent '
          'significativement l\'impact net.',
        ),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildImpactSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 4: CHECKLIST — Essential steps for new parents
  // ════════════════════════════════════════════════════════════

  Widget _buildTab4Checklist() {
    final items = _naissanceChecklistItems;
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
              const Icon(Icons.child_care,
                  color: MintColors.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'L\'arrivee d\'un enfant implique de nombreuses demarches '
                  'administratives et financieres. Voici les etapes a ne pas oublier.',
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
                    '$nbChecked/${items.length} demarches effectuees',
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

  // ── Checklist Data ──────────────────────────────────────

  static final List<Map<String, String>> _naissanceChecklistItems = [
    {
      'title': 'Inscrire bebe a l\'assurance maladie (3 mois)',
      'description':
          'Tu as 3 mois apres la naissance pour inscrire ton enfant aupres d\'une caisse '
          'maladie. Si tu le fais dans ce delai, la couverture est retroactive des la naissance. '
          'Passe ce delai, l\'enfant risque une interruption de couverture. '
          'Compare les primes enfants entre caisses — les ecarts peuvent etre significatifs.',
    },
    {
      'title': 'Demander les allocations familiales',
      'description':
          'Fais la demande aupres de ton employeur (ou de ta caisse d\'allocations si tu es '
          'independant-e). Les allocations sont versees des le mois de naissance. '
          'Le montant depend du canton (CHF 200 a CHF 305/mois par enfant).',
    },
    {
      'title': 'Annoncer la naissance a l\'etat civil',
      'description':
          'L\'hopital transmet generalement l\'annonce a l\'office de l\'etat civil. '
          'Verifie que l\'acte de naissance est bien etabli. '
          'Tu en auras besoin pour toutes les demarches administratives.',
    },
    {
      'title': 'Organiser le conge parental (APG)',
      'description':
          'Conge maternite : 14 semaines a 80% du salaire (max CHF 220/jour). '
          'Conge paternite : 2 semaines (10 jours), a prendre dans les 6 mois. '
          'L\'inscription APG se fait via ton employeur ou directement aupres de la caisse de compensation.',
    },
    {
      'title': 'Mettre a jour la declaration fiscale',
      'description':
          'Un enfant supplementaire te donne droit a une deduction fiscale de CHF 6\'700/an '
          '(LIFD art. 35). Si tu as des frais de garde, tu peux deduire jusqu\'a CHF 25\'500/an. '
          'Pense a adapter tes acomptes d\'impots pour l\'annee en cours.',
    },
    {
      'title': 'Adapter le budget familial',
      'description':
          'Un enfant coute en moyenne CHF 1\'200 a CHF 1\'500/mois en Suisse '
          '(alimentation, vetements, activites, assurance, couches, etc.). '
          'Reevalue ton budget avec le module Budget de MINT.',
    },
    {
      'title': 'Verifier la prevoyance (LPP et 3a)',
      'description':
          'Si tu reduis ton taux d\'activite, tes cotisations LPP baissent. '
          'Chaque annee a temps partiel represente moins de capital a la retraite. '
          'Envisage de compenser en versant le maximum au 3e pilier (CHF 7\'258/an).',
    },
    {
      'title': 'Rediger ou mettre a jour le testament',
      'description':
          'L\'arrivee d\'un enfant modifie l\'ordre successoral. '
          'Les enfants sont des heritiers reservataires (CC art. 471). '
          'Si tu as un testament, verifie qu\'il respecte les reserves legales.',
    },
    {
      'title': 'Souscrire une assurance risque deces/invalidite',
      'description':
          'Avec un enfant a charge, la protection financiere en cas de deces ou d\'invalidite '
          'devient encore plus importante. Verifie ta couverture actuelle (LPP, assurance-vie) '
          'et complete si necessaire.',
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

  Widget _buildStepper({
    required int value,
    required int minVal,
    required int maxVal,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        IconButton(
          onPressed: value > minVal
              ? () {
                  setState(() => onChanged(value - 1));
                }
              : null,
          icon: const Icon(Icons.remove_circle_outline, size: 24),
          color: MintColors.primary,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          onPressed: value < maxVal
              ? () {
                  setState(() => onChanged(value + 1));
                }
              : null,
          icon: const Icon(Icons.add_circle_outline, size: 24),
          color: MintColors.primary,
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MintColors.textSecondary,
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

  Widget _buildBarComparison({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              FamilyService.formatChf(value),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: MintColors.appleSurface,
            color: color,
            minHeight: 8,
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
                  'Le savais-tu ?',
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
              'Estimations simplifiees a but educatif — ne constitue pas '
              'un conseil en prevoyance ou conseil fiscal. Les montants dependent '
              'de nombreux facteurs (canton, commune, situation familiale, etc.). '
              'Consulte un-e specialiste pour un calcul personnalise.',
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
