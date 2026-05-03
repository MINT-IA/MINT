// ────────────────────────────────────────────────────────────────────
//  MintRatioCard — Handoff 2 Niveau 1 spécialisé (proportion)
// ────────────────────────────────────────────────────────────────────
//
//  « 63 % — c'est ce que tu gardes. » Petit widget qui montre une
//  proportion vive (ratio numerator/denominator). Source de vérité :
//    Downloads/handoff 2/03-components.md §2
//    Downloads/handoff 2/prototype/chat-vivant/insight-card.jsx
//      (composant `RatioCard`)
//
//  Anatomie (de haut en bas) :
//    1. Label eyebrow — labelMedium 10.5pt corailDiscret uppercase
//       letterSpacing 1.2
//    2. Row baseline-aligned :
//        • Gros chiffre % en Montserrat 44pt textPrimary lineHeight 1.0
//        • Sous-titre « {numerator} sur {denominator} CHF/mois »
//          bodySmall textSecondaryAaa
//    3. Barre de proportion gradient retirementLpp → retirementAvs,
//       hauteur 6px, fond lightBorder
//    4. Explainer — bodySmall textSecondaryAaa lineHeight 1.5
//
//  Notes :
//    • Pas de tone variant (toujours porcelaine — le ratio est neutre).
//    • Le pourcentage est calculé localement, pas reçu du backend
//      (Niveau 1 : pas de RPC, juste du visuel).
//    • Format CHF suisse : apostrophe typographique U+2019 séparateur
//      de milliers (« 4'416 », jamais « 4,416 » ou « 4416 »).
// ────────────────────────────────────────────────────────────────────

library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// MintRatioCard — Handoff 2 Niveau 1 spécialisé.
///
/// Renders a proportion (numerator on denominator) with a gradient
/// progression bar. Used inline in coach bubbles to give the user a
/// visual handle on a ratio they just heard mentioned in text — e.g.
/// « 63 % de ton train de vie », « 78 % des ans pour ta rente AVS ».
///
/// Example :
/// ```dart
/// MintRatioCard(
///   label: 'TON TRAIN DE VIE COUVERT',
///   numerator: 4416,
///   denominator: 7000,
///   explainer: 'Au taux actuel, ta rente AVS + LPP couvre cette part.',
/// )
/// ```
class MintRatioCard extends StatelessWidget {
  /// Eyebrow label, uppercase, accent corailDiscret.
  final String label;

  /// Numerator value (CHF/mois). Drives the gradient bar fill width.
  final double numerator;

  /// Denominator value (CHF/mois). Used for the percentage + sub-label.
  /// Must be > 0 — the widget guards a null/zero denominator silently
  /// (renders 0 % rather than crashing with a divide-by-zero).
  final double denominator;

  /// Explainer body text below the gradient bar.
  final String explainer;

  /// Optional [Semantics] label override. When omitted, the percentage
  /// + label + explainer are exposed to screen readers automatically.
  final String? semanticsLabel;

  const MintRatioCard({
    super.key,
    required this.label,
    required this.numerator,
    required this.denominator,
    required this.explainer,
    this.semanticsLabel,
  });

  // ── Computation (local, no backend) ─────────────────────────────────

  int get _percentage {
    if (denominator <= 0) return 0;
    return ((numerator / denominator) * 100).round().clamp(0, 100);
  }

  /// Format an integer CHF amount with Swiss thousands separators
  /// (apostrophe typographique U+2019). 4416 → « 4'416 », 1234567
  /// → « 1'234'567 ». Negative values are formatted as positive
  /// (the card is for positive proportions only).
  static String _fmtChf(num value) {
    final rounded = value.abs().round();
    final digits = rounded.toString();
    return digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}’',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = _percentage;
    final card = Container(
      decoration: BoxDecoration(
        color: MintColors.porcelaine,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.border,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eyebrow label.
          Text(
            label.toUpperCase(),
            style: MintTextStyles.labelMedium(
              color: MintColors.corailDiscret,
            ).copyWith(
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          // Big % number + subtitle row, baseline-aligned.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // 44pt Montserrat percentage. Use Text.rich to scale the
              // « % » sign down to 26pt textSecondaryAaa per JSX
              // prototype (`<span style={{ fontSize: 26, color, fontWeight: 600 }}>%</span>`).
              Text.rich(
                TextSpan(
                  text: '$pct',
                  style: MintTextStyles.displayLarge(
                    color: MintColors.textPrimary,
                  ).copyWith(
                    fontSize: 44,
                    height: 1.0,
                    letterSpacing: -0.8,
                  ),
                  children: [
                    TextSpan(
                      text: ' %', // U+2009 thin space avant le %
                      style: MintTextStyles.displayMedium(
                        color: MintColors.textSecondaryAaa,
                      ).copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_fmtChf(numerator)} sur ${_fmtChf(denominator)} CHF/mois',
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondaryAaa,
                    ).copyWith(fontWeight: FontWeight.w400, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Gradient proportion bar.
          _GradientBar(percentage: pct),
          const SizedBox(height: 10),
          // Explainer.
          Text(
            explainer,
            style: MintTextStyles.bodySmall(
              color: MintColors.textSecondaryAaa,
            ).copyWith(fontWeight: FontWeight.w400, height: 1.5),
          ),
        ],
      ),
    );

    if (semanticsLabel != null) {
      return Semantics(label: semanticsLabel, container: true, child: card);
    }
    return Semantics(
      container: true,
      label: '$label : $pct pour cent. $explainer',
      child: ExcludeSemantics(child: card),
    );
  }
}

/// Internal — the 6px-tall gradient bar that visualises the percentage.
/// Background = lightBorder, fill = LPP green → AVS blue gradient.
class _GradientBar extends StatelessWidget {
  final int percentage;

  const _GradientBar({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        width: double.infinity,
        child: Stack(
          children: [
            // Background track.
            Container(color: MintColors.lightBorder),
            // Filled portion — gradient from retirementLpp to retirementAvs
            // matching the JSX prototype linear-gradient(90deg, lpp, avs).
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100.0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      MintColors.retirementLpp,
                      MintColors.retirementAvs,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
