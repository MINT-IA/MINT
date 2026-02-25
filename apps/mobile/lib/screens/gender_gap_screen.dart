import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/segments_service.dart';

// ────────────────────────────────────────────────────────────
//  GENDER GAP PREVOYANCE SCREEN — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────
//
// Interactive screen showing the pension gap between current
// activity rate and 100%. Includes taux_activite slider,
// visual comparison, educational content about the
// coordination deduction, and personalised recommendations.
// ────────────────────────────────────────────────────────────

class GenderGapScreen extends StatefulWidget {
  const GenderGapScreen({super.key});

  @override
  State<GenderGapScreen> createState() => _GenderGapScreenState();
}

class _GenderGapScreenState extends State<GenderGapScreen> {
  // ── State ──────────────────────────────────────────────────
  double _tauxActivite = 60;
  final double _revenuAnnuel = 85000;
  final int _age = 40;
  final double _avoirLpp = 120000;
  final int _anneesCotisation = 15;
  final String _canton = 'VD';

  GenderGapResult? _result;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    // Scale revenue to match activity rate for the input
    final input = GenderGapInput(
      tauxActivite: _tauxActivite,
      age: _age,
      revenuAnnuel: _revenuAnnuel * (_tauxActivite / 100),
      avoirLpp: _avoirLpp,
      anneesCotisation: _anneesCotisation,
      canton: _canton,
    );
    setState(() {
      _result = GenderGapService.analyse(input: input);
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(),
                const SizedBox(height: 20),
                _buildIntro(),
                const SizedBox(height: 24),

                // Taux activite slider
                _buildTauxSlider(),
                const SizedBox(height: 24),

                // Input section
                _buildInputSection(),
                const SizedBox(height: 24),

                // Results
                if (_result != null) ...[
                  _buildPensionComparison(),
                  const SizedBox(height: 20),
                  _buildCoordinationExplanation(),
                  const SizedBox(height: 20),
                  _buildOfsStatistic(),
                  const SizedBox(height: 20),
                  _buildRecommendations(),
                  const SizedBox(height: 20),
                ],

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 16),

                // Sources
                _buildSourcesFooter(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'GENDER GAP PREVOYANCE',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: const Borderconst Radius.circular(16),
          ),
          child: Icon(
            Icons.balance,
            color: Colors.purple.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lacune de prevoyance',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Impact du temps partiel sur la retraite',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'La deduction de coordination (CHF\u00A026\'460) n\'est pas '
              'proratisee pour le temps partiel, ce qui penalise '
              'davantage les personnes travaillant a temps reduit. '
              'Deplacez le curseur pour voir l\'impact.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Taux slider ────────────────────────────────────────────

  Widget _buildTauxSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const Borderconst Radius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taux d\'activite',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _tauxActivite < 60
                      ? MintColors.error.withValues(alpha: 0.1)
                      : _tauxActivite < 80
                          ? MintColors.warning.withValues(alpha: 0.1)
                          : MintColors.success.withValues(alpha: 0.1),
                  borderRadius: const Borderconst Radius.circular(8),
                ),
                child: Text(
                  '${_tauxActivite.round()}%',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _tauxActivite < 60
                        ? MintColors.error
                        : _tauxActivite < 80
                            ? MintColors.warning
                            : MintColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _tauxActivite,
              min: 10,
              max: 100,
              divisions: 18,
              onChanged: (value) {
                _tauxActivite = value;
                _compute();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10%', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('100%', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Input section ──────────────────────────────────────────

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const Borderconst Radius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parametres',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInputRow('Revenu annuel brut (100%)', '${GenderGapService.formatChf(_revenuAnnuel)}'),
          const SizedBox(height: 8),
          _buildInputRow('Age', '$_age ans'),
          const SizedBox(height: 8),
          _buildInputRow('Avoir LPP actuel', GenderGapService.formatChf(_avoirLpp)),
          const SizedBox(height: 8),
          _buildInputRow('Annees de cotisation', '$_anneesCotisation'),
          const SizedBox(height: 8),
          _buildInputRow('Canton', _canton),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const Borderconst Radius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mode demo : profil exemple. Complete ton diagnostic '
                    'pour des resultats personnalises.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.blue.shade700,
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

  Widget _buildInputRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Pension comparison ─────────────────────────────────────

  Widget _buildPensionComparison() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const Borderconst Radius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rente LPP estimee',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Projection a ${result.anneesRestantes} ans (age 65)',
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Visual bars
          _buildPensionBar(
            label: 'A 100%',
            amount: result.renteAt100Pct,
            maxAmount: result.renteAt100Pct,
            color: MintColors.success,
          ),
          const SizedBox(height: 12),
          _buildPensionBar(
            label: 'A ${_tauxActivite.round()}%',
            amount: result.renteAtCurrentTaux,
            maxAmount: result.renteAt100Pct,
            color: _tauxActivite < 60 ? MintColors.error : MintColors.warning,
          ),
          const SizedBox(height: 20),

          // Gap highlight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.06),
              borderRadius: const Borderconst Radius.circular(12),
              border: Border.all(color: MintColors.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lacune annuelle',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MintColors.error,
                      ),
                    ),
                    Text(
                      GenderGapService.formatChf(result.lacuneAnnuelle),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MintColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lacune totale (~20 ans)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    Text(
                      GenderGapService.formatChf(result.lacuneTotale),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPensionBar({
    required String label,
    required double amount,
    required double maxAmount,
    required Color color,
  }) {
    final ratio = maxAmount > 0 ? (amount / maxAmount).clamp(0.0, 1.0) : 0.0;
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
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              '${GenderGapService.formatChf(amount)}/an',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: const Borderconst Radius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Coordination explanation ───────────────────────────────

  Widget _buildCoordinationExplanation() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const Borderconst Radius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, color: Colors.purple.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Comprendre la deduction de coordination',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'La deduction de coordination est un montant fixe de '
            'CHF\u00A026\'460 soustrait de ton salaire brut pour '
            'calculer le salaire coordonne (base LPP). Ce montant '
            'est le meme que tu travailles a 100% ou a 50%.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Comparison table
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: const Borderconst Radius.circular(12),
            ),
            child: Column(
              children: [
                _buildComparisonRow(
                  'Salaire brut a 100%',
                  GenderGapService.formatChf(_revenuAnnuel),
                ),
                const Divider(height: 16),
                _buildComparisonRow(
                  'Salaire coordonne a 100%',
                  GenderGapService.formatChf(result.salaireCoordonne100),
                ),
                const Divider(height: 16),
                _buildComparisonRow(
                  'Salaire brut a ${_tauxActivite.round()}%',
                  GenderGapService.formatChf(_revenuAnnuel * (_tauxActivite / 100)),
                ),
                const Divider(height: 16),
                _buildComparisonRow(
                  'Salaire coordonne a ${_tauxActivite.round()}%',
                  GenderGapService.formatChf(result.salaireCoordonneActuel),
                  highlight: true,
                ),
                const Divider(height: 16),
                _buildComparisonRow(
                  'Deduction coordination (fixe)',
                  GenderGapService.formatChf(result.deductionCoordination),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Source : LPP art. 8, OPP2 art. 5',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: highlight ? MintColors.error : MintColors.textSecondary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: highlight ? MintColors.error : MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── OFS Statistic ──────────────────────────────────────────

  Widget _buildOfsStatistic() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.purple.shade100.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const Borderconst Radius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bar_chart, color: Colors.purple.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistique OFS',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  GenderGapService.statistiqueOfs,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.purple.shade800,
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

  // ── Recommendations ────────────────────────────────────────

  Widget _buildRecommendations() {
    final result = _result!;
    if (result.recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'RECOMMANDATIONS',
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
        ...result.recommendations.map((rec) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRecommendationCard(rec),
        )),
      ],
    );
  }

  Widget _buildRecommendationCard(GenderGapRecommendation rec) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rec.title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rec.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rec.source,
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les resultats presentes sont des estimations simplifiees '
              'a titre indicatif. Ils ne constituent pas un conseil '
              'financier personnalise. Consulte ta caisse de pension '
              'et un professionnel qualifie avant toute decision.',
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

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'LPP art. 8 (deduction de coordination) / '
          'LPP art. 14 (taux de conversion 6.8%) / '
          'OPP2 art. 5 / OPP3 art. 7 / '
          'LPP art. 79b (rachat volontaire) / '
          'OFS 2024 (statistiques gender gap)',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
