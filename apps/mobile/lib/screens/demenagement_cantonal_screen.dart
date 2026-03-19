import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Screen for simulating the financial impact of a cantonal move in Switzerland.
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
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(s.demenagementTitre),
        backgroundColor: MintColors.primary,
        foregroundColor: MintColors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero: chiffre choc — économie/surcoût annuel ──
              _buildChiffreChoc(s),
              const SizedBox(height: 24),

              // ── Inputs ──
              _buildInputs(s),
              const SizedBox(height: 24),

              // ── Comparaison fiscale ──
              _buildComparaisonFiscale(s),
              const SizedBox(height: 24),

              // ── LAMal comparaison ──
              _buildLamalComparaison(s),
              const SizedBox(height: 24),

              // ── Checklist déménagement ──
              _buildChecklist(s),
              const SizedBox(height: 24),

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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: estPositif
              ? [MintColors.primary, MintColors.primaryLight]
              : [MintColors.error, MintColors.crisisRed],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '${estPositif ? '+' : ''}${formatChfWithPrefix(economieTotal)}',
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.demenagementChiffreChocSousTitre,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.demenagementChiffreChocDetail(
                _cantonDepart, _cantonArrivee),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInputs(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.demenagementSituation,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Canton départ / arrivée
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.demenagementCantonDepart,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: MintColors.textSecondary)),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _cantonDepart,
                    items: sortedCantonCodes
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _cantonDepart = v ?? _cantonDepart),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_forward, color: MintColors.textMuted),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.demenagementCantonArrivee,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: MintColors.textSecondary)),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _cantonArrivee,
                    items: sortedCantonCodes
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _cantonArrivee = v ?? _cantonArrivee),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Revenu brut
        Text(s.demenagementRevenu,
            style: GoogleFonts.inter(
                fontSize: 14, color: MintColors.textSecondary)),
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
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary)),
        const SizedBox(height: 16),

        // Situation familiale
        SegmentedButton<String>(
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
      ],
    );
  }

  Widget _buildComparaisonFiscale(S s) {
    final idxDepart = _indiceFiscal[_cantonDepart] ?? 75;
    final idxArrivee = _indiceFiscal[_cantonArrivee] ?? 75;
    final econFiscale = _economieFiscaleAnnuelle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.demenagementFiscalTitre,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _comparisonBar(
              _cantonDepart, idxDepart.toDouble(), MintColors.error),
          const SizedBox(height: 8),
          _comparisonBar(
              _cantonArrivee, idxArrivee.toDouble(), MintColors.success),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.demenagementEconomieFiscale,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: MintColors.textSecondary)),
              Text(
                '${econFiscale >= 0 ? '+' : ''}${formatChfWithPrefix(econFiscale)}/an',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(canton,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary)),
        ),
        const SizedBox(width: 8),
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
        const SizedBox(width: 8),
        Text('${index.round()}',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary)),
      ],
    );
  }

  Widget _buildLamalComparaison(S s) {
    final econLamal = _economieLamalAnnuelle;
    final lamalDepart = _lamalMensuelle[_cantonDepart] ?? 370;
    final lamalArrivee = _lamalMensuelle[_cantonArrivee] ?? 370;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.demenagementLamalTitre,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_cantonDepart\u00A0: CHF\u00A0$lamalDepart/mois',
                  style: GoogleFonts.inter(fontSize: 14)),
              Text('$_cantonArrivee\u00A0: CHF\u00A0$lamalArrivee/mois',
                  style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${econLamal >= 0 ? '+' : ''}${formatChfWithPrefix(econLamal)}/an',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color:
                  econLamal >= 0 ? MintColors.success : MintColors.error,
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
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.check_box_outline_blank,
                    color: MintColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: MintColors.textPrimary)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer(S s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.disclaimerBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        s.demenagementDisclaimer,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: MintColors.textMuted,
        ),
      ),
    );
  }
}
