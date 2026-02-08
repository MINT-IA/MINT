import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/domain/rente_vs_capital_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';

/// Scenario display colors
const _scenarioColors = {
  'prudent': Colors.orange,
  'central': Color(0xFF4F46E5),
  'optimiste': Color(0xFF2D6A4F),
};

const _scenarioLabels = {
  'prudent': 'Prudent (1%)',
  'central': 'Central (3%)',
  'optimiste': 'Optimiste (5%)',
};

class SimulatorRenteCapitalScreen extends StatefulWidget {
  const SimulatorRenteCapitalScreen({super.key});

  @override
  State<SimulatorRenteCapitalScreen> createState() =>
      _SimulatorRenteCapitalScreenState();
}

class _SimulatorRenteCapitalScreenState
    extends State<SimulatorRenteCapitalScreen> {
  double _avoirObligatoire = 200000;
  double _avoirSurobligatoire = 100000;
  double _tauxConversionSurob = 5.0;
  int _ageRetraite = 65;
  String _canton = 'ZH';
  String _statutCivil = 'single';

  RenteVsCapitalResult? _result;

  final _chf = NumberFormat.currency(
    symbol: 'CHF\u00A0',
    decimalDigits: 0,
    locale: 'fr_CH',
  );

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = computeRenteVsCapital(
        avoirObligatoire: _avoirObligatoire,
        avoirSurobligatoire: _avoirSurobligatoire,
        tauxConversionSurob: _tauxConversionSurob / 100,
        ageRetraite: _ageRetraite,
        canton: _canton,
        statutCivil: _statutCivil,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: const Text('Rente vs Capital'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildInputsSection(),
            const SizedBox(height: 24),
            if (_result != null) ...[
              _buildResultCards(),
              const SizedBox(height: 24),
              _buildChart(),
              const SizedBox(height: 24),
              _buildBreakEvenSection(),
              const SizedBox(height: 24),
            ],
            _buildEducationSection(),
            const SizedBox(height: 24),
            _buildDisclaimer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance,
                color: MintColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rente vs Capital',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Simulez votre 2e pilier \u2022 LPP',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Inputs Section ---
  Widget _buildInputsSection() {
    return SimulatorCard(
      title: 'Vos parametres',
      subtitle: 'Ajustez selon votre certificat LPP',
      icon: Icons.tune,
      child: Column(
        children: [
          _buildSlider(
            label: 'Avoir obligatoire',
            value: _avoirObligatoire,
            min: 0,
            max: 800000,
            divisions: 80,
            format: (v) => _chf.format(v),
            onChanged: (v) {
              _avoirObligatoire = v;
              _calculate();
            },
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Avoir surobligatoire',
            value: _avoirSurobligatoire,
            min: 0,
            max: 800000,
            divisions: 80,
            format: (v) => _chf.format(v),
            onChanged: (v) {
              _avoirSurobligatoire = v;
              _calculate();
            },
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Taux de conversion surobligatoire',
            value: _tauxConversionSurob,
            min: 3.0,
            max: 7.0,
            divisions: 40,
            format: (v) => '${v.toStringAsFixed(1)}%',
            onChanged: (v) {
              _tauxConversionSurob = v;
              _calculate();
            },
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Age de la retraite',
            value: _ageRetraite.toDouble(),
            min: 58,
            max: 70,
            divisions: 12,
            format: (v) => '${v.toInt()} ans',
            onChanged: (v) {
              _ageRetraite = v.toInt();
              _calculate();
            },
          ),
          const SizedBox(height: 20),
          // Canton dropdown + status
          Row(
            children: [
              Expanded(child: _buildCantonDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildStatusSelector()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              format(value),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCantonDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Canton',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _canton,
              isExpanded: true,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textPrimary,
              ),
              items: supportedCantons.map((c) {
                return DropdownMenuItem(value: c, child: Text(c));
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  _canton = v;
                  _calculate();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statut civil',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'single', label: Text('Seul')),
            ButtonSegment(value: 'married', label: Text('Marie')),
          ],
          selected: {_statutCivil},
          onSelectionChanged: (v) {
            _statutCivil = v.first;
            _calculate();
          },
          style: ButtonStyle(
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  // --- Result Cards ---
  Widget _buildResultCards() {
    final r = _result!;
    return Row(
      children: [
        Expanded(
          child: _buildResultCard(
            color: MintColors.success,
            icon: Icons.autorenew,
            title: 'Rente viagere',
            mainValue: _chf.format(r.renteAnnuelle),
            subtitle: '${_chf.format(r.renteMensuelle)} / mois',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildResultCard(
            color: MintColors.info,
            icon: Icons.account_balance_wallet,
            title: 'Capital net',
            mainValue: _chf.format(r.capitalNet),
            subtitle:
                'Impot: ${_chf.format(r.impotRetrait)} (${(r.tauxEffectif * 100).toStringAsFixed(1)}%)',
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required Color color,
    required IconData icon,
    required String title,
    required String mainValue,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              mainValue,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // --- Chart ---
  Widget _buildChart() {
    final r = _result!;
    final scenarios = r.scenarios;
    final nbYears = 100 - _ageRetraite;

    // Compute chart bounds from data
    double maxVal = 0;
    double minVal = double.infinity;
    for (final s in scenarios.values) {
      for (final v in s.capitalTimeSeries) {
        if (v > maxVal) maxVal = v;
        if (v < minVal) minVal = v;
      }
    }

    // Smart Y-axis: tighter framing reveals interest effects better
    final double effectiveMin = minVal < 0 ? 0.0 : minVal;
    final double dataRange = maxVal - effectiveMin;
    double maxY = maxVal + dataRange * 0.05;
    double minY;
    if (effectiveMin > 0) {
      // All scenarios stay positive: zoom in to the relevant range
      minY = effectiveMin - dataRange * 0.08;
      if (minY < 0) minY = 0;
    } else {
      // Some scenarios deplete: small negative buffer for visual clarity
      minY = -dataRange * 0.03;
    }
    if (maxY <= 0) maxY = r.capitalNet * 1.2;
    final double effectiveRange = maxY - minY;

    // Baseline: 0% return (pure withdrawal, no interest)
    final baselineSpots = <FlSpot>[];
    double baselineCapital = r.capitalNet;
    for (int year = 0; year <= nbYears; year++) {
      baselineSpots.add(FlSpot(
        year.toDouble(),
        baselineCapital > 0 ? baselineCapital : 0,
      ));
      baselineCapital -= r.renteAnnuelle;
    }

    return SimulatorCard(
      title: 'Evolution du capital',
      subtitle: 'De $_ageRetraite a 100 ans, en retirant la rente mensuelle',
      icon: Icons.show_chart,
      child: Column(
        children: [
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: nbYears.toDouble(),
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calcGridInterval(effectiveRange),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: MintColors.border.withOpacity(0.5),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        final age = _ageRetraite + value.toInt();
                        if (age > 100) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '$age',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: MintColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      interval: _calcGridInterval(effectiveRange),
                      getTitlesWidget: (value, meta) {
                        if (value < minY || value > maxY) {
                          return const SizedBox();
                        }
                        return Text(
                          '${(value / 1000).toStringAsFixed(0)}k',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: MintColors.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: MintColors.textMuted.withOpacity(0.5),
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.centerRight,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: MintColors.textMuted,
                        ),
                        labelResolver: (_) => 'Break-even',
                      ),
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        MintColors.textPrimary.withOpacity(0.9),
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final age = _ageRetraite + spot.x.toInt();
                        final name = spot.barIndex == 0
                            ? 'Sans interets'
                            : spot.barIndex == 1
                                ? 'Prudent'
                                : spot.barIndex == 2
                                    ? 'Central'
                                    : 'Optimiste';
                        return LineTooltipItem(
                          '$name a $age ans\n${_chf.format(spot.y)}',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // Baseline: 0% return (no interest)
                  LineChartBarData(
                    spots: baselineSpots,
                    isCurved: false,
                    color: MintColors.textMuted.withOpacity(0.35),
                    barWidth: 1.5,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  _buildLine(scenarios['prudent']!, _scenarioColors['prudent']!),
                  _buildLine(scenarios['central']!, _scenarioColors['central']!),
                  _buildLine(
                      scenarios['optimiste']!, _scenarioColors['optimiste']!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(ScenarioResult scenario, Color color) {
    final spots = <FlSpot>[];
    for (int i = 0; i < scenario.capitalTimeSeries.length; i++) {
      final val = scenario.capitalTimeSeries[i];
      spots.add(FlSpot(i.toDouble(), val < 0 ? 0 : val));
    }
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.05),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        // Baseline legend
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 2,
              color: MintColors.textMuted.withOpacity(0.35),
            ),
            const SizedBox(width: 6),
            Text(
              'Sans interets',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        ..._scenarioLabels.entries.map((entry) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _scenarioColors[entry.key],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                entry.value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  double _calcGridInterval(double range) {
    if (range > 1000000) return 200000;
    if (range > 500000) return 100000;
    if (range > 200000) return 50000;
    if (range > 100000) return 25000;
    return 10000;
  }

  // --- Break-Even Section ---
  Widget _buildBreakEvenSection() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POINTS CLES',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: r.scenarios.entries.map((entry) {
            final s = entry.value;
            final color = _scenarioColors[entry.key]!;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: entry.key != 'optimiste' ? 8 : 0,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _scenarioLabels[entry.key]!.split(' ').first,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Break-even',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: MintColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.breakEvenAge != null
                          ? '${s.breakEvenAge!.toStringAsFixed(1)} ans'
                          : 'Jamais',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capital a 85 ans',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: MintColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _chf.format(s.capital85),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: s.capital85 > 0
                              ? MintColors.success
                              : MintColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Education Section ---
  Widget _buildEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPRENDRE',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableTile(
          'Qu\'est-ce que le taux de conversion ?',
          'Le taux de conversion determine le montant de votre rente annuelle '
              'en fonction de votre avoir de vieillesse. Le taux legal minimum est '
              'de 6.8% pour la part obligatoire (LPP art. 14). Pour la part '
              'surobligatoire, chaque caisse de pension fixe son propre taux, '
              'generalement entre 3% et 6%.',
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          'Rente ou capital : comment choisir ?',
          'La rente offre un revenu regulier a vie, mais s\'arrete au deces '
              '(avec eventuellement une rente de survivant reduite). Le capital donne '
              'plus de flexibilite, mais comporte un risque d\'epuisement si les rendements '
              'sont faibles ou la longevite elevee. Les facteurs importants : etat de sante, '
              'projets, patrimoine existant, et fiscalite cantonale.',
        ),
      ],
    );
  }

  Widget _buildExpandableTile(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
          children: [
            Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Disclaimer ---
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les resultats presentes sont des estimations a titre indicatif. '
              'Ils ne constituent pas un conseil financier personnalise. '
              'Consultez votre caisse de pension et un conseiller qualifie '
              'avant toute decision.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
