import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Ecran de simulation du rachat LPP echelonne vs bloc.
///
/// Permet de comparer l'economie fiscale entre un rachat en une fois
/// et un rachat reparti sur plusieurs annees.
/// Base legale : LPP art. 79b al. 3.
class RachatEchelonneScreen extends StatefulWidget {
  const RachatEchelonneScreen({super.key});

  @override
  State<RachatEchelonneScreen> createState() => _RachatEchelonneScreenState();
}

class _RachatEchelonneScreenState extends State<RachatEchelonneScreen>
    with SingleTickerProviderStateMixin {
  // --- Inputs ---
  double _avoirActuel = 200000;
  double _rachatMax = 80000;
  double _revenu = 120000;
  int _horizon = 3;

  // --- Fiscal situation ---
  String _canton = 'VD';
  String _civilStatus = 'single';
  bool _manualTauxOverride = false;
  double _manualTaux = 0.32;

  // --- Animation ---
  late AnimationController _heroController;
  late Animation<double> _heroAnimation;

  static const List<String> _cantonCodes = [
    'ZH', 'BE', 'LU', 'UR', 'SZ', 'OW', 'NW', 'GL', 'ZG', 'FR',
    'SO', 'BS', 'BL', 'SH', 'AR', 'AI', 'SG', 'GR', 'AG', 'TG',
    'TI', 'VD', 'VS', 'NE', 'GE', 'JU',
  ];

  static const Map<String, String> _cantonNames = {
    'ZH': 'Zurich',
    'BE': 'Berne',
    'LU': 'Lucerne',
    'UR': 'Uri',
    'SZ': 'Schwyz',
    'OW': 'Obwald',
    'NW': 'Nidwald',
    'GL': 'Glaris',
    'ZG': 'Zoug',
    'FR': 'Fribourg',
    'SO': 'Soleure',
    'BS': 'Bale-Ville',
    'BL': 'Bale-Campagne',
    'SH': 'Schaffhouse',
    'AR': 'Appenzell RE',
    'AI': 'Appenzell RI',
    'SG': 'Saint-Gall',
    'GR': 'Grisons',
    'AG': 'Argovie',
    'TG': 'Thurgovie',
    'TI': 'Tessin',
    'VD': 'Vaud',
    'VS': 'Valais',
    'NE': 'Neuchatel',
    'GE': 'Geneve',
    'JU': 'Jura',
  };

  double get _autoTaux => TaxEstimatorService.estimateMarginalTaxRate(
        netMonthlyIncome: _revenu / 12,
        cantonCode: _canton,
        civilStatus: _civilStatus,
      );

  double get _effectiveTaux => _manualTauxOverride ? _manualTaux : _autoTaux;

  RachatEchelonneResult get _result => RachatEchelonneSimulator.compare(
        avoirActuel: _avoirActuel,
        rachatMax: _rachatMax,
        revenuImposable: _revenu,
        tauxMarginalEstime: _effectiveTaux,
        horizon: _horizon,
      );

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('lpp_deep');
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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

  void _onInputChanged() {
    _heroController.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'RACHAT LPP ECHELONNE',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Introduction
                _buildIntroCard(),
                const SizedBox(height: 16),

                // Hero chiffre choc
                _buildHeroChiffreChoc(result),
                const SizedBox(height: 24),

                // Card 1: Situation LPP
                _buildLppSituationCard(),
                const SizedBox(height: 16),

                // Card 2: Situation fiscale
                _buildFiscalSituationCard(),
                const SizedBox(height: 16),

                // Card 3: Strategie
                _buildStrategieCard(),
                const SizedBox(height: 24),

                // Comparison cards
                _buildComparisonSection(result),
                const SizedBox(height: 24),

                // Waterfall chart
                _buildWaterfallSection(),
                const SizedBox(height: 24),

                // Timeline yearly plan
                _buildTimelineSection(result),
                const SizedBox(height: 24),

                // Alert LPP art. 79b
                _buildBlockageAlert(),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Intro
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pourquoi echelonner ses rachats ?',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'impot suisse etant progressif, repartir un rachat LPP sur '
            'plusieurs annees permet de rester dans des tranches marginales '
            'plus elevees chaque annee, maximisant ainsi l\'economie fiscale '
            'totale. Ce simulateur compare les deux approches.',
            style: TextStyle(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Hero Chiffre Choc
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildHeroChiffreChoc(RachatEchelonneResult result) {
    final delta = result.delta;
    final showSavings = delta > 0;

    return AnimatedBuilder(
      animation: _heroAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: showSavings
                  ? [MintColors.primary, MintColors.primary.withAlpha(180)]
                  : [MintColors.textSecondary, MintColors.textMuted],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: MintColors.primary.withAlpha(40),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                showSavings ? Icons.savings_outlined : Icons.info_outline,
                color: Colors.white.withAlpha(180),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                showSavings
                    ? 'CHF ${formatChf(delta * _heroAnimation.value)}'
                    : 'CHF 0',
                style: GoogleFonts.montserrat(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                showSavings
                    ? 'd\'economie supplementaire en echelonnant'
                    : 'Rachat en bloc plus avantageux dans ce cas',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(220),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Card 1: Situation LPP
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildLppSituationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.accentPastel,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance, size: 18,
                    color: MintColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'SITUATION LPP',
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
          _buildSliderRow(
            label: 'Avoir actuel LPP',
            value: _avoirActuel,
            min: 0,
            max: 500000,
            divisions: 100,
            format: 'CHF ${formatChf(_avoirActuel)}',
            onChanged: (v) {
              _avoirActuel = v;
              _onInputChanged();
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Rachat maximum',
            value: _rachatMax,
            min: 0,
            max: 500000,
            divisions: 100,
            format: 'CHF ${formatChf(_rachatMax)}',
            onChanged: (v) {
              _rachatMax = v;
              _onInputChanged();
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Card 2: Situation fiscale
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildFiscalSituationCard() {
    final autoRate = _autoTaux;
    final displayRate = _effectiveTaux;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.accentPastel,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, size: 18,
                    color: MintColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'SITUATION FISCALE',
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

          // Canton dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Canton',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MintColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _canton,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                    items: _cantonCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text('$code — ${_cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _canton = v;
                        _onInputChanged();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Civil status toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Etat civil',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MintColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusChip('Celibataire', 'single'),
                    _buildStatusChip('Marie\u00b7e', 'married'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Revenu slider
          _buildSliderRow(
            label: 'Revenu imposable',
            value: _revenu,
            min: 50000,
            max: 300000,
            divisions: 50,
            format: 'CHF ${formatChf(_revenu)}',
            onChanged: (v) {
              _revenu = v;
              _onInputChanged();
            },
          ),
          const SizedBox(height: 20),

          // Auto-calculated taux marginal display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Taux marginal estime',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: MintColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _showTauxMarginalInfo(context),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: MintColors.primary.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: MintColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _manualTauxOverride
                                ? 'Valeur ajustee manuellement'
                                : 'Calcule pour $_canton, ${_civilStatus == 'married' ? 'marie\u00b7e' : 'celibataire'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: MintColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: MintColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(displayRate * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Manual override toggle
                if (!_manualTauxOverride)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _manualTauxOverride = true;
                          _manualTaux = autoRate;
                        });
                      },
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Ajuster'),
                      style: TextButton.styleFrom(
                        foregroundColor: MintColors.textMuted,
                        textStyle: const TextStyle(fontSize: 12),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),

                if (_manualTauxOverride) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _manualTaux,
                          min: 0.10,
                          max: 0.45,
                          divisions: 35,
                          activeThumbColor: MintColors.primary,
                          onChanged: (v) {
                            _manualTaux = v;
                            _onInputChanged();
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _manualTauxOverride = false;
                          });
                          _onInputChanged();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: MintColors.info,
                          textStyle: const TextStyle(fontSize: 12),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('Auto'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final selected = _civilStatus == value;
    return GestureDetector(
      onTap: () {
        _civilStatus = value;
        _onInputChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MintColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : MintColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showTauxMarginalInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MintColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Taux marginal d\'imposition',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Le taux marginal est le pourcentage d\'impot sur ton dernier '
                'franc gagne. Avec un taux de 32%, chaque CHF 1\'000 deduit '
                'te fait economiser CHF 320. Plus ton revenu est eleve, plus '
                'ce taux augmente (progressivite de l\'impot suisse).',
                style: TextStyle(
                  fontSize: 15,
                  color: MintColors.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MintColors.accentPastel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20,
                        color: MintColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'C\'est pour ca qu\'echelonner tes rachats est malin : '
                        'chaque tranche reste dans un taux marginal eleve.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade800,
                          fontStyle: FontStyle.italic,
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
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Card 3: Strategie
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildStrategieCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.accentPastel,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timeline, size: 18,
                    color: MintColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'STRATEGIE',
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
          _buildSliderRow(
            label: 'Horizon (annees)',
            value: _horizon.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            format: '$_horizon an${_horizon > 1 ? 's' : ''}',
            onChanged: (v) {
              _horizon = v.round();
              _onInputChanged();
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Slider row helper
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String format,
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
            ),
            Text(
              format,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeThumbColor: MintColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Comparison section
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildComparisonSection(RachatEchelonneResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPARAISON',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildComparisonCard(
                title: 'TOUT EN 1 AN',
                subtitle: 'Rachat bloc',
                amount: result.economieBlocTotal,
                color: Colors.orange,
                isWinner: result.delta <= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildComparisonCard(
                title: 'ECHELONNE SUR $_horizon ANS',
                subtitle: 'Rachat reparti',
                amount: result.economieEchelonneTotal,
                color: MintColors.success,
                isWinner: result.delta > 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required bool isWinner,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? color : MintColors.border,
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWinner)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MEILLEUR',
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'CHF ${formatChf(amount)}',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Economie fiscale',
            style: TextStyle(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Waterfall chart
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildWaterfallSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IMPACT PAR TRANCHE FISCALE',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'En bloc, la deduction traverse plusieurs tranches (taux moyen plus bas). '
            'En echelonnant, chaque deduction reste dans la tranche la plus haute.',
            style: TextStyle(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: CustomPaint(
              size: const Size(double.infinity, 240),
              painter: _WaterfallPainter(
                revenu: _revenu,
                rachatMax: _rachatMax,
                horizon: _horizon,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(Colors.orange, 'Bloc'),
              const SizedBox(width: 24),
              _buildLegendDot(MintColors.success, 'Echelonne'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: MintColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Timeline yearly plan
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildTimelineSection(RachatEchelonneResult result) {
    final cumulativeRachat = <double>[];
    double cumul = 0;
    for (final year in result.yearlyPlan) {
      cumul += year.montantRachat;
      cumulativeRachat.add(cumul);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLAN ANNUEL',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < result.yearlyPlan.length; i++)
            _buildTimelineNode(
              year: result.yearlyPlan[i],
              index: i,
              total: result.yearlyPlan.length,
              lacunePercent: _rachatMax > 0
                  ? (cumulativeRachat[i] / _rachatMax * 100).clamp(0.0, 100.0)
                  : 0.0,
            ),

          // Total row
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Economie : CHF ${formatChf(result.economieEchelonneTotal)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cout net : CHF ${formatChf(_rachatMax - result.economieEchelonneTotal)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MintColors.textSecondary,
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

  Widget _buildTimelineNode({
    required RachatYearPlan year,
    required int index,
    required int total,
    required double lacunePercent,
  }) {
    final isLast = index == total - 1;
    final progress = (index + 1) / total;

    // Gradient from primary to success as savings accumulate
    final lineColor = Color.lerp(
      MintColors.primary,
      MintColors.success,
      progress,
    )!;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: year node + vertical line
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: lineColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${year.annee}',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            lineColor,
                            Color.lerp(
                              MintColors.primary,
                              MintColors.success,
                              (index + 2) / total,
                            )!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right: card with details
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MintColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CHF ${formatChf(year.montantRachat)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      Text(
                        '-CHF ${formatChf(year.economieFiscale)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rachat',
                        style: TextStyle(
                          fontSize: 11,
                          color: MintColors.textMuted,
                        ),
                      ),
                      Text(
                        'Economie fiscale',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Cout net : CHF ${formatChf(year.coutNet)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: lineColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Lacune comblee : ${lacunePercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: lineColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Blockage alert (LPP art. 79b al. 3)
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildBlockageAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel, color: Colors.red.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LPP art. 79b al. 3 — Blocage EPL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apres chaque rachat, tout retrait EPL (encouragement a la '
                  'propriete du logement) est bloque pendant 3 ans. '
                  'Planifie en consequence si un achat immobilier est prevu.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
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

  // ─────────────────────────────────────────────────────────────────────
  // Disclaimer
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Waterfall Painter — Progressive tax bracket visualization
// ═══════════════════════════════════════════════════════════════════════════

class _WaterfallPainter extends CustomPainter {
  final double revenu;
  final double rachatMax;
  final int horizon;

  _WaterfallPainter({
    required this.revenu,
    required this.rachatMax,
    required this.horizon,
  });

  // Simplified progressive bracket model for visualization
  static const List<_TaxBracket> _brackets = [
    _TaxBracket(label: '0-50k', rate: 15, upperBound: 50000),
    _TaxBracket(label: '50-100k', rate: 25, upperBound: 100000),
    _TaxBracket(label: '100-150k', rate: 32, upperBound: 150000),
    _TaxBracket(label: '150k+', rate: 38, upperBound: 300000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double chartLeft = 70;
    final double chartRight = size.width - 16;
    final double chartTop = 10;
    final double chartBottom = size.height - 40;
    final double chartWidth = chartRight - chartLeft;
    final double chartHeight = chartBottom - chartTop;

    // Background grid and bracket labels
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E5E7)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < _brackets.length; i++) {
      final y = chartTop + (i / _brackets.length) * chartHeight;
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        gridPaint,
      );

      // Bracket labels on the left
      textPainter.text = TextSpan(
        text: '${_brackets[_brackets.length - 1 - i].label}\n${_brackets[_brackets.length - 1 - i].rate}%',
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF86868B),
          height: 1.3,
        ),
      );
      textPainter.layout(maxWidth: 60);
      textPainter.paint(canvas, Offset(4, y + 2));
    }
    // Bottom grid line
    canvas.drawLine(
      Offset(chartLeft, chartBottom),
      Offset(chartRight, chartBottom),
      gridPaint,
    );

    // Determine which brackets the deduction hits
    final blocDeduction = rachatMax;
    final echelonneDeduction = rachatMax / horizon;

    // Bar width calculations
    final groupWidth = chartWidth / 2;
    final barWidth = groupWidth * 0.5;
    final blocX = chartLeft + groupWidth * 0.25;
    final echelX = chartLeft + groupWidth + groupWidth * 0.25;

    // Draw bloc bar (orange) — single tall bar
    _drawDeductionBar(
      canvas: canvas,
      x: blocX,
      width: barWidth,
      deduction: blocDeduction,
      chartTop: chartTop,
      chartBottom: chartBottom,
      color: Colors.orange,
    );

    // Draw echelonne bar (green) — shorter bar
    _drawDeductionBar(
      canvas: canvas,
      x: echelX,
      width: barWidth,
      deduction: echelonneDeduction,
      chartTop: chartTop,
      chartBottom: chartBottom,
      color: const Color(0xFF24B14D),
    );

    // Labels below bars
    textPainter.text = const TextSpan(
      text: 'Bloc',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6E6E73),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(blocX + barWidth / 2 - textPainter.width / 2, chartBottom + 8),
    );

    final echelLabel = 'x$horizon ans';
    textPainter.text = TextSpan(
      text: echelLabel,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6E6E73),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(echelX + barWidth / 2 - textPainter.width / 2, chartBottom + 8),
    );

    // Amount labels on top of bars
    final blocBarHeight = _getBarHeight(blocDeduction, chartHeight);
    textPainter.text = TextSpan(
      text: 'CHF ${_formatShort(blocDeduction)}',
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1D1D1F),
      ),
    );
    textPainter.layout();
    final blocBarTop = chartBottom - blocBarHeight;
    textPainter.paint(
      canvas,
      Offset(
        blocX + barWidth / 2 - textPainter.width / 2,
        (blocBarTop - 14).clamp(0.0, chartBottom),
      ),
    );

    final echelBarHeight = _getBarHeight(echelonneDeduction, chartHeight);
    textPainter.text = TextSpan(
      text: 'CHF ${_formatShort(echelonneDeduction)}',
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1D1D1F),
      ),
    );
    textPainter.layout();
    final echelBarTop = chartBottom - echelBarHeight;
    textPainter.paint(
      canvas,
      Offset(
        echelX + barWidth / 2 - textPainter.width / 2,
        (echelBarTop - 14).clamp(0.0, chartBottom),
      ),
    );
  }

  double _getBarHeight(double deduction, double chartHeight) {
    // Max deduction for scale = 200k (matches slider max)
    final maxDeduction = 500000.0;
    return (deduction / maxDeduction * chartHeight).clamp(8.0, chartHeight);
  }

  void _drawDeductionBar({
    required Canvas canvas,
    required double x,
    required double width,
    required double deduction,
    required double chartTop,
    required double chartBottom,
    required Color color,
  }) {
    final chartHeight = chartBottom - chartTop;
    final barHeight = _getBarHeight(deduction, chartHeight);

    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, chartBottom - barHeight, width, barHeight),
      const Radius.circular(4),
    );

    // Gradient fill
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withAlpha(160)],
      ).createShader(barRect.outerRect);

    canvas.drawRRect(barRect, paint);
  }

  String _formatShort(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter oldDelegate) {
    return oldDelegate.revenu != revenu ||
        oldDelegate.rachatMax != rachatMax ||
        oldDelegate.horizon != horizon;
  }
}

class _TaxBracket {
  final String label;
  final int rate;
  final double upperBound;

  const _TaxBracket({
    required this.label,
    required this.rate,
    required this.upperBound,
  });
}
