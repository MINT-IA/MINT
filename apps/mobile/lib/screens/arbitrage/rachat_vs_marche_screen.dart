import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/utils/profile_auto_fill_mixin.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';

/// Rachat LPP vs Investissement libre arbitrage screen.
///
/// Sprint S33 — Arbitrage Phase 2.
///
/// NEVER ranks options. Side-by-side comparison only.
/// All text in French, informal "tu".
/// No banned terms.
class RachatVsMarcheScreen extends StatefulWidget {
  const RachatVsMarcheScreen({super.key});

  @override
  State<RachatVsMarcheScreen> createState() => _RachatVsMarcheScreenState();
}

class _RachatVsMarcheScreenState extends State<RachatVsMarcheScreen>
    with ProfileAutoFillMixin {
  // ── Input controllers ──
  final _montantCtrl = TextEditingController(text: '30000');
  double _tauxMarginal = 30.0; // percentage
  int _anneesAvantRetraite = 20;
  String _canton = 'VD';
  bool _isMarried = false;

  // ── Hypothesis sliders ──
  Map<String, double> _hypotheses = {
    'rendement_lpp': 1.25,
    'rendement_marche': 4.0,
  };

  ArbitrageResult? _result;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    autoFillFromProfile(context, (p) {
      final revenu = p.revenuBrutAnnuel;
      final canton = p.canton.isNotEmpty ? p.canton : 'VD';
      // Use financial_core TaxCalculator — canton-aware marginal rate.
      final taux = revenu > 0
          ? (RetirementTaxCalculator.estimateMarginalRate(revenu, canton) * 100)
          : 30.0;
      final annees = p.anneesAvantRetraite.clamp(1, 40);
      final isMarried = p.etatCivil == CoachCivilStatus.marie;
      setState(() {
        _tauxMarginal = taux;
        _canton = canton;
        _anneesAvantRetraite = annees;
        _isMarried = isMarried;
      });
      _recalculate();
    });
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final montant =
        double.tryParse(_montantCtrl.text.replaceAll("'", '')) ?? 30000;

    final result = ArbitrageEngine.compareRachatVsMarche(
      montant: montant,
      tauxMarginal: _tauxMarginal / 100,
      anneesAvantRetraite: _anneesAvantRetraite,
      rendementLpp: (_hypotheses['rendement_lpp'] ?? 1.25) / 100,
      rendementMarche: (_hypotheses['rendement_marche'] ?? 4.0) / 100,
      tauxConversion: lppTauxConversionMin / 100,
      canton: _canton,
      isMarried: _isMarried,
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
                'Rachat LPP ou investissement libre ?',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
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
                      MintColors.retirementLpp,
                      MintColors.purple,
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Breakeven ──
                  BreakevenIndicatorWidget(
                    breakevenYear: _result!.breakevenYear,
                    ageRetraite: 65,
                    horizon: _anneesAvantRetraite,
                    sensitivity: _result!.sensitivity,
                  ),
                  const SizedBox(height: 20),

                  ArbitrageTornadoSection(result: _result!),
                  const SizedBox(height: 20),

                  // ── Blocage warning ──
                  _buildBlocageWarning(),
                  const SizedBox(height: 20),

                  // ── Chiffre choc ──
                  _buildChiffreChocCard(),
                  const SizedBox(height: 20),

                  // ── Hypothesis sliders ──
                  HypothesisEditorWidget(
                    hypotheses: const [
                      HypothesisConfig(
                        key: 'rendement_lpp',
                        label: 'Rendement LPP',
                        min: 0,
                        max: 4,
                        divisions: 8,
                        defaultValue: 1.25,
                      ),
                      HypothesisConfig(
                        key: 'rendement_marche',
                        label: 'Rendement marche',
                        min: 0,
                        max: 8,
                        divisions: 16,
                        defaultValue: 4,
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
            'Ton rachat potentiel',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _montantCtrl,
            label: 'Montant a investir (CHF)',
          ),
          const SizedBox(height: 16),

          // Taux marginal slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Taux marginal d\'imposition estime',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_tauxMarginal.toStringAsFixed(0)} %',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.textMuted.withAlpha(40),
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withAlpha(30),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _tauxMarginal,
              min: 10,
              max: 50,
              divisions: 8,
              onChanged: (v) {
                setState(() => _tauxMarginal = v);
                _recalculate();
              },
            ),
          ),
          const SizedBox(height: 8),

          // Annees avant retraite slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Annees avant la retraite',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$_anneesAvantRetraite ans',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.textMuted.withAlpha(40),
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withAlpha(30),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _anneesAvantRetraite.toDouble(),
              min: 3,
              max: 40,
              divisions: 37,
              onChanged: (v) {
                setState(() => _anneesAvantRetraite = v.round());
                _recalculate();
              },
            ),
          ),
          const SizedBox(height: 12),

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
                'Comparer les strategies',
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
  //  BLOCAGE WARNING
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBlocageWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            color: MintColors.info,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blocage 3 ans (LPP art. 79b al. 3)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apres un rachat LPP, tu ne peux pas retirer ton capital sous '
                  'forme de capital pendant 3 ans. Si tu prevois un retrait '
                  '(retraite, EPL, depart a l\'etranger), planifie en consequence.',
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
              Icons.savings_rounded,
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
}
