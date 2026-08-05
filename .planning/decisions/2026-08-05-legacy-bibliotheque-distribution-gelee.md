---
date: 2026-08-05
status: Proposed
authors: Julien Battaglia (product owner), Claude (lead)
panel: single
supersedes: —
superseded_by: —
description: La distribution de l'app legacy est gelée ; le legacy sert de bibliothèque et de source d'inspiration ; MINT Next est le seul chemin produit.
related:
  - .planning/decisions/2026-08-03-doctrine-reconstruction-mint.md
  - .planning/decisions/2026-08-04-experience-navigation-compagnon.md
---

# La distribution de l'app legacy est gelée — le legacy devient bibliothèque

## TLDR

La distribution TestFlight de l'app legacy est gelée ; le legacy sert de bibliothèque active (backend fiscal, financial_core) et de source d'inspiration UX ; MINT Next est le seul chemin produit.

## Context

La reconstruction MINT Next (voir `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md`) suit le motif strangler-fig : construction parallèle sous `product/mint_next/`, legacy maintenu vivant. Restait ouverte la question de la distribution : la branche `dev` porte une série de correctifs de l'app legacy déjà fusionnés, et la reprise des envois TestFlight était en attente d'arbitrage du product owner. Le 2026-08-05, le product owner tranche en session : l'app legacy ne répond plus au niveau d'exigence produit ; elle sert de source d'inspiration, pas de véhicule de distribution.

## Decision

- La distribution de l'app legacy (TestFlight) est gelée. La question de sa reprise n'est plus posée par défaut ; seule une décision explicite du product owner la rouvrirait.
- Le legacy reste vivant comme **bibliothèque** : les organes que MINT Next enlace (modèles fiscaux étalon ESTV sous `services/backend/app/services/fiscal/`, `apps/mobile/lib/services/financial_core/`) restent maintenus, testés, CI verte requise.
- Le legacy reste une **source d'inspiration** : parcours, copies, mécanismes existants sont du matériau de fouille pour MINT Next, jamais un standard à égaler.
- Les correctifs legacy déjà fusionnés dans `dev` servent la santé de la bibliothèque ; ils ne déclenchent pas de distribution.
- MINT Next reste en design lab non promu (`product_promotion: forbidden` dans ses contrats) jusqu'à décision explicite du product owner.
- Conséquence assumée : aucune distribution utilisateur pendant la construction de MINT Next. La levée de cet état est une décision explicite du product owner ; le critère de bascule sera défini à ce moment-là.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  Les correctifs vérifiés dans `dev` couvrent des défauts que le product owner a lui-même rencontrés sur device ; les geler prive le seul utilisateur réel de correctifs prêts, et un canal de distribution qui ne tourne plus se dégrade (signing, review Apple, workflows). Distribuer le legacy corrigé aurait aussi fourni un banc d'essai réel pendant la construction de MINT Next.
- **What does this source not address ?**
  Aucune mesure du coût de remise en route du canal TestFlight après une longue pause (certificats, profils, review). Pas de date de fin de vie du backend legacy ni d'inventaire exhaustif des organes-bibliothèque effectivement enlacés vs code mort. Pas de critère chiffré de bascule « MINT Next distribuable ».
- **What would change this conclusion ?**
  Un besoin de test utilisateur réel avant que MINT Next n'atteigne un parcours complet distribuable ; ou une exigence externe (Apple, partenaire) imposant un binaire à jour ; ou la découverte qu'un organe-bibliothèque ne peut être maintenu sans distribution de l'app hôte.

## Sources

- `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md` (doctrine reconstruction, strangler-fig)
- `.planning/decisions/2026-08-04-experience-navigation-compagnon.md` (North Star expérience MINT Next)
- Arbitrage product owner du 2026-08-05 (session de revue des écrans batch20)

## Status & follow-up

- Implementation tracking : aucun changement de code requis ; les items d'exploitation liés à la distribution legacy (vérification register Apple post-promotion staging, pipeline TestFlight) passent en priorité dormante.
- Mécanisme de gel effectif : le pipeline TestFlight ne se déclenche que sur promotion vers `staging` ; aucune promotion `dev`→`staging` n'est effectuée. Un verrou mécanique du workflow peut être ajouté en durcissement ultérieur.
- Re-litigation triggers : les trois signaux listés en counter-arguments ; toute demande explicite du product owner.

---
*Template v1 — Wiki Pattern Karpathy practice 3 enforced by `tools/checks/wiki_lint.py`.*
