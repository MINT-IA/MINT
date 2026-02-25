import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';

/// Rente vs Capital arbitrage screen — compare full rente, full capital,
/// and mixed strategies with real-time recalculation.
///
/// Sprint S32 — Arbitrage Phase 1.
///
/// NEVER ranks options. Side-by-side comparison only.
/// All text in French, informal "tu".
/// No banned terms.
class RenteVsCapitalScreen extends StatefulWidget {
  const RenteVsCapitalScreen({super.key});

  @override
  State<RenteVsCapitalScreen> createState() => _RenteVsCapitalScreenState();
}

class _RenteVsCapitalScreenState extends State<RenteVsCapitalScreen> {
  // ── Input controllers ──
  final _capitalObligCtrl = TextEditingController(text: '200000');
  final _capitalSurobCtrl = TextEditingController(text: '100000');
  final _renteCtrl = TextEditingController(text: '20400');
  String _canton = 'VD';
  bool _isMarried = false;

  // ── Hypothesis sliders ──
  Map<String, double> _hypotheses = {
    'rendement': 3.0,
    'swr': 4.0,
    'inflation': 2.0,
  };

  bool _isLoading = false;
  int _requestCounter = 0;
  ArbitrageResult? _result;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _capitalObligCtrl.dispose();
    _capitalSurobCtrl.dispose();
    _renteCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    _recalculateAsync();
  }

  Future<void> _recalculateAsync() async {
    final requestId = ++_requestCounter;
    final capitalOblig =
        double.tryParse(_capitalObligCtrl.text.replaceAll("'", '')) ?? 200000;
    final capitalSurob =
        double.tryParse(_capitalSurobCtrl.text.replaceAll("'", '')) ?? 100000;
    final renteAnnuelle =
        double.tryParse(_renteCtrl.text.replaceAll("'", '')) ?? 20400;
    final capitalTotal = capitalOblig + capitalSurob;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.compareRenteVsCapital(
        capitalLppTotal: capitalTotal,
        capitalObligatoire: capitalOblig,
        capitalSurobligatoire: capitalSurob,
        renteAnnuelleProposee: renteAnnuelle,
        tauxConversionObligatoire: lppTauxConversionMin / 100,
        tauxConversionSurobligatoire: 0.05,
        canton: _canton,
        ageRetraite: 65,
        tauxRetrait: (_hypotheses['swr'] ?? 4.0) / 100,
        rendementCapital: (_hypotheses['rendement'] ?? 3.0) / 100,
        inflation: (_hypotheses['inflation'] ?? 2.0) / 100,
        horizon: 25,
        isMarried: _isMarried,
      );

      if (!mounted || requestId != _requestCounter) return;
      setState(() => _result = result);
      return;
    } catch (_) {
      final fallback = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: capitalTotal,
        capitalObligatoire: capitalOblig,
        capitalSurobligatoire: capitalSurob,
        renteAnnuelleProposee: renteAnnuelle,
        tauxConversionObligatoire: lppTauxConversionMin / 100,
        tauxConversionSurobligatoire: 0.05,
        canton: _canton,
        ageRetraite: 65,
        tauxRetrait: (_hypotheses['swr'] ?? 4.0) / 100,
        rendementCapital: (_hypotheses['rendement'] ?? 3.0) / 100,
        inflation: (_hypotheses['inflation'] ?? 2.0) / 100,
        horizon: 25,
        isMarried: _isMarried,
      );

      if (!mounted || requestId != _requestCounter) return;
      setState(() => _result = fallback);
    } finally {
      if (mounted && requestId == _requestCounter) {
        setState(() => _isLoading = false);
      }
    }
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
                'Rente ou capital LPP ?',
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
                if (_isLoading && _result == null)
                  const Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: const CircularProgressIndicator()),
                  ),
                if (_result != null) ...[
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
                  ),
                  const SizedBox(height: 20),

                  // ── Breakeven ──
                  BreakevenIndicatorWidget(
                    breakevenYear: _result!.breakevenYear,
                    ageRetraite: 65,
                    horizon: 25,
                    sensitivity: _result!.sensitivity,
                  ),
                  const SizedBox(height: 20),

                  ArbitrageTornadoSection(result: _result!),
                  const SizedBox(height: 20),

                  // ── Chiffre choc ──
                  _buildChiffreChocCard(),
                  const SizedBox(height: 20),

                  // ── Hypothesis sliders ──
                  HypothesisEditorWidget(
                    hypotheses: const [
                      HypothesisConfig(
                        key: 'rendement',
                        label: 'Rendement du capital',
                        min: 0,
                        max: 8,
                        divisions: 16,
                        defaultValue: 3,
                      ),
                      HypothesisConfig(
                        key: 'swr',
                        label: 'Taux de retrait (SWR)',
                        min: 2,
                        max: 6,
                        divisions: 8,
                        defaultValue: 4,
                      ),
                      HypothesisConfig(
                        key: 'inflation',
                        label: 'Inflation',
                        min: 0,
                        max: 4,
                        divisions: 8,
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

  // ═══════════════════════════════════════════════════════════════
  //  INPUT SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: const BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ton avoir LPP',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _capitalObligCtrl,
            label: 'Capital obligatoire (CHF)',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _capitalSurobCtrl,
            label: 'Capital surobligatoire (CHF)',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _renteCtrl,
            label: 'Rente annuelle proposee (CHF)',
          ),
          const SizedBox(height: 16),

          // Canton dropdown
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
                        borderRadius: const BorderRadius.circular(12),
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
              // Married toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marie·e',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Switch(
                    value: _isMarried,
                    activeThumbColor: MintColors.primary,
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
                  borderRadius: const BorderRadius.circular(14),
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
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.circular(12),
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
  //  CHIFFRE CHOC CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildChiffreChocCard() {
    if (_result == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: const BorderRadius.circular(20),
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
        borderRadius: const BorderRadius.circular(16),
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
