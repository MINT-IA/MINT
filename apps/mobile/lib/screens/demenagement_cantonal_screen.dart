import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Screen for simulating the financial impact of a cantonal move (Cat C — Life Event).
///
/// Covers tax comparison (income + capital withdrawal + wealth),
/// LAMal premium differences, and administrative checklist.
/// Life Event: cantonMove.
class DemenagementCantonalScreen extends StatefulWidget {
  const DemenagementCantonalScreen({super.key});

  @override
  State<DemenagementCantonalScreen> createState() =>
      _DemenagementCantonalScreenState();
}

class _DemenagementCantonalScreenState
    extends State<DemenagementCantonalScreen> {
  // ── Input state ──
  String _cantonDepart = 'GE';
  String _cantonArrivee = 'VS';
  double _revenuBrut = 120000;
  String _situationFamiliale = 'marie';

  // Simplified cantonal tax burden index (relative, GE=100)
  static const _indiceFiscal = {
    'AG': 72, 'AI': 58, 'AR': 65, 'BE': 82, 'BL': 78, 'BS': 85,
    'FR': 70, 'GE': 100, 'GL': 62, 'GR': 68, 'JU': 88, 'LU': 60,
    'NE': 92, 'NW': 48, 'OW': 50, 'SG': 72, 'SH': 70, 'SO': 78,
    'SZ': 45, 'TG': 68, 'TI': 80, 'UR': 55, 'VD': 95, 'VS': 75,
    'ZG': 40, 'ZH': 72,
  };

  // Simplified LAMal monthly premium by canton (adult, franchise 300)
  static const _lamalMensuelle = {
    'AG': 370, 'AI': 290, 'AR': 320, 'BE': 400, 'BL': 410, 'BS': 440,
    'FR': 360, 'GE': 480, 'GL': 310, 'GR': 320, 'JU': 380, 'LU': 350,
    'NE': 420, 'NW': 300, 'OW': 290, 'SG': 340, 'SH': 350, 'SO': 370,
    'SZ': 310, 'TG': 330, 'TI': 400, 'UR': 290, 'VD': 450, 'VS': 370,
    'ZG': 310, 'ZH': 390,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.surface,
      // ── White standard AppBar (Design System §4.5) ──
      appBar: AppBar(
        title: Text(
          s.demenagementTitreV2,
          style: MintTextStyles.headlineMedium(),
        ),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.md + MintSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero: chiffre choc — economie/surcout annuel ──
              _buildChiffreChoc(s),
              const SizedBox(height: MintSpacing.lg),

              // ── Inputs ──
              _buildInputs(s),
              const SizedBox(height: MintSpacing.lg),

              // ── Comparaison fiscale ──
              _buildComparaisonFiscale(s),
              const SizedBox(height: MintSpacing.lg),

              // ── LAMal comparaison ──
              _buildLamalComparaison(s),
              const SizedBox(height: MintSpacing.lg),

              // ── Emotional insight ──
              _buildInsight(s),
              const SizedBox(height: MintSpacing.lg),

              // ── Checklist demenagement ──
              _buildChecklist(s),
              const SizedBox(height: MintSpacing.lg),

              // ── Disclaimer ──
              _buildDisclaimer(s),
            ],
          ),
        ),
      ),
    );
  }

  double get _economieFiscaleAnnuelle {
    final idxDepart = _indiceFiscal[_cantonDepart] ?? 75;
    final idxArrivee = _indiceFiscal[_cantonArrivee] ?? 75;
    // Simplified: proportional to income and index difference
    final tauxMoyenDepart = idxDepart / 100 * 0.22; // ~22% charge GE
    final tauxMoyenArrivee = idxArrivee / 100 * 0.22;
    return _revenuBrut * (tauxMoyenDepart - tauxMoyenArrivee);
  }

  double get _economieLamalAnnuelle {
    final lamalDepart = _lamalMensuelle[_cantonDepart] ?? 370;
    final lamalArrivee = _lamalMensuelle[_cantonArrivee] ?? 370;
    final nbPersonnes = 1 + (_situationFamiliale == 'marie' ? 1 : 0);
    return (lamalDepart - lamalArrivee) * 12 * nbPersonnes.toDouble();
  }

  Widget _buildChiffreChoc(S s) {
    final economieTotal = _economieFiscaleAnnuelle + _economieLamalAnnuelle;
    final estPositif = economieTotal >= 0;
    final color = estPositif ? MintColors.success : MintColors.error;

    return Semantics(
      label: s.demenagementBilanTotal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            // displayMedium for Life Event (Cat C)
            Text(
              '${estPositif ? '+' : ''}${formatChfWithPrefix(economieTotal)}',
              style: MintTextStyles.displayMedium(color: color),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              s.demenagementChiffreChocSousTitre,
              style: MintTextStyles.bodyMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              s.demenagementChiffreChocDetail(
                  _cantonDepart, _cantonArrivee),
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputs(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.demenagementSituation,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: MintSpacing.md),

        // Canton depart / arrivee
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.demenagementCantonDepart,
                      style: MintTextStyles.bodySmall()),
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    label: s.demenagementCantonDepart,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _cantonDepart,
                      items: sortedCantonCodes
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _cantonDepart = v ?? _cantonDepart),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: MintSpacing.sm + MintSpacing.xs),
              child: Icon(Icons.arrow_forward, color: MintColors.textMuted),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.demenagementCantonArrivee,
                      style: MintTextStyles.bodySmall()),
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    label: s.demenagementCantonArrivee,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _cantonArrivee,
                      items: sortedCantonCodes
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _cantonArrivee = v ?? _cantonArrivee),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.md),

        // Revenu brut
        Text(s.demenagementRevenu,
            style: MintTextStyles.bodyMedium()),
        Slider(
          value: _revenuBrut,
          min: 30000,
          max: 500000,
          divisions: 94,
          label: formatChfWithPrefix(_revenuBrut),
          activeColor: MintColors.primary,
          onChanged: (v) => setState(() => _revenuBrut = v),
        ),
        Text(formatChfWithPrefix(_revenuBrut),
            style: MintTextStyles.titleMedium()),
        const SizedBox(height: MintSpacing.md),

        // Situation familiale
        Semantics(
          label: s.demenagementCelibataire,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'celibataire', label: Text(s.demenagementCelibataire)),
              ButtonSegment(
                  value: 'marie', label: Text(s.demenagementMarie)),
            ],
            selected: {_situationFamiliale},
            onSelectionChanged: (v) =>
                setState(() => _situationFamiliale = v.first),
          ),
        ),
      ],
    );
  }

  Widget _buildComparaisonFiscale(S s) {
    final idxDepart = _indiceFiscal[_cantonDepart] ?? 75;
    final idxArrivee = _indiceFiscal[_cantonArrivee] ?? 75;
    final econFiscale = _economieFiscaleAnnuelle;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.demenagementFiscalTitre,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.md),
          _comparisonBar(
              _cantonDepart, idxDepart.toDouble(), MintColors.error),
          const SizedBox(height: MintSpacing.sm),
          _comparisonBar(
              _cantonArrivee, idxArrivee.toDouble(), MintColors.success),
          const SizedBox(height: MintSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.demenagementEconomieFiscale,
                  style: MintTextStyles.bodyMedium()),
              Text(
                '${econFiscale >= 0 ? '+' : ''}${formatChfWithPrefix(econFiscale)}/an',
                style: MintTextStyles.titleMedium(
                  color: econFiscale >= 0
                      ? MintColors.success
                      : MintColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparisonBar(String canton, double index, Color color) {
    return Semantics(
      label: '$canton: ${index.round()}',
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(canton,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: index / 100,
                backgroundColor: MintColors.border,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Text('${index.round()}',
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildLamalComparaison(S s) {
    final econLamal = _economieLamalAnnuelle;
    final lamalDepart = _lamalMensuelle[_cantonDepart] ?? 370;
    final lamalArrivee = _lamalMensuelle[_cantonArrivee] ?? 370;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.demenagementLamalTitre,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_cantonDepart\u00A0: CHF\u00A0$lamalDepart/mois',
                  style: MintTextStyles.bodyMedium()),
              Text('$_cantonArrivee\u00A0: CHF\u00A0$lamalArrivee/mois',
                  style: MintTextStyles.bodyMedium()),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
          Text(
            '${econLamal >= 0 ? '+' : ''}${formatChfWithPrefix(econLamal)}/an',
            style: MintTextStyles.headlineMedium(
              color: econLamal >= 0 ? MintColors.success : MintColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsight(S s) {
    final economieTotal = _economieFiscaleAnnuelle + _economieLamalAnnuelle;
    final estPositif = economieTotal >= 0;
    // Average monthly rent in Switzerland ~ CHF 1'500
    const loyerMoyen = 1500.0;
    final moisCouverts = economieTotal.abs() / loyerMoyen;

    final color = estPositif ? MintColors.success : MintColors.warning;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            estPositif ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: MintSpacing.sm + MintSpacing.xs),
          Expanded(
            child: Text(
              estPositif
                  ? s.demenagementInsightPositif(moisCouverts.toStringAsFixed(0))
                  : s.demenagementInsightNegatif,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist(S s) {
    final items = [
      s.demenagementChecklist1,
      s.demenagementChecklist2,
      s.demenagementChecklist3,
      s.demenagementChecklist4,
      s.demenagementChecklist5,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.demenagementChecklistTitre,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
        ...items.map(
          (item) => Semantics(
            label: item,
            child: Container(
              margin: const EdgeInsets.only(bottom: MintSpacing.sm),
              padding: const EdgeInsets.all(MintSpacing.sm + MintSpacing.xs),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MintColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outline_blank,
                      color: MintColors.textMuted, size: 20),
                  const SizedBox(width: MintSpacing.sm + MintSpacing.xs),
                  Expanded(
                    child: Text(item,
                        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.sm + MintSpacing.xs),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Text(
        s.demenagementDisclaimer,
        style: MintTextStyles.micro(),
      ),
    );
  }
}
