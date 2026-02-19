import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/domain/rente_vs_capital_calculator.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
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
  bool _useCustomRetrait = false;
  double _retraitMensuel = 1500;
  String _modeRetrait = 'compare'; // compare, rente, capital, mixte
  double _partRente = 0.5; // 0.0 to 1.0, for mixte mode

  RenteVsCapitalResult? _result;

  final _chf = NumberFormat.currency(
    symbol: 'CHF\u00A0',
    decimalDigits: 0,
    locale: 'fr_CH',
  );

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('rente_capital');
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
        retraitMensuelOverride: _useCustomRetrait ? _retraitMensuel : null,
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
            const SizedBox(height: 16),
            if (_result != null) _buildChiffreChoc(),
            const SizedBox(height: 20),
            _buildInputsSection(),
            const SizedBox(height: 24),
            if (_result != null) ...[
              _buildModeSelector(),
              _buildMixteSlider(),
              const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            _buildSources(),
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
                  'Simule ton 2e pilier \u2022 LPP',
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

  // --- Chiffre Choc ---
  Widget _buildChiffreChoc() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MintColors.primary, MintColors.primary.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Rente : ${_chf.format(r.renteMensuelle)}/mois a vie  \u2022  '
              'Capital : ${_chf.format(r.capitalNet)} net',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Inputs Section ---
  Widget _buildInputsSection() {
    return SimulatorCard(
      title: 'Tes parametres',
      subtitle: 'Ajuste selon ton certificat LPP',
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
          _buildCantonDropdown(),
          const SizedBox(height: 16),
          _buildStatusSelector(),
          const SizedBox(height: 20),
          _buildCustomRetraitToggle(),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Canton',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
              ),
            ),
            Text(
              'Taux : ${((tauxImpotRetraitCapital[_canton] ?? 0) * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.textMuted,
              ),
            ),
          ],
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
              items: sortedCantonCodes.map((code) {
                return DropdownMenuItem(
                  value: code,
                  child: Text('$code \u2014 ${cantonFullNames[code]}'),
                );
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
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildPillOption('single', 'Seul\u00B7e'),
              _buildPillOption('married', 'Mari\u00E9\u00B7e'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillOption(String value, String label) {
    final isSelected = _statutCivil == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_statutCivil != value) {
            _statutCivil = value;
            _calculate();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? MintColors.textPrimary : MintColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomRetraitToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Retrait mensuel personnalise',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Switch(
              value: _useCustomRetrait,
              activeColor: MintColors.primary,
              onChanged: (v) {
                _useCustomRetrait = v;
                if (v && _result != null) {
                  _retraitMensuel = _result!.renteMensuelle;
                }
                _calculate();
              },
            ),
          ],
        ),
        if (!_useCustomRetrait)
          Text(
            'Par defaut : retrait = rente (${_result != null ? _chf.format(_result!.renteMensuelle) : "-"}/mois). '
            'Active pour simuler un retrait different.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              height: 1.4,
            ),
          ),
        if (_useCustomRetrait) ...[
          const SizedBox(height: 8),
          _buildSlider(
            label: 'Retrait mensuel',
            value: _retraitMensuel,
            min: 500,
            max: 15000,
            divisions: 145,
            format: (v) => _chf.format(v),
            onChanged: (v) {
              _retraitMensuel = v;
              _calculate();
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Rente equivalente : ${_result != null ? _chf.format(_result!.renteMensuelle) : "-"}/mois',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  // --- Mode Selector ---
  Widget _buildModeSelector() {
    const modes = ['compare', 'rente', 'capital', 'mixte'];
    const labels = ['Comparer', 'Rente', 'Capital', 'Mixte'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Row(
        children: List.generate(4, (i) {
          final selected = _modeRetrait == modes[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _modeRetrait = modes[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? MintColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0 ? const Radius.circular(20) : Radius.zero,
                    right: i == 3 ? const Radius.circular(20) : Radius.zero,
                  ),
                  border: Border.all(
                      color: MintColors.primary.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? Colors.white : MintColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- Mixte Slider ---
  Widget _buildMixteSlider() {
    if (_modeRetrait != 'mixte') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Part en rente : ${(_partRente * 100).round()}%',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          Slider(
            value: _partRente,
            min: 0,
            max: 1,
            divisions: 20,
            activeColor: MintColors.primary,
            label: '${(_partRente * 100).round()}%',
            onChanged: (v) => setState(() {
              _partRente = v;
              _calculate();
            }),
          ),
        ],
      ),
    );
  }

  // --- Mixte Calculation ---
  Map<String, dynamic>? _computeMixteResult() {
    if (_result == null) return null;

    final rentePartObl = _avoirObligatoire * _partRente;
    final capitalPartObl = _avoirObligatoire * (1 - _partRente);
    final rentePartSurob = _avoirSurobligatoire * _partRente;
    final capitalPartSurob = _avoirSurobligatoire * (1 - _partRente);

    // Rente mensuelle from rente portion
    final renteObl = rentePartObl * 0.068 / 12; // 6.8% LPP conversion rate
    final renteSurob = rentePartSurob * (_tauxConversionSurob / 100) / 12;
    final renteMensuelle = renteObl + renteSurob;

    // Capital net from capital portion (use existing result ratios)
    final capitalBrut = capitalPartObl + capitalPartSurob;
    final tauxImposition = _result!.capitalNet > 0
        ? 1 -
            (_result!.capitalNet /
                (_avoirObligatoire + _avoirSurobligatoire))
        : 0.05;
    final capitalNet = capitalBrut * (1 - tauxImposition);
    final impotCapital = capitalBrut - capitalNet;

    // SWR 4% on net capital for monthly equivalent
    final revenuCapitalMensuel = capitalNet * 0.04 / 12;
    final revenuTotalMensuel = renteMensuelle + revenuCapitalMensuel;

    return {
      'renteMensuelle': renteMensuelle,
      'capitalBrut': capitalBrut,
      'capitalNet': capitalNet,
      'impot': impotCapital,
      'revenuTotal': revenuTotalMensuel,
      'partRente': _partRente,
    };
  }

  // --- Mixte Result Card ---
  Widget _buildMixteCard() {
    final mixte = _computeMixteResult();
    if (mixte == null) return const SizedBox.shrink();

    final renteMens = mixte['renteMensuelle'] as double;
    final capitalNet = mixte['capitalNet'] as double;
    final impot = mixte['impot'] as double;
    final revenuTotal = mixte['revenuTotal'] as double;
    final pctRente = (mixte['partRente'] as double) * 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.purple.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart, color: MintColors.purple, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mode mixte (${pctRente.round()}% rente)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMixteRow('Rente mensuelle', _chf.format(renteMens),
              MintColors.success),
          const SizedBox(height: 10),
          _buildMixteRow(
              'Capital net', _chf.format(capitalNet), MintColors.info),
          const SizedBox(height: 10),
          _buildMixteRow(
              'Impot estime', _chf.format(impot), MintColors.warning),
          const Divider(height: 24),
          _buildMixteRow(
            'Revenu total equivalent',
            '${_chf.format(revenuTotal)}/mois',
            MintColors.purple,
            isBold: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Capital : rendement hypothetique de 4%/an (SWR). '
            'Le revenu reel depend des marches.',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixteRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // --- Result Cards ---
  Widget _buildResultCards() {
    if (_modeRetrait == 'mixte') return _buildMixteCard();

    final r = _result!;
    final dimRente = _modeRetrait == 'capital';
    final dimCapital = _modeRetrait == 'rente';

    return Row(
      children: [
        Expanded(
          child: AnimatedOpacity(
            opacity: dimRente ? 0.35 : 1.0,
            duration: const Duration(milliseconds: 250),
            child: _buildResultCard(
              color: MintColors.success,
              icon: Icons.autorenew,
              title: 'Rente viagere',
              mainValue: '${_chf.format(r.renteAnnuelle)}/an',
              subtitle: '${_chf.format(r.renteMensuelle)} / mois, a vie',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedOpacity(
            opacity: dimCapital ? 0.35 : 1.0,
            duration: const Duration(milliseconds: 250),
            child: _buildResultCard(
              color: MintColors.info,
              icon: Icons.account_balance_wallet,
              title: 'Capital net',
              mainValue: _chf.format(r.capitalNet),
              subtitle:
                  'Impot: ${_chf.format(r.impotRetrait)} (${(r.tauxEffectif * 100).toStringAsFixed(1)}%)',
            ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: color),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                fontSize: 26,
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
          ),
          ],
        ),
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
      minY = effectiveMin - dataRange * 0.08;
      if (minY < 0) minY = 0;
    } else {
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
          'Le taux de conversion determine le montant de ta rente annuelle '
              'en fonction de ton avoir de vieillesse. Le taux legal minimum est '
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
        const SizedBox(height: 8),
        _buildExpandableTile(
          'Comment est impose le retrait en capital ?',
          'Le retrait en capital LPP est impose separement a un taux reduit '
              '(LIFD art. 38). Le taux est progressif : plus le montant est eleve, '
              'plus le taux effectif augmente. Les couples maries beneficient '
              'generalement d\'un taux reduit grace au splitting. Le taux varie '
              'fortement selon le canton \u2014 de ~3.5% (Zoug) a ~8% (Vaud).',
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
              'Ces resultats ne constituent pas un conseil en prevoyance au sens de la LSFin. '
              'Cet outil educatif presente des estimations a titre indicatif. '
              'Les taux d\'imposition sont des approximations cantonales. '
              'Consulte ta caisse de pension et un\u00B7e sp\u00E9cialiste qualifi\u00E9\u00B7e '
              'avant toute d\u00E9cision.',
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

  // --- Sources ---
  Widget _buildSources() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Sources : LPP art. 14 (taux de conversion 6.8%), '
        'LIFD art. 38 (imposition des prestations en capital)',
        style: GoogleFonts.inter(
          fontSize: 10,
          color: MintColors.textMuted,
          height: 1.4,
        ),
      ),
    );
  }
}
