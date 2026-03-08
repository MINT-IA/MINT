import 'dart:math' as math;

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
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';
import 'package:mint_mobile/widgets/precision/field_help_tooltip.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';

/// Rente vs Capital arbitrage screen — the "a-ha" moment.
///
/// Redesigned for clarity: hero monthly amounts, life-expectancy slider,
/// educational before/after cards, impact cards, vulgarized labels.
///
/// NEVER ranks options. Side-by-side comparison only.
/// All text in French, informal "tu". No banned terms.
class RenteVsCapitalScreen extends StatefulWidget {
  const RenteVsCapitalScreen({super.key});

  @override
  State<RenteVsCapitalScreen> createState() => _RenteVsCapitalScreenState();
}

enum _InputMode { estimate, certificate }

class _RenteVsCapitalScreenState extends State<RenteVsCapitalScreen> {
  // ── Input mode ──
  _InputMode _inputMode = _InputMode.estimate;

  // ── Estimate mode controllers ──
  final _ageCtrl = TextEditingController(text: '50');
  final _ageRetraiteSlider = ValueNotifier<double>(65);
  final _salaryCtrl = TextEditingController(text: '100000');
  final _lppTotalCtrl = TextEditingController(text: '350000');

  // ── Certificate mode controllers ──
  final _capitalObligCtrl = TextEditingController(text: '500000');
  final _capitalSurobCtrl = TextEditingController(text: '150000');
  final _renteCtrl = TextEditingController(text: '37000');
  final _tcObligCtrl = TextEditingController(text: '6.8');
  final _tcSurobCtrl = TextEditingController(text: '5.0');

  // ── Shared inputs ──
  String _canton = 'VD';
  bool _isMarried = false;

  // ── Hypothesis sliders ──
  Map<String, double> _hypotheses = {
    'rendement': 3.0,
    'swr': 4.0,
    'inflation': 2.0,
  };

  // ── Life expectancy slider ──
  double _lifeExpectancy = 85;

  bool _isLoading = false;
  int _requestCounter = 0;
  ArbitrageResult? _result;

  // ── CoachProfile auto-fill ──
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

