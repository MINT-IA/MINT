import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';

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
  static const int _ageRetraiteReference = 65;

  // ── CoachProfile auto-fill (P8 Phase 4) ──
  bool _didAutoFill = false;
  Map<String, ProfileDataSource> _dataSources = {};
  bool _hasEstimatedValues = false;

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

    final lpp = profile.prevoyance.avoirLppTotal;
    if (lpp != null && lpp > 0) {
      // MINT default: 70% obligatoire / 30% surobligatoire (moyenne industrie
      // suisse, pas de source legale — valeur indicative, l'utilisateur peut
      // modifier les champs).
      final oblig = (lpp * 0.7).round();
      final surob = (lpp * 0.3).round();
      _capitalObligCtrl.text = oblig.toString();
      _capitalSurobCtrl.text = surob.toString();
      // Estimate rente from obligatory part at 6.8%
      final rente = (oblig * (lppTauxConversionMin / 100)).round();
      _renteCtrl.text = rente.toString();
      _hasEstimatedValues = true;
    }
    if (profile.canton.isNotEmpty) {
      _canton = profile.canton;
    }
    _isMarried = profile.etatCivil == CoachCivilStatus.marie;
    _dataSources = profile.dataSources;
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
        dataSources: _dataSources,
      );

      if (!mounted || requestId != _requestCounter) return;
      setState(() => _result = fallback);
    } finally {
      if (mounted && requestId == _requestCounter) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<TrajectoireOption> _optionsAsAgeTrajectories(
    List<TrajectoireOption> options,
  ) {
    return options.map((option) {
      final mappedTrajectory = <YearlySnapshot>[];
      for (int i = 0; i < option.trajectory.length; i++) {
        final snap = option.trajectory[i];
        mappedTrajectory.add(
          YearlySnapshot(
            year: _ageRetraiteReference + i,
            netPatrimony: snap.netPatrimony,
            annualCashflow: snap.annualCashflow,
            cumulativeTaxDelta: snap.cumulativeTaxDelta,
          ),
        );
      }
      return TrajectoireOption(
        id: option.id,
        label: option.label,
        trajectory: mappedTrajectory,
        terminalValue: option.terminalValue,
        cumulativeTaxImpact: option.cumulativeTaxImpact,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chartOptions = _result == null
        ? const <TrajectoireOption>[]
        : _optionsAsAgeTrajectories(_result!.options);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ──
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rente ou capital LPP ?',
                    style: GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'La décision peut valoir 100\'000 CHF',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A6B45), Color(0xFF2E8B5A)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 60, 24, 0),
                    child: Text(
                      '6.8%',
                      style: GoogleFonts.montserrat(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
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
                // ── Hero insight card (L6 + L7) ──
                _buildHeroInsightCard(),
                const SizedBox(height: 20),

                // ── Inputs ──
                _buildInputSection(),
                const SizedBox(height: 24),

                // ── Chart ──
                if (_isLoading && _result == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_result != null) ...[
                  // ── Chiffre choc (L6 — ouvre le résultat) ──
                  _buildChiffreChocCard(),
                  const SizedBox(height: 20),

                  // ── Indicatif banner (P8 Phase 4) ──
                  if (_result!.confidenceScore < 70)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: MintColors.warning.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MintColors.warning.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: MintColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Resultat indicatif — precise tes donnees pour un resultat plus fiable.',
                              style: GoogleFonts.inter(fontSize: 12, color: MintColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_hasEstimatedValues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SmartDefaultIndicator(
                        source: 'Valeurs pre-remplies depuis ton profil '
                            '(repartition estimee 70 % oblig. / 30 % surob.)',
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
                    'Axe horizontal = age (65 a 90). '
                    'Valeurs = patrimoine net cumule (capital restant + flux encaisses).',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TrajectoryComparisonChart(
                    options: chartOptions,
                    breakevenYear: _result!.breakevenYear,
                    selectedAxisLabel: 'Age',
                  ),
                  const SizedBox(height: 20),

                  // ── Breakeven ──
                  BreakevenIndicatorWidget(
                    breakevenYear: _result!.breakevenYear,
                    ageRetraite: _ageRetraiteReference,
                    horizon: 25,
                    sensitivity: _result!.sensitivity,
                    showCalendarYear: false,
                  ),
                  const SizedBox(height: 20),

                  ArbitrageTornadoSection(result: _result!),
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
        borderRadius: BorderRadius.circular(20),
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
  //  CHIFFRE CHOC CARD
  // ═══════════════════════════════════════════════════════════════

  // ─── Hero insight card — L6 ouvre, L7 métaphore ─────────────
  // Affiche l'insight clé AVANT que l'utilisateur entre ses données.
  // Source : ONBOARDING_ARBITRAGE_ENGINE.md Module C.
  Widget _buildHeroInsightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MintColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '💡  L\'INSIGHT CLÉ',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '6.8% de taux de conversion = ~4.5% de rendement garanti',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF14532D),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sur la part obligatoire LPP, la rente est presque toujours rationnelle : '
            'aucun placement sans risque ne sert actuellement ce niveau. '
            'Sur le surobligatoire (souvent 4.5-5.5%), le capital est souvent supérieur.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF166534),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stratégie mixte : rente sur obligatoire + capital sur surobligatoire. '
                    'MINT la modélise — c\'est souvent la meilleure option.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF14532D),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'LPP art. 14/37 · LIFD art. 22 (rente) / art. 38 (capital)',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

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
}
