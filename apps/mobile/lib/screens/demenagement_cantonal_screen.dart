import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Screen for simulating the financial impact of a cantonal move (Cat C — Life Event).
///
/// Layout S55: enjeu d'abord, consequence avant controle, matiere chaude.
/// Hero = delta fiscal annuel. Consequence de demenager, pas un tableau fiscal.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        // Departure canton = user's CURRENT canton
        if (cantonFullNames.containsKey(profile.canton)) {
          _cantonDepart = profile.canton;
        }
        final revenu = profile.revenuBrutAnnuel;
        if (revenu > 0) {
          _revenuBrut = revenu;
        }
        // Map etatCivil to situation familiale
        switch (profile.etatCivil) {
          case CoachCivilStatus.marie:
            _situationFamiliale = 'marie';
          case CoachCivilStatus.celibataire:
          case CoachCivilStatus.divorce:
          case CoachCivilStatus.veuf:
          case CoachCivilStatus.concubinage:
            _situationFamiliale = 'celibataire';
        }
      });
    } catch (_) {
      // Provider not in tree (tests) — keep defaults
    }
  }

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
    final economieTotal = _economieFiscaleAnnuelle + _economieLamalAnnuelle;
    final estPositif = economieTotal >= 0;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
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
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 1 — L'ENJEU : delta fiscal hero
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              MintEntrance(child: MintHeroNumber(
                value: '${estPositif ? '+\u00a0' : ''}'
                    '${formatChfWithPrefix(economieTotal)}',
                caption: s.demenagementChiffreChocSousTitre,
                color: estPositif ? MintColors.success : MintColors.error,
                semanticsLabel: s.demenagementBilanTotal,
              )),
              const SizedBox(height: MintSpacing.sm),
              MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
                s.demenagementChiffreChocDetail(_cantonDepart, _cantonArrivee),
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              )),
              const SizedBox(height: MintSpacing.xxl),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 2 — COMPARAISON : deux cantons cote a cote
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              MintEntrance(delay: const Duration(milliseconds: 200), child: _buildCantonComparison(s)),
              const SizedBox(height: MintSpacing.xl),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 3 — DETAIL par poste (MintSignalRow)
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              MintEntrance(delay: const Duration(milliseconds: 300), child: _buildDetailParPoste(s)),
              const SizedBox(height: MintSpacing.lg),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 4 — INSIGHT emotionnel
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              MintEntrance(delay: const Duration(milliseconds: 400), child: _buildInsight(s)),
              const SizedBox(height: MintSpacing.lg),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 5 — CONFIDENCE NOTICE
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              MintConfidenceNotice(
                percent: 40,
                message: s.demenagementDisclaimer,
              ),
              const SizedBox(height: MintSpacing.xl),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 6 — CONTROLES : sous le resultat
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              _buildInputs(s),
              const SizedBox(height: MintSpacing.xl),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 7 — CHECKLIST demenagement
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              _buildChecklist(s),
              const SizedBox(height: MintSpacing.lg),

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // SECTION 8 — DISCLAIMER (micro)
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              Text(
                s.demenagementDisclaimer,
                style: MintTextStyles.micro(),
              ),
            ],
          ),
        ),
      ))),
    );
  }

  double get _economieFiscaleAnnuelle {
    final idxDepart = _indiceFiscal[_cantonDepart] ?? 75;
    final idxArrivee = _indiceFiscal[_cantonArrivee] ?? 75;
    // Simplified: proportional to income and index difference
    final tauxMoyenDepart = idxDepart / 100 * 0.22; // ~22% charge GE — TODO: use tax_calculator.dart for cantonal rates
    final tauxMoyenArrivee = idxArrivee / 100 * 0.22; // TODO: use financial_core/tax_calculator.dart
    return _revenuBrut * (tauxMoyenDepart - tauxMoyenArrivee);
  }

  double get _economieLamalAnnuelle {
    final lamalDepart = _lamalMensuelle[_cantonDepart] ?? 370;
    final lamalArrivee = _lamalMensuelle[_cantonArrivee] ?? 370;
    final nbPersonnes = 1 + (_situationFamiliale == 'marie' ? 1 : 0);
    return (lamalDepart - lamalArrivee) * 12 * nbPersonnes.toDouble();
  }

  /// Two MintSurface cards side by side: sauge for the winning canton, peche for the losing one.
  Widget _buildCantonComparison(S s) {
    final econFiscale = _economieFiscaleAnnuelle;
    final econLamal = _economieLamalAnnuelle;
    final economieTotal = econFiscale + econLamal;

    // Determine which canton "wins"
    final departGagne = economieTotal < 0;
    final idxDepart = _indiceFiscal[_cantonDepart] ?? 75;
    final idxArrivee = _indiceFiscal[_cantonArrivee] ?? 75;
    final lamalDepart = _lamalMensuelle[_cantonDepart] ?? 370;
    final lamalArrivee = _lamalMensuelle[_cantonArrivee] ?? 370;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Canton depart
        Expanded(
          child: MintSurface(
            tone: departGagne
                ? MintSurfaceTone.sauge
                : MintSurfaceTone.peche,
            padding: const EdgeInsets.all(MintSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cantonDepart,
                  style: MintTextStyles.headlineMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  s.demenagementCantonDepart,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                Text(
                  s.demenagementFiscalTitre,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
                Text(
                  '$idxDepart',
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  s.demenagementLamalTitre,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
                Text(
                  'CHF\u00a0$lamalDepart/mois',
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: MintSpacing.sm),
        // Canton arrivee
        Expanded(
          child: MintSurface(
            tone: departGagne
                ? MintSurfaceTone.peche
                : MintSurfaceTone.sauge,
            padding: const EdgeInsets.all(MintSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cantonArrivee,
                  style: MintTextStyles.headlineMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  s.demenagementCantonArrivee,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                Text(
                  s.demenagementFiscalTitre,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
                Text(
                  '$idxArrivee',
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  s.demenagementLamalTitre,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMuted,
                  ),
                ),
                Text(
                  'CHF\u00a0$lamalArrivee/mois',
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Detail breakdown with MintSignalRow for each financial post.
  Widget _buildDetailParPoste(S s) {
    final econFiscale = _economieFiscaleAnnuelle;
    final econLamal = _economieLamalAnnuelle;
    final economieTotal = econFiscale + econLamal;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.demenagementSituation,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          MintSignalRow(
            label: s.demenagementEconomieFiscale,
            value: '${econFiscale >= 0 ? '+' : ''}${formatChfWithPrefix(econFiscale)}/an',
            valueColor:
                econFiscale >= 0 ? MintColors.success : MintColors.error,
          ),
          MintSignalRow(
            label: s.demenagementLamalTitre,
            value: '${econLamal >= 0 ? '+' : ''}${formatChfWithPrefix(econLamal)}/an',
            valueColor:
                econLamal >= 0 ? MintColors.success : MintColors.error,
          ),
          Divider(
            color: MintColors.border.withValues(alpha: 0.3),
            height: 1,
          ),
          MintSignalRow(
            label: s.demenagementBilanTotal,
            value: '${economieTotal >= 0 ? '+' : ''}${formatChfWithPrefix(economieTotal)}/an',
            valueColor:
                economieTotal >= 0 ? MintColors.success : MintColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildInsight(S s) {
    final economieTotal = _economieFiscaleAnnuelle + _economieLamalAnnuelle;
    final estPositif = economieTotal >= 0;
    const loyerMoyen = 1500.0;
    final moisCouverts = economieTotal.abs() / loyerMoyen;

    return MintSurface(
      tone: estPositif ? MintSurfaceTone.sauge : MintSurfaceTone.peche,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            estPositif ? Icons.check_circle_outline : Icons.info_outline,
            color: estPositif ? MintColors.success : MintColors.corailDiscret,
            size: 20,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              estPositif
                  ? s.demenagementInsightPositif(
                      moisCouverts.toStringAsFixed(0))
                  : s.demenagementInsightNegatif,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputs(S s) {
    return MintSurface(
      tone: MintSurfaceTone.craie,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.demenagementSituation,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
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
                        style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary)),
                    const SizedBox(height: MintSpacing.xs),
                    Semantics(
                      label: s.demenagementCantonDepart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: MintColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _cantonDepart,
                            items: sortedCantonCodes
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        style: MintTextStyles.bodySmall(
                                            color: MintColors.textPrimary))))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _cantonDepart = v ?? _cantonDepart),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                child:
                    Icon(Icons.arrow_forward, color: MintColors.textMuted),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.demenagementCantonArrivee,
                        style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary)),
                    const SizedBox(height: MintSpacing.xs),
                    Semantics(
                      label: s.demenagementCantonArrivee,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: MintColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _cantonArrivee,
                            items: sortedCantonCodes
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        style: MintTextStyles.bodySmall(
                                            color: MintColors.textPrimary))))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _cantonArrivee = v ?? _cantonArrivee),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          // Revenu brut
          MintPremiumSlider(
            label: s.demenagementRevenu,
            value: _revenuBrut,
            min: 30000,
            max: 500000,
            divisions: 94,
            formatValue: (_) => formatChfWithPrefix(_revenuBrut),
            onChanged: (v) => setState(() => _revenuBrut = v),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Situation familiale
          Semantics(
            label: s.demenagementCelibataire,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'celibataire',
                    label: Text(s.demenagementCelibataire)),
                ButtonSegment(
                    value: 'marie', label: Text(s.demenagementMarie)),
              ],
              selected: {_situationFamiliale},
              onSelectionChanged: (v) =>
                  setState(() => _situationFamiliale = v.first),
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
        const SizedBox(height: MintSpacing.sm),
        ...items.map(
          (item) => Semantics(
            label: item,
            child: MintSurface(
              tone: MintSurfaceTone.blanc,
              padding: const EdgeInsets.all(MintSpacing.md),
              radius: 12,
              child: Row(
                children: [
                  const Icon(Icons.check_box_outline_blank,
                      color: MintColors.textMuted, size: 20),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(item,
                        style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
