import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/pillar_3a_deep_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/constants/social_insurance.dart';

/// Ecran comparateur de providers 3a (fintech / banque / assurance).
///
/// Compare les rendements, frais et capital final estimé de 5 providers.
/// Alerte rouge si assurance choisie avant 35 ans.
class ProviderComparatorScreen extends StatefulWidget {
  const ProviderComparatorScreen({super.key});

  @override
  State<ProviderComparatorScreen> createState() =>
      _ProviderComparatorScreenState();
}

class _ProviderComparatorScreenState extends State<ProviderComparatorScreen> {
  int _age = 30;
  double _versementAnnuel = 7258;
  int _duree = 35;
  ProfilRisque _profilRisque = ProfilRisque.dynamique;

  ProviderComparisonResult get _result => ProviderComparator.compare(
        age: _age,
        versementAnnuel: _versementAnnuel,
        duree: _duree,
        profilRisque: _profilRisque,
      );

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
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MintColors.primary,
                      MintColors.primary.withAlpha(220),
                    ],
                  ),
                ),
              ),
              title: Text(
                'COMPARATEUR 3A',
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
                // Chiffre choc
                _buildChiffreChoc(result),
                const SizedBox(height: 24),

                // Inputs
                _buildInputsSection(),
                const SizedBox(height: 24),

                // Provider cards
                _buildProviderCards(result),
                const SizedBox(height: 24),

                // Warning assurance
                ..._buildAssuranceWarnings(result),

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

  Widget _buildChiffreChoc(ProviderComparisonResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Difference sur $_duree ans',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'CHF ${formatChf(result.differenceMax)}',
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'entre le provider le plus et le moins performant',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsSection() {
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

          // Age
          _buildSliderRow(
            label: 'Age',
            value: _age.toDouble(),
            min: 18,
            max: 60,
            divisions: 42,
            format: '$_age ans',
            onChanged: (v) => setState(() {
              _age = v.round();
              _duree = (65 - _age).clamp(5, 45);
            }),
          ),
          const SizedBox(height: 12),

          // Versement
          _buildSliderRow(
            label: 'Versement annuel',
            value: _versementAnnuel,
            min: 1000,
            max: pilier3aPlafondAvecLpp,
            divisions: 62,
            format: 'CHF ${formatChf(_versementAnnuel)}',
            onChanged: (v) => setState(() => _versementAnnuel = v),
          ),
          const SizedBox(height: 12),

          // Duree
          _buildSliderRow(
            label: 'Duree',
            value: _duree.toDouble(),
            min: 5,
            max: 45,
            divisions: 40,
            format: '$_duree ans',
            onChanged: (v) => setState(() => _duree = v.round()),
          ),
          const SizedBox(height: 16),

          // Profil de risque
          _buildProfilRisque(),
        ],
      ),
    );
  }

  Widget _buildProfilRisque() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profil de risque',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: ProfilRisque.values.map((profil) {
            final isSelected = _profilRisque == profil;
            final label = switch (profil) {
              ProfilRisque.prudent => 'Prudent',
              ProfilRisque.equilibre => 'Equilibre',
              ProfilRisque.dynamique => 'Dynamique',
            };
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _profilRisque = profil),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MintColors.primary
                        : MintColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? MintColors.primary
                          : MintColors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : MintColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
          activeColor: MintColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildProviderCards(ProviderComparisonResult result) {
    // Trier par capital final descendant
    final sorted = List<ProviderResult>.from(result.providers)
      ..sort((a, b) => b.capitalFinal.compareTo(a.capitalFinal));

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
        for (final provider in sorted) ...[
          _buildProviderCard(provider, sorted.first.capitalFinal),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildProviderCard(ProviderResult result, double maxCapital) {
    final isWarning = result.hasWarning;
    final isBest = result.badge != null &&
        result.badge!.contains('Meilleur rendement');

    Color bgColor = Colors.white;
    Color borderColor = MintColors.border;
    double borderWidth = 1;

    if (isBest) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      borderWidth = 2;
    } else if (isWarning) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      borderWidth = 2;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.provider.nom,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      result.provider.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.badge != null && !isWarning)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.badge!.length > 20
                        ? result.badge!.substring(0, 20)
                        : result.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (isWarning)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'WARNING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rendement',
                      style:
                          TextStyle(fontSize: 10, color: MintColors.textMuted)),
                  Text(
                    '${(result.rendementNet * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frais',
                      style:
                          TextStyle(fontSize: 10, color: MintColors.textMuted)),
                  Text(
                    '${(result.provider.fraisGestion * 100).toStringAsFixed(2)}%',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Capital final',
                      style:
                          TextStyle(fontSize: 10, color: MintColors.textMuted)),
                  Text(
                    'CHF ${formatChf(result.capitalFinal)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isBest
                          ? Colors.green.shade700
                          : isWarning
                              ? Colors.red.shade700
                              : MintColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Difference vs meilleur
          if (result.capitalFinal < maxCapital) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '-CHF ${formatChf(maxCapital - result.capitalFinal)} vs meilleur',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAssuranceWarnings(ProviderComparisonResult result) {
    final warnings = result.providers
        .where((p) => p.hasWarning && p.warningMessage != null)
        .toList();

    if (warnings.isEmpty) return [const SizedBox.shrink()];

    return [
      for (final w in warnings) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade50, Colors.red.shade100],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ATTENTION — Assurance 3a',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                w.warningMessage!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Les assurances 3a combinent epargne et couverture risque, '
                'mais les frais eleves (souvent > 1.5%) et la rigidite du '
                'contrat les rendent defavorables pour les jeunes epargnants.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    ];
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
