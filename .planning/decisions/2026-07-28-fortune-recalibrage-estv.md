---
date: 2026-07-28
status: Proposed
authors: Claude (synthèse) — panel 3 experts (fiscaliste fortune, ingénieur calibration, product lead)
panel: 3-pers + revue Codex
supersedes: —
superseded_by: —
description: Recalibrer l'impôt fortune par collecte ESTV — fortune NETTE, revenu de référence non nul (bouclier fiscal), 11 points × 2 états civils, montants CHF interpolés, codegen py+dart avec parité ; attribution fausse purgée AVANT toute collecte.
related:
  - .planning/architecture/2026-07-27-HANDOFF.md
  - tools/collect_estv.py
  - services/backend/app/services/fiscal/wealth_tax_service.py
---

# Recalibrer l'impôt sur la fortune par collecte ESTV outillée

## TLDR

La table `EFFECTIVE_WEALTH_TAX_RATES_500K` n'a jamais vu de fortune (archive
collectée à fortune = 0) ; on la remplace par une courbe de montants CHF
collectée par `collect_estv.py` étendu — fortune **nette**, revenu de
référence **non nul** (bouclier fiscal), 11 points × 2 états civils — et on
purge l'attribution fausse **avant** la collecte.

## Contexte

Hand-off 2026-07-27 §3.2 (🔴) : la table porte « Source: OFS Charge Fiscale
2024 », 26 valeurs strictement croissantes sans ex æquo (signal
d'artificialité, §2.1), et l'archive ESTV du 2026-07-23 documente
`fortune imposable = 0` — elle calibre le revenu, pas la fortune. Le
2026-07-28, Julien a délégué les décisions au processus panel + Codex
(« toutes les prochaines questions et décisions : codex et experts
agents »). Panel du 2026-07-28 : trois mémos, deux divergences arbitrées
ci-dessous.

## Décision

1. **Purge d'attribution immédiate, avant toute collecte** (unité
   strings-only) : « OFS Charge Fiscale 2024 » devient « estimation modèle
   simplifié MINT, recalibrage ESTV en cours » — dans `SOURCES` backend
   (`wealth_tax_service.py:145-150`), les en-têtes du miroir Dart, et les
   descriptions d'outils coach (`anthropic_defer_loading_adapter.py:251-262`,
   le vrai vecteur vers l'utilisateur : l'écran fiscal ne rend pas
   l'attribution, le coach oui). La ligne fortune reste affichée (retirer
   sans remplacer = produit vide) ; l'étiquette honnête porte l'attente.
2. **Grille de collecte** : 26 cantons × fortune **NETTE**
   {0, 50k, 100k, 200k, 300k, 500k, 750k, 1M, 2M, 3M, 5M} × 2 états civils
   (Relationship 1 et 2), au revenu de référence **90k (célibataire) /
   110k (marié)**. Stockage des **montants CHF** retournés, interpolation
   linéaire par morceaux, ancre (0, 0), clamp marginal au-delà de 5M.
3. **Arbitrage fiscaliste > ingénieur sur la mécanique** : revenu ≠ 0 (à
   revenu nul, le bouclier fiscal GE/VD écrase artificiellement l'impôt
   fortune) et saisie en fortune **nette** (l'API applique elle-même les
   franchises cantonales — saisir de l'imposable produirait une double
   déduction). Conséquences code : suppression de `WEALTH_ADJUSTMENT`,
   `MARRIED_RATE_FACTOR`, et de la soustraction `WEALTH_TAX_EXEMPTIONS`.
4. **Arbitrage ingénieur > fiscaliste sur le processus** : extension de
   `collect_estv.py` (pas de second script), **pilote 1 canton d'abord** qui
   gèle la convention d'isolation dans `meta.méthode` (lire un éventuel
   champ `WealthTax*` de la réponse complète ; sinon différence
   `TotalTax(I, F) − TotalTax(I, 0)`), sonde GE aux deux conventions
   (bouclier), étape 0 `API_searchLocation` pour les 5 chefs-lieux du lot 4,
   `Confession1` normalisé.
5. **Validation** : intégrité d'archive au franc (consolidated == lot ==
   somme du détail) ; monotonie **faible** par canton seulement (les ex æquo
   réels sont un signe de santé, pas un défaut à lisser) ; points hold-out
   (350k, 1.25M) ≤ 3 % ; interpolation ≤ 5 % relatif.
   **Borne bouclier au runtime** (revue Codex P1) : la courbe collectée est
   income-free par convention, mais le bouclier rend l'impôt fortune
   dépendant du revenu à GE/VD — le service applique donc au runtime un
   plafond dérivé du revenu réel de l'utilisateur (impôt cantonal
   revenu+fortune ≤ ~60 % du revenu net imposable pour les cantons à
   bouclier) et lève l'alerte existante quand le plafond mord ; le modèle
   est étiqueté « hors bouclier » dans ses sources.
6. **Livraison** : les deux tables (py + dart) sont **générées** depuis le
   même JSON archivé, avec test de parité — l'écran fiscal est L1
   offline-capable, pas de délégation backend. Nouvelle table inscrite
   consciemment dans l'allowlist du garde `no_cantonal_rate_table`
   (« donnée sourcée », règle 5.4 du hand-off). Affichage : montant CHF
   arrondi à la centaine + taux effectif ‰ en sous-texte.

## Counter-arguments and data gaps

- **Vue opposée la plus forte** : déléguer le calcul au backend
  supprimerait le miroir Dart et son risque de divergence. Refusé : l'écran
  fiscal est un output L1 chiffrer offline-capable (CLAUDE.md règle 4) —
  le codegen + parité traite le risque de divergence sans casser l'offline.
- **Ce que le panel n'a pas établi** : la sémantique exacte de la réponse
  API pour la fortune (champ dédié ou fondu dans le total) — c'est
  précisément l'objet du pilote ; toute la grille est suspendue à cette
  convention. Le comportement du bouclier fiscal dans le simulateur ESTV
  n'a pas été observé, seulement déduit des textes cantonaux.
- **Limites assumées** : rentiers à revenu quasi nul (le bouclier mord
  réellement → l'estimation surestimera ; l'alerte existante reste) ;
  immobilier en valeur fiscale ≠ titres (l'API traite la fortune en bloc) ;
  barèmes et franchises changent chaque année → cadence de recalibrage
  annuelle à inscrire.
- **Coût** : 26 × 11 × 2 × 2 conventions ≈ 570-1'144 appels réseau à
  exécuter poliment (rate-limit) ; assumé, en 4 lots comme la collecte
  revenu.

## Exécution (unités, dans l'ordre)

U1 purge attribution (strings-only, py + dart + coach) · U2 extension
`collect_estv.py` mode fortune + `API_searchLocation` lot 4 (réseau refusé
par défaut, activé par flag explicite) · U3 pilote 1 canton + sonde GE,
convention gelée · U4 collecte 4 lots + archives · U5 codegen py/dart +
parité + bascule du service + borne bouclier runtime + allowlist garde.

**Dépendance déclarée** (revue Codex P2) : `tools/collect_estv.py` vit sur
la PR #1069 (`codex/journey-os-collect-estv-dry-run`), non fusionnée à la
date de cet ADR — U2-U4 ne démarrent qu'après sa fusion dans `dev`.
