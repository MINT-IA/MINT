---
description: Constat §3.4 du hand-off 2026-07-27 — CANTON_SUCCESSION_TAX de succession_simulator (12/26, aucune source) alimente des montants d'impôt affichés par catégorie d'héritier et une alerte concubin, avec fallback silencieux pour 14 cantons. La table appartient à la classe d'erreur déjà tranchée par #1058 : GE tiers affiché 26 % contre ~54 % réels (centimes additionnels +110 % ignorés). Décision 🔴 : le remplacement, pas la suppression sèche.
---

# Constat — succession_simulator : la table de taux plats survit à la décision #1058

Ligne §3.4 du hand-off `2026-07-27-HANDOFF.md` : `succession_simulator.py:83`,
couverture 12/26, source déclarée : aucune. Phase 1 (« prouver ») seulement.

## 1. Qui appelle, et ce qui atteint l'écran

`CANTON_SUCCESSION_TAX` (`:83`, 12 cantons × 6 catégories d'héritiers,
taux plats) a **deux lecteurs**, tous deux user-facing :

1. `_compute_succession_tax` (`:528`) — `montant hérité × taux plat` par
   catégorie (conjoint, descendants, parents, fratrie, concubin, tiers),
   retourné dans `tax_details` avec le montant d'impôt **affiché par
   héritier**.
2. `_generate_alerts` (`:760`) — alerte concubin citant le taux du canton
   en clair (« le taux d'imposition successorale pour les concubins est
   de X % »).

Surface : `endpoints/life_events.py` (`SuccessionSimulator` instancié
`:66`) ; écrans mobiles succession/concubinage/décès d'un proche.

Fallback : les **14 cantons absents** reçoivent `DEFAULT_TAX_RATES`
(fratrie 8 %, concubin 22 %, tiers 25 %) **silencieusement** — dont NW,
dont on a prouvé cette semaine (PR #1058, deux sources) qu'il impose les
non-parents à 15 % après franchise de 20'000 CHF, avec exonération du
concubin après 5 ans de ménage commun. Le défaut fabrique donc un taux
pour la moitié du pays.

## 2. Écart contre sources primaires — la classe d'erreur de #1058

**GE (dans la table)** : `tiers: 0.26`. Réalité (ge.ch, notaires de
Genève, LDS rsGE D 3 25) : barème progressif **plus centimes
additionnels de 110 % des droits** (sauf 1ʳᵉ catégorie) → les tiers sans
lien de parenté paient **jusqu'à ~54 %**. La table sous-estime d'un
facteur ~2 au sommet — elle encode le barème de base et ignore les
centimes.

**NW (hors table → défaut)** : concubin 22 %/tiers 25 % servis, contre
15 % après franchise 20'000 CHF et exonération du concubin ≥ 5 ans de
vie commune (vérifié 2 sources, PR #1058). Ici le défaut **sur**-estime
et rate deux mécanismes (franchise, exonération).

C'est mot pour mot la classe d'erreur qui a fait retirer
`_inheritanceTaxRatesNonMarie` / `TAUX_SUCCESSION_PAR_CANTON` (PR #1058,
commentaire anti-résurrection dans `family_service.dart:234`) : « le
domaine est trop fin pour un taux plat : barèmes tantôt progressifs,
franchises variables, et plusieurs cantons (VD, FR, GR) ajoutent un
impôt communal qui peut presque doubler la charge. » La présente table
est la **jumelle survivante** de celles retirées — même service, même
classe de chiffre, non couverte par la décision de l'époque parce
qu'elle vit dans `succession_simulator` et non dans le couple
`family_service`/`TAUX_SUCCESSION_PAR_CANTON`.

## 3. Ce que la suppression sèche casserait

- les montants d'impôt par héritier de `deces_proche`/succession ;
- l'alerte concubin — qui porte un message **directionnellement juste et
  utile** (concubin lourdement taxé → mariage/pacte exonère) même quand
  son chiffre est faux.

Le reproche « produit vide » de l'audit s'applique en plein : ce
simulateur est une des rares surfaces où MINT dit quelque chose que
l'utilisateur ne sait pas déjà.

## 4. Verdict — décision 🔴 (hand-off §4.5), options instruites

1. **Directionnel sans chiffre** : garder les catégories exonérées
   (conjoint/descendants, vrai presque partout) et remplacer les taux
   fratrie/concubin/tiers par des plages sourcées par canton («
   GE : jusqu'à ~54 % ») — cohérent avec la règle 6 du hand-off (un
   chiffre retiré cède la place à un objet utile).
2. **Recalibrage** : barèmes progressifs par canton + franchises — c'est
   un chantier de collecte de 26 lois cantonales, la version «
   collect_estv » de la fiscalité successorale. Coût élevé.
3. **Statu quo étiqueté** : garder les taux plats en les déclarant
   « ordre de grandeur, hors centimes additionnels et franchises » —
   incompatible avec la ligne « chiffres défendables » de la campagne.

L'option 1 est la seule qui soit à la fois honnête et livrable en une
unité ; elle suit la décision déjà prise pour #1058. À trancher par
Julien avant toute implémentation (⛔).

## 5. Limites

- Deux cantons ancrés (GE primaire-adjacent via ge.ch/LDS ; NW via la
  double vérification de #1058). Les 10 autres cantons de la table n'ont
  pas été comparés ligne à ligne.
- `deces_proche_screen`/`concubinage_screen` identifiés par grep comme
  surfaces ; le rendu exact du `tax_details` n'a pas été retracé widget
  par widget.

Sources : [ge.ch — estimer l'impôt sur la succession](https://www.ge.ch/impots-cas-deces/estimer-impot-succession) · [Notaires de Genève — les successions](https://notaires-geneve.ch/docview/262/Succession.pdf) · [rsGE D 3 25 — LDS](https://silgeneve.ch/legis/data/rsg_d3_25.htm)
