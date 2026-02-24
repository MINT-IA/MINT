import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';

/// Allocation annuelle arbitrage screen — compare 3a, rachat LPP,
/// amortissement indirect, and investissement libre.
///
/// Sprint S32 — Arbitrage Phase 1.
///
/// NEVER ranks options. Side-by-side comparison only.
/// All text in French, informal "tu".
/// No banned terms.
class AllocationAnnuelleScreen extends StatefulWidget {
  const AllocationAnnuelleScreen({super.key});

  @override
  State<AllocationAnnuelleScreen> createState() =>
      _AllocationAnnuelleScreenState();
}

class _AllocationAnnuelleScreenState extends State<AllocationAnnuelleScreen> {
  // ── Input controllers ──
  final _montantCtrl = TextEditingController(text: '7000');
  final _potentielRachatCtrl = TextEditingController(text: '50000');
  double _tauxMarginal = 30.0; // percentage
  bool _a3aMaxed = false;
  bool _hasRachatLpp = true;
  bool _isPropertyOwner = false;
  int _anneesAvantRetraite = 20;

  // ── Hypothesis sliders ──
  Map<String, double> _hypotheses = {
    'rendement_marche': 4.0,
    'rendement_lpp': 1.25,
    'rendement_3a': 2.0,
  };

  ArbitrageResult? _result;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _potentielRachatCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final montant =
        double.tryParse(_montantCtrl.text.replaceAll("'", '')) ?? 7000;
    final potentielRachat = _hasRachatLpp
        ? (double.tryParse(_potentielRachatCtrl.text.replaceAll("'", '')) ??
            50000)
        : 0.0;

    final result = ArbitrageEngine.compareAllocationAnnuelle(
      montantDisponible: montant,
      tauxMarginal: _tauxMarginal / 100,
      a3aMaxed: _a3aMaxed,
      potentielRachatLpp: potentielRachat,
      isPropertyOwner: _isPropertyOwner,
      tauxHypothecaire: 0.015,
      anneesAvantRetraite: _anneesAvantRetraite,
      rendement3a: (_hypotheses['rendement_3a'] ?? 2.0) / 100,
      rendementLpp: (_hypotheses['rendement_lpp'] ?? 1.25) / 100,
      rendementMarche: (_hypotheses['rendement_marche'] ?? 4.0) / 100,
      canton: 'VD',
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
                'Ou placer tes CHF ?',
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
                    colors: _colorsForOptions(_result!.options),
                  ),
                  const SizedBox(height: 20),

                  // ── Terminal values ──
                  _buildTerminalValuesCard(),
                  const SizedBox(height: 20),

                  // ── Chiffre choc ──
                  _buildChiffreChocCard(),
                  const SizedBox(height: 20),

                  // ── Sensitivity ──
                  BreakevenIndicatorWidget(
                    breakevenYear: _result!.breakevenYear,
                    ageRetraite: 65,
                    horizon: _anneesAvantRetraite,
                    sensitivity: _result!.sensitivity,
                  ),
                  const SizedBox(height: 20),

                  ArbitrageTornadoSection(result: _result!),
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
                        key: 'rendement_lpp',
                        label: 'Rendement LPP',
                        min: 0,
                        max: 4,
                        divisions: 8,
                        defaultValue: 1.25,
                      ),
                      HypothesisConfig(
                        key: 'rendement_3a',
                        label: 'Rendement 3a',
                        min: 0,
                        max: 5,
                        divisions: 10,
                        defaultValue: 2,
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

  List<Color> _colorsForOptions(List<TrajectoireOption> options) {
    const colorMap = <String, Color>{
      '3a': MintColors.retirementAvs,
      'rachat_lpp': MintColors.retirementLpp,
      'amort_indirect': MintColors.trajectoryPrudent,
      'invest_libre': MintColors.purple,
    };
    return options
        .map((o) => colorMap[o.id] ?? MintColors.textMuted)
        .toList();
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
            'Ton budget annuel',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _montantCtrl,
            label: 'Montant disponible par an (CHF)',
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
              min: 5,
              max: 40,
              divisions: 35,
              onChanged: (v) {
                setState(() => _anneesAvantRetraite = v.round());
                _recalculate();
              },
            ),
          ),
          const SizedBox(height: 12),

          // Toggles
          _buildToggle(
            label: '3a deja au maximum',
            value: _a3aMaxed,
            onChanged: (v) {
              _a3aMaxed = v;
              _recalculate();
            },
          ),
          _buildToggle(
            label: 'Potentiel de rachat LPP',
            value: _hasRachatLpp,
            onChanged: (v) {
              _hasRachatLpp = v;
              _recalculate();
            },
          ),
          if (_hasRachatLpp) ...[
            const SizedBox(height: 8),
            _buildTextField(
              controller: _potentielRachatCtrl,
              label: 'Montant de rachat possible (CHF)',
            ),
          ],
          _buildToggle(
            label: 'Proprietaire immobilier',
            value: _isPropertyOwner,
            onChanged: (v) {
              _isPropertyOwner = v;
              _recalculate();
            },
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

  Widget _buildToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: MintColors.primary,
            onChanged: (v) {
              setState(() => onChanged(v));
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TERMINAL VALUES CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTerminalValuesCard() {
    if (_result == null) return const SizedBox.shrink();
    final options = _result!.options;
    final colorMap = _colorsForOptions(options);

    return Container(
      width: double.infinity,
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
            'Valeur terminale estimee',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          Text(
            'Apres $_anneesAvantRetraite ans',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: i < colorMap.length
                          ? colorMap[i]
                          : MintColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      options[i].label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    _formatChf(options[i].terminalValue),
                    style: GoogleFonts.inter(
                      fontSize: 14,
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
              Icons.insights_rounded,
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
