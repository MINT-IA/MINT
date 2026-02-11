import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/retirement_service.dart';
import 'package:mint_mobile/widgets/retirement/avs_scenario_card.dart';
import 'package:mint_mobile/widgets/retirement/lpp_comparison_card.dart';
import 'package:mint_mobile/widgets/retirement/budget_gauge_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT SCREEN — Sprint S21 / Retraite complete
// ────────────────────────────────────────────────────────────
//
// Four-tab comprehensive retirement planning screen:
//   Tab 1: "AVS"      — Pension estimate (LAVS art. 21-29)
//   Tab 2: "LPP"      — Capital vs Rente comparison
//   Tab 3: "Budget"   — Retirement budget reconciliation
//   Tab 4: "Planning" — Timeline + Checklist
//
// All text in French (informal "tu").
// Material 3, MintColors theme, GoogleFonts.
// Ne constitue pas un conseil en prevoyance (LSFin).
// ────────────────────────────────────────────────────────────

class RetirementScreen extends StatefulWidget {
  const RetirementScreen({super.key});

  @override
  State<RetirementScreen> createState() => _RetirementScreenState();
}

class _RetirementScreenState extends State<RetirementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: AVS inputs ─────────────────────────────────────
  int _ageActuel = 45;
  int _ageRetraite = 65;
  bool _isCouple = false;
  int _anneesLacunes = 0;

  Map<String, dynamic>? _avsNormal;
  Map<String, dynamic>? _avsAnticipation;
  Map<String, dynamic>? _avsAjournement;

  // ── Tab 2: LPP inputs ────────────────────────────────────
  double _capitalLpp = 500000;
  String _cantonLpp = 'ZH';

  Map<String, dynamic>? _lppResult;

  // ── Tab 3: Budget inputs ─────────────────────────────────
  double _budgetAvs = avsRenteMaxMensuelle;
  double _budgetLpp = 1500;
  double _budget3a = 100000;
  double _budgetAutres = 0;
  double _budgetDepenses = 5000;
  double _budgetRevenuPre = 8000;
  bool _budgetCouple = false;

  Map<String, dynamic>? _budgetResult;

  // ── Tab 4: Planning checklist ────────────────────────────
  final Set<int> _planningChecked = {};

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
      _recalculateAvs();
      _recalculateLpp();
      _recalculateBudget();
    });
  }

  void _recalculateAvs() {
    _avsNormal = RetirementService.estimateAvs(
      ageActuel: _ageActuel,
      ageRetraite: 65,
      isCouple: _isCouple,
      anneesLacunes: _anneesLacunes,
    );
    _avsAnticipation = RetirementService.estimateAvs(
      ageActuel: _ageActuel,
      ageRetraite: 63,
      isCouple: _isCouple,
      anneesLacunes: _anneesLacunes,
    );
    _avsAjournement = RetirementService.estimateAvs(
      ageActuel: _ageActuel,
      ageRetraite: 70,
      isCouple: _isCouple,
      anneesLacunes: _anneesLacunes,
    );
  }

  void _recalculateLpp() {
    _lppResult = RetirementService.compareLpp(
      capitalLpp: _capitalLpp,
      canton: _cantonLpp,
    );
  }

  void _recalculateBudget() {
    _budgetResult = RetirementService.calculateBudget(
      avsMensuel: _budgetAvs,
      lppMensuel: _budgetLpp,
      capital3aNet: _budget3a,
      autresRevenus: _budgetAutres,
      depensesMensuelles: _budgetDepenses,
      revenuPreRetraite: _budgetRevenuPre,
      isCouple: _budgetCouple,
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
            _buildTab1Avs(),
            _buildTab2Lpp(),
            _buildTab3Budget(),
            _buildTab4Planning(),
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
          'Retraite complete',
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
          Tab(text: 'AVS'),
          Tab(text: 'LPP'),
          Tab(text: 'Budget'),
          Tab(text: 'Planning'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: AVS
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Avs() {
    final selected = RetirementService.estimateAvs(
      ageActuel: _ageActuel,
      ageRetraite: _ageRetraite,
      isCouple: _isCouple,
      anneesLacunes: _anneesLacunes,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // ── Inputs ─────────────────────────────────────
        _buildAvsInputsCard(),
        const SizedBox(height: 20),

        // ── Chiffre choc ──────────────────────────────
        _buildChiffreChocAvs(selected),
        const SizedBox(height: 20),

        // ── 3 Scenarios ───────────────────────────────
        Row(
          children: [
            const Icon(Icons.compare_arrows,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'SCENARIOS',
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AvsScenarioCard(
                scenario: 'anticipation',
                renteMensuelle:
                    _avsAnticipation!['renteMensuelle'] as double,
                penalitePct:
                    _avsAnticipation!['penaliteOuBonusPct'] as double,
                isSelected: _ageRetraite < 65,
                onTap: () => setState(() {
                  _ageRetraite = 63;
                  _recalculateAvs();
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AvsScenarioCard(
                scenario: 'normal',
                renteMensuelle:
                    _avsNormal!['renteMensuelle'] as double,
                penalitePct:
                    _avsNormal!['penaliteOuBonusPct'] as double,
                isSelected: _ageRetraite == 65,
                onTap: () => setState(() {
                  _ageRetraite = 65;
                  _recalculateAvs();
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AvsScenarioCard(
                scenario: 'ajournement',
                renteMensuelle:
                    _avsAjournement!['renteMensuelle'] as double,
                penalitePct:
                    _avsAjournement!['penaliteOuBonusPct'] as double,
                isSelected: _ageRetraite > 65,
                onTap: () => setState(() {
                  _ageRetraite = 70;
                  _recalculateAvs();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Result card ───────────────────────────────
        _buildAvsResultCard(selected),
        const SizedBox(height: 20),

        // ── Couple info ───────────────────────────────
        if (_isCouple && selected['renteCoupleMensuelle'] != null)
          _buildCoupleBanner(selected),
        if (_isCouple && selected['renteCoupleMensuelle'] != null)
          const SizedBox(height: 20),

        // ── Educational ───────────────────────────────
        _buildAvsEducation(),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildAvsInputsCard() {
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
          // Age depart slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Age de depart souhaite',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$_ageRetraite ans',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _ageRetraite.toDouble(),
              min: 63,
              max: 70,
              divisions: 7,
              onChanged: (v) {
                setState(() {
                  _ageRetraite = v.round();
                  _recalculateAvs();
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('63 ans',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
              Text('70 ans',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),

          // Couple toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Couple',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _isCouple,
                activeColor: MintColors.primary,
                onChanged: (v) {
                  setState(() {
                    _isCouple = v;
                    _recalculateAvs();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lacunes counter
          Row(
            children: [
              Expanded(
                child: Text(
                  'Annees de lacunes AVS',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _anneesLacunes > 0
                        ? () {
                            setState(() {
                              _anneesLacunes--;
                              _recalculateAvs();
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline, size: 24),
                    color: MintColors.primary,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$_anneesLacunes',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _anneesLacunes < 10
                        ? () {
                            setState(() {
                              _anneesLacunes++;
                              _recalculateAvs();
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline, size: 24),
                    color: MintColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChocAvs(Map<String, dynamic> result) {
    final rente = result['renteMensuelle'] as double;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            RetirementService.formatChf(rente),
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ta rente AVS estimee par mois a $_ageRetraite ans',
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

  Widget _buildAvsResultCard(Map<String, dynamic> result) {
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
                'DETAIL DE TA RENTE',
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
            'Rente mensuelle',
            RetirementService.formatChf(
                result['renteMensuelle'] as double),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Rente annuelle',
            RetirementService.formatChf(
                result['renteAnnuelle'] as double),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Scenario',
            (result['scenario'] as String).toUpperCase(),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Ajustement',
            '${(result['penaliteOuBonusPct'] as double) > 0 ? '+' : ''}${(result['penaliteOuBonusPct'] as double).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Duree estimee',
            '${result['dureeEstimeeAns']} ans',
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Total cumule estime',
            RetirementService.formatChf(
                result['totalCumule'] as double),
          ),
        ],
      ),
    );
  }

  Widget _buildCoupleBanner(Map<String, dynamic> result) {
    final renteCouple = result['renteCoupleMensuelle'] as double;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline, size: 20, color: MintColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rente de couple plafonnee',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${RetirementService.formatChf(renteCouple)}/mois (max 150% de la rente individuelle)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvsEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'BON A SAVOIR',
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
        _buildEduCard(
          Icons.calendar_today_outlined,
          'Anticiper = penalite a vie',
          'Chaque annee d\'anticipation reduit ta rente de 6.8% — et ce de facon permanente. '
          'A 63 ans, tu perds 13.6% a vie.',
        ),
        _buildEduCard(
          Icons.trending_up,
          'Ajourner = bonus a vie',
          'Tu peux reporter ta rente AVS jusqu\'a 5 ans. Le bonus va de +5.2% (1 an) '
          'a +31.5% (5 ans), de facon permanente.',
        ),
        _buildEduCard(
          Icons.warning_amber_outlined,
          'Lacunes = rente reduite',
          'Chaque annee de cotisation manquante reduit ta rente proportionnellement. '
          'Verifie ton extrait CI aupres de ta caisse AVS.',
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: LPP
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Lpp() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // ── Inputs ─────────────────────────────────────
        _buildLppInputsCard(),
        const SizedBox(height: 20),

        // ── Comparison ────────────────────────────────
        if (_lppResult != null)
          LppComparisonCard(
            renteMensuelle: _lppResult!['renteMensuelle'] as double,
            renteAnnuelle: _lppResult!['renteAnnuelle'] as double,
            capitalBrut: _lppResult!['capitalBrut'] as double,
            capitalNet: _lppResult!['capitalNet'] as double,
            capitalImpot: _lppResult!['capitalImpot'] as double,
            breakevenAge: _lppResult!['breakevenAge'] as int,
          ),
        const SizedBox(height: 20),

        // ── Neutral recommendation ───────────────────
        _buildNeutralRecommendation(),
        const SizedBox(height: 20),

        // ── Education ────────────────────────────────
        _buildLppEducation(),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildLppInputsCard() {
    final sortedCodes = RetirementService.sortedCantonCodes;

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
          // Capital slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Capital LPP',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                RetirementService.formatChf(_capitalLpp),
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _capitalLpp,
              min: 100000,
              max: 2000000,
              divisions: 38,
              onChanged: (v) {
                setState(() {
                  _capitalLpp = (v / 50000).round() * 50000.0;
                  _recalculateLpp();
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CHF\u00A0100'000",
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
              Text("CHF\u00A02'000'000",
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
            ],
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
                    value: _cantonLpp,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textPrimary,
                    ),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code — ${RetirementService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _cantonLpp = v;
                          _recalculateLpp();
                        });
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

  Widget _buildNeutralRecommendation() {
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
            child:
                const Icon(Icons.balance, size: 18, color: MintColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pas de reponse universelle',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Le choix entre rente et capital depend de ta situation personnelle : '
                  'etat de sante, patrimoine, projets, regime matrimonial. '
                  'Un-e specialiste en prevoyance peut t\'aider a y voir clair.',
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

  Widget _buildLppEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'BON A SAVOIR',
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
        _buildEduCard(
          Icons.percent,
          'Taux de conversion : 6.8%',
          'Le taux minimum legal est de 6.8% sur la part obligatoire. '
          'Le taux surobligatoire peut etre plus bas (souvent 5-6%).',
        ),
        _buildEduCard(
          Icons.favorite_outline,
          'Rente de veuf/veuve',
          'Avec la rente LPP, ton conjoint touche 60% de ta rente en cas de deces. '
          'Avec le capital, il faut prevoir autrement.',
        ),
        _buildEduCard(
          Icons.pie_chart_outline,
          'Mix possible',
          'Beaucoup de caisses de pension permettent de retirer une partie en capital '
          'et de recevoir le reste en rente. Renseigne-toi aupres de ta caisse.',
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: BUDGET
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Budget() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // ── Inputs ─────────────────────────────────────
        _buildBudgetInputsCard(),
        const SizedBox(height: 20),

        // ── Gauge ──────────────────────────────────────
        if (_budgetResult != null)
          BudgetGaugeWidget(
            revenus: _budgetResult!['totalRevenus'] as double,
            depenses: _budgetResult!['depenses'] as double,
            tauxRemplacement:
                _budgetResult!['tauxRemplacement'] as double,
          ),
        const SizedBox(height: 20),

        // ── Alerts ─────────────────────────────────────
        if (_budgetResult != null)
          ..._buildAlerts(_budgetResult!['alertes'] as List<String>),

        // ── 3a durability ──────────────────────────────
        if (_budgetResult != null &&
            (_budgetResult!['duree3aAns'] as double) > 0) ...[
          _build3aDurability(_budgetResult!['duree3aAns'] as double),
          const SizedBox(height: 20),
        ],

        // ── Budget checklist ──────────────────────────
        _buildBudgetChecklist(),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildBudgetInputsCard() {
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
          Text(
            'Tes revenus a la retraite',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildBudgetSlider(
            label: 'Rente AVS mensuelle',
            value: _budgetAvs,
            min: 0,
            max: 3000,
            step: 100,
            onChanged: (v) {
              _budgetAvs = v;
              _recalculateBudget();
            },
          ),
          const SizedBox(height: 12),
          _buildBudgetSlider(
            label: 'Rente LPP mensuelle',
            value: _budgetLpp,
            min: 0,
            max: 5000,
            step: 100,
            onChanged: (v) {
              _budgetLpp = v;
              _recalculateBudget();
            },
          ),
          const SizedBox(height: 12),
          _buildBudgetSlider(
            label: 'Capital 3a net',
            value: _budget3a,
            min: 0,
            max: 500000,
            step: 10000,
            onChanged: (v) {
              _budget3a = v;
              _recalculateBudget();
            },
          ),
          const SizedBox(height: 12),
          _buildBudgetSlider(
            label: 'Autres revenus',
            value: _budgetAutres,
            min: 0,
            max: 5000,
            step: 100,
            onChanged: (v) {
              _budgetAutres = v;
              _recalculateBudget();
            },
          ),
          const SizedBox(height: 20),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 16),

          Text(
            'Tes depenses',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildBudgetSlider(
            label: 'Depenses mensuelles',
            value: _budgetDepenses,
            min: 1000,
            max: 15000,
            step: 250,
            onChanged: (v) {
              _budgetDepenses = v;
              _recalculateBudget();
            },
          ),
          const SizedBox(height: 12),
          _buildBudgetSlider(
            label: 'Revenu pre-retraite',
            value: _budgetRevenuPre,
            min: 2000,
            max: 20000,
            step: 500,
            onChanged: (v) {
              _budgetRevenuPre = v;
              _recalculateBudget();
            },
          ),
          const SizedBox(height: 12),

          // Couple toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Couple',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _budgetCouple,
                activeColor: MintColors.primary,
                onChanged: (v) {
                  setState(() {
                    _budgetCouple = v;
                    _recalculateBudget();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSlider({
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
              RetirementService.formatChf(value),
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
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

  List<Widget> _buildAlerts(List<String> alertes) {
    if (alertes.isEmpty) return [];
    return [
      ...alertes.map((alerte) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: MintColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber,
                      size: 18, color: MintColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alerte,
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
          )),
      const SizedBox(height: 10),
    ];
  }

  Widget _build3aDurability(double dureeAns) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, size: 20, color: MintColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ton capital 3a couvrirait environ ${dureeAns.toStringAsFixed(1)} ans de depenses.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetChecklist() {
    final items = [
      'Verifie ton extrait CI AVS (lacunes)',
      'Demande un releve de ta caisse LPP',
      'Estime tes depenses reelles (pas seulement les fixes)',
      'Prevois une marge pour les imprevus sante',
      'Pense aux impots sur les rentes',
    ];

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
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'CHECKLIST BUDGET RETRAITE',
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
          ...List.generate(items.length, (index) {
            final checked = _planningChecked.contains(index + 100);
            return _buildCheckItem(
              items[index],
              checked,
              () {
                setState(() {
                  if (checked) {
                    _planningChecked.remove(index + 100);
                  } else {
                    _planningChecked.add(index + 100);
                  }
                });
              },
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 4: PLANNING
  // ════════════════════════════════════════════════════════════

  Widget _buildTab4Planning() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // ── Intro ──────────────────────────────────────
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
              const Icon(Icons.timeline, color: MintColors.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Voici les etapes cles pour preparer ta retraite. '
                  'Coche les actions au fur et a mesure.',
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
        const SizedBox(height: 24),

        // ── Timeline ──────────────────────────────────
        _buildTimeline(),
        const SizedBox(height: 24),

        // ── Action checklist ──────────────────────────
        _buildPlanningChecklist(),
        const SizedBox(height: 24),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildTimeline() {
    final milestones = [
      _Milestone(age: 60, title: 'Bilan prevoyance',
          desc: 'Fais le point sur tes 3 piliers. Demande les releves AVS + LPP.'),
      _Milestone(age: 62, title: 'Choix rente/capital LPP',
          desc: 'Informe ta caisse de pension au minimum 3 ans avant si tu veux le capital.'),
      _Milestone(age: 63, title: 'Anticipation possible',
          desc: 'Tu peux anticiper ta rente AVS des 63 ans (avec penalite de 6.8%/an).'),
      _Milestone(age: 64, title: 'Demande AVS',
          desc: 'Depose ta demande de rente AVS 3-4 mois avant la date souhaitee.'),
      _Milestone(age: 65, title: 'Age de reference',
          desc: 'Age legal de la retraite AVS. Debut de la rente sans penalite ni bonus.'),
      _Milestone(age: 66, title: 'Ajournement possible',
          desc: 'Tu peux ajourner ta rente AVS jusqu\'a 70 ans pour un bonus permanent.'),
      _Milestone(age: 70, title: 'Ajournement max',
          desc: 'Dernier delai pour commencer ta rente AVS. Bonus max : +31.5%.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timeline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'JALONS RETRAITE',
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
        ...milestones.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;
          final isLast = idx == milestones.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line + dot
                SizedBox(
                  width: 50,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: m.age == 65
                              ? MintColors.primary
                              : MintColors.appleSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: m.age == 65
                                ? MintColors.primary
                                : MintColors.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${m.age}',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: m.age == 65
                                ? Colors.white
                                : MintColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: MintColors.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MintColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.desc,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: MintColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlanningChecklist() {
    final items = [
      'Commander ton extrait de compte individuel (CI) AVS',
      'Demander un certificat de prevoyance LPP a ta caisse',
      'Lister tous tes comptes 3a et libre passage',
      'Calculer ton budget retraite realiste',
      'Annoncer le retrait en capital 3 ans a l\'avance (si capital LPP)',
      'Verifier l\'echelonnement optimal des retraits 3a',
      'Consulter un-e specialiste en prevoyance',
      'Deposer ta demande AVS 3-4 mois avant le depart',
      'Adapter ton portefeuille d\'investissement',
      'Planifier ta couverture maladie post-retraite',
    ];

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
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'CHECKLIST RETRAITE',
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
          ...List.generate(items.length, (index) {
            final checked = _planningChecked.contains(index);
            return _buildCheckItem(
              items[index],
              checked,
              () {
                setState(() {
                  if (checked) {
                    _planningChecked.remove(index);
                  } else {
                    _planningChecked.add(index);
                  }
                });
              },
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

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

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
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
      ),
    );
  }

  Widget _buildCheckItem(String text, bool checked, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? MintColors.success : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? MintColors.success : MintColors.border,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color:
                      checked ? MintColors.textMuted : MintColors.textPrimary,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
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
              'Estimations simplifiees a but educatif — ne constitue pas un '
              'conseil en prevoyance (LSFin). Les montants dependent de nombreux '
              'facteurs (duree de cotisation, revenus, canton, etc.). '
              'Consulte un-e specialiste en prevoyance pour un calcul personnalise.',
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

// ── Internal data class for timeline ───────────────────────

class _Milestone {
  final int age;
  final String title;
  final String desc;

  const _Milestone({
    required this.age,
    required this.title,
    required this.desc,
  });
}
