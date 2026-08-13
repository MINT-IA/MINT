// Bascule 4 — l'état vide de la première ouverture.
//
// Contrat : product/mint_next/storyboard/first_open.storyboard.json, beat
// b4_empty_today. Décisions des 4 axes Codex (synthèse au wiki) :
//
//  * c'est un écran d'ACTION, pas d'absence ;
//  * exactement UNE action de collecte primaire, SPÉCIFIQUE (le domicile
//    fiscal) et accompagnée de sa justification — une action générique
//    ramènerait au catalogue et priverait du « pourquoi » ;
//  * le refus est un choix normal : il ferme sans relance et SANS
//    substituer une autre question (sinon questionnaire déguisé) ;
//  * aucune progression numérique, aucune jauge, aucun chiffre : la
//    matière éditoriale du vertical 3a sans ses métriques ;
//  * un seul nœud sémantique par action, sélectionné par identifiant.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Hauteur minimale d'une cible tactile (contrat d'accessibilité).
const double kMinTouchTarget = 48;

class FirstOpenEmptyState extends StatefulWidget {
  const FirstOpenEmptyState({super.key, this.onAddFirstFact});

  /// Seam de test : par défaut, navigation vers le parcours canonique.
  final VoidCallback? onAddFirstFact;

  @override
  State<FirstOpenEmptyState> createState() => _FirstOpenEmptyStateState();
}

class _FirstOpenEmptyStateState extends State<FirstOpenEmptyState> {
  bool _declined = false;

  void _addFirstFact() {
    if (widget.onAddFirstFact != null) {
      widget.onAddFirstFact!();
      return;
    }
    // Le premier prérequis canonique manquant — aucun autre moteur de
    // collecte n'est sollicité.
    context.go('/mint-next/domicile');
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Semantics(
      identifier: 'screen:today.empty',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: MintColors.porcelaine,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.firstOpenEmptyEyebrow.toUpperCase(),
                style: MintTextStyles.labelMedium(
                        color: MintColors.textSecondary)
                    .copyWith(letterSpacing: 1.2),
              ),
              const SizedBox(height: MintSpacing.sm),
              // Ordre de lecture : promesse → état factuel → action.
              Semantics(
                identifier: 'node:today.empty_editorial',
                child: Text(
                  l.firstOpenEmptyTitle,
                  style: MintTextStyles.editorialLarge(
                      color: MintColors.textPrimary),
                ),
              ),
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'status:today.no_financial_facts',
                child: Text(
                  l.firstOpenEmptyProof,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary),
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
              if (!_declined) ...[
                Semantics(
                  identifier: 'node:today.first_fact_rationale',
                  child: Text(
                    l.firstOpenFirstFactRationale,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary),
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: kMinTouchTarget + 6,
                  child: Semantics(
                    identifier: 'action:today.add_first_fact',
                    button: true,
                    child: FilledButton(
                      // lint-ignore: prefer_mint_cta
                      onPressed: _addFirstFact,
                      child: Text(l.firstOpenAddFirstFact),
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  height: kMinTouchTarget,
                  child: Semantics(
                    identifier: 'action:today.decline_first_fact',
                    button: true,
                    child: TextButton(
                      // lint-ignore: prefer_mint_cta
                      onPressed: () => setState(() => _declined = true),
                      child: Text(l.firstOpenDeclineFirstFact),
                    ),
                  ),
                ),
              ] else ...[
                // Refus : aucune relance, AUCUNE question substituée —
                // l'écran reste utilisable et propose une reprise stable.
                Semantics(
                  identifier: 'status:today.first_fact_declined',
                  child: Text(
                    l.firstOpenDeclinedNote,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary),
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: kMinTouchTarget,
                  child: Semantics(
                    identifier: 'action:today.resume_first_fact',
                    button: true,
                    child: TextButton(
                      // lint-ignore: prefer_mint_cta
                      onPressed: () => setState(() => _declined = false),
                      child: Text(l.firstOpenResumeFirstFact),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
