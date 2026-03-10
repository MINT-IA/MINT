import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:mint_mobile/widgets/coach/rent_vs_buy_scoreboard_widget.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';

/// Location vs Propriete arbitrage screen — compare renting + investing
/// surplus vs buying property with mortgage.
///
/// Sprint S33 — Arbitrage Phase 2.
///
/// NEVER ranks options. Side-by-side comparison only.
/// All text in French, informal "tu".
/// No banned terms.
class LocationVsProprieteScreen extends StatefulWidget {
  const LocationVsProprieteScreen({super.key});

  @override
  State<LocationVsProprieteScreen> createState() =>
      _LocationVsProprieteScreenState();
}

class _LocationVsProprieteScreenState extends State<LocationVsProprieteScreen> {
  // ── Input controllers ──
  final _capitalCtrl = TextEditingController(text: '200000');
  final _loyerCtrl = TextEditingController(text: '2000');
  final _prixBienCtrl = TextEditingController(text: '800000');
  String _canton = 'VD';
  bool _isMarried = false;
  bool _hasEstimatedValues = false;

  // ── Hypothesis sliders ──
  Map<String, double> _hypotheses = {
    'rendement_marche': 4.0,
    'appreciation_immo': 1.5,
    'taux_hypo': 2.0,
    'horizon': 20.0,
  };

  ArbitrageResult? _result;

