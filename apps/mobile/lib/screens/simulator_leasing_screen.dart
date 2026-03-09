import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/leasing_cost_widget.dart';

class SimulatorLeasingScreen extends StatefulWidget {
  const SimulatorLeasingScreen({super.key});

  @override
  State<SimulatorLeasingScreen> createState() => _SimulatorLeasingScreenState();
}

class _SimulatorLeasingScreenState extends State<SimulatorLeasingScreen> {
  double _monthlyPayment = 400;
  int _durationMonths = 48;
  double _alternativeRate = 5.0;

  Map<String, dynamic>? _result;

  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = calculateLeasingOpportunityCost(
        monthlyPayment: _monthlyPayment,
        durationMonths: _durationMonths,
        alternativeAnnualRate: _alternativeRate,
      );
    });
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;
    
    // TODO: Implement PDF export for leasing simulator
    // await PdfService.generateBilanPdf(
    //   title: 'Bilan Anti-Leasing',
    //   results: results,
    //   recommendations: recommendations,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: const Text('Analyse Anti-Leasing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportPdf,
            tooltip: 'Exporter mon bilan',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCoachSection(),
            const SizedBox(height: 32),
            _buildInputSection(),
            const SizedBox(height: 32),
            if (_result != null) _buildResultSection(),
            const SizedBox(height: 32),
            // ── P10-D : Le vrai coût du leasing ─────────────────
            LeasingCostWidget(
              vehiclePrice: _monthlyPayment * _durationMonths / 0.55,
              monthlyLeasing: _monthlyPayment,
              leasingDurationMonths: _durationMonths,
              annualReturnRate: _alternativeRate / 100,
            ),
            const SizedBox(height: 32),
            _buildAlternativesSection(),
            const SizedBox(height: 48),
            _buildDisclaimer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: MintColors.primary, size: 24),
              SizedBox(width: 12),
              Text('Réflexion du Mentor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Le leasing est souvent une "fuite" de capital. Cet argent pourrait servir à construire ton patrimoine plutôt qu\'à financer la dépréciation d\'un véhicule.',
            style: TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Données du Contrat'),
        const SizedBox(height: 24),
        _buildSlider(
          label: 'Mensualité prévue',
          value: _monthlyPayment,
          min: 100,
          max: 1500,
          divisions: 28,
          format: (v) => _currencyFormat.format(v),
          onChanged: (v) {
            _monthlyPayment = v;
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: 'Durée du leasing',
          value: _durationMonths.toDouble(),
          min: 12,
          max: 60,
          divisions: 4,
          format: (v) => '${v.toInt()} mois',
          onChanged: (v) {
            _durationMonths = v.toInt();
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: 'Rendement alternatif espéré',
          value: _alternativeRate,
          min: 1,
          max: 10,
          divisions: 18,
          format: (v) => '${v.toStringAsFixed(1)}%',
          onChanged: (v) {
            _alternativeRate = v;
            _calculate();
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: MintColors.textMuted,
        letterSpacing: 1.2,
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
            Text(label, style: const TextStyle(fontSize: 14, color: MintColors.textPrimary)),
            Text(
              format(value),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: MintColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
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

  Widget _buildResultSection() {
    final opportunityCost20 = _result!['opportunityCost']['20y'] as double;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Text('Coût d\'opportunité sur 20 ans', style: TextStyle(fontSize: 14, color: MintColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(opportunityCost20),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: MintColors.error),
          ),
          const SizedBox(height: 24),
          const Text(
            'Si tu investissais cette mensualité au lieu de payer un leasing, voilà le capital que tu aurais construit.',
            style: TextStyle(fontSize: 13, color: MintColors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_work_outlined, color: MintColors.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'C\'est environ ${_currencyFormat.format(opportunityCost20 * 0.2)} de fonds propres pour un achat immobilier.',
                    style: const TextStyle(color: MintColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('S\'écarter du Trou Noir'),
        const SizedBox(height: 24),
        _buildAltItem(Icons.directions_car_outlined, 'Occasion de Qualité', 'Acheter cash une voiture de 3-4 ans réduit drastiquement la perte de valeur.'),
        _buildAltItem(Icons.train_outlined, 'Abo Général / Transports', 'Le confort du train en Suisse est souvent plus rentable et serein.'),
        _buildAltItem(Icons.share_outlined, 'Mobility / Partage', 'Ne paie que quand tu roules. Pas d\'assurance, pas d\'entretien, pas de leasing.'),
      ],
    );
  }

  Widget _buildAltItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: MintColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Le leasing reste une option pour certains professionnels. Cette analyse vise à sensibiliser le particulier sur le coût à long terme.',
          style: TextStyle(color: MintColors.textMuted, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
