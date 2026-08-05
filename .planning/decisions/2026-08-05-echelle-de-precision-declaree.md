---
date: 2026-08-05
status: Proposed
authors: Julien Battaglia (product owner, question posée), Claude (lead, arbitrage délégué)
panel: single
supersedes: —
superseded_by: —
description: Collecte par tranches d'abord ; raffinement en place tiré par la valeur (tranche → exact → document) ; la fourchette se resserre mais ne s'effondre jamais.
related:
  - .planning/decisions/2026-08-04-experience-navigation-compagnon.md
  - .planning/decisions/2026-08-03-doctrine-reconstruction-mint.md
---

# Échelle de précision déclarée — tranches d'abord, raffinage en place

## TLDR

Les faits chiffrés se collectent d'abord en tranches (effort minimal, honnêteté maximale) ; ils se raffinent en place, tirés par la valeur au moment du payoff — tranche → valeur exacte → document — sans jamais re-demander, et la fourchette de sortie se resserre sans jamais s'effondrer en chiffre unique tant que des approximations moteur subsistent.

## Context

Revue du batch R3 (arc éclairage) : le product owner soulève la tension « si on commence par des estimations, il faudra quand même faire l'effort des chiffres précis plus tard » et délègue l'arbitrage. Précédent interne : la régression corrigée par #1061 — un chiffre affiché précis mais surestimé de 25 à 77 % parce que la précision de l'affichage dépassait celle du calcul. Infrastructure existante alignée : score de confiance multi-axes avec invitations d'enrichissement (doctrine projection), parseurs de documents (certificat de salaire, taxation) dans la bibliothèque legacy.

## Decision

- **Entrée, moteur et sortie montent en précision ensemble.** La précision demandée à l'utilisateur ne dépasse jamais celle que le moteur peut honnêtement restituer.
- **Collecte par défaut = tranche** (une touche, répondable de mémoire). La largeur de la fourchette rendue est dérivée des bornes de tranche et des approximations moteur — jamais d'un ± décoratif.
- **Raffinement tiré par la valeur** : sur l'écran de restitution, chaque hypothèse affichée est une action de raffinage optionnelle (tranche → valeur exacte déclarée → document importé). L'effort est demandé au moment de motivation maximale, jamais à l'accueil.
- **Raffiner remplace en place** : même fait, résolution et provenance mises à niveau. On ne repose jamais une question déjà répondue.
- **La fourchette se resserre mais ne s'effondre jamais** en chiffre unique tant que des approximations moteur subsistent.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  Demander la valeur exacte d'emblée simplifie le modèle de données (une seule résolution), évite un mécanisme de raffinage à construire et à tester, et correspond aux attentes d'utilisateurs habitués aux formulaires financiers ; pour un sujet d'impôts, des tranches peuvent paraître peu sérieuses. Et si personne ne raffine jamais, les données restent grossières et les restitutions plafonnent.
- **What does this source not address ?**
  Aucune mesure de taux d'abandon tranche-vs-exact sur nos écrans ; taux de raffinage réel inconnu (aucun utilisateur) ; pas de test de perception « sérieux vs approximatif » ; le coût d'implémentation du remplacement en place (modèle de provenance par fait) n'est pas chiffré.
- **What would change this conclusion ?**
  Un taux de raffinage proche de zéro en usage réel (les invitations d'enrichissement ne suffiraient pas) ; une source externe sans effort (API bancaire/LPP, import de documents fiable) qui rendrait la valeur exacte aussi peu coûteuse que la tranche — l'échelle sauterait alors des barreaux ; un retour utilisateur montrant que les tranches minent la confiance sur le sujet fiscal.

## Sources

- `services/backend/app/services/fiscal/cantonal_comparator.py` (étalon, points de calibration, estimation par différence)
- `services/backend/app/services/document_parser/tax_declaration_parser.py` (import de taxation, bibliothèque)
- Commit c62d70682 (#1061) — régression « chiffre précis mais faux », origine du principe
- Revue R3 du 2026-08-05 (galerie, maquettes fact_revenu / eclairage_impot_3a)

## Status & follow-up

- Implementation tracking : amendement des drafts de contrat R3 (état de raffinage, action par hypothèse, largeur minimale de fourchette) — batch R3, avant scellement.
- Re-litigation triggers : les trois signaux listés ci-dessus ; arrivée d'une source de données externe sans effort.

---
*Template v1 — Wiki Pattern Karpathy practice 3 enforced by `tools/checks/wiki_lint.py`.*