  // ── CoachProfile auto-fill (P8 Phase 4) ──
  bool _didAutoFill = false;
  Map<String, ProfileDataSource> _dataSources = {};

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFill) {
      _didAutoFill = true;
      _autoFillFromProfile();
    }
  }

  void _autoFillFromProfile() {
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;

    final canton = profile.canton.isNotEmpty ? profile.canton : 'VD';
    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final patrimoine = profile.patrimoine;
    final capital = patrimoine?.epargneLiquide ?? 0;

    setState(() {
      _canton = canton;
      _isMarried = isMarried;
      if (capital > 0) {
        _capitalCtrl.text = capital.round().toString();
        _hasEstimatedValues = true;
      }
      // Loyer mensuel from profile
      if (profile.depenses.loyer > 0) {
        _loyerCtrl.text = profile.depenses.loyer.round().toString();
        _hasEstimatedValues = true;
      }
      _dataSources = profile.dataSources;
    });
    _recalculate();
  }

  @override
  void dispose() {
    _capitalCtrl.dispose();
    _loyerCtrl.dispose();
    _prixBienCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final capital =
        double.tryParse(_capitalCtrl.text.replaceAll("'", '')) ?? 200000;
    final loyer =
        double.tryParse(_loyerCtrl.text.replaceAll("'", '')) ?? 2000;
    final prixBien =
        double.tryParse(_prixBienCtrl.text.replaceAll("'", '')) ?? 800000;

    final result = ArbitrageEngine.compareLocationVsPropriete(
      capitalDisponible: capital,
      loyerMensuelActuel: loyer,
      prixBien: prixBien,
      canton: _canton,
      horizonAnnees: (_hypotheses['horizon'] ?? 20).round(),
      rendementMarche: (_hypotheses['rendement_marche'] ?? 4.0) / 100,
      appreciationImmo: (_hypotheses['appreciation_immo'] ?? 1.5) / 100,
      tauxHypotheque: (_hypotheses['taux_hypo'] ?? 2.0) / 100,
      tauxEntretien: 0.01,
      isMarried: _isMarried,
      dataSources: _dataSources.isNotEmpty ? _dataSources : null,
    );

    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ──
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Louer ou acheter ?',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MintColors.primary, MintColors.accent],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Inputs ──
                _buildInputSection(),
                const SizedBox(height: 24),

                // ── Chart ──
                if (_result != null && _result!.options.isNotEmpty) ...[
                  // ── Indicatif banner (P8 Phase 4) ──
                  IndicatifBanner(
                    confidenceScore: _result!.confidenceScore,
                    topEnrichmentCategory: 'patrimoine',
                  ),
                  if (_hasEstimatedValues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SmartDefaultIndicator(
                        source: 'Valeurs pre-remplies depuis ton profil',
                        confidence: _result!.confidenceScore / 100,
                      ),
                    ),
                  Text(
                    'Trajectoires comparees',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Touche le graphique pour voir les valeurs a chaque annee.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TrajectoryComparisonChart(
                    options: _result!.options,
                    breakevenYear: _result!.breakevenYear,
                    colors: const [
                      MintColors.retirementAvs,
                      MintColors.retirementLpp,
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Breakeven ──
                  BreakevenIndicatorWidget(
                    breakevenYear: _result!.breakevenYear,
                    ageRetraite: 0,
                    horizon: (_hypotheses['horizon'] ?? 20).round(),
                    sensitivity: _result!.sensitivity,
                  ),
                  const SizedBox(height: 20),

                  ArbitrageTornadoSection(result: _result!),
                  const SizedBox(height: 20),

                  // ── Affordability warning ──
                  _buildAffordabilityWarning(),
                  const SizedBox(height: 20),

                  // ── Chiffre choc ──
                  _buildChiffreChocCard(),
                  const SizedBox(height: 20),

                  // ── Hypothesis sliders ──
                  HypothesisEditorWidget(
                    hypotheses: const [
                      HypothesisConfig(
                        key: 'rendement_marche',
                        label: 'Rendement marche',
                        min: 0,
                        max: 8,
                        divisions: 16,
                        defaultValue: 4,
                      ),
                      HypothesisConfig(
                        key: 'appreciation_immo',
                        label: 'Appreciation immobiliere',
                        min: 0,
                        max: 4,
                        divisions: 8,
                        defaultValue: 1.5,
                      ),
                      HypothesisConfig(
                        key: 'taux_hypo',
                        label: 'Taux hypothecaire',
                        min: 0.5,
                        max: 5,
                        divisions: 9,
                        defaultValue: 2,
                      ),
                      HypothesisConfig(
                        key: 'horizon',
                        label: 'Horizon',
                        min: 5,
                        max: 30,
                        divisions: 25,
                        defaultValue: 20,
                        unit: 'ans',
                      ),
                    ],
                    values: _hypotheses,
                    onChanged: (updated) {
                      _hypotheses = updated;
                      _recalculate();
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Hypotheses list ──
                  _buildHypothesesSection(),
                  const SizedBox(height: 20),

                  // ── P3-A : Grand Match Louer vs Acheter ─────────
                  RentVsBuyScoreboardWidget(
                    propertyPrice: double.tryParse(
                            _prixBienCtrl.text.replaceAll("'", '')) ??
                        800000,
                    equity: double.tryParse(
                            _capitalCtrl.text.replaceAll("'", '')) ??
                        200000,
                    monthlyRent: double.tryParse(
                            _loyerCtrl.text.replaceAll("'", '')) ??
                        2000,
                    mortgageMonthly: ((double.tryParse(
                                    _prixBienCtrl.text.replaceAll("'", '')) ??
                                800000) -
                            (double.tryParse(
                                    _capitalCtrl.text.replaceAll("'", '')) ??
                                200000)) *
                        0.05 /
                        12,
                    years: (_hypotheses['horizon'] ?? 20).round(),
                    appreciationRate: (_hypotheses['appreciation_immo'] ?? 1.5) /
                        100,
                    investmentReturnRate:
                        (_hypotheses['rendement_marche'] ?? 4.0) / 100,
                  ),
                  const SizedBox(height: 20),

                  // ── Disclaimer ──
                  _buildDisclaimerCard(),
                  const SizedBox(height: 32),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  INPUT SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ton projet immobilier',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _capitalCtrl,
            label: 'Capital disponible / fonds propres (CHF)',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _loyerCtrl,
            label: 'Loyer mensuel actuel (CHF)',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _prixBienCtrl,
            label: 'Prix du bien immobilier (CHF)',
          ),
          const SizedBox(height: 16),

          // Canton dropdown + married toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canton',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: MintColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _canton,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: sortedCantonCodes.map((code) {
                          final name = cantonFullNames[code] ?? code;
                          return DropdownMenuItem(
                            value: code,
                            child: Text(
                              '$code - $name',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
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
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marie\u00b7e',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Switch(
                    value: _isMarried,
                    activeColor: MintColors.primary,
                    onChanged: (v) {
                      _isMarried = v;
                      _recalculate();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _recalculate,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Comparer les trajectoires',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (_) => _recalculate(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  AFFORDABILITY WARNING
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAffordabilityWarning() {
    final prixBien =
        double.tryParse(_prixBienCtrl.text.replaceAll("'", '')) ?? 800000;
    // FINMA theoretical charge: 5% interest + 1% amortization + 1% maintenance
    final chargeTheorique = prixBien * 0.07;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warning.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: MintColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification de la capacite financiere (FINMA)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Charge theorique annuelle : ${_formatChf(chargeTheorique)} '
                  '(taux theorique 5 % + amortissement 1 % + entretien 1 %). '
                  'Les banques exigent que cette charge ne depasse pas 1/3 de '
                  'ton revenu brut annuel.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revenu brut minimum necessaire : ${_formatChf(chargeTheorique * 3)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

  // ═══════════════════════════════════════════════════════════════
  //  CHIFFRE CHOC CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildChiffreChocCard() {
    if (_result == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.info.withAlpha(15),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MintColors.info.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_rounded,
              color: MintColors.info,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _result!.chiffreChoc,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _result!.displaySummary,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HYPOTHESES EXPANDABLE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHypothesesSection() {
    if (_result == null) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        'Hypotheses utilisees',
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: MintColors.textPrimary,
        ),
      ),
      children: [
        for (final h in _result!.hypotheses)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('  \u2022  ',
                    style: TextStyle(color: MintColors.textMuted)),
                Expanded(
                  child: Text(
                    h,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DISCLAIMER CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDisclaimerCard() {
    if (_result == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: MintColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Avertissement',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _result!.disclaimer,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sources : ${_result!.sources.join(' | ')}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatChf(double value) {
    final intVal = value.round().abs();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${value < 0 ? '-' : ''}${buffer.toString()}';
  }
}
