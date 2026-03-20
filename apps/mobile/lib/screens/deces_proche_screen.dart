import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Screen for navigating the financial impact of a relative's death in Switzerland.
///
/// Covers succession timeline, urgent actions, fiscal obligations,
/// 2nd/3rd pillar beneficiaries, and marital regime impact.
/// Life Event: deathOfRelative.
class DecesProcheScreen extends StatefulWidget {
  const DecesProcheScreen({super.key});

  @override
  State<DecesProcheScreen> createState() => _DecesProcheScreenState();
}

class _DecesProcheScreenState extends State<DecesProcheScreen> {
  // ── Input state ──
  String _lienParente = 'conjoint';
  String _canton = 'VD';
  double _fortuneDefunt = 500000;
  final double _lppDefunt = 200000;
  final double _pilier3aDefunt = 50000;
  bool _testamentExiste = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(s.decesProcheTitre, style: MintTextStyles.headlineMedium()),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero: chiffre choc ──
              _buildChiffreChoc(s),
              const SizedBox(height: 24),

              // ── Urgences 48h ──
              _buildUrgences48h(s),
              const SizedBox(height: 24),

              // ── Inputs ──
              _buildInputs(s),
              const SizedBox(height: 24),

              // ── Timeline succession ──
              _buildTimeline(s),
              const SizedBox(height: 24),

              // ── Beneficiaires LPP / 3a ──
              _buildBeneficiaires(s),
              const SizedBox(height: 24),

              // ── Impact fiscal ──
              _buildImpactFiscal(s),
              const SizedBox(height: 24),

              // ── Actions concrètes ──
              _buildActions(s),
              const SizedBox(height: 24),

              // ── Disclaimer ──
              _buildDisclaimer(s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChiffreChoc(S s) {
    const delaiRepudiation = 3; // mois — CC art. 567
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MintColors.primary, MintColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$delaiRepudiation',
            style: MintTextStyles.displayLarge(color: MintColors.white),
          ),
          Text(
            s.decesProcheMoisRepudiation,
            style: MintTextStyles.bodyLarge(color: MintColors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUrgences48h(S s) {
    final urgences = [
      s.decesProche48hActe,
      s.decesProche48hBanque,
      s.decesProche48hAssurance,
      s.decesProche48hEmployeur,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.urgentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.decesProche48hTitre,
            style: MintTextStyles.titleMedium(color: MintColors.error).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...urgences.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: MintColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${e.key + 1}',
                          style: MintTextStyles.labelSmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value,
                          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
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
          s.decesProcheSituation,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 18),
        ),
        const SizedBox(height: MintSpacing.md),

        // Lien de parenté
        Text(s.decesProcheLienParente,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'conjoint', label: Text(s.decesProcheLienConjoint)),
            ButtonSegment(value: 'parent', label: Text(s.decesProcheLienParent)),
            ButtonSegment(value: 'enfant', label: Text(s.decesProcheLienEnfant)),
          ],
          selected: {_lienParente},
          onSelectionChanged: (v) => setState(() => _lienParente = v.first),
        ),
        const SizedBox(height: 16),

        // Fortune du défunt
        Text(s.decesProcheFortune,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)),
        Slider(
          value: _fortuneDefunt,
          min: 0,
          max: 5000000,
          divisions: 100,
          label: formatChfWithPrefix(_fortuneDefunt),

          onChanged: (v) => setState(() => _fortuneDefunt = v),
        ),
        Text(formatChfWithPrefix(_fortuneDefunt),
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        // Canton
        Row(
          children: [
            Text(s.decesProcheCanton,
                style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _canton,
              items: ['VD', 'GE', 'VS', 'BE', 'ZH', 'BS', 'LU', 'TI', 'SG', 'AG']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _canton = v ?? _canton),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Testament
        SwitchListTile(
          title: Text(s.decesProchTestament,
              style: MintTextStyles.bodyMedium()),
          value: _testamentExiste,

          onChanged: (v) => setState(() => _testamentExiste = v),
        ),
      ],
    );
  }

  Widget _buildTimeline(S s) {
    final etapes = [
      (s.decesProchTimeline1Titre, s.decesProchTimeline1Desc, '0-3\u00A0j'),
      (s.decesProchTimeline2Titre, s.decesProchTimeline2Desc, '1-4\u00A0sem'),
      (s.decesProchTimeline3Titre, s.decesProchTimeline3Desc, '1-3\u00A0mois'),
      (s.decesProchTimeline4Titre, s.decesProchTimeline4Desc, '3-12\u00A0mois'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.decesProchTimelineTitre,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 18),
        ),
        const SizedBox(height: MintSpacing.md),
        ...etapes.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(e.$3,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.$1,
                          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(e.$2,
                          style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeneficiaires(S s) {
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
            s.decesProchebeneficiairesTitre,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _infoRow(s.decesProchebeneficiairesLpp,
              formatChfWithPrefix(_lppDefunt)),
          const SizedBox(height: 8),
          _infoRow(s.decesProchebeneficiaires3a,
              formatChfWithPrefix(_pilier3aDefunt)),
          const SizedBox(height: 12),
          Text(
            s.decesProchebeneficiairesNote,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary)),
        Text(value,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildImpactFiscal(S s) {
    // Simplified succession tax estimate — most cantons exempt conjoint
    final estExempt = _lienParente == 'conjoint';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: estExempt ? MintColors.successBg : MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.decesProchImpactFiscalTitre,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            estExempt
                ? s.decesProchImpactFiscalExempt(_canton)
                : s.decesProchImpactFiscalTaxe(_canton),
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(S s) {
    final actions = [
      s.decesProchAction1,
      s.decesProchAction2,
      s.decesProchAction3,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.decesProchActionsTitre,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        ...actions.map(
          (a) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: MintColors.success, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(a,
                      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)),
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
        s.decesProchDisclaimer,
        style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}
