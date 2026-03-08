import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/expat_service.dart';

// ────────────────────────────────────────────────────────────
//  FRONTALIER SCREEN — Sprint S23 / Expatriation + Frontaliers
// ────────────────────────────────────────────────────────────
//
// Three-tab interactive screen for cross-border workers:
//   Tab 1: "Impots"   — Source tax calculator (Bareme C)
//   Tab 2: "90 jours" — Home office 90-day rule gauge
//   Tab 3: "Charges"  — Social security comparison CH vs abroad
//
// All text in French (informal "tu").
// Material 3, MintColors theme, GoogleFonts.
// Ne constitue pas un conseil fiscal ou juridique (LSFin).
// ────────────────────────────────────────────────────────────

class FrontalierScreen extends StatefulWidget {
  const FrontalierScreen({super.key});

  @override
  State<FrontalierScreen> createState() => _FrontalierScreenState();
}

class _FrontalierScreenState extends State<FrontalierScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Impots inputs ──────────────────────────────
  String _taxCanton = 'GE';
  double _taxSalary = 7000;
  int _taxMaritalStatus = 0; // 0=Celibataire, 1=Marie(e)
  int _taxChildren = 0;
  Map<String, dynamic>? _taxResult;

  // ── Tab 2: 90 jours inputs ────────────────────────────
  int _bureauDays = 180;
  int _homeOfficeDays = 40;
  Map<String, dynamic>? _ruleResult;

  // ── Tab 3: Charges inputs ─────────────────────────────
  double _chargesSalary = 7000;
  String _chargesCountry = 'France';
  Map<String, dynamic>? _chargesResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _recalculateTax();
    _recalculate90Day();
    _recalculateCharges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recalculateTax() {
    setState(() {
      _taxResult = ExpatService.calculateSourceTax(
        salary: _taxSalary,
        canton: _taxCanton,
        isMarried: _taxMaritalStatus == 1,
        children: _taxChildren,
      );
    });
  }

  void _recalculate90Day() {
    setState(() {
      _ruleResult = ExpatService.simulate90DayRule(
        homeOfficeDays: _homeOfficeDays,
        commuteDays: _bureauDays,
      );
    });
  }

  void _recalculateCharges() {
    setState(() {
      _chargesResult = ExpatService.compareSocialCharges(
        salary: _chargesSalary,
        residenceCountry: _chargesCountry,
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
            _buildTab1Impots(),
            _buildTab290Jours(),
            _buildTab3Charges(),
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
          'Frontalier',
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
          Tab(text: 'Impôts'),
          Tab(text: '90 jours'),
          Tab(text: 'Charges'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: IMPOTS — Source Tax Calculator
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Impots() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildTaxInputsCard(),
        const SizedBox(height: 20),
        if (_taxResult != null) ...[
          _buildTaxResultCard(),
          const SizedBox(height: 20),
          // Quasi-resident badge (GE only)
          if (_taxCanton == 'GE') _buildQuasiResidentBadge(),
          if (_taxCanton == 'GE') const SizedBox(height: 20),
          // Tessin note
          if (_taxResult!['isTessin'] == true) _buildTessinNote(),
          if (_taxResult!['isTessin'] == true) const SizedBox(height: 20),
        ],
        _buildEducationalInsert(
          'En Suisse, les frontaliers sont imposés à la source (barème C). '
          'Le taux varie selon le canton, l\'état civil et le nombre d\'enfants. '
          'À Genève, si plus de 90% de tes revenus mondiaux proviennent de Suisse, '
          'tu peux demander le statut de quasi-résident pour bénéficier des déductions.',
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildTaxInputsCard() {
    final sortedCodes = ExpatService.sortedCantonCodes;

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
          // Canton dropdown
          Row(
            children: [
              Expanded(
                child: Text(
                  'Canton de travail',
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
                    value: _taxCanton,
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
                        _taxCanton = v;
                        _recalculateTax();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Salary slider
          _buildSlider(
            label: 'Salaire brut mensuel',
            value: _taxSalary,
            min: 3000,
            max: 25000,
            step: 500,
            onChanged: (v) {
              _taxSalary = v;
              _recalculateTax();
            },
          ),
          const SizedBox(height: 20),

          // Marital status segmented button
          Text(
            'Etat civil',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _taxMaritalStatus = 0;
                    _recalculateTax();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _taxMaritalStatus == 0
                          ? MintColors.primary
                          : MintColors.appleSurface,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12)),
                      border: Border.all(
                        color: _taxMaritalStatus == 0
                            ? MintColors.primary
                            : MintColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Celibataire',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _taxMaritalStatus == 0
                              ? Colors.white
                              : MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _taxMaritalStatus = 1;
                    _recalculateTax();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _taxMaritalStatus == 1
                          ? MintColors.primary
                          : MintColors.appleSurface,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12)),
                      border: Border.all(
                        color: _taxMaritalStatus == 1
                            ? MintColors.primary
                            : MintColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Marie(e)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _taxMaritalStatus == 1
                              ? Colors.white
                              : MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Children stepper
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enfants a charge',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              _buildStepper(
                value: _taxChildren,
                minVal: 0,
                maxVal: 5,
                onChanged: (v) {
                  _taxChildren = v;
                  _recalculateTax();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxResultCard() {
    final result = _taxResult!;
    final isTessin = result['isTessin'] as bool;
    if (isTessin) return const SizedBox.shrink();

    final monthlyTax = result['monthlyTax'] as double;
    final effectiveRate = result['effectiveRate'] as double;
    final annualTax = result['annualTax'] as double;
    final cantonNom = result['cantonNom'] as String;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
              const Icon(Icons.receipt_long, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'IMPÔT À LA SOURCE — $cantonNom'.toUpperCase(),
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

          // Monthly tax hero
          Center(
            child: Column(
              children: [
                Text(
                  ExpatService.formatChf(monthlyTax),
                  style: GoogleFonts.montserrat(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'par mois',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Effective rate progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taux effectif',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                ),
              ),
              Text(
                ExpatService.formatPercent(effectiveRate * 100),
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: min(1.0, effectiveRate / 0.20),
              backgroundColor: MintColors.border.withValues(alpha: 0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MintColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // Annual total
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
                  'Total annuel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
                Text(
                  ExpatService.formatChf(annualTax),
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

  Widget _buildQuasiResidentBadge() {
    // Simple quasi-resident indicator for GE
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gavel, size: 18, color: MintColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quasi-résident (Genève)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.info,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Si plus de 90% de tes revenus mondiaux proviennent de Suisse, '
                  'tu peux demander la taxation ordinaire avec déductions '
                  '(3a, frais effectifs, etc.). Cela peut réduire '
                  'significativement ton impôt.',
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

  Widget _buildTessinNote() {
    final note = _taxResult!['note'] as String;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, size: 20, color: MintColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tessin — regime special',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
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
  //  TAB 2: 90 JOURS — Home Office Rule
  // ════════════════════════════════════════════════════════════

  Widget _buildTab290Jours() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Input card
        _build90DayInputCard(),
        const SizedBox(height: 20),

        if (_ruleResult != null) ...[
          // Risk gauge
          _build90DayGauge(),
          const SizedBox(height: 20),

          // Recommendation
          _build90DayRecommendation(),
          const SizedBox(height: 20),

          // Legal reference
          _build90DayLegalRef(),
          const SizedBox(height: 20),
        ],

        _buildEducationalInsert(
          'Depuis 2023, les accords amiables entre la Suisse et ses voisins '
          'fixent un seuil de tolerance pour le teletravail des frontaliers. '
          'Au-dela de 90 jours de home office par an, les cotisations sociales '
          'et l\'imposition peuvent basculer vers le pays de residence.',
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _build90DayInputCard() {
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
            label: 'Jours au bureau en Suisse',
            value: _bureauDays.toDouble(),
            min: 0,
            max: 250,
            step: 5,
            onChanged: (v) {
              _bureauDays = v.round();
              _recalculate90Day();
            },
            formatAsInt: true,
            suffix: 'jours',
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: 'Jours en home office a l\'etranger',
            value: _homeOfficeDays.toDouble(),
            min: 0,
            max: 250,
            step: 5,
            onChanged: (v) {
              _homeOfficeDays = v.round();
              _recalculate90Day();
            },
            formatAsInt: true,
            suffix: 'jours',
          ),
        ],
      ),
    );
  }

  Widget _build90DayGauge() {
    final result = _ruleResult!;
    final riskDays = result['riskDays'] as int;
    final riskLevel = result['riskLevel'] as String;
    final daysRemaining = result['daysRemaining'] as int;

    Color gaugeColor;
    String statusLabel;
    IconData statusIcon;

    switch (riskLevel) {
      case 'low':
        gaugeColor = MintColors.success;
        statusLabel = 'Pas de risque';
        statusIcon = Icons.check_circle;
        break;
      case 'medium':
        gaugeColor = MintColors.warning;
        statusLabel = 'Zone d\'attention';
        statusIcon = Icons.warning_amber;
        break;
      case 'high':
      default:
        gaugeColor = MintColors.error;
        statusLabel = 'Risque fiscal — l\'imposition bascule';
        statusIcon = Icons.dangerous;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gaugeColor.withValues(alpha: 0.3)),
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
              const Icon(Icons.speed, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'JAUGE DE RISQUE',
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

          // Big number
          Text(
            '$riskDays',
            style: GoogleFonts.montserrat(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: gaugeColor,
            ),
          ),
          Text(
            'jours de home office',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),

          // Multi-color gauge bar
          _buildMultiColorGauge(riskDays),
          const SizedBox(height: 12),

          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('70', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('90', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.error)),
              Text('120', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),

          // Status badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: gaugeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gaugeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, size: 20, color: gaugeColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: gaugeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (riskLevel != 'high') ...[
            const SizedBox(height: 12),
            Text(
              'Il te reste $daysRemaining jours de marge',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiColorGauge(int riskDays) {
    // Build a multi-section gauge: green (0-70), orange (70-90), red (90-120)
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final greenWidth = totalWidth * (70 / 120);
        final orangeWidth = totalWidth * (20 / 120);
        final redWidth = totalWidth * (30 / 120);

        // Indicator position
        final indicatorPos = min(1.0, riskDays / 120.0) * totalWidth;

        return SizedBox(
          height: 24,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background segments
              Row(
                children: [
                  Container(
                    width: greenWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.success.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(4)),
                    ),
                  ),
                  Container(
                    width: orangeWidth,
                    height: 8,
                    color: MintColors.warning.withValues(alpha: 0.3),
                  ),
                  Container(
                    width: redWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4)),
                    ),
                  ),
                ],
              ),
              // Fill
              Row(
                children: [
                  Container(
                    width: min(indicatorPos, greenWidth),
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.success,
                      borderRadius: indicatorPos <= greenWidth
                          ? BorderRadius.circular(4)
                          : const BorderRadius.horizontal(
                              left: Radius.circular(4)),
                    ),
                  ),
                  if (indicatorPos > greenWidth)
                    Container(
                      width: min(indicatorPos - greenWidth, orangeWidth),
                      height: 8,
                      color: MintColors.warning,
                    ),
                  if (indicatorPos > greenWidth + orangeWidth)
                    Container(
                      width: min(
                          indicatorPos - greenWidth - orangeWidth, redWidth),
                      height: 8,
                      decoration: const BoxDecoration(
                        color: MintColors.error,
                        borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(4)),
                      ),
                    ),
                ],
              ),
              // Indicator triangle
              Positioned(
                left: indicatorPos - 6,
                top: 10,
                child: CustomPaint(
                  size: const Size(12, 10),
                  painter: _TrianglePainter(
                    color: riskDays < 70
                        ? MintColors.success
                        : riskDays < 90
                            ? MintColors.warning
                            : MintColors.error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _build90DayRecommendation() {
    final result = _ruleResult!;
    final recommendation = result['recommendation'] as String;

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
              const Icon(Icons.tips_and_updates, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'RECOMMANDATION',
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

  Widget _build90DayLegalRef() {
    final result = _ruleResult!;
    final legalRef = result['legalReference'] as String;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book, size: 16, color: MintColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              legalRef,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: CHARGES — Social Security Comparison
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Charges() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildChargesInputCard(),
        const SizedBox(height: 20),
        if (_chargesResult != null) ...[
          _buildChargesComparison(),
          const SizedBox(height: 20),
          _buildChargesDifferenceBadge(),
          const SizedBox(height: 20),
          _buildLamalSection(),
          const SizedBox(height: 20),
        ],
        _buildEducationalInsert(
          'En tant que frontalier, tu cotises aux assurances sociales suisses '
          '(AVS/AI/APG, AC, LPP). Les taux sont generalement plus bas qu\'en '
          'France ou en Allemagne — mais la LAMal est a ta charge individuellement, '
          'ce qui peut compenser l\'avantage.',
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildChargesInputCard() {
    final countries = ExpatService.countryLabels.keys.toList();

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
            label: 'Salaire brut mensuel',
            value: _chargesSalary,
            min: 3000,
            max: 25000,
            step: 500,
            onChanged: (v) {
              _chargesSalary = v;
              _recalculateCharges();
            },
          ),
          const SizedBox(height: 20),

          Text(
            'Pays de residence',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: countries.map((country) {
                final isSelected = _chargesCountry == country;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      _chargesCountry = country;
                      _recalculateCharges();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? MintColors.primary
                            : MintColors.appleSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? MintColors.primary
                              : MintColors.border,
                        ),
                      ),
                      child: Text(
                        country,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesComparison() {
    final result = _chargesResult!;
    final ch = result['ch'] as Map<String, dynamic>;
    final foreign = result['foreign'] as Map<String, dynamic>;
    final country = result['residenceCountry'] as String;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: CH charges
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Charges CH',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildChargeRow('AVS/AI/APG', ch['avs_ai_apg'] as double),
                _buildChargeRow('AC', ch['ac'] as double),
                _buildChargeRow('LPP (est.)', ch['lpp'] as double),
                const Divider(height: 16),
                _buildChargeRow('Total', ch['total'] as double, bold: true),
                const SizedBox(height: 4),
                Text(
                  '${((ch['totalRate'] as double) * 100).toStringAsFixed(1)}% du salaire',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Right: Foreign charges
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Charges $country',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildForeignChargeRows(foreign),
                const Divider(height: 16),
                _buildChargeRow(
                    'Total', foreign['total'] as double, bold: true),
                const SizedBox(height: 4),
                Text(
                  '${((foreign['totalRate'] as double) * 100).toStringAsFixed(1)}% du salaire',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildForeignChargeRows(Map<String, dynamic> foreign) {
    final details = foreign['details'] as Map<String, dynamic>;
    final annualSalary = _chargesSalary * 12;
    final entries = details.entries
        .where((e) => e.key != 'total')
        .toList();

    return entries.map((e) {
      final label = e.key
          .replaceAll('_', ' ')
          .replaceFirst(
              e.key[0], e.key[0].toUpperCase());
      final amount = annualSalary * (e.value as double);
      return _buildChargeRow(label, amount);
    }).toList();
  }

  Widget _buildChargeRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color:
                    bold ? MintColors.textPrimary : MintColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            ExpatService.formatChf(value),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesDifferenceBadge() {
    final result = _chargesResult!;
    final difference = result['difference'] as double;
    final chLessCostly = result['chLessCostly'] as bool;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: chLessCostly
            ? MintColors.success.withValues(alpha: 0.1)
            : MintColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: chLessCostly
              ? MintColors.success.withValues(alpha: 0.3)
              : MintColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            chLessCostly ? Icons.trending_down : Icons.trending_up,
            size: 20,
            color: chLessCostly ? MintColors.success : MintColors.warning,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              chLessCostly
                  ? 'Charges CH moins elevees: ${ExpatService.formatChf(difference.abs())}/an'
                  : 'Charges CH plus elevees: +${ExpatService.formatChf(difference.abs())}/an',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: chLessCostly ? MintColors.success : MintColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLamalSection() {
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
              const Icon(Icons.local_hospital, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'ASSURANCE MALADIE',
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
          _buildLamalOptionRow(
            'LAMal (suisse)',
            'Obligatoire si tu travailles en CH. '
                'Prime individuelle (~CHF 300-500/mois).',
            Icons.shield_outlined,
          ),
          const SizedBox(height: 10),
          _buildLamalOptionRow(
            'CMU/Secu (France)',
            'Droit d\'option possible pour les frontaliers FR. '
                'Cotisation ~8% du revenu fiscal.',
            Icons.health_and_safety_outlined,
          ),
          const SizedBox(height: 10),
          _buildLamalOptionRow(
            'Assurance privee (DE/IT/AT)',
            'En Allemagne, option PKV pour hauts revenus. '
                'IT/AT: regime obligatoire du pays.',
            Icons.security_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildLamalOptionRow(String title, String desc, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: MintColors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
              ExpatService.disclaimer,
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

// ── Triangle Painter for gauge indicator ─────────────────────

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
