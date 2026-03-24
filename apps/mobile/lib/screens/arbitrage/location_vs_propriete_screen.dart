import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:mint_mobile/widgets/coach/rent_vs_buy_scoreboard_widget.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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

    // Capital disponible = epargne liquide + 3a + investissements
    // (LPP is handled separately for EPL max 10% rule)
    final epargneLiquide = patrimoine.epargneLiquide;
    final avoir3a = profile.prevoyance.totalEpargne3a;
    final investissements = patrimoine.investissements;
    final totalCapital = epargneLiquide + avoir3a + investissements;

    setState(() {
      _canton = canton;
      _isMarried = isMarried;
      if (totalCapital > 0) {
        _capitalCtrl.text = totalCapital.round().toString();
        _hasEstimatedValues = true;
      }
      // Loyer mensuel from profile
      if (profile.depenses.loyer > 0) {
        _loyerCtrl.text = profile.depenses.loyer.round().toString();
        _hasEstimatedValues = true;
      }
      // Income-based property price estimate (rule of 1/3)
      final revenu = profile.revenuBrutAnnuel;
      if (revenu > 0) {
        // Max property affordable: revenu / 7% theoretical charges / 20% equity
        // Simplified: max ~= revenu / 0.07 (rough capacity estimate)
        // But we don't override prixBien — user should set it
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
            foregroundColor: MintColors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                S.of(context)!.locationLouerOuAcheter,
                style: MintTextStyles.headlineMedium(color: MintColors.white),
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
                        source: S.of(context)!.locationValeursProfil,
                        confidence: _result!.confidenceScore / 100,
                      ),
                    ),
                  Text(
                    S.of(context)!.locationTrajectoires,
                    style: MintTextStyles.titleMedium(),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    S.of(context)!.locationToucheGraphique,
                    style: MintTextStyles.bodySmall(),
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
                    hypotheses: [
                      HypothesisConfig(
                        key: 'rendement_marche',
                        label: S.of(context)!.locationRendementMarche,
                        min: 0,
                        max: 8,
                        divisions: 16,
                        defaultValue: 4,
                      ),
                      HypothesisConfig(
                        key: 'appreciation_immo',
                        label: S.of(context)!.locationAppreciationImmo,
                        min: 0,
                        max: 4,
                        divisions: 8,
                        defaultValue: 1.5,
                      ),
                      HypothesisConfig(
                        key: 'taux_hypo',
                        label: S.of(context)!.locationTauxHypo,
                        min: 0.5,
                        max: 5,
                        divisions: 9,
                        defaultValue: 2,
                      ),
                      HypothesisConfig(
                        key: 'horizon',
                        label: S.of(context)!.locationHorizon,
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
          MintEntrance(child: Text(
            S.of(context)!.locationProjetImmobilier,
            style: MintTextStyles.titleMedium(),
          )),
          const SizedBox(height: 16),
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildTextField(
            controller: _capitalCtrl,
            label: S.of(context)!.locationCapitalDispo,
          )),
          const SizedBox(height: 12),
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildTextField(
            controller: _loyerCtrl,
            label: S.of(context)!.locationLoyerMensuel,
          )),
          const SizedBox(height: 12),
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildTextField(
            controller: _prixBienCtrl,
            label: S.of(context)!.locationPrixBien,
          )),
          const SizedBox(height: 16),

          // Canton dropdown + married toggle
          MintEntrance(delay: const Duration(milliseconds: 400), child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.locationCanton,
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
                              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
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
                    S.of(context)!.locationMarie,
                    style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Switch(
                    value: _isMarried,
                    activeTrackColor: MintColors.primary,
                    onChanged: (v) {
                      _isMarried = v;
                      _recalculate();
                    },
                  ),
                ],
              ),
            ],
          )),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: S.of(context)!.locationComparer,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _recalculate,
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  S.of(context)!.locationComparer,
                  style: MintTextStyles.titleMedium(color: MintColors.white),
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
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
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
                  S.of(context)!.locationCapaciteFinma,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.locationChargeTheorique(_formatChf(chargeTheorique)),
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.locationRevenuMinimum(_formatChf(chargeTheorique * 3)),
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _result!.displaySummary,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
        S.of(context)!.locationHypotheses,
        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
                    style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
                S.of(context)!.locationAvertissement,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _result!.disclaimer,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Sources : ${_result!.sources.join(' | ')}',
            style: MintTextStyles.micro(color: MintColors.textMuted),
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
