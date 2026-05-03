// ────────────────────────────────────────────────────────────────────
//  MintSceneRenteCapital — Handoff 2 Niveau 2 hero scene
// ────────────────────────────────────────────────────────────────────
//
//  Interactive scene posed in the MINT bubble: « Si tu vis jusqu'à
//  X ans, la rente te rapporte plus / coûte plus. » Slider on
//  espérance de vie drives both columns (Rente à vie / Capital placé)
//  in real-time. The « avantageRente » side is highlighted with a
//  white card + dot accent.
//
//  Source of truth:
//    Downloads/handoff 2/03-components.md §4
//    prototype/chat-vivant/scene-rente-capital.jsx
//    SPEC: .planning/specs/SPEC-handoff2-niveau2-scenes.md
//
//  Computation: local, deterministic, NO backend RPC. Reference
//  values + iterative ageEpuisement projection match the JSX
//  prototype exactly so visual parity is byte-identical at any age.
//
//  Variants:
//    • inline   — full card with « Creuser » CTA at bottom
//    • embedded — card without CTA (for canvas-embedded reuse)
//
//  Invariants (Handoff 2 §éditoriaux):
//    • Aucun emoji
//    • UN seul chiffre-héros (les colonnes sont displaySmall, pas Large)
//    • Phrase de recul sur fond craie avec em Fraunces
//    • CTA noir (textPrimary fond, white texte)
// ────────────────────────────────────────────────────────────────────

library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/chat_vivant/mint_life_line_slider.dart';

/// Variant — inline includes the « Creuser » CTA, embedded omits it
/// (for use inside a canvas chapter where the canvas owns its own
/// navigation buttons).
enum MintSceneVariant { inline, embedded }

/// Reference computation values for MintSceneRenteCapital. Static so
/// callers can override defaults via constructor params (typed seeds
/// from ScenePayload, future Phase 55+).
class RenteCapitalSeed {
  final double capitalBrut;
  final double tauxConversion;
  final double impotCapital;
  final double rendementReel;
  final int ageRetraite;

  const RenteCapitalSeed({
    this.capitalBrut = 520000,
    this.tauxConversion = 0.048,
    this.impotCapital = 0.18,
    this.rendementReel = 0.025,
    this.ageRetraite = 65,
  });

  // ── Derived values ──────────────────────────────────────────────

  double get renteAnnuelle => capitalBrut * tauxConversion;
  double get renteMensuelle => renteAnnuelle / 12;
  double get capitalNet => capitalBrut * (1 - impotCapital);
  double get renteAnnuelleNette => renteAnnuelle * 0.80; // 20% revenu tax
  double get depenseAnnuelleEquivalente => renteAnnuelleNette;

  /// Iterative projection — at what age does the capital placé run out
  /// when consumed at the same net rate as the rente nette?
  /// Cap at 110 to avoid infinite loops on degenerate inputs.
  int get ageEpuisement {
    var reste = capitalNet;
    var a = ageRetraite;
    while (reste > 0 && a < 110) {
      reste = reste * (1 + rendementReel) - depenseAnnuelleEquivalente;
      a++;
    }
    return a;
  }

  /// Compute the cumulative rente nette + remaining capital values
  /// at the given age (≥ ageRetraite). Returns ((renteCumulee,
  /// capitalRemaining)) — capitalRemaining clamps at 0.
  ({double renteCumuleeNette, double capitalRestant}) projectionAt(int age) {
    final anneesRetraite = (age - ageRetraite).clamp(0, 999);
    final renteCumulee = renteAnnuelleNette * anneesRetraite;
    var reste = capitalNet;
    for (var i = 0; i < anneesRetraite; i++) {
      reste = reste * (1 + rendementReel) - depenseAnnuelleEquivalente;
    }
    return (
      renteCumuleeNette: renteCumulee,
      capitalRestant: reste.clamp(0.0, double.infinity),
    );
  }
}

/// MintSceneRenteCapital — Niveau 2 hero scene.
///
/// Stateful because the slider drives local re-renders of the columns
/// (no backend RPC — pure local computation per the deterministic
/// projection model in [RenteCapitalSeed]).
class MintSceneRenteCapital extends StatefulWidget {
  /// Reference computation seed. Defaults to the JSX prototype values
  /// (capital 520'000 CHF, taux 4.8%, etc.) so out-of-the-box render
  /// matches the design comp pixel-for-pixel.
  final RenteCapitalSeed seed;

  /// Inline (with Creuser CTA) or embedded (no CTA — for canvas reuse).
  final MintSceneVariant variant;

  /// Fired when the user taps « Creuser » (inline variant only).
  final VoidCallback? onOpenCanvas;

  /// Initial slider age. Defaults to 89 (per JSX prototype default).
  final int initialAge;

