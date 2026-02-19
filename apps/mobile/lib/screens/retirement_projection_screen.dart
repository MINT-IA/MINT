import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/fullscreen_chart_wrapper.dart';
import 'package:mint_mobile/widgets/retirement/income_stacked_bar_chart.dart';
import 'package:mint_mobile/widgets/retirement/early_retirement_chart.dart';
import 'package:mint_mobile/widgets/retirement/couple_timeline_chart.dart';
import 'package:mint_mobile/widgets/retirement/budget_gap_chart.dart';
import 'package:provider/provider.dart';

/// Unified retirement projection screen — scrollable narrative.
///
/// Sections:
///   1. Hero number (revenu mensuel at 65 + taux de remplacement)
///   2. Parameters (sliders: retirement age, expenses)
///   3. Income decomposition (stacked bars)
///   4. Early retirement comparison (63-70)
///   5. Couple timeline (if couple with age gap)
///   6. Budget gap (waterfall)
///   7. 25-year indexed projection
///   8. Educational cards
///   9. Disclaimer
class RetirementProjectionScreen extends StatefulWidget {
  const RetirementProjectionScreen({super.key});

  @override
  State<RetirementProjectionScreen> createState() =>
      _RetirementProjectionScreenState();
}

class _RetirementProjectionScreenState
    extends State<RetirementProjectionScreen>
    with TickerProviderStateMixin {
  int _retirementAgeUser = 65;
  int? _retirementAgeConjoint;
  double? _depensesMensuelles;
  bool _parametersExpanded = false;

  late AnimationController _heroController;
  late Animation<double> _heroAnimation;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _heroAnimation = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    );
    _heroController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CoachProfileProvider>();
    final profile = provider.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final result = RetirementProjectionService.project(
      profile: profile,
      retirementAgeUser: _retirementAgeUser,
      retirementAgeConjoint: _retirementAgeConjoint,
      depensesMensuelles: _depensesMensuelles,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────
          _buildAppBar(),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // 1. Hero number
                  _buildHero(result),
                  const SizedBox(height: 24),

                  // 2. Parameters
                  _buildParameters(profile, result),
                  const SizedBox(height: 24),

                  // 3. Income decomposition
                  _buildSectionTitle(
                    'Decomposition des revenus',
                    Icons.stacked_bar_chart,
                  ),
                  const SizedBox(height: 12),
                  FullscreenChartWrapper(
                    title: 'Decomposition des revenus',
                    disclaimer: result.disclaimer,
                    child: IncomeStackedBarChart(
                      phases: result.phases,
                      currentIncome: result.revenuPreRetraiteMensuel,
                      monthlyExpenses: _depensesMensuelles ??
                          result.budgetGap.depensesMensuelles,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 4. Early retirement
                  _buildSectionTitle(
                    'Retraite anticipee ou ajournee ?',
                    Icons.timelapse,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Impact sur ton revenu mensuel selon l\'age de depart '
                    '(LAVS art. 21-29).',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FullscreenChartWrapper(
                    title: 'Retraite anticipee / ajournee',
                    disclaimer: result.disclaimer,
                    child: EarlyRetirementChart(
                      scenarios: result.earlyRetirementComparisons,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 5. Couple timeline (if applicable)
                  if (result.isCouple &&
                      result.phases.length > 1) ...[
                    _buildSectionTitle(
                      'Timeline du couple',
                      Icons.people_outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quand les deux partenaires ne prennent pas la retraite '
                      'la meme annee, les revenus du menage changent en deux phases.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FullscreenChartWrapper(
                      title: 'Timeline couple',
                      disclaimer: result.disclaimer,
                      child: CoupleTimelineChart(
                        phases: result.phases,
                        userName: profile.firstName ?? 'Toi',
                        conjointName:
                            profile.conjoint?.firstName ?? 'Conjoint·e',
                        userBirthYear: profile.birthYear,
                        conjointBirthYear:
                            profile.conjoint?.birthYear ?? profile.birthYear,
                        userRetirementAge: _retirementAgeUser,
                        conjointRetirementAge:
                            _retirementAgeConjoint ?? 65,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // 6. Budget gap
                  _buildSectionTitle(
                    'Budget a la retraite',
                    Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Construction des revenus, deduction des impots estimes '
                    'et comparaison avec tes depenses.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FullscreenChartWrapper(
                    title: 'Budget retraite',
                    disclaimer: result.disclaimer,
                    child: BudgetGapChart(budgetGap: result.budgetGap),
                  ),
                  const SizedBox(height: 32),

                  // 7. Indexed projection
                  _buildSectionTitle(
                    'Projection sur 25 ans',
                    Icons.show_chart,
                  ),
                  const SizedBox(height: 12),
                  _buildIndexedProjection(result),
                  const SizedBox(height: 32),

                  // 8. Educational cards
                  _buildEducationalCards(result),
                  const SizedBox(height: 24),

                  // 9. Disclaimer + sources
                  _buildDisclaimer(result),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Projection retraite',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.primary, Color(0xFF2D2D30)],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HERO NUMBER
  // ════════════════════════════════════════════════════════════

  Widget _buildHero(RetirementProjectionResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.info.withValues(alpha: 0.06),
            MintColors.purple.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            'Revenu mensuel du menage a $_retirementAgeUser ans',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _heroAnimation,
            builder: (context, _) {
              final value =
                  result.revenuMensuelAt65 * _heroAnimation.value;
              return Text(
                RetirementProjectionService.formatChf(value),
                style: GoogleFonts.montserrat(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: MintColors.textPrimary,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoBadge(
                'Taux de remplacement',
                '${result.tauxRemplacement.toStringAsFixed(0)}%',
                result.tauxRemplacement >= 60
                    ? MintColors.success
                    : MintColors.warning,
              ),
              const SizedBox(width: 16),
              _infoBadge(
                'Revenu actuel net',
                RetirementProjectionService.formatChf(
                    result.revenuPreRetraiteMensuel),
                MintColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PARAMETERS
  // ════════════════════════════════════════════════════════════

  Widget _buildParameters(
    CoachProfile profile,
    RetirementProjectionResult result,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(
                () => _parametersExpanded = !_parametersExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 20, color: MintColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Parametres de simulation',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _parametersExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: MintColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_parametersExpanded) ...[
            const Divider(height: 1, color: MintColors.lightBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Retirement age user
                  _sliderRow(
                    label: 'Age de depart',
                    value: _retirementAgeUser.toDouble(),
                    min: 63,
                    max: 70,
                    suffix: 'ans',
                    onChanged: (v) => setState(
                        () => _retirementAgeUser = v.round()),
                  ),

                  // Retirement age conjoint
                  if (profile.isCouple &&
                      profile.conjoint != null) ...[
                    const SizedBox(height: 16),
                    _sliderRow(
                      label:
                          'Age depart ${profile.conjoint!.firstName ?? "conjoint·e"}',
                      value:
                          (_retirementAgeConjoint ?? 65).toDouble(),
                      min: 63,
                      max: 70,
                      suffix: 'ans',
                      onChanged: (v) => setState(
                          () => _retirementAgeConjoint = v.round()),
                    ),
                  ],

                  // Monthly expenses
                  const SizedBox(height: 16),
                  _sliderRow(
                    label: 'Depenses mensuelles',
                    value: _depensesMensuelles ??
                        result.budgetGap.depensesMensuelles,
                    min: 2000,
                    max: 10000,
                    suffix: 'CHF',
                    divisions: 80,
                    onChanged: (v) => setState(() =>
                        _depensesMensuelles = (v / 100).round() * 100.0),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
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
              suffix == 'CHF'
                  ? 'CHF ${value.toStringAsFixed(0)}'
                  : '${value.toStringAsFixed(0)} $suffix',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions ?? (max - min).round(),
          activeColor: MintColors.info,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  INDEXED PROJECTION TABLE
  // ════════════════════════════════════════════════════════════

  Widget _buildIndexedProjection(RetirementProjectionResult result) {
    final points = result.indexedProjection;
    if (points.isEmpty) return const SizedBox.shrink();

    // Show every 5 years
    final keyPoints = points.where((p) => p.age % 5 == 0 || p == points.first || p == points.last).toList();

    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Age',
                      style: _tableHeaderStyle),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Nominal',
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Indexe',
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Pouvoir d\'achat',
                      style: _tableHeaderStyle,
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: MintColors.lightBorder),
          ...keyPoints.map((p) => _projectionRow(p)),
        ],
      ),
    );
  }

  Widget _projectionRow(IndexedProjectionPoint point) {
    final isFirst = point.age == _retirementAgeUser;
    return Container(
      color: isFirst ? MintColors.info.withValues(alpha: 0.04) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${point.age}',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _formatK(point.revenuNominal),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _formatK(point.revenuIndexe),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _formatK(point.pouvoirAchat),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: point.pouvoirAchat < point.revenuNominal
                    ? MintColors.warning
                    : MintColors.success,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _tableHeaderStyle => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: MintColors.textMuted,
      );

  // ════════════════════════════════════════════════════════════
  //  EDUCATIONAL CARDS
  // ════════════════════════════════════════════════════════════

  Widget _buildEducationalCards(RetirementProjectionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Le savais-tu ?', Icons.lightbulb_outline),
        const SizedBox(height: 12),
        _educationCard(
          'Indexation AVS',
          'Les rentes AVS sont adaptees periodiquement selon l\'indice '
              'mixte (prix + salaires). En moyenne ~1% par an. '
              'Les rentes LPP ne sont pas indexees obligatoirement.',
          Icons.trending_up,
          MintColors.info,
        ),
        if (result.isCouple)
          _educationCard(
            'Plafonnement couple (150%)',
            'Les rentes AVS d\'un couple marie sont plafonnees a 150% de '
                'la rente maximale individuelle, soit CHF 3\'780/mois. '
                'Meme si chaque conjoint a droit a la rente max.',
            Icons.people,
            MintColors.purple,
          ),
        _educationCard(
          'Prestations complementaires (PC)',
          'Si tes revenus a la retraite sont insuffisants, tu peux '
              'potentiellement beneficier des PC. Renseigne-toi aupres '
              'de ton office cantonal des assurances sociales.',
          Icons.support,
          MintColors.teal,
        ),
        _educationCard(
          'Retrait 3a echelonne',
          'Retirer ton capital 3a sur plusieurs annees fiscales '
              '(comptes separes, retrait a 60, 62, 64) peut reduire '
              'significativement l\'impot sur le retrait en capital.',
          Icons.calendar_month,
          MintColors.amber,
        ),
      ],
    );
  }

  Widget _educationCard(
    String title,
    String body,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 12,
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
  //  DISCLAIMER
  // ════════════════════════════════════════════════════════════

  Widget _buildDisclaimer(RetirementProjectionResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'Avertissement',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.disclaimer,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sources : ${result.sources.join(' · ')}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MintColors.textPrimary),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatK(double value) {
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}k";
    }
    return value.toStringAsFixed(0);
  }
}
