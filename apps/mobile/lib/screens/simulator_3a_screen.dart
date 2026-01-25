import 'package:flutter/material.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';

class Simulator3aScreen extends StatefulWidget {
  const Simulator3aScreen({super.key});

  @override
  State<Simulator3aScreen> createState() => _Simulator3aScreenState();
}

class _Simulator3aScreenState extends State<Simulator3aScreen> {
  double _annualContribution = 7258;
  double _marginalTaxRate = 0.25;
  int _years = 30;
  double _annualReturn = 4.0;

  Map<String, double>? _result;

  final _currencyFormat = NumberFormat.currency(symbol: 'CHF ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _initializeFromProfile();
    _calculate();
  }

  void _initializeFromProfile() {
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.hasProfile) {
      final profile = profileProvider.profile!;
      if (profile.birthYear != null) {
        final age = DateTime.now().year - profile.birthYear!;
        _years = (65 - age).clamp(5, 45);
      }
      
      // Rough estimate of marginal tax rate based on income if available
      if (profile.incomeNetMonthly != null) {
        final annualIncome = profile.incomeNetMonthly! * 12;
        if (annualIncome > 150000) {
          _marginalTaxRate = 0.35;
        } else if (annualIncome > 100000) {
          _marginalTaxRate = 0.30;
        } else if (annualIncome > 60000) {
          _marginalTaxRate = 0.25;
        } else {
          _marginalTaxRate = 0.20;
        }
      }
    }
  }

  void _calculate() {
    setState(() {
      _result = calculate3aTaxBenefit(
        annualContribution: _annualContribution,
        marginalTaxRate: _marginalTaxRate,
        years: _years,
        annualReturn: _annualReturn,
      );
    });
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;
    
    final results = {
      'Versement annuel': _currencyFormat.format(_annualContribution),
      'Économie fiscale /an': _currencyFormat.format(_result!['annualTaxSaved']!),
      'Économie totale': _currencyFormat.format(_result!['totalTaxSavedOverPeriod']!),
      'Capital final': _currencyFormat.format(_result!['potentialFinalValue']!),
    };

    final recommendations = [
      'Privilégiez le 3a bancaire pour sa flexibilité et ses coûts réduits.',
      'Ouvrez plusieurs comptes (jusqu\'à 5) pour échelonner les retraits.',
      'Réinvestissez votre économie d\'impôts pour un effet boule de neige maximal.',
    ];

    // TODO: Implement PDF export for 3a simulator
    // await PdfService.generateBilanPdf(
    //   title: 'Bilan Optimisation Pilier 3a',
    //   results: results,
    //   recommendations: recommendations,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: const Text('Optimiseur Pilier 3a'),
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
            _buildEducationSection(),
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
              Text('Le conseil du Mentor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Le 3a est votre meilleur outil d\'optimisation en Suisse. L\'économie fiscale immédiate est un "rendement" garanti.',
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
        _buildSectionHeader('Vos Paramètres'),
        const SizedBox(height: 24),
        _buildSlider(
          label: 'Versement annuel',
          value: _annualContribution,
          min: 1000,
          max: 7258,
          divisions: 62,
          format: (v) => _currencyFormat.format(v),
          onChanged: (v) {
            _annualContribution = v;
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: 'Taux marginal d’imposition',
          value: _marginalTaxRate * 100,
          min: 10,
          max: 45,
          divisions: 35,
          format: (v) => '${v.toStringAsFixed(0)}%',
          onChanged: (v) {
            _marginalTaxRate = v / 100;
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: 'Années jusqu\'à la retraite',
          value: _years.toDouble(),
          min: 5,
          max: 45,
          divisions: 40,
          format: (v) => '${v.toInt()} ans',
          onChanged: (v) {
            _years = v.toInt();
            _calculate();
          },
        ),
        const SizedBox(height: 20),
        _buildSlider(
          label: 'Rendement annuel espéré',
          value: _annualReturn,
          min: 0,
          max: 10,
          divisions: 20,
          format: (v) => '${v.toStringAsFixed(1)}%',
          onChanged: (v) {
            _annualReturn = v;
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
        if (label.isNotEmpty)
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.accentPastel.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text('Gain Fiscal Annuel', style: TextStyle(fontSize: 14, color: MintColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(_result!['annualTaxSaved']!),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: MintColors.primary),
          ),
          const SizedBox(height: 24),
          const Divider(color: MintColors.border),
          const SizedBox(height: 16),
          _buildImpactRow('Capital au terme', _result!['potentialFinalValue']!),
          const SizedBox(height: 8),
          _buildImpactRow('Économie fiscale cumulée', _result!['totalTaxSavedOverPeriod']!, color: MintColors.success),
        ],
      ),
    );
  }

  Widget _buildImpactRow(String label, double value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: MintColors.textSecondary)),
        Text(
          _currencyFormat.format(value),
          style: TextStyle(fontWeight: FontWeight.w600, color: color ?? MintColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Strategie Gagnante'),
        const SizedBox(height: 24),
        _buildSmartItem(Icons.account_balance_wallet_outlined, 'Bancaire > Assurance', 'Évitez les contrats d\'assurance liés. Restez flexible avec un 3a bancaire investi.'),
        _buildSmartItem(Icons.layers_outlined, 'La règle des 5 comptes', 'Ouvrez plusieurs comptes pour retirer de manière échelonnée et éviter la progression fiscale au retrait.'),
        _buildSmartItem(Icons.trending_up, '100% Actions', 'Si votre retraite est dans plus de 15 ans, une stratégie actions maximise votre capital.'),
      ],
    );
  }

  Widget _buildSmartItem(IconData icon, String title, String subtitle) {
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
          'Calculs basés sur des moyennes cantonales. Les économies réelles dépendent de votre lieu de résidence et situation familiale.',
          style: TextStyle(color: MintColors.textMuted, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
