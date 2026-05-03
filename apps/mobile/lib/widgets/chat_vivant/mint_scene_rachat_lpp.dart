// ────────────────────────────────────────────────────────────────────
//  MintSceneRachatLPP — Handoff 2 Niveau 2 second scene
// ────────────────────────────────────────────────────────────────────
//
//  « Et si tu rachetais 60'000 sur 4 ans ? » L'économie fiscale +
//  l'effet retraite. Plus minimal que la scène rente/capital :
//  1 slider (montant rachat), 2 chiffres signature.
//
//  Source: Downloads/handoff 2/03-components.md §5 +
//  prototype/chat-vivant/scene-rachat-lpp.jsx
//  SPEC: .planning/specs/SPEC-handoff2-niveau2-scenes.md
//
//  Computation (canton Genève, revenu 130k, marginal ~35%):
//    rachatAnnuel    = montant / anneesEchelon
//    economieParAn   = rachatAnnuel × tauxMarginal
//    economieTotale  = economieParAn × anneesEchelon
//    coutReelNet     = montant - economieTotale
//    renteAddAnnuel  = montant × tauxConversion (4.8%)
//    renteAddMensuel = renteAddAnnuel / 12
//
//  Slider: montant 20'000..150'000 CHF, step 5'000.
// ────────────────────────────────────────────────────────────────────

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/chat_vivant/mint_scene_rente_capital.dart'
    show MintSceneVariant;

/// Reference computation seed for MintSceneRachatLPP.
class RachatLppSeed {
  final double tauxMarginal;
  final int anneesEchelon;
  final double tauxConversion;

  const RachatLppSeed({
    this.tauxMarginal = 0.35,
    this.anneesEchelon = 4,
    this.tauxConversion = 0.048,
  });

  double rachatAnnuel(double montant) => montant / anneesEchelon;
  double economieParAn(double montant) => rachatAnnuel(montant) * tauxMarginal;
  double economieTotale(double montant) => economieParAn(montant) * anneesEchelon;
  double coutReelNet(double montant) => montant - economieTotale(montant);
  double renteAddAnnuelle(double montant) => montant * tauxConversion;
  double renteAddMensuelle(double montant) => renteAddAnnuelle(montant) / 12;
}

/// MintSceneRachatLPP — Niveau 2 rachat échelonné scene.
class MintSceneRachatLPP extends StatefulWidget {
  final RachatLppSeed seed;
  final MintSceneVariant variant;
  final VoidCallback? onOpenCanvas;
  final double initialMontant;
  final double minMontant;
  final double maxMontant;
  final double stepMontant;

  const MintSceneRachatLPP({
    super.key,
    this.seed = const RachatLppSeed(),
    this.variant = MintSceneVariant.inline,
    this.onOpenCanvas,
    this.initialMontant = 60000,
    this.minMontant = 20000,
    this.maxMontant = 150000,
    this.stepMontant = 5000,
  });

  @override
  State<MintSceneRachatLPP> createState() => _MintSceneRachatLPPState();
}

class _MintSceneRachatLPPState extends State<MintSceneRachatLPP> {
  late double _montant;

  @override
  void initState() {
    super.initState();
    _montant = widget.initialMontant.clamp(
      widget.minMontant,
      widget.maxMontant,
    );
  }

  String _fmtChf(num value) {
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final separated = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}’',
    );
    return value < 0 ? '-$separated' : separated;
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.seed;
    final economieTotale = seed.economieTotale(_montant);
    final economieParAn = seed.economieParAn(_montant);
    final coutReelNet = seed.coutReelNet(_montant);
    final renteAddMensuelle = seed.renteAddMensuelle(_montant);
    final isInline = widget.variant == MintSceneVariant.inline;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.porcelaine,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header eyebrow
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'SCÈNE',
                style: MintTextStyles.labelMedium(
                  color: MintColors.corailDiscret,
                ).copyWith(
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'rachat échelonné sur ${seed.anneesEchelon} ans',
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMutedAaa,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Phrase-signature with em accents
          Text.rich(
            TextSpan(
              style: MintTextStyles.editorialLarge(
                color: MintColors.textPrimary,
              ).copyWith(height: 1.25),
              children: [
                const TextSpan(text: 'Si tu rachètes '),
                TextSpan(
                  text: '${_fmtChf(_montant)} CHF',
                  style: const TextStyle(
                    color: MintColors.corailDiscret,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(text: ', tu '),
                TextSpan(
                  text:
                      'récupères ${_fmtChf(economieTotale)} CHF en impôts',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Two side-by-side cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RachatCard(
                  label: 'Économie fiscale',
                  amount: '${_fmtChf(economieTotale)} CHF',
                  amountColor: MintColors.successAaa,
                  sub:
                      '~${_fmtChf(economieParAn)}/an × ${seed.anneesEchelon}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RachatCard(
                  label: 'Rente en plus',
                  amount: '+${_fmtChf(renteAddMensuelle)} CHF/mois',
                  amountColor: MintColors.retirementLpp,
                  sub: 'à vie dès 65 ans',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Slider — montant rachat
          _RachatSlider(
            montant: _montant,
            min: widget.minMontant,
            max: widget.maxMontant,
            step: widget.stepMontant,
            onChanged: (v) => setState(() => _montant = v),
            fmtChf: _fmtChf,
          ),
          const SizedBox(height: 14),
          // Phrase de recul
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.craie,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text.rich(
              TextSpan(
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondaryAaa,
                ).copyWith(height: 1.5, fontWeight: FontWeight.w400),
                children: [
                  const TextSpan(text: 'Coût réel net : '),
                  TextSpan(
                    text: '${_fmtChf(coutReelNet)} CHF',
                    style: const TextStyle(
                      color: MintColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                      text:
                          '. Le reste, c\'est l\'État qui finance.'),
                ],
              ),
            ),
          ),
          // CTA inline
          if (isInline) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onOpenCanvas,
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Voir le plan année par année',
                        style:
                            MintTextStyles.titleMedium(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Internal — single chiffre card (Économie fiscale / Rente en plus).
class _RachatCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color amountColor;
  final String sub;

  const _RachatCard({
    required this.label,
    required this.amount,
    required this.amountColor,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMutedAaa,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: MintTextStyles.displaySmall(color: amountColor).copyWith(
              fontSize: 18,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMutedAaa,
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal — montant slider (corailDiscret accent).
class _RachatSlider extends StatelessWidget {
  final double montant;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String Function(num) fmtChf;

  const _RachatSlider({
    required this.montant,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.fmtChf,
  });

  @override
  Widget build(BuildContext context) {
    final divisions = ((max - min) / step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fmtChf(min),
                style: MintTextStyles.labelSmall(
                  color: MintColors.textMutedAaa,
                ),
              ),
              Text(
                'Montant du rachat',
                style: MintTextStyles.labelSmall(
                  color: MintColors.textSecondaryAaa,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                fmtChf(max),
                style: MintTextStyles.labelSmall(
                  color: MintColors.textMutedAaa,
                ),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: MintColors.corailDiscret,
            inactiveTrackColor: MintColors.lightBorder,
            thumbColor: Colors.white,
            overlayColor: MintColors.corailDiscret.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 2,
            ),
            valueIndicatorColor: MintColors.corailDiscret,
          ),
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: montant.clamp(min, max),
            label: fmtChf(montant),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
