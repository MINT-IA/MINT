import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/family_service.dart';

// ────────────────────────────────────────────────────────────
//  MARIAGE SCREEN — Sprint S22 / Famille & Concubinage
// ────────────────────────────────────────────────────────────
//
// Three-tab interactive screen:
//   Tab 1: "Impots"     — Marriage penalty/bonus calculator
//   Tab 2: "Regime"     — Matrimonial regime comparison
//   Tab 3: "Protection" — Survivor benefits (married vs not)
//
// All text in French (informal "tu").
// Material 3, MintColors theme, GoogleFonts.
// Ne constitue pas un conseil fiscal ou juridique (LSFin).
// ────────────────────────────────────────────────────────────

class MariageScreen extends StatefulWidget {
  const MariageScreen({super.key});

  @override
  State<MariageScreen> createState() => _MariageScreenState();
}

class _MariageScreenState extends State<MariageScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Impots inputs ──────────────────────────────
  double _revenu1 = 80000;
  double _revenu2 = 60000;
  String _canton = 'VD';
  int _nbEnfants = 0;
  Map<String, dynamic>? _fiscalResult;

  // ── Tab 2: Regime inputs ──────────────────────────────
  int _selectedRegime = 0; // 0=participation, 1=separation, 2=communaute
  double _patrimoine1 = 200000;
  double _patrimoine2 = 100000;

  // ── Tab 3: Protection ─────────────────────────────────
  double _renteLpp = 2500;

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
      _fiscalResult = FamilyService.compareFiscalMariage(
        revenu1: _revenu1,
        revenu2: _revenu2,
        canton: _canton,
        nbEnfants: _nbEnfants,
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
            _buildTab2Regime(),
            _buildTab3Protection(),
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
          'Mariage & fiscalite',
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
          Tab(text: 'Impots'),
          Tab(text: 'Regime'),
          Tab(text: 'Protection'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: IMPOTS — Marriage fiscal impact
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Impots() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildImpotsInputsCard(),
        const SizedBox(height: 20),
        if (_fiscalResult != null) ...[
          _buildHeroComparisonCard(),
          const SizedBox(height: 20),
          _buildDeductionsBreakdown(),
          const SizedBox(height: 20),
        ],
        _buildEducationalInsert(
          'Savais-tu que la penalite du mariage touche ~700\'000 couples en Suisse ? '
          'Le Tribunal federal a juge cette situation anticonstitutionnelle en 1984, '
          'mais elle n\'a toujours pas ete corrigee.',
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildImpotsInputsCard() {
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
          // Revenue 1 slider
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

          // Revenue 2 slider
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
          const SizedBox(height: 16),

          // Children counter
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enfants',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              _buildStepper(
                value: _nbEnfants,
                minVal: 0,
                maxVal: 5,
                onChanged: (v) {
                  _nbEnfants = v;
                  _recalculate();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroComparisonCard() {
    final result = _fiscalResult!;
    final totalCelib = result['totalCelibataires'] as double;
    final totalMarie = result['totalMarie'] as double;
    final difference = result['difference'] as double;
    final isPenalite = result['isPenalite'] as bool;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'COMPARAISON FISCALE',
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

          // Side by side cards
          Row(
            children: [
              // Left: 2 celibataires
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MintColors.appleSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 24, color: MintColors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        '2 celibataires',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        FamilyService.formatChf(totalCelib),
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MintColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right: Maries
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MintColors.appleSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 24, color: MintColors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'Maries',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        FamilyService.formatChf(totalMarie),
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MintColors.textPrimary,
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

          // Animated difference badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isPenalite
                  ? MintColors.error.withValues(alpha: 0.1)
                  : MintColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPenalite
                    ? MintColors.error.withValues(alpha: 0.3)
                    : MintColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPenalite ? Icons.trending_up : Icons.trending_down,
                  size: 20,
                  color: isPenalite ? MintColors.error : MintColors.success,
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isPenalite
                        ? 'Penalite +${FamilyService.formatChf(difference.abs())}/an'
                        : 'Bonus -${FamilyService.formatChf(difference.abs())}/an',
                    key: ValueKey(difference),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color:
                          isPenalite ? MintColors.error : MintColors.success,
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

  Widget _buildDeductionsBreakdown() {
    final result = _fiscalResult!;
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
                'DEDUCTIONS MARIAGE',
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
            'Deduction couple marie',
            FamilyService.formatChf(result['deductionMarie'] as double),
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Deduction assurance (mariee)',
            FamilyService.formatChf(result['deductionAssurance'] as double),
          ),
          const SizedBox(height: 8),
          if ((result['deductionDoubleRevenu'] as double) > 0) ...[
            _buildResultRow(
              'Deduction double revenu',
              FamilyService.formatChf(
                  result['deductionDoubleRevenu'] as double),
            ),
            const SizedBox(height: 8),
          ],
          if ((result['deductionEnfants'] as double) > 0) ...[
            _buildResultRow(
              'Deduction enfants',
              FamilyService.formatChf(result['deductionEnfants'] as double),
            ),
            const SizedBox(height: 8),
          ],
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          _buildResultRow(
            'Total deductions',
            FamilyService.formatChf(result['totalDeductions'] as double),
            bold: true,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: REGIME — Matrimonial regime comparison
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Regime() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Regime cards
        Row(
          children: [
            const Icon(Icons.gavel, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'REGIME MATRIMONIAL',
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
        _buildRegimeCard(
          index: 0,
          icon: Icons.handshake_outlined,
          title: 'Participation aux acquets',
          subtitle: 'Regime par defaut (CC art. 181)',
          description:
              'Chacun garde ses biens propres. Les acquets (gains durant le mariage) sont partages 50/50 en cas de dissolution.',
        ),
        const SizedBox(height: 10),
        _buildRegimeCard(
          index: 1,
          icon: Icons.lock_outline,
          title: 'Separation de biens',
          subtitle: 'CC art. 247',
          description:
              'Chacun conserve l\'integralite de ses biens et de ses revenus. Aucun partage automatique.',
        ),
        const SizedBox(height: 10),
        _buildRegimeCard(
          index: 2,
          icon: Icons.group_outlined,
          title: 'Communaute de biens',
          subtitle: 'CC art. 221',
          description:
              'Tout est mis en commun : biens propres et acquets. Partage egalitaire total en cas de dissolution.',
        ),
        const SizedBox(height: 24),

        // Patrimoine sliders
        Container(
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
                label: 'Patrimoine Personne 1',
                value: _patrimoine1,
                min: 0,
                max: 1000000,
                step: 10000,
                onChanged: (v) {
                  setState(() {
                    _patrimoine1 = v;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildSlider(
                label: 'Patrimoine Personne 2',
                value: _patrimoine2,
                min: 0,
                max: 1000000,
                step: 10000,
                onChanged: (v) {
                  setState(() {
                    _patrimoine2 = v;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Pie chart visualization
        _buildRegimeSplitVisualization(),
        const SizedBox(height: 20),

        // Chiffre choc
        _buildChiffreChocRegime(),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildRegimeCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
  }) {
    final isSelected = _selectedRegime == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedRegime = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.lightBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? MintColors.primary.withValues(alpha: 0.1)
                    : MintColors.appleSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color:
                    isSelected ? MintColors.primary : MintColors.textSecondary,
              ),
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
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: MintColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.check, size: 14, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegimeSplitVisualization() {
    final total = _patrimoine1 + _patrimoine2;
    if (total <= 0) return const SizedBox.shrink();

    double part1;
    double part2;
    String label1;
    String label2;

    switch (_selectedRegime) {
      case 0: // Participation aux acquets — 50/50 of gains
        part1 = total / 2;
        part2 = total / 2;
        label1 = 'Personne 1 recoit';
        label2 = 'Personne 2 recoit';
        break;
      case 1: // Separation — each keeps own
        part1 = _patrimoine1;
        part2 = _patrimoine2;
        label1 = 'Personne 1 garde';
        label2 = 'Personne 2 garde';
        break;
      case 2: // Communaute — everything shared
        part1 = total / 2;
        part2 = total / 2;
        label1 = 'Personne 1 recoit';
        label2 = 'Personne 2 recoit';
        break;
      default:
        part1 = total / 2;
        part2 = total / 2;
        label1 = 'Personne 1';
        label2 = 'Personne 2';
    }

    final ratio1 = part1 / total;
    final ratio2 = part2 / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'REPARTITION EN CAS DE DISSOLUTION',
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

          // Animated pie chart
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _PieChartPainter(
                ratio1: ratio1,
                color1: MintColors.info,
                color2: MintColors.warning,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Legend
          Row(
            children: [
              Expanded(
                child: _buildPieLegend(
                  label: label1,
                  value: FamilyService.formatChf(part1),
                  pct: '${(ratio1 * 100).toStringAsFixed(0)}%',
                  color: MintColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPieLegend(
                  label: label2,
                  value: FamilyService.formatChf(part2),
                  pct: '${(ratio2 * 100).toStringAsFixed(0)}%',
                  color: MintColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend({
    required String label,
    required String value,
    required String pct,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              pct,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChiffreChocRegime() {
    final total = _patrimoine1 + _patrimoine2;
    if (total <= 0) return const SizedBox.shrink();

    double acquetsPartage;
    if (_selectedRegime == 0) {
      // Participation: 50/50 of total
      acquetsPartage = (total / 2 - min(_patrimoine1, _patrimoine2)).abs();
    } else if (_selectedRegime == 2) {
      acquetsPartage = (total / 2 - min(_patrimoine1, _patrimoine2)).abs();
    } else {
      return const SizedBox.shrink();
    }

    if (acquetsPartage <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            FamilyService.formatChf(acquetsPartage),
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedRegime == 0
                ? 'En regime par defaut, cette part de tes acquets reviendrait a ton conjoint en cas de dissolution'
                : 'En communaute de biens, ce montant serait partage avec ton conjoint',
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
  //  TAB 3: PROTECTION — Survivor benefits
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Protection() {
    final avsSurvivor = avsRenteMaxMensuelle *
        FamilyService.avsSurvivorFactor;
    final lppSurvivor = _renteLpp * FamilyService.lppSurvivorFactor;
    final totalSurvivor = avsSurvivor + lppSurvivor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Scenario introduction
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
                  'Que se passe-t-il si l\'un de vous decede ? '
                  'Compare la protection legale entre maries et concubins.',
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

        // LPP slider
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
          ),
          child: _buildSlider(
            label: 'Rente LPP mensuelle du defunt',
            value: _renteLpp,
            min: 0,
            max: 8000,
            step: 100,
            onChanged: (v) {
              setState(() {
                _renteLpp = v;
              });
            },
          ),
        ),
        const SizedBox(height: 20),

        // AVS survivor
        _buildSurvivorCard(
          icon: Icons.account_balance_outlined,
          label: 'Rente AVS de survivant',
          subtitle: '80% de la rente maximale du defunt',
          value: avsSurvivor,
          footnote: 'LAVS art. 35 — uniquement pour les maries',
        ),
        const SizedBox(height: 12),

        // LPP survivor
        _buildSurvivorCard(
          icon: Icons.savings_outlined,
          label: 'Rente LPP de survivant',
          subtitle: '60% de la rente assuree du defunt',
          value: lppSurvivor,
          footnote: 'LPP art. 19 — maries (concubins : clause necessaire)',
        ),
        const SizedBox(height: 12),

        // Total
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                FamilyService.formatChf(totalSurvivor),
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Revenu mensuel du survivant marie',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Married vs unmarried comparison
        _buildProtectionComparison(),
        const SizedBox(height: 20),

        // Protection checklist
        _buildProtectionChecklist(),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildSurvivorCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required double value,
    required String footnote,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: MintColors.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  footnote,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${FamilyService.formatChf(value)}/mois',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionComparison() {
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
              const Icon(Icons.compare, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'MARIE VS CONCUBIN',
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
          _buildComparisonRow('Rente AVS survivant', true, false),
          _buildComparisonRow('Rente LPP survivant', true, false),
          _buildComparisonRow('Heritage exonere', true, false),
          _buildComparisonRow('Pension alimentaire', true, false),
          const SizedBox(height: 8),
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
                    'En concubinage, le partenaire survivant n\'a droit a rien '
                    'par defaut — ni rente AVS, ni heritage exonere. '
                    'Il faut tout prevoir par contrat.',
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

  Widget _buildComparisonRow(String label, bool married, bool concubin) {
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

  Widget _buildProtectionChecklist() {
    final items = [
      'Rediger un testament (clause d\'usufruit)',
      'Clause beneficiaire LPP (demander a ta caisse de pension)',
      'Assurance-vie croisee (protection du partenaire)',
      'Mandat pour cause d\'inaptitude',
      'Directives anticipees du patient',
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
              const Icon(Icons.checklist, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'PROTECTIONS ESSENTIELLES',
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
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: MintColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: MintColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
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

  Widget _buildResultRow(String label, String value, {bool bold = false}) {
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
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: MintColors.textPrimary,
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
            child:
                const Icon(Icons.lightbulb_outline, size: 18, color: MintColors.info),
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
              'un conseil fiscal ou juridique. Les montants dependent de nombreux '
              'facteurs (deductions, commune, fortune, etc.). '
              'Consulte un-e specialiste fiscal-e pour un calcul personnalise.',
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

// ── Pie Chart Painter ───────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final double ratio1;
  final Color color1;
  final Color color2;

  _PieChartPainter({
    required this.ratio1,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    final paint1 = Paint()
      ..color = color1
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = color2
      ..style = PaintingStyle.fill;

    const startAngle = -pi / 2;
    final sweep1 = 2 * pi * ratio1;
    final sweep2 = 2 * pi * (1 - ratio1);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep1,
      true,
      paint1,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + sweep1,
      sweep2,
      true,
      paint2,
    );

    // White center hole
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.ratio1 != ratio1;
  }
}
