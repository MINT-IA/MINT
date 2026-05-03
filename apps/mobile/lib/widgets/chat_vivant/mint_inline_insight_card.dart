// ────────────────────────────────────────────────────────────────────
//  MintInlineInsightCard — Handoff 2 Niveau 1 (inline scene)
// ────────────────────────────────────────────────────────────────────
//
//  Une petite carte éditoriale posée dans la bulle MINT, pas un
//  widget grisâtre. Source de vérité du design :
//    Downloads/handoff 2/03-components.md §1
//    Downloads/handoff 2/prototype/chat-vivant/insight-card.jsx
//
//  Anatomie (de haut en bas) :
//    1. Label eyebrow — labelMedium 10.5pt corailDiscret uppercase
//       letterSpacing 1.2 (ou successAaa pour tone.sauge)
//    2. Headline — editorialLarge (Fraunces 22pt italic) Text.rich
//       supporté pour les `em` Fraunces inline
//    3. Supporting (optionnel) — bodySmall textSecondaryAaa
//
//  Tones supportés (couleur de fond + accent label) :
//    • porcelaine — défaut, fond hero chaud + accent corailDiscret
//    • sauge       — bonne nouvelle, fond saugeClaire + accent successAaa
//    • peche       — milestone, fond pecheDouce 35% + accent corailDiscret
//    • craie       — neutre coach, fond craie + accent corailDiscret
//
//  Invariants Handoff 2 (00-README.md §éditoriaux) :
//    • Aucun emoji.
//    • Un seul chiffre-héros par vue (le headline porte le poids visuel).
//    • Fraunces = signature éditoriale, pas pour body long.
//    • CTA dans les scènes = noirs (textPrimary fond, white texte).
// ────────────────────────────────────────────────────────────────────

library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Tone variants — selects the surface color + label accent of an
/// inline insight card. Each tone reflects a conversational moment :
///
/// * [porcelaine] — neutral hero (default), warm cream surface, coral label.
/// * [sauge]      — positive insight (« 63 % de ton train de vie »),
///                   sage-green surface, deep-success label (AAA contrast).
/// * [peche]      — milestone / warmth moment, soft peach surface, coral label.
/// * [craie]      — coach-neutral surface, blends with the chat background,
///                   coral label.
enum MintInsightTone { porcelaine, sauge, peche, craie }

/// MintInlineInsightCard — Handoff 2 Niveau 1 (inline scene).
///
/// Renders an editorial card inside a MINT bubble. The headline is a
/// [Widget] (not a [String]) so callers can use [Text.rich] to mix
/// Fraunces italic `em` words with the default editorialLarge body —
/// matching the « Tu as 58 ans. *7 ans avant la retraite.* » pattern
/// from the Handoff 2 prototype `01-chat-comparison.png`.
///
/// Example :
/// ```dart
/// MintInlineInsightCard(
///   label: 'CE QUI COMPTE VRAIMENT',
///   headline: Text(
///     'Tu n\'as pas besoin de choisir tout de suite.',
///     style: MintTextStyles.editorialLarge(),
///   ),
///   supporting: 'Tu dois décider 3 ans avant.',
///   tone: MintInsightTone.craie,
/// )
/// ```
class MintInlineInsightCard extends StatelessWidget {
  /// Eyebrow label, uppercase, letterSpacing 1.2, accent color per tone.
  /// Per Handoff 2 invariant : labels horodatés / accent moments.
  final String label;

  /// Editorial headline. Pass a plain [Text] with
  /// `MintTextStyles.editorialLarge()` for the default look, or a
  /// [Text.rich] with mixed [TextSpan]s for `em` accents.
  final Widget headline;

  /// Optional supporting text below the headline. bodySmall, textSecondaryAaa.
  final String? supporting;

  /// Visual tone — selects fond + label accent. Defaults to
  /// [MintInsightTone.porcelaine] (warm hero).
  final MintInsightTone tone;

  /// Optional [Semantics] label for screen readers. When omitted, the
  /// label + headline + supporting are concatenated automatically.
  final String? semanticsLabel;

  const MintInlineInsightCard({
    super.key,
    required this.label,
    required this.headline,
    this.supporting,
    this.tone = MintInsightTone.porcelaine,
    this.semanticsLabel,
  });

  // ── Tone resolution ─────────────────────────────────────────────────

  Color get _backgroundColor {
    switch (tone) {
      case MintInsightTone.sauge:
        return MintColors.saugeClaire;
      case MintInsightTone.peche:
        return MintColors.pecheDouce.withValues(alpha: 0.35);
      case MintInsightTone.craie:
        return MintColors.craie;
      case MintInsightTone.porcelaine:
        return MintColors.porcelaine;
    }
  }

  Color get _labelAccent {
    // Sauge → AAA-compliant deep success green so the eyebrow keeps its
    // editorial weight against the saugeClaire surface (corail on sauge
    // background fails 4.5:1 contrast). All other tones use the
    // signature coral.
    switch (tone) {
      case MintInsightTone.sauge:
        return MintColors.successAaa;
      case MintInsightTone.porcelaine:
      case MintInsightTone.peche:
      case MintInsightTone.craie:
        return MintColors.corailDiscret;
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.border,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eyebrow label — uppercase, accent color.
          Text(
            label.toUpperCase(),
            style: MintTextStyles.labelMedium(color: _labelAccent).copyWith(
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          SizedBox(height: supporting != null ? 6 : 4),
          // Editorial headline. Wrapped in DefaultTextStyle so callers
          // who pass a bare Text() with no style get editorialLarge
          // automatically — matches the JSX prototype default.
          DefaultTextStyle.merge(
            style: MintTextStyles.editorialLarge(
              color: MintColors.textPrimary,
            ).copyWith(height: 1.3),
            child: headline,
          ),
          if (supporting != null) ...[
            const SizedBox(height: 6),
            Text(
              supporting!,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondaryAaa,
              ).copyWith(fontWeight: FontWeight.w400, height: 1.4),
            ),
          ],
        ],
      ),
    );

    // Default semantics : concatenate label + headline-text + supporting
    // for screen readers when caller hasn't supplied a custom label.
    if (semanticsLabel != null) {
      return Semantics(label: semanticsLabel, container: true, child: card);
    }
    return Semantics(container: true, child: card);
  }
}