  const MintSceneRenteCapital({
    super.key,
    this.seed = const RenteCapitalSeed(),
    this.variant = MintSceneVariant.inline,
    this.onOpenCanvas,
    this.initialAge = 89,
  });

  @override
  State<MintSceneRenteCapital> createState() => _MintSceneRenteCapitalState();
}

class _MintSceneRenteCapitalState extends State<MintSceneRenteCapital> {
  late int _age;

  @override
  void initState() {
    super.initState();
    _age = widget.initialAge;
  }

  // ── Format helpers ─────────────────────────────────────────────────

  /// Swiss CHF format with apostrophe typographique U+2019.
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
    final epuisement = seed.ageEpuisement;
    final projection = seed.projectionAt(_age);
    final avantageRente = _age > epuisement;
    final isInline = widget.variant == MintSceneVariant.inline;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.porcelaine,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border, width: 0.5),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isInline ? 18 : 24,
        vertical: isInline ? 20 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header eyebrow ──
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
                  'ta LPP · ${_fmtChf(seed.capitalBrut)} CHF',
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textMutedAaa,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── Phrase-signature Fraunces (em accents inline) ──
          Text.rich(
            TextSpan(
              style: MintTextStyles.editorialLarge(
                color: MintColors.textPrimary,
              ).copyWith(height: 1.25),
              children: [
                const TextSpan(text: 'Si tu vis jusqu\'à '),
                TextSpan(
                  text: '$_age ans',
                  style: const TextStyle(
                    color: MintColors.corailDiscret,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(text: ', la rente te '),
                TextSpan(
                  text: avantageRente ? 'rapporte plus' : 'coûte plus',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // ── Two columns side-by-side ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SceneColumn(
                  label: 'Rente à vie',
                  amount: projection.renteCumuleeNette,
                  amountText: _fmtChf(projection.renteCumuleeNette),
                  sub: '${_fmtChf(seed.renteMensuelle)} CHF/mois',
                  highlighted: avantageRente,
                  color: MintColors.retirementLpp,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SceneColumn(
                  label: 'Capital placé',
                  amount: seed.capitalNet +
                      (projection.capitalRestant > 0
                          ? projection.capitalRestant
                          : 0),
                  amountText: _fmtChf(seed.capitalNet +
                      (projection.capitalRestant > 0
                          ? projection.capitalRestant
                          : 0)),
                  sub: projection.capitalRestant > 0
                      ? 'reste ${_fmtChf(projection.capitalRestant)}'
                      : 'épuisé à $epuisement ans',
                  highlighted: !avantageRente,
                  color: MintColors.retirement3a,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Slider ──
          MintLifeLineSlider(
            age: _age,
            onAgeChanged: (v) => setState(() => _age = v),
            ageEpuisement: epuisement,
          ),
          const SizedBox(height: 14),
          // ── Phrase de recul (fond craie, em Fraunces) ──
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
                children: avantageRente
                    ? const [
                        TextSpan(
                            text:
                                'Pour toi qui as peu d\'autres revenus, la rente protège '),
                        TextSpan(
                          text: 'contre le risque de vivre longtemps',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                        TextSpan(text: '.'),
                      ]
                    : const [
                        TextSpan(
                            text:
                                'Tu pars tôt — le capital laisse un reste à tes proches.'),
                      ],
              ),
            ),
          ),
          // ── CTA Creuser (inline only, black) ──
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
                        'Creuser — fiscalité, transmission, sensibilité',
                        style: MintTextStyles.titleMedium(color: Colors.white),
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

/// Internal — one of the two side-by-side columns. White card + dot
/// accent when highlighted (avantageRente / !avantageRente flip).
class _SceneColumn extends StatelessWidget {
  final String label;
  final double amount;
  final String amountText;
  final String sub;
  final bool highlighted;
  final Color color;

  const _SceneColumn({
    required this.label,
    required this.amount,
    required this.amountText,
    required this.sub,
    required this.highlighted,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(
        horizontal: highlighted ? 14 : 4,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: highlighted ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? MintColors.border : Colors.transparent,
          width: 0.5,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: MintTextStyles.labelSmall(
                  color: MintColors.textMutedAaa,
                ).copyWith(letterSpacing: 0.2, height: 1.2),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: MintTextStyles.displaySmall(
                    color: highlighted
                        ? MintColors.textPrimary
                        : MintColors.textSecondaryAaa,
                  ).copyWith(
                    fontSize: 24,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(text: amountText),
                    TextSpan(
                      text: ' CHF',
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMutedAaa,
                      ).copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: MintTextStyles.labelSmall(
                  color: highlighted ? color : MintColors.textMutedAaa,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (highlighted)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
