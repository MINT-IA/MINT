import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

/// Ecran de simulation du retrait EPL (Encouragement a la Propriete du Logement).
///
/// Permet d'estimer le montant retirable, l'impot et l'impact sur
/// les prestations de risque (invalidite, deces).
/// Base legale : art. 30c LPP, OEPL.
class EplScreen extends StatefulWidget {
  const EplScreen({super.key});

  @override
  State<EplScreen> createState() => _EplScreenState();
}

class _EplScreenState extends State<EplScreen> {
  double _avoirTotal = 300000;
  int _age = 40;
  double _montantSouhaite = 100000;
  bool _aRachete = false;
  int _anneesSDepuisRachat = 0;
  String _canton = 'ZH';

  EplResult get _result {
    // Repartition simplifiee oblig / suroblig
    final oblig = _avoirTotal * 0.6;
    final suroblig = _avoirTotal * 0.4;

    return EplSimulator.simulate(
      avoirTotal: _avoirTotal,
      avoirObligatoire: oblig,
      avoirSurobligatoire: suroblig,
      age: _age,
      montantSouhaite: _montantSouhaite,
      aRachete: _aRachete,
      anneesSDepuisRachat: _anneesSDepuisRachat,
      canton: _canton,
    );
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
                'RETRAIT EPL',
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
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Results
                _buildResultsSection(result),
                const SizedBox(height: 24),

                // Impact on benefits
                if (result.montantSouhaiteApplicable > 0) ...[
                  _buildImpactSection(result),
                  const SizedBox(height: 24),
                ],

                // Tax estimate
                if (result.montantSouhaiteApplicable > 0) ...[
                  _buildTaxCard(result),
                  const SizedBox(height: 24),
                ],

                // Alerts
                if (result.alerts.isNotEmpty) ...[
                  _buildAlertsSection(result.alerts),
                  const SizedBox(height: 24),
                ],

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
            'Retrait EPL — Propriete du logement',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'EPL permet d\'utiliser ton avoir LPP pour financer '
            'l\'achat d\'un logement en propriete, amortir une hypotheque '
            'ou financer des renovations. Montant minimum : CHF 20\'000. '
            'Ce retrait a un impact direct sur tes prestations de risque.',
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

  Widget _buildSlidersSection() {
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
            'PARAMETRES',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Avoir total
          _buildSliderRow(
            label: 'Avoir LPP total',
            value: _avoirTotal,
            min: 0,
            max: 800000,
            divisions: 160,
            format: 'CHF ${formatChf(_avoirTotal)}',
            onChanged: (v) => setState(() => _avoirTotal = v),
          ),
          const SizedBox(height: 12),

          // Age
          _buildSliderRow(
            label: 'Age',
            value: _age.toDouble(),
            min: 25,
            max: 65,
            divisions: 40,
            format: '$_age ans',
            onChanged: (v) => setState(() => _age = v.round()),
          ),
          const SizedBox(height: 12),

          // Montant souhaite
          _buildSliderRow(
            label: 'Montant souhaite',
            value: _montantSouhaite,
            min: 20000,
            max: 500000,
            divisions: 96,
            format: 'CHF ${formatChf(_montantSouhaite)}',
            onChanged: (v) => setState(() => _montantSouhaite = v),
          ),
          const SizedBox(height: 12),

          // Canton (pour l'impot sur retrait)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Canton',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
              DropdownButton<String>(
                value: _canton,
                underline: const SizedBox(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
                items: sortedCantonCodes.map((code) {
                  final name = cantonFullNames[code] ?? code;
                  return DropdownMenuItem(
                    value: code,
                    child: Text('$code — $name'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _canton = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rachats recents
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Rachats LPP recents',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'As-tu effectue un rachat LPP ces 3 dernieres annees ?',
                      style: TextStyle(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _aRachete,
                activeThumbColor: MintColors.primary,
                onChanged: (v) => setState(() {
                  _aRachete = v;
                  if (!v) _anneesSDepuisRachat = 0;
                }),
              ),
            ],
          ),

          if (_aRachete) ...[
            const SizedBox(height: 12),
            _buildSliderRow(
              label: 'Annees depuis le rachat',
              value: _anneesSDepuisRachat.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              format: '$_anneesSDepuisRachat an${_anneesSDepuisRachat > 1 ? 's' : ''}',
              onChanged: (v) =>
                  setState(() => _anneesSDepuisRachat = v.round()),
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _buildResultsSection(EplResult result) {
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
            'RESULTAT',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            'Montant maximum retirable',
            'CHF ${formatChf(result.montantMaxRetirable)}',
          ),
          const Divider(height: 20),
          _buildResultRow(
            'Montant applicable',
            'CHF ${formatChf(result.montantSouhaiteApplicable)}',
            isBold: true,
            color: result.montantSouhaiteApplicable > 0
                ? MintColors.success
                : MintColors.error,
          ),
          if (result.montantSouhaiteApplicable == 0 &&
              result.alerts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Le retrait n\'est pas possible dans la configuration actuelle.',
              style: TextStyle(
                fontSize: 12,
                color: MintColors.error,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactSection(EplResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IMPACT SUR LES PRESTATIONS',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.red.shade700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildImpactRow(
            icon: Icons.accessible,
            label: 'Reduction rente invalidite (estimation annuelle)',
            amount: '-CHF ${formatChf(result.reductionRenteInvalidite)}',
          ),
          const SizedBox(height: 12),
          _buildImpactRow(
            icon: Icons.heart_broken_outlined,
            label: 'Reduction capital-deces (estimation)',
            amount: '-CHF ${formatChf(result.reductionCapitalDeces)}',
          ),
          const SizedBox(height: 12),
          Text(
            'Le retrait EPL reduit proportionnellement tes prestations '
            'de risque. Verifie aupres de ta caisse de pension les '
            'montants exacts et les possibilites d\'assurance complementaire.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.red.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactRow({
    required IconData icon,
    required String label,
    required String amount,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.red.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxCard(EplResult result) {
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
            'ESTIMATION FISCALE',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            'Montant retire',
            'CHF ${formatChf(result.montantSouhaiteApplicable)}',
          ),
          _buildResultRow(
            'Impot estime sur le retrait',
            'CHF ${formatChf(result.impotEstime)}',
            color: Colors.red.shade600,
          ),
          const Divider(height: 20),
          _buildResultRow(
            'Montant net apres impot',
            'CHF ${formatChf(result.montantSouhaiteApplicable - result.impotEstime)}',
            isBold: true,
            color: MintColors.success,
          ),
          const SizedBox(height: 8),
          Text(
            'Le retrait en capital est impose a un taux reduit '
            '(environ 1/5 du bareme ordinaire). Le taux exact depend '
            'du canton, de la commune et de la situation personnelle.',
            style: TextStyle(
              fontSize: 11,
              color: MintColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(List<String> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POINTS D\'ATTENTION',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        for (final alert in alerts)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
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
