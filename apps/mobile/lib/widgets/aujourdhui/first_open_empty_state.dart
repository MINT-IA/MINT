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
import 'package:shared_preferences/shared_preferences.dart';

/// Hauteur minimale d'une cible tactile (contrat d'accessibilité).
const double kMinTouchTarget = 48;

class FirstOpenEmptyState extends StatefulWidget {
  const FirstOpenEmptyState({
    super.key,
    this.onAddFirstFact,
    this.hasSwissTaxDomicile = true,
  });

  /// Seam de test : par défaut, navigation vers le parcours canonique.
  final VoidCallback? onAddFirstFact;

  /// Faux quand la personne a déclaré n'avoir aucune commune fiscale suisse.
  /// Lui reproposer « d'abord, ta commune » serait la relance que le contrat
  /// de la première ouverture interdit — et une question à laquelle elle
  /// vient de répondre.
  final bool hasSwissTaxDomicile;

  @override
  State<FirstOpenEmptyState> createState() => _FirstOpenEmptyStateState();
}

class _FirstOpenEmptyStateState extends State<FirstOpenEmptyState> {
  /// Clé du refus, PAR DEMANDE et non globale.
  ///
  /// Un booléen local disparaîtrait au moindre rebuild et la demande
  /// reviendrait — ce serait la relance que le contrat interdit. Mais un
  /// booléen unique était pire encore : quelqu'un refusant « Choisir ma
  /// commune », puis déclarant n'avoir aucune commune fiscale suisse, voyait
  /// le MÊME refus masquer la demande de revenu qui prend sa place. Un refus
  /// de commune devenait silencieusement un refus de revenu. Trouvé par la
  /// relecture adversariale.
  static const String declinedKeyPrefix = 'mint_first_open_declined_v2_';

  /// Clé héritée, purgée au premier passage : sa valeur ne dit pas à quelle
  /// demande elle se rapportait, donc elle n'est transposable à aucune.
  static const String legacyDeclinedKey = 'mint_first_open_declined_v1';

  String get _declinedKey =>
      '$declinedKeyPrefix${widget.hasSwissTaxDomicile ? 'commune' : 'revenu'}';

  bool _declined = false;

  @override
  void initState() {
    super.initState();
    _restoreDecline();
  }

  Future<void> _restoreDecline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(legacyDeclinedKey);
    if (!mounted) return;
    if (prefs.getBool(_declinedKey) == true) {
      setState(() => _declined = true);
    }
  }

  Future<void> _decline() async {
    setState(() => _declined = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_declinedKey, true);
  }

  Future<void> _resume() async {
    setState(() => _declined = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_declinedKey);
  }

  void _addFirstFact() {
    if (widget.onAddFirstFact != null) {
      widget.onAddFirstFact!();
      return;
    }
    // Le premier prérequis canonique manquant — aucun autre moteur de
    // collecte n'est sollicité. Sans commune fiscale suisse, ce prérequis
    // n'existe pas : le revenu prend sa place, il ne dépend d'aucun
    // territoire.
    context.go(widget.hasSwissTaxDomicile
        ? '/mint-next/domicile'
        : '/mint-next/revenu');
  }

  @override
  void didUpdateWidget(FirstOpenEmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La demande a changé : le refus de la précédente ne dit rien de
    // celle-ci. On relit, on ne transpose pas.
    if (oldWidget.hasSwissTaxDomicile != widget.hasSwissTaxDomicile) {
      setState(() => _declined = false);
      _restoreDecline();
    }
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
                  widget.hasSwissTaxDomicile
                      ? l.firstOpenEmptyTitle
                      : l.firstOpenEmptyTitleNoCommune,
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
                    widget.hasSwissTaxDomicile
                      ? l.firstOpenFirstFactRationale
                      : l.firstOpenFirstFactRationaleNoCommune,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary),
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                // Un SEUL nœud par action : le bouton fournit déjà rôle,
                // libellé et action — un wrapper `button: true` par-dessus
                // produirait une annonce VoiceOver dupliquée. La hauteur
                // est un MINIMUM, jamais un plafond (troncature à 200 %).
                Semantics(
                  identifier: 'action:today.add_first_fact',
                  child: FilledButton(
                    // lint-ignore: prefer_mint_cta
                    onPressed: _addFirstFact,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(kMinTouchTarget),
                      padding: const EdgeInsets.symmetric(
                          vertical: MintSpacing.sm),
                    ),
                    child: Text(widget.hasSwissTaxDomicile
                        ? l.firstOpenAddFirstFact
                        : l.firstOpenAddFirstFactNoCommune),
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Semantics(
                  identifier: 'action:today.decline_first_fact',
                  // « Plus tard » est ambigu hors contexte visuel.
                  label: l.firstOpenDeclineFirstFactA11y,
                  child: TextButton(
                    // lint-ignore: prefer_mint_cta
                    onPressed: _decline,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(kMinTouchTarget),
                    ),
                    child: Text(l.firstOpenDeclineFirstFact),
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
                Semantics(
                  identifier: 'action:today.resume_first_fact',
                  child: TextButton(
                    // lint-ignore: prefer_mint_cta
                    onPressed: _resume,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(kMinTouchTarget),
                    ),
                    child: Text(l.firstOpenResumeFirstFact),
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