    // If profile has oblig/surob split → certificate mode
    final obligVal = profile.prevoyance.avoirLppObligatoire;
    if (obligVal != null && obligVal > 0) {
      _inputMode = _InputMode.certificate;
      _capitalObligCtrl.text = obligVal.round().toString();
      _capitalSurobCtrl.text =
          (profile.prevoyance.avoirLppSurobligatoire ?? 0).round().toString();
      final rente =
          (obligVal * (lppTauxConversionMin / 100)).round();
      _renteCtrl.text = rente.toString();
    } else {
      // Estimate mode
      _inputMode = _InputMode.estimate;
      _ageCtrl.text = profile.age.toString();
      if (profile.salaireBrutMensuel > 0) {
        _salaryCtrl.text = (profile.salaireBrutMensuel * 12).round().toString();
      }
      final lppTotal = profile.prevoyance.avoirLppTotal;
      if (lppTotal != null && lppTotal > 0) {
        _lppTotalCtrl.text = lppTotal.round().toString();
      }
      _hasEstimatedValues = true;
    }
    if (profile.canton.isNotEmpty) _canton = profile.canton;
    _isMarried = profile.etatCivil == CoachCivilStatus.marie;
    _dataSources = profile.dataSources;
    _recalculate();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _salaryCtrl.dispose();
    _lppTotalCtrl.dispose();
    _capitalObligCtrl.dispose();
    _capitalSurobCtrl.dispose();
    _renteCtrl.dispose();
    _tcObligCtrl.dispose();
    _tcSurobCtrl.dispose();
    _ageRetraiteSlider.dispose();
    super.dispose();
  }

  void _recalculate() {
    _recalculateAsync();
  }

  Future<void> _recalculateAsync() async {
    final requestId = ++_requestCounter;
    final ageRetraite = _ageRetraiteSlider.value.round();

    double capitalOblig, capitalSurob, renteAnnuelle;
    double tcOblig, tcSurob;
    int? currentAge;
    double? salary;

    if (_inputMode == _InputMode.estimate) {
      // Estimate mode: use LPP total with 70/30 split as starting point
      final lppTotal =
          double.tryParse(_lppTotalCtrl.text.replaceAll("'", '')) ?? 350000;
      capitalOblig = lppTotal * 0.7;
      capitalSurob = lppTotal * 0.3;
      tcOblig = lppTauxConversionMin / 100;
      tcSurob = 0.05;
      renteAnnuelle = capitalOblig * tcOblig;
      currentAge = int.tryParse(_ageCtrl.text);
      salary = double.tryParse(_salaryCtrl.text.replaceAll("'", ''));
    } else {
      // Certificate mode: direct values
      capitalOblig =
          double.tryParse(_capitalObligCtrl.text.replaceAll("'", '')) ?? 500000;
      capitalSurob =
          double.tryParse(_capitalSurobCtrl.text.replaceAll("'", '')) ?? 150000;
      renteAnnuelle =
          double.tryParse(_renteCtrl.text.replaceAll("'", '')) ?? 37000;
      tcOblig = (double.tryParse(_tcObligCtrl.text) ?? 6.8) / 100;
      tcSurob = (double.tryParse(_tcSurobCtrl.text) ?? 5.0) / 100;
      currentAge = null;
      salary = null;
    }

    final capitalTotal = capitalOblig + capitalSurob;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.compareRenteVsCapital(
        capitalLppTotal: capitalTotal,
        capitalObligatoire: capitalOblig,
        capitalSurobligatoire: capitalSurob,
        renteAnnuelleProposee: renteAnnuelle,
        tauxConversionObligatoire: tcOblig,
        tauxConversionSurobligatoire: tcSurob,
        canton: _canton,
        ageRetraite: ageRetraite,
        tauxRetrait: (_hypotheses['swr'] ?? 4.0) / 100,
        rendementCapital: (_hypotheses['rendement'] ?? 3.0) / 100,
        inflation: (_hypotheses['inflation'] ?? 2.0) / 100,
        horizon: 30,
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
        tauxConversionObligatoire: tcOblig,
        tauxConversionSurobligatoire: tcSurob,
        canton: _canton,
        ageRetraite: ageRetraite,
        tauxRetrait: (_hypotheses['swr'] ?? 4.0) / 100,
        rendementCapital: (_hypotheses['rendement'] ?? 3.0) / 100,
        inflation: (_hypotheses['inflation'] ?? 2.0) / 100,
        horizon: 30,
        isMarried: _isMarried,
        dataSources: _dataSources,
        currentAge: currentAge,
        grossAnnualSalary: salary,
      );
      if (!mounted || requestId != _requestCounter) return;
      setState(() => _result = fallback);
    } finally {
      if (mounted && requestId == _requestCounter) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _ageRetraite => _ageRetraiteSlider.value.round();

  List<TrajectoireOption> _optionsAsAgeTrajectories(
    List<TrajectoireOption> options,
  ) {
    return options.map((option) {
      final mappedTrajectory = <YearlySnapshot>[];
      for (int i = 0; i < option.trajectory.length; i++) {
        final snap = option.trajectory[i];
        mappedTrajectory.add(
          YearlySnapshot(
            year: _ageRetraite + i,
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
          // ── 1. SliverAppBar ──
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Rente ou capital : ta decision',
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
                // ── 2. Hero intro ──
                _buildHeroIntro(),
                const SizedBox(height: 20),

                // ── 3. Inputs (2 modes) ──
                _buildInputSection(),
                const SizedBox(height: 24),

                if (_isLoading && _result == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (_result != null) ...[
                  // ── Confidence banner ──
                  if (_result!.confidenceScore < 70)
                    _buildConfidenceBanner(),

                  if (_hasEstimatedValues && _inputMode == _InputMode.estimate)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SmartDefaultIndicator(
                        source: 'Valeurs pre-remplies depuis ton profil',
                        confidence: _result!.confidenceScore / 100,
                      ),
                    ),

                  // ── 4. Hero CHF/mois (Monzo moment) ──
                  _buildHeroMonthly(),
                  const SizedBox(height: 20),

                  // ── 5. Life expectancy slider ──
                  _buildLifeExpectancySlider(),
                  const SizedBox(height: 24),

                  // ── 6. Trajectory chart ──
                  Text(
                    'Combien il te reste a chaque age',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'En francs d\'aujourd\'hui (pouvoir d\'achat reel). '
                    'Touche le graphique pour voir les details.',
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
                  const SizedBox(height: 24),

                  // ── 7. Three educational before/after cards ──
                  _buildEducationalCards(),
                  const SizedBox(height: 24),

                  // ── 8. Hypothesis sliders (vulgarized labels) ──
                  HypothesisEditorWidget(
                    hypotheses: const [
                      HypothesisConfig(
                        key: 'rendement',
                        label: 'Ce que ton capital rapporte par an',
                        min: 0,
                        max: 8,
                        divisions: 16,
                        defaultValue: 3,
                      ),
                      HypothesisConfig(
                        key: 'swr',
                        label: 'Combien tu retires chaque annee',
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
                  const SizedBox(height: 24),

                  // ── 9. Impact cards (simplified sensitivity) ──
                  _buildImpactCards(),
                  const SizedBox(height: 16),

                  // ── 10. Tornado in ExpansionTile ──
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: Text(
                      'Voir le diagramme de sensibilite',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    children: [ArbitrageTornadoSection(result: _result!)],
                  ),
                  const SizedBox(height: 20),

                  // ── 11. Chiffre choc ──
                  _buildChiffreChocCard(),
                  const SizedBox(height: 20),

                  // ── 12. Hypotheses detaillees ──
                  _buildHypothesesSection(),
                  const SizedBox(height: 20),

                  // ── 13. Disclaimer ──
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
  //  2. HERO INTRO
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 20, color: MintColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A la retraite, tu choisis une fois pour toutes : '
                  'un revenu a vie (rente) ou ton capital en main (liberte).',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _introPuce(
            'Rente',
            'Un montant fixe chaque mois, verse a vie — '
                'meme si tu vis jusqu\'a 100 ans.',
          ),
          _introPuce(
            'Capital',
            'Tu recuperes tout ton avoir LPP. Liberte totale, '
                'mais le risque de manquer est reel.',
          ),
          _introPuce(
            'Mixte',
            'La partie obligatoire en rente (6.8 %) + '
                'le surobligatoire en capital. Un compromis.',
          ),
        ],
      ),
    );
  }

  Widget _introPuce(String term, String explanation) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: () => _showExplanation(term, explanation),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 28),
              Text('•  ', style: TextStyle(color: MintColors.info)),
              Text(
                term,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.info,
                  decoration: TextDecoration.underline,
                  decorationColor: MintColors.info.withAlpha(60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExplanation(String term, String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              term,
              style: GoogleFonts.montserrat(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: MintColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15, color: MintColors.textPrimary, height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  3. INPUTS — 2 modes via SegmentedButton
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
          // Mode selector
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_InputMode>(
              segments: const [
                ButtonSegment(
                  value: _InputMode.estimate,
                  label: Text('Estimer pour moi'),
                  icon: Icon(Icons.auto_fix_high, size: 16),
                ),
                ButtonSegment(
                  value: _InputMode.certificate,
                  label: Text('J\'ai mon certificat'),
                  icon: Icon(Icons.description_outlined, size: 16),
                ),
              ],
              selected: {_inputMode},
              onSelectionChanged: (v) {
                setState(() => _inputMode = v.first);
                _recalculate();
              },
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_inputMode == _InputMode.estimate) ...[
            _buildLabeledField(
              controller: _ageCtrl,
              label: 'Ton age',
              fieldName: 'age',
            ),
            const SizedBox(height: 12),
            // Retirement age slider
            _buildRetirementAgeSlider(),
            const SizedBox(height: 12),
            _buildLabeledField(
              controller: _salaryCtrl,
              label: 'Ton salaire brut annuel (CHF)',
              fieldName: 'salaire_brut',
            ),
            const SizedBox(height: 12),
            _buildLabeledField(
              controller: _lppTotalCtrl,
              label: 'Ton avoir LPP actuel (CHF)',
              fieldName: 'lpp_total',
            ),
            // Auto-computed readout
            if (_result != null && _result!.isProjected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capital estime a ${_ageRetraite} ans : '
                      '~${_formatChf(_result!.capitalProjecte)}',
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rente estimee : ~${_formatChf(_result!.renteNetMensuelle * 12)}/an',
                      style: GoogleFonts.inter(
                        fontSize: 12, color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SmartDefaultIndicator(
                          source: 'Projection basee sur ton age, salaire et LPP actuel',
                          confidence: _result!.confidenceScore / 100,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // Certificate mode
            _buildLabeledField(
              controller: _capitalObligCtrl,
              label: 'Avoir obligatoire projete (CHF)',
              fieldName: 'lpp_obligatoire',
            ),
            const SizedBox(height: 12),
            _buildLabeledField(
              controller: _capitalSurobCtrl,
              label: 'Avoir surobligatoire projete (CHF)',
              fieldName: 'lpp_surobligatoire',
            ),
            const SizedBox(height: 12),
            _buildLabeledField(
              controller: _renteCtrl,
              label: 'Rente annuelle projetee par ta caisse (CHF)',
              fieldName: 'rente_projetee',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildLabeledField(
                    controller: _tcObligCtrl,
                    label: 'Taux conv. oblig. (%)',
                    isPercent: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLabeledField(
                    controller: _tcSurobCtrl,
                    label: 'Taux conv. surob. (%)',
                    isPercent: true,
                  ),
                ),
              ],
            ),
            // Confidence gratification
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MintColors.success.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MintColors.success.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 20, color: MintColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Precision maximale — resultats bases sur tes vrais chiffres.',
                          style: GoogleFonts.inter(
                            fontSize: 12, color: MintColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: 16),
          // Canton + Married
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Canton', style: _labelStyle),
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
                            child: Text('$code - $name',
                                style: GoogleFonts.inter(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) { _canton = v; _recalculate(); }
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
                  Text('Marie·e', style: _labelStyle),
                  const SizedBox(height: 6),
                  Switch(
                    value: _isMarried,
                    activeColor: MintColors.primary,
                    onChanged: (v) { _isMarried = v; _recalculate(); },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetirementAgeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Retraite prevue a', style: _labelStyle),
            const Spacer(),
            ValueListenableBuilder<double>(
              valueListenable: _ageRetraiteSlider,
              builder: (_, v, __) => Text(
                '${v.round()} ans',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: MintColors.primary,
                ),
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
            value: _ageRetraiteSlider.value,
            min: 58, max: 70, divisions: 12,
            onChanged: (v) {
              _ageRetraiteSlider.value = v;
              _recalculate();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    String? fieldName,
    bool isPercent = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: _labelStyle)),
            if (fieldName != null)
              FieldHelpTooltip(fieldName: fieldName),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isPercent
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: isPercent
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(fontSize: 15, color: MintColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14,
            ),
          ),
          onChanged: (_) => _recalculate(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  4. HERO CHF/MOIS (the Monzo moment)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroMonthly() {
    final r = _result!;
    final renteMois = r.renteNetMensuelle;
    final capitalMois = r.capitalRetraitMensuel;
    final delta = (capitalMois - renteMois).abs();
    final capitalDuration = r.capitalEpuiseAge != null
        ? '~${r.capitalEpuiseAge! - _ageRetraite} ans'
        : '30+ ans';

    final higherIsCapital = capitalMois > renteMois;
    final synthese = higherIsCapital
        ? 'Le capital te donne ${_formatChf(delta)}/mois de plus, '
            'mais pourrait s\'epuiser.'
        : 'La rente te donne ${_formatChf(delta)}/mois de plus, '
            'et ne s\'arrete jamais.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withAlpha(8),
            blurRadius: 20, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rente column
              Expanded(
                child: Column(
                  children: [
                    Text('RENTE', style: GoogleFonts.montserrat(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: MintColors.retirementAvs,
                      letterSpacing: 1.2,
                    )),
                    const SizedBox(height: 6),
                    Text(
                      _formatChf(renteMois),
                      style: GoogleFonts.montserrat(
                        fontSize: 26, fontWeight: FontWeight.w800,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text('/mois', style: GoogleFonts.inter(
                      fontSize: 13, color: MintColors.textSecondary,
                    )),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MintColors.retirementAvs.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('a vie', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: MintColors.retirementAvs,
                      )),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 1, height: 80,
                color: MintColors.lightBorder,
              ),
              // Capital column
              Expanded(
                child: Column(
                  children: [
                    Text('CAPITAL', style: GoogleFonts.montserrat(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: MintColors.retirementLpp,
                      letterSpacing: 1.2,
                    )),
                    const SizedBox(height: 6),
                    Text(
                      _formatChf(capitalMois),
                      style: GoogleFonts.montserrat(
                        fontSize: 26, fontWeight: FontWeight.w800,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text('/mois', style: GoogleFonts.inter(
                      fontSize: 13, color: MintColors.textSecondary,
                    )),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MintColors.retirementLpp.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('pendant $capitalDuration', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: MintColors.retirementLpp,
                      )),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              synthese,
              style: GoogleFonts.inter(
                fontSize: 13, color: MintColors.textPrimary,
                height: 1.5, fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  5. LIFE EXPECTANCY SLIDER ("Et si je vis jusqu'a...")
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLifeExpectancySlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Et si je vis jusqu\'a...',
            style: GoogleFonts.montserrat(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.textMuted.withAlpha(40),
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withAlpha(30),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              value: _lifeExpectancy,
              min: 70, max: 95, divisions: 25,
              label: '${_lifeExpectancy.round()} ans',
              onChanged: (v) => setState(() => _lifeExpectancy = v),
            ),
          ),
          // Delta display
          _buildDeltaAtAge(_lifeExpectancy.round()),
          const SizedBox(height: 8),
          Text(
            'Esperance de vie suisse : hommes 84 ans · femmes 87 ans',
            style: GoogleFonts.inter(
              fontSize: 11, color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaAtAge(int age) {
    if (_result == null) return const SizedBox.shrink();
    final yearIndex = age - _ageRetraite;
    if (yearIndex < 0) return const SizedBox.shrink();

    final renteOption = _result!.options.firstWhere(
      (o) => o.id == 'full_rente', orElse: () => _result!.options.first,
    );
    final capitalOption = _result!.options.firstWhere(
      (o) => o.id == 'full_capital', orElse: () => _result!.options.last,
    );

    if (yearIndex >= renteOption.trajectory.length ||
        yearIndex >= capitalOption.trajectory.length) {
      return Text(
        'A $age ans : au-dela de l\'horizon de simulation.',
        style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
      );
    }

    final renteVal = renteOption.trajectory[yearIndex].netPatrimony;
    final capitalVal = capitalOption.trajectory[yearIndex].netPatrimony;
    final delta = capitalVal - renteVal;
    final winner = delta > 0 ? 'Capital' : 'Rente';
    final winnerColor = delta > 0 ? MintColors.retirementLpp : MintColors.retirementAvs;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: winnerColor.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            delta > 0 ? Icons.trending_up : Icons.trending_down,
            color: winnerColor, size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'A $age ans : ',
                  style: GoogleFonts.inter(
                    fontSize: 13, color: MintColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: '$winner = +${_formatChf(delta.abs())} ',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: winnerColor,
                  ),
                ),
                TextSpan(
                  text: 'd\'avance',
                  style: GoogleFonts.inter(
                    fontSize: 13, color: MintColors.textSecondary,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  7. THREE EDUCATIONAL BEFORE/AFTER CARDS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEducationalCards() {
    final r = _result!;
    final inflation = (_hypotheses['inflation'] ?? 2.0) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ce que ca veut dire pour toi',
          style: GoogleFonts.montserrat(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Card 1: Fiscalite
        _educationalCard(
          icon: Icons.receipt_long,
          iconColor: const Color(0xFF6366F1),
          title: 'Fiscalite',
          leftTitle: 'Rente',
          leftSubtitle: 'Imposee chaque annee',
          leftValue: '~${_formatChf(r.impotCumulRente)}',
          leftDetail: 'sur 30 ans',
          rightTitle: 'Capital',
          rightSubtitle: 'Taxe une seule fois',
          rightValue: '~${_formatChf(r.impotRetraitCapital)}',
          rightDetail: 'au retrait',
          bottomText: r.impotCumulRente > r.impotRetraitCapital
              ? 'Sur 30 ans, le capital te fait economiser '
                '~${_formatChf(r.impotCumulRente - r.impotRetraitCapital)} d\'impots.'
              : 'Sur 30 ans, la rente genere '
                '~${_formatChf(r.impotRetraitCapital - r.impotCumulRente)} d\'impots en moins.',
        ),
        const SizedBox(height: 12),

        // Card 2: Inflation
        _educationalCard(
          icon: Icons.trending_down,
          iconColor: MintColors.warning,
          title: 'Inflation',
          leftTitle: 'Aujourd\'hui',
          leftSubtitle: '',
          leftValue: '${_formatChf(r.renteNetMensuelle)}',
          leftDetail: '/mois',
          rightTitle: 'Dans 20 ans',
          rightSubtitle: 'pouvoir d\'achat',
          rightValue: '${_formatChf(r.renteReelleAn20 / 12)}',
          rightDetail: '/mois',
          bottomText: 'Ta rente LPP n\'est pas indexee. '
              'Elle achete ${((1 - 1 / math.pow(1 + inflation, 20)) * 100).round()} % '
              'de moins dans 20 ans.',
        ),
        const SizedBox(height: 12),

        // Card 3: Transmission
        _educationalCard(
          icon: Icons.family_restroom,
          iconColor: MintColors.primary,
          title: 'Transmission',
          leftTitle: 'Rente',
          leftSubtitle: _isMarried ? 'Ton conjoint recoit' : 'A ton deces',
          leftValue: _isMarried
              ? '60 % = ${_formatChf(r.renteSurvivant / 12)}/mois'
              : 'Rien',
          leftDetail: _isMarried ? 'LPP art. 19' : 'pour tes heritiers',
          rightTitle: 'Capital',
          rightSubtitle: 'Tes heritiers recoivent',
          rightValue: '100 %',
          rightDetail: 'du solde restant',
          bottomText: _isMarried
              ? 'Avec la rente, seul·e ton conjoint·e recoit 60 %. '
                'Rien pour les enfants.'
              : 'Avec la rente, rien ne revient a tes proches.',
        ),
      ],
    );
  }

  Widget _educationalCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String leftTitle,
    required String leftSubtitle,
    required String leftValue,
    required String leftDetail,
    required String rightTitle,
    required String rightSubtitle,
    required String rightValue,
    required String rightDetail,
    required String bottomText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.montserrat(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              )),
            ],
          ),
          const SizedBox(height: 14),
          // Before/After comparison
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(leftTitle, style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    )),
                    if (leftSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(leftSubtitle, style: GoogleFonts.inter(
                        fontSize: 10, color: MintColors.textMuted,
                      )),
                    ],
                    const SizedBox(height: 6),
                    Text(leftValue, style: GoogleFonts.montserrat(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: MintColors.textPrimary,
                    ), textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(leftDetail, style: GoogleFonts.inter(
                      fontSize: 10, color: MintColors.textMuted,
                    )),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: MintColors.lightBorder),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(rightTitle, style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    )),
                    if (rightSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(rightSubtitle, style: GoogleFonts.inter(
                        fontSize: 10, color: MintColors.textMuted,
                      )),
                    ],
                    const SizedBox(height: 6),
                    Text(rightValue, style: GoogleFonts.montserrat(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: MintColors.textPrimary,
                    ), textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(rightDetail, style: GoogleFonts.inter(
                      fontSize: 10, color: MintColors.textMuted,
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom insight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bottomText,
              style: GoogleFonts.inter(
                fontSize: 12, color: MintColors.textPrimary,
                height: 1.5, fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  9. IMPACT CARDS (simplified sensitivity)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildImpactCards() {
    if (_result == null) return const SizedBox.shrink();
    final variables = _result!.tornadoVariables;
    if (variables.isEmpty) return const SizedBox.shrink();

    final top = variables.take(4).toList();
    final maxSwing = top.first.swing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qu\'est-ce qui change le plus le resultat ?',
          style: GoogleFonts.montserrat(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Les parametres les plus influents sur l\'ecart entre tes options.',
          style: GoogleFonts.inter(
            fontSize: 12, color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < top.length; i++) ...[
          _impactCard(i + 1, top[i], maxSwing),
          if (i < top.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _impactCard(int rank, ArbitrageTornadoVariable v, double maxSwing) {
    final barFraction = maxSwing > 0 ? v.swing / maxSwing : 0.0;
    final lowDelta = v.lowValue - v.baseValue;
    final highDelta = v.highValue - v.baseValue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('#$rank', style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(v.label, style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Impact bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 6,
              backgroundColor: MintColors.border.withAlpha(60),
              valueColor: AlwaysStoppedAnimation(MintColors.primary.withAlpha(180)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${v.lowLabel} : ${_formatDelta(lowDelta)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: lowDelta < 0
                      ? const Color(0xFFEF4444)
                      : MintColors.success,
                ),
              ),
              Text(
                '${v.highLabel} : ${_formatDelta(highDelta)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: highDelta >= 0
                      ? MintColors.success
                      : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONFIDENCE BANNER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildConfidenceBanner() {
    return Container(
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
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  11. CHIFFRE CHOC CARD
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
            blurRadius: 30, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: MintColors.info.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insights_rounded, color: MintColors.info, size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _result!.chiffreChoc,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: MintColors.textPrimary, height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _result!.displaySummary,
            style: GoogleFonts.inter(
              fontSize: 12, color: MintColors.textSecondary, height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  12. HYPOTHESES EXPANDABLE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHypothesesSection() {
    if (_result == null) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        'Hypotheses de cette simulation',
        style: GoogleFonts.montserrat(
          fontSize: 14, fontWeight: FontWeight.w600,
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
                  child: Text(h, style: GoogleFonts.inter(
                    fontSize: 12, color: MintColors.textSecondary, height: 1.4,
                  )),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  13. DISCLAIMER CARD
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
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text('Avertissement', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: MintColors.textMuted,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Text(_result!.disclaimer, style: GoogleFonts.inter(
            fontSize: 11, color: MintColors.textMuted, height: 1.4,
          )),
          const SizedBox(height: 8),
          Text(
            'Sources : ${_result!.sources.join(' | ')}',
            style: GoogleFonts.inter(
              fontSize: 10, color: MintColors.textMuted, height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FORMATTING HELPERS
  // ═══════════════════════════════════════════════════════════════

  static final _labelStyle = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: MintColors.textSecondary,
  );

  static String _formatChf(double value) {
    final intVal = value.round().abs();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return '${value < 0 ? '-' : ''}${buffer.toString()}';
  }

  static String _formatDelta(double delta) {
    final abs = delta.abs();
    String formatted;
    if (abs >= 1000000) {
      formatted = '${(abs / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 10000) {
      formatted = '${(abs / 1000).round()}k';
    } else {
      formatted = _formatChf(abs);
    }
    return '${delta >= 0 ? '+' : '-'}$formatted';
  }
}
